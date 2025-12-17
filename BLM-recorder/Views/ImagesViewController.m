#import "ImagesViewController.h"
#import "Theme.h"
#import "ScreenDataProcessor.h"
#import "DataModel.h"
#import "MainContainerViewController.h"

@interface ImagesViewController ()
@property (nonatomic, strong) UIImageView *ballDataImageView;
@property (nonatomic, strong) UIImageView *clubDataImageView;
@property (nonatomic, strong) UIView *cameraContainer;

@end

@implementation ImagesViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = APP_COLOR_BG;

    // Add header with title and mode
    [self setupHeader];

    // Left side: Monitor images (ball and club data)
    self.ballDataImageView = [[UIImageView alloc] init];
    self.ballDataImageView.backgroundColor = [UIColor blackColor];
    self.ballDataImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.ballDataImageView.image = [DataModel shared].currentShotBallImage;
    // Add border
    self.ballDataImageView.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;
    self.ballDataImageView.layer.borderWidth = 1.0;
    [self.view addSubview:self.ballDataImageView];

    self.clubDataImageView = [[UIImageView alloc] init];
    self.clubDataImageView.backgroundColor = [UIColor blackColor];
    self.clubDataImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.clubDataImageView.image = [DataModel shared].currentShotClubImage;
    // Add border
    self.clubDataImageView.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;
    self.clubDataImageView.layer.borderWidth = 1.0;
    [self.view addSubview:self.clubDataImageView];

    // Right side: Camera placeholder
    self.cameraContainer = [[UIView alloc] init];
    self.cameraContainer.backgroundColor = [UIColor blackColor];
    // Add border
    self.cameraContainer.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;
    self.cameraContainer.layer.borderWidth = 1.0;
    [self.view addSubview:self.cameraContainer];

    // Add camera placeholder label
    UILabel *cameraLabel = [[UILabel alloc] init];
    cameraLabel.text = @"Camera";
    cameraLabel.textColor = [UIColor grayColor];
    cameraLabel.textAlignment = NSTextAlignmentCenter;
    cameraLabel.font = [UIFont systemFontOfSize:20];
    cameraLabel.frame = CGRectMake(0, 0, 200, 40);
    cameraLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.cameraContainer addSubview:cameraLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNewBallData:)
                                                 name:ScreenDataProcessorNewBallDataNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNewClubData:)
                                                 name:ScreenDataProcessorNewClubDataNotification
                                               object:nil];

    // Add swipe gestures for tab switching
    [self setupSwipeGestures];
}

- (void)setupHeader {
    // Header container - smaller height to save space
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 20, self.view.bounds.size.width, 35)];
    headerView.backgroundColor = APP_COLOR_BG;
    [self.view addSubview:headerView];

    // BLM Recorder title (left) - smaller and adjusted position
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 5, 200, 25)];
    titleLabel.text = @"BLM Recorder";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [headerView addSubview:titleLabel];

    // Mode pill (right) - smaller and adjusted position
    UIView *modePill = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 75, 7, 55, 21)];
    modePill.backgroundColor = APP_COLOR_ACCENT;
    modePill.layer.cornerRadius = 10;
    [headerView addSubview:modePill];

    UILabel *modeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 55, 21)];
    modeLabel.text = @"MONITOR";
    modeLabel.textColor = [UIColor whiteColor];
    modeLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
    modeLabel.textAlignment = NSTextAlignmentCenter;
    [modePill addSubview:modeLabel];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    // Use safe area insets to adjust for tab bar, etc.
    UIEdgeInsets safeInsets = self.view.safeAreaInsets;
    CGFloat margin = 0;
    CGFloat headerHeight = 55; // 20 for top offset + 35 for smaller header height
    CGFloat gap = 4; // Small gap in the middle

    CGFloat availableWidth = self.view.bounds.size.width - safeInsets.left - safeInsets.right - margin * 2;
    CGFloat availableHeight = self.view.bounds.size.height - safeInsets.top - safeInsets.bottom - margin * 2 - headerHeight;

    // LEFT half (50% - half gap): Monitor images - split vertically for ball (top) and club (bottom)
    CGFloat leftWidth = (availableWidth - gap) * 0.5;
    CGFloat imageHeight = availableHeight / 2;

    self.ballDataImageView.frame = CGRectMake(margin + safeInsets.left,
                                               headerHeight + margin + safeInsets.top,
                                               leftWidth,
                                               imageHeight);

    self.clubDataImageView.frame = CGRectMake(margin + safeInsets.left,
                                               headerHeight + margin + safeInsets.top + imageHeight,
                                               leftWidth,
                                               imageHeight);

    // RIGHT half (50% - half gap): Camera
    CGFloat rightWidth = (availableWidth - gap) * 0.5;
    self.cameraContainer.frame = CGRectMake(margin + safeInsets.left + leftWidth + gap,
                                            headerHeight + margin + safeInsets.top,
                                            rightWidth,
                                            availableHeight);

    // Center the camera label
    for (UIView *subview in self.cameraContainer.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            subview.center = CGPointMake(rightWidth / 2, availableHeight / 2);
        }
    }
}

- (void)handleNewBallData:(NSNotification *)notification {
    UIImage *image = notification.userInfo[@"image"];

    // Update UI on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        if (image) {
            self.ballDataImageView.image = image;
            self.clubDataImageView.image = nil;
        }
    });
}

- (void)handleNewClubData:(NSNotification *)notification {
    UIImage *image = notification.userInfo[@"image"];

    // Update UI on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        if (image) {
            self.clubDataImageView.image = image;
        }
    });
}

#pragma mark - Swipe Gestures

- (void)setupSwipeGestures {
    // Swipe up gesture (previous tab)
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeUp:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:swipeUp];

    // Swipe down gesture (next tab)
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeDown:)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:swipeDown];
}

- (void)swipeUp:(UISwipeGestureRecognizer *)gesture {
    // Switch to next tab
    if (self.parentContainer) {
        [self.parentContainer switchToNextTab];
    }
}

- (void)swipeDown:(UISwipeGestureRecognizer *)gesture {
    // Switch to previous tab
    if (self.parentContainer) {
        [self.parentContainer switchToPreviousTab];
    }
}

@end
