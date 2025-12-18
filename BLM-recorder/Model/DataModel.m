#import "DataModel.h"
#import "CameraManager.h"
#import "GSProConnector.h"
#import "SettingsManager.h"
#import "ModelManager.h"
#import "ShotManager.h"
#import "ImageUtilities.h"
#import "Constants.h"

NSString * const ModelsLoadedNotification = @"ModelsLoadedNotification";

@interface DataModel ()
    @property (nonatomic, strong) ScreenDataProcessor *screenDataProcessor;
    @property (nonatomic, assign) int shotNumber;
    @property (nonatomic, assign) int gsProPort;
    @property (nonatomic, strong) ShotManager *shotManager;
@end

@implementation DataModel

static DataModel *_sharedInstance = nil;

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[DataModel alloc] init];
    });
    return _sharedInstance;
}

+ (instancetype)sharedIfExists {
    // Returns the shared instance only if it's already been created
    // Does NOT trigger initialization
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Listen for new frames
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(processFrame:)
                                                     name:CameraManagerNewFrameNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateCorners:)
                                                     name:ScreenDataProcessorNewCornersNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleNewBallData:)
                                                     name:ScreenDataProcessorNewBallDataNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleNewClubData:)
                                                     name:ScreenDataProcessorNewClubDataNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleIpChanged:)
                                                     name:GSProIPChangedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(startMiniGame:)
                                                     name:MiniGameStartNotification
                                                   object:nil];
        
        [UIApplication sharedApplication].idleTimerDisabled = YES; // Prevent the app from going to sleep
        
        self.currentShotBallData = nil;
        self.currentShotClubData = nil;
        self.currentShotBallImage = nil;
        self.currentShotClubImage = nil;
        
        self.shotNumber = -1;
        
        self.gsProPort = 921;
        self.screenDataProcessor = [[ScreenDataProcessor alloc] init];
        [SettingsManager shared];
        [[CameraManager shared] startCamera];
        [[GSProConnector shared] connectToServerWithIP:[SettingsManager shared].gsProIP port:self.gsProPort];
        
        self.shotManager = [[ShotManager alloc] init];
        self.modelsLoaded = NO;

        // Load CV models asynchronously to prevent blocking UI startup
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSError *error = nil;

            if (![[ModelManager shared] loadModelWithName:@"hla-direction" error:&error]) {
                NSLog(@"Failed to load model hla-direction: %@", error.localizedDescription);
            }
            if (![[ModelManager shared] loadModelWithName:@"spin-axis-direction" error:&error]) {
                NSLog(@"Failed to load model spin-axis-direction: %@", error.localizedDescription);
            }
            if (![[ModelManager shared] loadModelWithName:@"ball-speed-units" error:&error]) {
                NSLog(@"Failed to load model ball-speed-units: %@", error.localizedDescription);
            }
            if (![[ModelManager shared] loadModelWithName:@"carry-units" error:&error]) {
                NSLog(@"Failed to load model carry-units: %@", error.localizedDescription);
            }
            if (![[ModelManager shared] loadModelWithName:@"club-speed-units" error:&error]) {
                NSLog(@"Failed to load model club-speed-units: %@", error.localizedDescription);
            }
            if (![[ModelManager shared] loadModelWithName:@"path-direction" error:&error]) {
                NSLog(@"Failed to load model path-direction: %@", error.localizedDescription);
            }
            if (![[ModelManager shared] loadModelWithName:@"aoa-direction" error:&error]) {
                NSLog(@"Failed to load model aoa-direction: %@", error.localizedDescription);
            }

            // Notify on main thread that models are loaded
            dispatch_async(dispatch_get_main_queue(), ^{
                self.modelsLoaded = YES;
                [[NSNotificationCenter defaultCenter] postNotificationName:ModelsLoadedNotification
                                                                    object:nil
                                                                  userInfo:nil];
            });
        });
    }
    return self;
}

- (void)processFrame:(NSNotification *)notification {
    UIImage *frame = notification.userInfo[@"frame"];
    if (!frame)
        return;
    
    // Rate limit the processing.
    //  This exists because the detections/OCR can produce wrong results from time to time,
    //  especially if the frame is captured while the screen is changing. There is a mechanism
    //  in screenDataProcessor that ensures we only call a frame "correct" if it decodes the
    //  same results twice in a row. By looking at frames spaced farther apart (i.e. 200+ ms
    //  rather than 15-30), these issues seem to not occur.
    static NSTimeInterval lastCallTime = 0;
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    if (currentTime - lastCallTime < OCR_RATE_SECONDS) { // X seconds
        return;
    }
    lastCallTime = currentTime;

    NSError *error = nil;
    [self.screenDataProcessor processScreenDataFromImage:frame error:&error];
    // Screen corner detection failures are normal when monitor not visible - don't log
}

- (void)updateCorners:(NSNotification *)notification {
    NSArray *corners = notification.userInfo[@"corners"];
    if (!corners)
        return;
    
    self.screenCorners = [corners copy];
}

- (void)handleNewBallData:(NSNotification *)notification {
    UIImage *image = notification.userInfo[@"image"];
    if (image)
        self.currentShotBallImage = image;
    
    NSDictionary *data = notification.userInfo[@"data"];
    if (!data)
        return;

    self.currentShotBallData = [data copy];
    // Don't clear club data - let it persist until new club data arrives
    self.shotNumber++;

    NSLog(@"Got new BALL data (shot #%d)", self.shotNumber);

    [self.shotManager addShot:self.currentShotBallData];
    
    [[GSProConnector shared] sendShotWithBallData:self.currentShotBallData
                                         clubData:nil
                                       shotNumber:(int)self.shotNumber];
    
    DEBUG_SAVE_SHOT_DATA(image, data, self.shotNumber);
}

