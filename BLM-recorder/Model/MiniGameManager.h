#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const MiniGameStartNotification;
extern NSString * const MiniGameStatusChangedNotification;

@interface MiniGameManager : NSObject

// Basic game settings (from your MiniGameSettings)
@property (nonatomic, copy)   NSString *gameType;    // e.g. @"Swings" or @"Putting"
@property (nonatomic, assign) NSInteger minDistance;
@property (nonatomic, assign) NSInteger maxDistance;
@property (nonatomic, copy)   NSString *format;      // e.g. @"Incremental" or @"Random"
@property (nonatomic, assign) NSInteger totalShots;

// Designated initializer
- (instancetype)initWithGameType:(NSString *)type
                     minDistance:(NSInteger)minDist
                     maxDistance:(NSInteger)maxDist
                          format:(NSString *)format
                     numberOfShots:(NSInteger)shots;

// Accessors
- (NSInteger)getShotsRemaining;
- (NSInteger)getTargetDistanceForCurrentShot;
- (NSInteger)getTotalScore;
- (NSInteger)getTotalToPar;
- (NSInteger)getMostRecentShotScore;
- (NSInteger)getMostRecentShotToPar;
- (float)getMostRecentShotDistanceDiff;

// Main method to register a shot
- (NSDictionary*)addShot:(NSDictionary*)shotDict;

@end

NS_ASSUME_NONNULL_END
