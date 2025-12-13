
#import "AppDelegate.h"
#import "MainContainerViewController.h"
#import "DataModel.h"
#import "LocalHttpServer.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    NSLog(@"[STARTUP] App launch starting");

    // Create a window the same size as the screen.
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    // Set window background to match app theme (prevents white flash)
    self.window.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];

    // Create your ViewController SYNCHRONOUSLY (required before method returns)
    NSLog(@"[STARTUP] Creating MainContainerViewController");
    MainContainerViewController *rootVC = [[MainContainerViewController alloc] init];

    // Set the root view controller (MUST be done before makeKeyAndVisible)
    self.window.rootViewController = rootVC;
    NSLog(@"[STARTUP] Root view controller set");

    // Show window
    [self.window makeKeyAndVisible];
    NSLog(@"[STARTUP] Window made visible");

    // Initialize data model AFTER window is visible
    // This allows UI to render before heavy initialization
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[STARTUP] Initializing DataModel after UI is visible");
        [DataModel shared];
    });

    // Just for debugging
    [[LocalHttpServer shared] startServer];

    return YES;
}

// Optional: If you’re not using SceneDelegate, you can implement 
// the usual application lifecycle methods here if needed.

@end
