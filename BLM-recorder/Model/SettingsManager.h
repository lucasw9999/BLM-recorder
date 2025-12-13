#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const GSProIPChangedNotification; // *** NEW *** (notification name)

@interface SettingsManager : NSObject

@property (nonatomic, assign) NSInteger stimp; // 5..15

// Remove or rename the direct gsProIP property if you prefer a custom setter method
//@property (nonatomic, copy) NSString *gsProIP;

@property (nonatomic, assign) NSInteger fairwaySpeedIndex; // 0=slow,1=medium,...

+ (instancetype)shared;
- (void)loadSettings;
- (void)saveSettings;

// *** NEW *** Provide a public setter method for the IP. Alternatively, you can override the property setter.
- (NSString *)gsProIP;
- (void)setGSProIP:(NSString *)newIP;

@end

NS_ASSUME_NONNULL_END
