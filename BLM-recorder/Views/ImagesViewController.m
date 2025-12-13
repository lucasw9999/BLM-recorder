#import "ImagesViewController.h"
#import "Theme.h"
#import "ScreenDataProcessor.h"
#import "DataModel.h"
#import "MainContainerViewController.h"

@interface ImagesViewController ()
@property (nonatomic, strong) UIImageView *ballDataImageView;
@property (nonatomic, strong) UIImageView *clubDataImageView;
@end

@implementation ImagesViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = APP_COLOR_BG;

    // Add header with title and mode
    [self setupHeader];

    // Initialize image views without setting their frames
    self.ballDataImageView = [[UIImageView alloc] init];
    self.ballDataImageView.backgroundColor = [UIColor blackColor];
    self.ballDataImageView.contentMode = UIViewContentModeScaleToFill;
    self.ballDataImageView.image = [DataModel shared].currentShotBallImage;
    [self.view addSubview:self.ballDataImageView];

    self.clubDataImageView = [[UIImageView alloc] init];
    self.clubDataImageView.backgroundColor = [UIColor blackColor];
    self.clubDataImageView.contentMode = UIViewContentModeScaleToFill;
    self.clubDataImageView.image = [DataModel shared].currentShotClubImage;
    [self.view addSubview:self.clubDataImageView];

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

    CGFloat availableWidth = self.view.bounds.size.width - safeInsets.left - safeInsets.right - margin * 2;
    CGFloat availableHeight = self.view.bounds.size.height - safeInsets.top - safeInsets.bottom - margin * 2 - headerHeight;
    CGFloat leftWidth = availableWidth * 0.6;
    CGFloat rightWidth = availableWidth * 0.4;

    // Update frames with the adjusted dimensions (starting below header)
    self.ballDataImageView.frame = CGRectMake(margin + safeInsets.left, headerHeight + margin + safeInsets.top,
                                                leftWidth, availableHeight);
    self.clubDataImageView.frame = CGRectMake(margin + safeInsets.left + leftWidth,
                                                headerHeight + margin + safeInsets.top,
                                                rightWidth, availableHeight);
}

- (void)handleNewBallData:(NSNotification *)notification {
    UIImage *image = notification.userInfo[@"image"];
    if (!image)
        return;
    
    // Update UI on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        self.ballDataImageView.image = image;
        self.clubDataImageView.image = nil;
    });
}

- (void)handleNewClubData:(NSNotification *)notification {
    UIImage *image = notification.userInfo[@"image"];
    if (!image)
        return;
    
    // Update UI on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        self.clubDataImageView.image = image;
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
