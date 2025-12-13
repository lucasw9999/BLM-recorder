#import "SettingsManager.h"

NSString * const GSProIPChangedNotification = @"GSProIPChangedNotification"; // *** NEW ***

@interface SettingsManager ()
{
    NSString *_gsProIP; // *** NEW *** Private backing store
}
@end

@implementation SettingsManager

+ (instancetype)shared {
    static SettingsManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SettingsManager alloc] init];
        [instance loadSettings]; // load from NSUserDefaults
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // defaults
        _stimp = 10;
        _gsProIP = @"192.168.1.100";
        _fairwaySpeedIndex = 1; // "medium"
    }
    return self;
}

- (void)loadSettings {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSInteger loadedStimp = [ud integerForKey:@"settings_stimp"];
    if (loadedStimp < 5 || loadedStimp > 15) {
        loadedStimp = 10; // fallback
    }
    self.stimp = loadedStimp;
    
    NSString *ip = [ud stringForKey:@"settings_gsProIP"];
    if (ip) {
        _gsProIP = ip; // directly set the ivar so we don't trigger notifications while loading
    }
    
    NSInteger fairwayIdx = [ud integerForKey:@"settings_fairwaySpeed"];
    self.fairwaySpeedIndex = fairwayIdx;
}

- (void)saveSettings {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setInteger:self.stimp forKey:@"settings_stimp"];
    [ud setObject:_gsProIP forKey:@"settings_gsProIP"];
    [ud setInteger:self.fairwaySpeedIndex forKey:@"settings_fairwaySpeed"];
    [ud synchronize];
}

// *** NEW *** Accessor & custom setter for gsProIP
- (NSString *)gsProIP {
    return _gsProIP;
}

- (void)setGSProIP:(NSString *)newIP {
    // Only do something if new value is different from current
    if (![_gsProIP isEqualToString:newIP]) {
        _gsProIP = [newIP copy];
        
        // Persist the new value
        [self saveSettings];
        
        // Post notification so other parts of the system get updated
        NSDictionary *userInfo = @{ @"gsProIP": _gsProIP };
        [[NSNotificationCenter defaultCenter] postNotificationName:GSProIPChangedNotification
                                                            object:nil
                                                          userInfo:userInfo];
    }
}

@end
