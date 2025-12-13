#import <Foundation/Foundation.h>
#import "MiniGameManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface ShotManager : NSObject

// Array of dictionaries, each representing a shot (ball data, club data, etc.)
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *shotList;

// Holds game logic/state
@property (nonatomic, strong, nullable) MiniGameManager *miniGameManager;

// Add a new shot dictionary
- (void)addShot:(NSDictionary *)shotDict;

// Update the latest shot with extra club data
- (void)updateShotClubData:(NSDictionary *)clubDict;

// Export all shots to CSV
- (NSString *)exportShotsAsCSV;

@end

NS_ASSUME_NONNULL_END
