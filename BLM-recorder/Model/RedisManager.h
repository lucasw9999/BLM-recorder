#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Notification sent when Redis connection status changes
extern NSString * const RedisConnectionStatusChangedNotification;

@interface RedisManager : NSObject

+ (instancetype)shared;

// Settings management
- (void)setRedisHost:(NSString *)host;
- (void)setRedisPort:(NSInteger)port;
- (void)setRedisPassword:(NSString *)password;

- (NSString *)getRedisHost;
- (NSInteger)getRedisPort;
- (BOOL)hasRedisPassword;

// Connection management
- (BOOL)isConfigured;
- (void)testConnectionWithCompletion:(void (^)(BOOL success, NSString * _Nullable error))completion;

// Data recording
- (void)recordShotData:(NSDictionary *)shotData completion:(void (^ _Nullable)(BOOL success, NSString * _Nullable error))completion;

// Error reporting
- (NSString * _Nullable)getLastError;

@end

NS_ASSUME_NONNULL_END
