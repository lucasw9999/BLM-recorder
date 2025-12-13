#import "TrajectoryEstimator.h"
#import "SettingsManager.h"
@import CoreML; // Needed for MLModel, etc.

float puttDistanceYardsFromMphAndStimp(float mph, float stimp) {
    const float fpsToMph = 0.6818181818181818;
    float feetPerSecond = mph / fpsToMph;
    float stimpmeterVelocityFeetPerSecond = 6.0; // USGA says 6 ft/s :shrug:
    float drag = stimpmeterVelocityFeetPerSecond / stimp;
    float distFeet = feetPerSecond / drag;
    return distFeet;
}

float calculateOfflineDistance(float distance, float hla) {
    float hlaRadians = hla * M_PI / 180.0;
    return distance * sin(hlaRadians);
}

static inline float signf(float x) {
    return (x > 0.0f) ? 1.0f : ((x < 0.0f) ? -1.0f : 0.0f);
}


@interface TrajectoryEstimator ()

@property (nonatomic, strong) MLModel *modelHeight;
@property (nonatomic, strong) MLModel *modelLateralSpin;
@property (nonatomic, strong) MLModel *modelRoll;

@end

@implementation TrajectoryEstimator

+ (instancetype)shared {
    static TrajectoryEstimator *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TrajectoryEstimator alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize models to nil - will be loaded lazily when needed
        _modelHeight = nil;
        _modelLateralSpin = nil;
        _modelRoll = nil;
    }
    return self;
}

/// Helper that loads the compiled model ( .mlmodelc ) from the main bundle
- (MLModel *)loadCompiledModelNamed:(NSString *)modelBaseName {
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:modelBaseName withExtension:@"mlmodelc"];
    if (!modelURL) {
        NSLog(@"Error: Could not find model resource %@.mlmodelc", modelBaseName);
        return nil;
    }

    NSError *error = nil;
    MLModel *model = [MLModel modelWithContentsOfURL:modelURL error:&error];
    if (error) {
        NSLog(@"Error loading model %@: %@", modelBaseName, error);
        return nil;
    }
    return model;
}

/// Ensures all trajectory models are loaded before use
- (BOOL)ensureModelsLoaded {
    if (self.modelHeight && self.modelLateralSpin && self.modelRoll) {
        return YES; // All models already loaded
    }

    // Load models lazily
    self.modelHeight = [self loadCompiledModelNamed:@"trajectory_model_height_ft"];
    self.modelLateralSpin = [self loadCompiledModelNamed:@"trajectory_model_lateral_spin_yd"];
    self.modelRoll = [self loadCompiledModelNamed:@"trajectory_model_roll_yd"];

    // Return YES only if all models loaded successfully
    return (self.modelHeight && self.modelLateralSpin && self.modelRoll);
}

