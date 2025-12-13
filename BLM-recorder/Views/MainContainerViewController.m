#import "MainContainerViewController.h"
#import "LaunchMonitorDataViewController.h"
#import "ImagesViewController.h"
#import "DebugViewController.h"
#import "SettingsViewController.h"
#import "Theme.h"

@interface MainContainerViewController ()
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) UIViewController *currentChildVC;
@property (nonatomic, assign) NSInteger selectedTabIndex;
@property (nonatomic, strong) NSArray<Class> *viewControllerClasses;
@end

@implementation MainContainerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"[STARTUP] MainContainerViewController viewDidLoad starting");
    self.view.backgroundColor = APP_COLOR_BG;

    self.selectedTabIndex = 0; // Start with first tab (Play)

    // Define the view controller classes in tab order
    self.viewControllerClasses = @[
        [LaunchMonitorDataViewController class],
        [ImagesViewController class],
        [DebugViewController class],
        [SettingsViewController class]
    ];

    [self setupContentContainer];

    // Load default page (Play tab)
    [self switchToChildViewController:[LaunchMonitorDataViewController new] tabIndex:0 animated:NO isForward:YES];
    NSLog(@"[STARTUP] MainContainerViewController viewDidLoad completed");
}

- (void)setupContentContainer {
    // Full width content container (no sidebar)
    self.contentContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    self.contentContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.contentContainer.backgroundColor = APP_COLOR_BG;
    [self.view addSubview:self.contentContainer];
}

- (void)switchToChildViewController:(UIViewController *)newVC tabIndex:(NSInteger)tabIndex animated:(BOOL)animated isForward:(BOOL)isForward {
    // Prevent switching to same tab
    if (tabIndex == self.selectedTabIndex && self.currentChildVC) {
        return;
    }

    UIViewController *oldVC = self.currentChildVC;
    self.currentChildVC = newVC;
    self.selectedTabIndex = tabIndex;

    // Setup the new view controller
    [self addChildViewController:newVC];
    newVC.view.frame = self.contentContainer.bounds;
    newVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // Set parent reference for swipe navigation
    [self setParentReferenceForViewController:newVC];

    if (animated && oldVC) {
        // Determine slide direction based on navigation direction (not index comparison)
        CGFloat slideDistance = self.contentContainer.bounds.size.height;
        BOOL slideDown = isForward; // Forward navigation slides down, backward slides up

        // Position new view off-screen (vertically)
        newVC.view.frame = CGRectOffset(self.contentContainer.bounds,
                                       0, slideDown ? slideDistance : -slideDistance);
        [self.contentContainer addSubview:newVC.view];

        // Animate the vertical transition
        [UIView animateWithDuration:0.3
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            // Slide old view out (vertically)
            oldVC.view.frame = CGRectOffset(oldVC.view.frame,
                                          0, slideDown ? -slideDistance : slideDistance);
            // Slide new view in
            newVC.view.frame = self.contentContainer.bounds;
        } completion:^(BOOL finished) {
            // Clean up old view controller
            [oldVC willMoveToParentViewController:nil];
            [oldVC.view removeFromSuperview];
            [oldVC removeFromParentViewController];
            [newVC didMoveToParentViewController:self];
        }];
    } else {
        // No animation - immediate switch
        if (oldVC) {
            [oldVC willMoveToParentViewController:nil];
            [oldVC.view removeFromSuperview];
            [oldVC removeFromParentViewController];
        }
        [self.contentContainer addSubview:newVC.view];
        [newVC didMoveToParentViewController:self];
    }
}

- (void)setParentReferenceForViewController:(UIViewController *)viewController {
    if ([viewController isKindOfClass:[LaunchMonitorDataViewController class]]) {
        ((LaunchMonitorDataViewController *)viewController).parentContainer = self;
    } else if ([viewController isKindOfClass:[ImagesViewController class]]) {
        ((ImagesViewController *)viewController).parentContainer = self;
    } else if ([viewController isKindOfClass:[DebugViewController class]]) {
        ((DebugViewController *)viewController).parentContainer = self;
    } else if ([viewController isKindOfClass:[SettingsViewController class]]) {
        ((SettingsViewController *)viewController).parentContainer = self;
    }
}

- (NSInteger)indexForViewController:(UIViewController *)viewController {
    for (NSInteger i = 0; i < self.viewControllerClasses.count; i++) {
        if ([viewController isKindOfClass:self.viewControllerClasses[i]]) {
            return i;
        }
    }
    return 0;
}

#pragma mark - Tab Switching Methods

- (void)switchToNextTab {
    NSInteger nextTab = (self.selectedTabIndex + 1) % self.viewControllerClasses.count;
    UIViewController *newVC = [[self.viewControllerClasses[nextTab] alloc] init];
    [self switchToChildViewController:newVC tabIndex:nextTab animated:YES isForward:YES];
}

- (void)switchToPreviousTab {
    NSInteger previousTab = (self.selectedTabIndex - 1 + self.viewControllerClasses.count) % self.viewControllerClasses.count;
    UIViewController *newVC = [[self.viewControllerClasses[previousTab] alloc] init];
    [self switchToChildViewController:newVC tabIndex:previousTab animated:YES isForward:NO];
}

@end
