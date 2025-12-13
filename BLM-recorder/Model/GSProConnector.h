
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const GSProConnectionStateNotification; // Notification name

@interface GSProConnector : NSObject <NSStreamDelegate>

+ (instancetype)shared;
- (void)connectToServerWithIP:(NSString *)ip port:(NSInteger)port;
- (void)disconnect;
- (void)sendShotWithBallData:(NSDictionary * _Nullable)ballData
                    clubData:(NSDictionary * _Nullable)clubData
                  shotNumber:(int)shotNumber;

- (NSString *)getConnectionState; 

@end

NS_ASSUME_NONNULL_END