/// Reads the 5 inputs from `ballData`, runs inference on all three models,
/// then writes "RollDistance", "LateralSpin", and "Height" back into `ballData`.
- (void)processBallData:(NSMutableDictionary *)ballData {
    
    // 1) Extract the five input values from the dictionary
    //    (Make sure they exist; otherwise, handle missing keys or use defaults)
    float speed         = [ballData[@"Speed"] floatValue];         // mph
    float hla           = [ballData[@"HLA"] floatValue];           // degrees
    float vla           = [ballData[@"VLA"] floatValue];           // degrees
    float carryDistance = [ballData[@"CarryDistance"] floatValue]; // yards
    float spinAxis      = [ballData[@"SpinAxis"] floatValue];      // degrees
    float totalSpin     = [ballData[@"TotalSpin"] floatValue];     // rpm
    
    // Handle putt data as a special case, just compute distance from speed+stimp
    if([ballData[@"IsPutt"] boolValue]) {
        float stimp = (float)[[SettingsManager shared] stimp];
        float puttDistanceYards = puttDistanceYardsFromMphAndStimp(speed, stimp);
        float offlineDistanceYards = calculateOfflineDistance(puttDistanceYards, hla);
        ballData[@"TotalDistance"] = @(puttDistanceYards);
        ballData[@"TotalOffline"] = @(offlineDistanceYards);
        ballData[@"CarryDistance"] = @(0.f);
        ballData[@"CarryOffline"] = @(0.f);
        ballData[@"TotalSpin"] = @(0.f);
        ballData[@"SpinAxis"] = @(0.f);
        ballData[@"Height"] = @(0.f);
        return;
    }

    // For non-putts, use models to estimate total distance

    // Ensure CoreML models are loaded before proceeding
    if (![self ensureModelsLoaded]) {
        NSLog(@"Failed to load trajectory models - skipping trajectory calculations");
        return;
    }

    // 2) Build the feature dict for each model (must match the names from conversion)
    //    Here, the model expects:
    //      carry_yd, ball_mph, spin_rpm, spin_axis_deg, launch_v_deg
    NSDictionary<NSString *, NSNumber *> *featureDict = @{
        @"carry_yd":       @(carryDistance),
        @"ball_mph":       @(speed),
        @"spin_rpm":       @(totalSpin),
        @"spin_axis_deg":  @(fabs(spinAxis)), // We trained on all positive values since the results are symmetric
        @"launch_v_deg":   @(vla)
    };

    NSError *inputError = nil;
    MLDictionaryFeatureProvider *inputProvider =
        [[MLDictionaryFeatureProvider alloc] initWithDictionary:featureDict
                                                          error:&inputError];
    if (inputError) {
        NSLog(@"Error creating input provider: %@", inputError);
        return;
    }

    // We'll store predictions in local variables, then write them back to ballData.
    float predictedHeightFt      = 0.0f;
    float predictedLateralSpin   = 0.0f;
    float predictedRoll          = 0.0f;

    // 3) Predict Height using modelHeight
    if (self.modelHeight) {
        NSError *heightError = nil;
        id<MLFeatureProvider> heightOutput = [self.modelHeight predictionFromFeatures:inputProvider
                                                                                error:&heightError];
        if (!heightError && heightOutput) {
            MLFeatureValue *val = [heightOutput featureValueForName:@"height_ft"];
            if (val) {
                predictedHeightFt = (float)val.doubleValue;
            }
        } else {
            NSLog(@"Height prediction error: %@", heightError);
        }
    }

    // 4) Predict Lateral Spin using modelLateralSpin
    if (self.modelLateralSpin) {
        NSError *latSpinError = nil;
        id<MLFeatureProvider> latSpinOutput =
            [self.modelLateralSpin predictionFromFeatures:inputProvider error:&latSpinError];
        if (!latSpinError && latSpinOutput) {
            MLFeatureValue *val = [latSpinOutput featureValueForName:@"lateral_spin_yd"];
            if (val) {
                predictedLateralSpin = signf(spinAxis) * (float)val.doubleValue; // Add in sign since we trained on all positive values
            }
        } else {
            NSLog(@"Lateral spin prediction error: %@", latSpinError);
        }
    }

    // 5) Predict Roll Distance using modelRoll
    if (self.modelRoll) {
        NSError *rollError = nil;
        id<MLFeatureProvider> rollOutput =
            [self.modelRoll predictionFromFeatures:inputProvider error:&rollError];
        if (!rollError && rollOutput) {
            MLFeatureValue *val = [rollOutput featureValueForName:@"roll_yd"];
            if (val) {
                predictedRoll = (float)val.doubleValue;
            }
        } else {
            NSLog(@"Roll prediction error: %@", rollError);
        }
    }
    
    // Use settings to modulate the roll out. This is very rough, does not work well for backspin.
    NSInteger fairwaySpeedIndex = [[SettingsManager shared] fairwaySpeedIndex];
    if(fairwaySpeedIndex == 0) // Slow
        predictedRoll *= 0.5;
    else if(fairwaySpeedIndex == 1) // Medium
        predictedRoll *= 1.0;
    else if(fairwaySpeedIndex == 2) // Fast
        predictedRoll *= 2.0;
    else if(fairwaySpeedIndex == 3) // Links
        predictedRoll *= 3.5;

    // 6) Store the final results
    float carryOffline = calculateOfflineDistance(carryDistance, hla) + predictedLateralSpin;
    float carryOfflineAngle = atan2(carryOffline, carryDistance) * 180.0 / M_PI;
    float totalDistance = carryDistance + predictedRoll;
    float totalOffline = calculateOfflineDistance(totalDistance, carryOfflineAngle);
    ballData[@"CarryOffline"] = @(carryOffline);
    ballData[@"TotalDistance"] = @(totalDistance);
    ballData[@"TotalOffline"] = @(totalOffline);
    ballData[@"Height"] = @(predictedHeightFt/3.0); // Convert to yards
}

@end
