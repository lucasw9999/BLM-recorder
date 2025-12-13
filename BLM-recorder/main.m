
#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        // The third parameter is nil, so it uses UIKit’s default UIApplication class.
        // The fourth is the name of our AppDelegate class.
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
