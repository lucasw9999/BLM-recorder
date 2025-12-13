#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "ScreenDataProcessor.h"
#import "MiniGameManager.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const ModelsLoadedNotification;

@interface DataModel : NSObject

+ (instancetype)shared;
+ (instancetype)sharedIfExists;  // Returns nil if not yet initialized

- (MiniGameManager*)getMiniGameManager;
- (void)endMiniGameEarly;
- (void)exportShots;

@property (nonatomic, strong) NSArray<NSValue *> *screenCorners;

@property (nonatomic, strong, nullable) NSDictionary *currentShotBallData;
@property (nonatomic, strong, nullable) UIImage *currentShotBallImage;
@property (nonatomic, strong, nullable) NSDictionary *currentShotClubData;
@property (nonatomic, strong, nullable) UIImage *currentShotClubImage;

@property (nonatomic, assign) BOOL modelsLoaded;

@end

NS_ASSUME_NONNULL_END
