
#import <Foundation/Foundation.h>

@interface NSubmissionValidator : NSObject

// The number of consecutive identical dictionaries required
@property (nonatomic, assign, readonly) NSInteger requiredCount;

- (instancetype)initWithRequiredCount:(NSInteger)count;
- (BOOL)validateDictionary:(NSDictionary *)dict;

@end
