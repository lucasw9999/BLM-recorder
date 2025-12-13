#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MiniGameSettingsStore : NSObject

+ (void)saveSettingsForType:(NSString *)type
                     format:(NSString *)format
                minDistance:(NSInteger)minDistance
                maxDistance:(NSInteger)maxDistance
                  numShots:(NSInteger)numShots;

+ (NSDictionary *)loadSettingsForType:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
