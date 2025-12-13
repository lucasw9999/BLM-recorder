#import <UIKit/UIKit.h>

@class MainContainerViewController;

@interface SettingsViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate>

// Tab switching reference
@property (nonatomic, weak) MainContainerViewController *parentContainer;

@end
