#import "MiniGameManager.h"

NSString * const MiniGameStartNotification = @"MiniGameStartNotification";
NSString * const MiniGameStatusChangedNotification = @"MiniGameStatusChangedNotification";

@interface MiniGameManager ()

@property (nonatomic, assign) NSInteger shotsRemaining;
@property (nonatomic, assign) NSInteger targetDistanceForCurrentShot;
@property (nonatomic, assign) NSInteger totalScore;
@property (nonatomic, assign) NSInteger totalToPar;
@property (nonatomic, assign) NSInteger mostRecentShotScore;
@property (nonatomic, assign) NSInteger mostRecentShotToPar;
@property (nonatomic, assign) float mostRecentShotDistanceDiff;

@end

@implementation MiniGameManager

- (instancetype)initWithGameType:(NSString *)type
                     minDistance:(NSInteger)minDist
                     maxDistance:(NSInteger)maxDist
                          format:(NSString *)format
                   numberOfShots:(NSInteger)shots
{
    self = [super init];
    if (self) {
        _gameType        = [type copy];
        _minDistance     = minDist;
        _maxDistance     = maxDist;
        _format          = [format copy];
        _totalShots      = shots;
        
        _shotsRemaining = shots;
        _targetDistanceForCurrentShot = 0;
        _totalScore = 0;
        _totalToPar = 0;
        _mostRecentShotScore = 0;
        _mostRecentShotToPar = 0;
        _mostRecentShotDistanceDiff = 0;
        
        // Initialize first target distance
        [self updateTargetDistance];
        
        [self broadcastUpdate];
    }
    return self;
}

#pragma mark - Accessors

- (NSInteger)getShotsRemaining {
    return self.shotsRemaining;
}

- (NSInteger)getTargetDistanceForCurrentShot {
    return self.targetDistanceForCurrentShot;
}

- (NSInteger)getTotalScore {
    return self.totalScore;
}

- (NSInteger)getTotalToPar {
    return self.totalToPar;
}

- (NSInteger)getMostRecentShotScore {
    return self.mostRecentShotScore;
}

- (NSInteger)getMostRecentShotToPar {
    return self.mostRecentShotToPar;
}

- (float)getMostRecentShotDistanceDiff {
    return self.mostRecentShotDistanceDiff;
}

#pragma mark - Adding a Shot

- (NSDictionary *)addShot:(NSDictionary*)shotDict {
    // If no shots remain, do nothing
    if (self.shotsRemaining <= 0) {
        return @{};
    }
    
    float distance = 0.0f;
    float distanceOffline = 0.0f;
    if ([self.gameType isEqualToString:@"Swings"]) {
        // Use carry distance + carry offline
        distance = [shotDict[@"CarryDistance"] floatValue];
        distanceOffline = [shotDict[@"CarryOffline"] floatValue];
    } else if ([self.gameType isEqualToString:@"Putting"]) {
        // Use total distance + total offline
        distance = [shotDict[@"TotalDistance"] floatValue];
        distanceOffline = [shotDict[@"TotalOffline"] floatValue];
    }
    
    // Update scores
    float targetFloat = (float)self.targetDistanceForCurrentShot;
    self.mostRecentShotDistanceDiff = sqrtf(powf(targetFloat - distance, 2) + powf(distanceOffline, 2));
    float shotScore = 1.0f - (self.mostRecentShotDistanceDiff / targetFloat);
    self.mostRecentShotToPar = (shotScore > 0.9f) ? -1 : (shotScore > 0.8f) ? 0 : 1;
    self.mostRecentShotScore = MAX(0, (NSInteger)(100.f * shotScore));
    
    float numShots = (float)(self.totalShots - self.shotsRemaining);
    float newScore = ((float)self.totalScore * numShots + self.mostRecentShotScore) / (float)(numShots + 1); // Running average
    self.totalScore = (NSInteger)roundf(newScore);
    self.totalToPar += self.mostRecentShotToPar;
    
    // Decrement shots remaining
    self.shotsRemaining -= 1;
    
    // Update the target distance for next shot (if any left)
    if (self.shotsRemaining > 0) {
        [self updateTargetDistance];
    }
    
    // Create the dictionary to return
    NSMutableDictionary *miniGameShotResult = [NSMutableDictionary dictionary];
    miniGameShotResult[@"MGTargetDistance"] = @(self.targetDistanceForCurrentShot);
    miniGameShotResult[@"MGDistanceDiff"] = @(self.mostRecentShotDistanceDiff);
    miniGameShotResult[@"MGScore"] = @(self.mostRecentShotScore);
    miniGameShotResult[@"MGToPar"] = @(self.mostRecentShotToPar);
    
    [self broadcastUpdate];
    
    return [miniGameShotResult copy];
    
}

#pragma mark - Private Helpers

- (void)updateTargetDistance {
    if ([self.format isEqualToString:@"Random"]) {
        // Generate a random target within [minDistance, maxDistance]
        NSInteger range = self.maxDistance - self.minDistance;
        self.targetDistanceForCurrentShot = self.minDistance + arc4random_uniform((u_int32_t)range + 1);
    } else {
        // Go incrementally
        if (self.totalShots <= 1) {
            self.targetDistanceForCurrentShot = self.minDistance; // Avoid division by zero
        } else {
            NSInteger currentShotIndex = self.totalShots - self.shotsRemaining;
            NSInteger interpolatedDistance = self.minDistance +
                ((currentShotIndex * (self.maxDistance - self.minDistance)) / (self.totalShots - 1));
            self.targetDistanceForCurrentShot = interpolatedDistance;
        }
    }
}

- (void)broadcastUpdate {
    NSDictionary *userInfo = @{@"miniGameManager": self};
    [[NSNotificationCenter defaultCenter] postNotificationName:MiniGameStatusChangedNotification
                                                        object:nil
                                                      userInfo:userInfo];
}

@end
