#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TrajectoryEstimator : NSObject

+ (instancetype)shared;

/**
 Takes a mutable dictionary that already has these keys with float (NSNumber) values:
   - "Speed"         (ball velocity in mph)
   - "VLA"           (vertical launch angle in degrees)
   - "CarryDistance" (carry in yards)
   - "SpinAxis"      (spin axis in degrees)
   - "TotalSpin"     (spin in rpm)

 Then performs predictions using the three Random Forest models and adds:
   - "RollDistance"
   - "LateralSpin"
   - "Height"

 directly into the same dictionary.
*/
- (void)processBallData:(NSMutableDictionary *)ballData;

@end

NS_ASSUME_NONNULL_END
