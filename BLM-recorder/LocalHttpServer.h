#import <Foundation/Foundation.h>

@interface LocalHttpServer : NSObject

+ (instancetype)shared;
- (void)startServer;

@end
