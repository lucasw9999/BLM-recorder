#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class MainContainerViewController;

@interface DebugViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate>

// Tab switching reference
@property (nonatomic, weak) MainContainerViewController *parentContainer;

@end
