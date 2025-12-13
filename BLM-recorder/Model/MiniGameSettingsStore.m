#import "MiniGameSettingsStore.h"

@implementation MiniGameSettingsStore

+ (void)saveSettingsForType:(NSString *)type
                     format:(NSString *)format
                minDistance:(NSInteger)minDistance
                maxDistance:(NSInteger)maxDistance
                  numShots:(NSInteger)numShots
{
    // Build a dictionary to store
    NSDictionary *dict = @{
        @"format"      : format ?: @"Incremental",
        @"minDistance" : @(minDistance),
        @"maxDistance" : @(maxDistance),
        @"numShots"    : @(numShots)
    };
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // For uniqueness, append the type name to the key:
    NSString *settingsKey = [NSString stringWithFormat:@"MiniGameSettings_%@", type];
    [defaults setObject:dict forKey:settingsKey];
    [defaults synchronize];
}

+ (NSDictionary *)loadSettingsForType:(NSString *)type
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *settingsKey = [NSString stringWithFormat:@"MiniGameSettings_%@", type];
    NSDictionary *dict = [defaults dictionaryForKey:settingsKey];
    if(!dict) { // Nothing saved, load defaults
        if([type isEqualToString:@"Swings"]) {
            return @{
                @"format"      : @"Incremental",
                @"minDistance" : @(20),
                @"maxDistance" : @(100),
                @"numShots"    : @(10)
            };
        } else if([type isEqualToString:@"Putting"]) {
            return @{
                @"format"      : @"Incremental",
                @"minDistance" : @(5),
                @"maxDistance" : @(30),
                @"numShots"    : @(10)
            };
        } else {
            return @{};
        }
    }
    
    return dict;
}

@end
