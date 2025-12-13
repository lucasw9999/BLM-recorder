#import "NSubmissionValidator.h"


// Helper: Fuzzy compare two dictionaries (values assumed to be numbers)
// Returns YES if for every key the absolute difference is < 0.1.
static BOOL dictionariesFuzzyEqual(NSDictionary *dict1, NSDictionary *dict2) {
    int diffCount = 0;
    
    if (dict1 == nil || dict2 == nil) return NO;
    if (dict1.count != dict2.count) return NO;
    for (id key in dict1) {
        NSNumber *num1 = dict1[key];
        NSNumber *num2 = dict2[key];
        if (!num2) return NO;
        if (fabs([num1 floatValue] - [num2 floatValue]) >= 0.1f) {
            diffCount++;
        }
    }
    return (diffCount <= 0); // I've played with setting this <= 1 instead of 0 to help the case when OCR fail
}


@interface NSubmissionValidator ()
// Tracks the last dictionary (content) we saw
@property (nonatomic, strong) NSDictionary *lastDictionary;
@property (nonatomic, strong) NSDictionary *lastValidDictionary;
// How many times the lastDictionary has been repeated consecutively
@property (nonatomic, assign) NSInteger repetitionCount;
@end

@implementation NSubmissionValidator

- (instancetype)initWithRequiredCount:(NSInteger)count
{
    self = [super init];
    if (self) {
        _requiredCount = count;
        _repetitionCount = 0;
        _lastDictionary = nil;
        
    }
    return self;
}

- (BOOL)validateDictionary:(NSDictionary *)dict
{
    // Check if dict matches the last dictionary (by content)
    if (dictionariesFuzzyEqual(dict, self.lastDictionary)) {
        self.repetitionCount++;
    } else {
        // Reset tracking to the new dictionary
        self.lastDictionary = [dict copy];
        self.repetitionCount = 1;
    }
    
    // Return YES only if repetitionCount == requiredCount and the new dict is NOT equal to the last valid one
    if (self.repetitionCount == self.requiredCount && !dictionariesFuzzyEqual(dict, self.lastValidDictionary)) {
        self.lastValidDictionary = [dict copy];
        return YES;
    }
    
    return NO;
}

@end