- (void)handleNewClubData:(NSNotification *)notification {
    if(self.currentShotClubData || !self.currentShotBallData) {
        // We already have club data for this shot, ignore this until we get new shot data
        // OR we haven't received any ball data yet, ignore until we get the first shot
        return;
    }
    
    UIImage *image = notification.userInfo[@"image"];
    if (image)
        self.currentShotClubImage = image;
    
    NSDictionary *data = notification.userInfo[@"data"];
    if (!data)
        return;
    
    self.currentShotClubData = [data copy];
    [self.shotManager updateShotClubData:self.currentShotClubData];

    NSLog(@"Got new CLUB data (shot #%d)", self.shotNumber);

    [[GSProConnector shared]  sendShotWithBallData:nil
                                          clubData:self.currentShotClubData
                                        shotNumber:(int)self.shotNumber];
    
    DEBUG_SAVE_SHOT_DATA(image, data, self.shotNumber);
}

- (void)handleIpChanged:(NSNotification *)notification {
    NSString *ip = notification.userInfo[@"gsProIP"];
    if (!ip)
        return;
    
    [[GSProConnector shared] connectToServerWithIP:ip port:self.gsProPort];
}

- (void)startMiniGame:(NSNotification *)notification {
    NSString *gameType = notification.userInfo[@"gameType"];
    if (!gameType)
        return;
    
    NSNumber *minDistanceNumber = notification.userInfo[@"minDistance"];
    if (!minDistanceNumber || ![minDistanceNumber isKindOfClass:[NSNumber class]])
        return;
    int minDistance = [minDistanceNumber intValue];
    
    NSNumber *maxDistanceNumber = notification.userInfo[@"maxDistance"];
    if (!maxDistanceNumber || ![maxDistanceNumber isKindOfClass:[NSNumber class]])
        return;
    int maxDistance = [maxDistanceNumber intValue];
    
    NSString *format = notification.userInfo[@"format"];
    if (!format)
        return;
    
    NSNumber *numberOfShotsNumber = notification.userInfo[@"numberOfShots"];
    if (!numberOfShotsNumber || ![numberOfShotsNumber isKindOfClass:[NSNumber class]])
        return;
    int numberOfShots = [numberOfShotsNumber intValue];
    
    self.shotManager.miniGameManager = [[MiniGameManager alloc] initWithGameType:gameType
                                                                     minDistance:minDistance
                                                                     maxDistance:maxDistance
                                                                          format:format
                                                                   numberOfShots:numberOfShots];
}

- (void)exportShots {
    NSString *shotCsv = [self.shotManager exportShotsAsCSV];

    // Generate timestamp string (yyyy-MM-dd-HH-mm)
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd-HH-mm"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];

    // Define file name with timestamp
    NSString *fileName = [NSString stringWithFormat:@"shots_%@.csv", timestamp];
    
    // Get temporary directory path
    NSURL *temporaryDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL = [temporaryDirectory URLByAppendingPathComponent:fileName];

    // Write CSV data to file
    NSError *error;
    BOOL success = [shotCsv writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (!success) {
        NSLog(@"Error writing CSV file: %@", error.localizedDescription);
        return;
    }

    // Create activity view controller for sharing
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];

    // Exclude certain activities if necessary
    activityVC.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypePostToFacebook];

    // Find the active window's root view controller
    UIWindow *keyWindow = nil;
    for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
        if (windowScene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
        }
        if (keyWindow) {
            break;
        }
    }

    // Present the sharing sheet
    [keyWindow.rootViewController presentViewController:activityVC animated:YES completion:nil];
}

- (MiniGameManager*)getMiniGameManager {
    return self.shotManager.miniGameManager;
}

- (void)endMiniGameEarly {
    self.shotManager.miniGameManager = nil;
}

- (void)DEBUG_saveShotImage:(UIImage *)warpedImage
                   withData:(NSDictionary *)data
              andShotNumber:(int)shotNumber
{
    static NSString *timestamp = nil;
    if (!timestamp) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyyMMdd_HHmm"; // e.g. 20240305_1530
        timestamp = [formatter stringFromDate:[NSDate date]];
    }
    
    // 1) Figure out the Documents folder and a subfolder named <timestamp>.
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];

    // 3) Build a base name "<timestamp>/<timestamp>-%04d" for the image.
    BOOL hasCarryDistance = ([data objectForKey:@"CarryDistance"] != nil);
    NSString *ballOrClubSuffix = hasCarryDistance ? @"ball" : @"club";
    NSString *baseName = [NSString stringWithFormat:@"%@-%04d-%@", timestamp, shotNumber, ballOrClubSuffix];
    
    // 4) Save the warped image as a .png in the <timestamp> directory.
    //    This calls your existing utility method.
    NSString *imageFileName = [baseName stringByAppendingString:@".png"];
    [ImageUtilities saveImageToDocuments:warpedImage fileName:imageFileName];
    
    // 6) Construct the JSON filename:
    NSString *jsonFileName = [baseName stringByAppendingString:@".json"];
    NSString *jsonFilePath = [documentsPath stringByAppendingPathComponent:jsonFileName];

    // 7) Serialize the data dictionary to JSON and write it out.
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&jsonError];
    if (jsonError) {
        NSLog(@"Error serializing JSON: %@", jsonError.localizedDescription);
        return;
    }

    BOOL writeSuccess = [jsonData writeToFile:jsonFilePath atomically:YES];
    if (!writeSuccess) {
        NSLog(@"Failed to write JSON to file: %@", jsonFilePath);
    }
}

@end
