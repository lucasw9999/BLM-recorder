#import "MainContainerViewController.h"
#import "LaunchMonitorDataViewController.h"
#import "ImagesViewController.h"
#import "DebugViewController.h"
#import "SettingsViewController.h"
#import "CameraManager.h"
#import "Theme.h"

@interface MainContainerViewController ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) NSArray<UIViewController *> *viewControllers;
@property (nonatomic, strong) UIViewController *currentViewController;
@end

@implementation MainContainerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = APP_COLOR_BG;

    // Create view controllers
    LaunchMonitorDataViewController *playVC = [[LaunchMonitorDataViewController alloc] init];
    ImagesViewController *monitorVC = [[ImagesViewController alloc] init];
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];

    self.viewControllers = @[playVC, monitorVC, settingsVC];

    // Create app title/logo at top left
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"BLM Recorder";
    self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = APP_COLOR_TEXT;
    self.titleLabel.accessibilityLabel = @"BLM Recorder";
    [self.view addSubview:self.titleLabel];

    // Create segmented control at top right for landscape-optimized navigation
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Play", @"Monitor", @"Settings"]];
    self.segmentedControl.selectedSegmentIndex = 0;
    self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];

    // Accessibility
    self.segmentedControl.accessibilityLabel = @"Screen selector";
    self.segmentedControl.accessibilityHint = @"Choose between Play, Monitor, and Settings screens";

    [self.view addSubview:self.segmentedControl];

    // Container view for child view controllers
    self.containerView = [[UIView alloc] init];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.containerView];

    // Layout constraints
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        // Title label at top left
        [self.titleLabel.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:8],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:16],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.segmentedControl.centerYAnchor],

        // Segmented control at top right
        [self.segmentedControl.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:8],
        [self.segmentedControl.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-16],
        [self.segmentedControl.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.titleLabel.trailingAnchor constant:16],

        // Container view fills remaining space
        [self.containerView.topAnchor constraintEqualToAnchor:self.segmentedControl.bottomAnchor constant:8],
        [self.containerView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [self.containerView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [self.containerView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor]
    ]];

    // Show initial view controller (Play)
    [self showViewController:playVC];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    NSInteger index = sender.selectedSegmentIndex;
    if (index >= 0 && index < self.viewControllers.count) {
        // Stop camera when entering Settings (index 2)
        if (index == 2) {
            [[CameraManager shared] stopCamera];
        } else {
            // Start camera when leaving Settings
            [[CameraManager shared] startCamera];
        }

        [self showViewController:self.viewControllers[index]];
    }
}

- (void)showViewController:(UIViewController *)viewController {
    // Remove current view controller
    if (self.currentViewController) {
        [self.currentViewController willMoveToParentViewController:nil];
        [self.currentViewController.view removeFromSuperview];
        [self.currentViewController removeFromParentViewController];
    }

    // Add new view controller
    [self addChildViewController:viewController];
    viewController.view.frame = self.containerView.bounds;
    viewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.containerView addSubview:viewController.view];
    [viewController didMoveToParentViewController:self];

    self.currentViewController = viewController;
}

@end
