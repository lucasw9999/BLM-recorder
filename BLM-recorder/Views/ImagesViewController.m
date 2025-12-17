#import "ImagesViewController.h"
#import "Theme.h"
#import "ScreenDataProcessor.h"
#import "DataModel.h"
#import "MainContainerViewController.h"
#import "CameraManager.h"

@interface ImagesViewController ()
@property (nonatomic, strong) UIImageView *ballDataImageView;
@property (nonatomic, strong) UIImageView *clubDataImageView;
@property (nonatomic, strong) UIView *cameraContainer;
@property (nonatomic, strong) UIImageView *cameraView;
@property (nonatomic, strong) NSArray<NSValue *> *corners;

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

    // Right side: Camera view
    self.cameraContainer = [[UIView alloc] init];
    self.cameraContainer.backgroundColor = [UIColor blackColor];
    // Add border
    self.cameraContainer.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;
    self.cameraContainer.layer.borderWidth = 1.0;
    [self.view addSubview:self.cameraContainer];

    // Camera image view for displaying live camera feed
    self.cameraView = [[UIImageView alloc] init];
    self.cameraView.contentMode = UIViewContentModeScaleAspectFit;
    self.cameraView.clipsToBounds = YES;
    [self.cameraContainer addSubview:self.cameraView];

    // Listen for camera frames and detected corners
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCameraFrame:)
                                                 name:CameraManagerNewFrameNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCorners:)
                                                 name:ScreenDataProcessorNewCornersNotification
                                               object:nil];

    self.corners = [[DataModel shared].screenCorners copy];

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
    titleLabel.textColor = APP_COLOR_TEXT; // Adaptive: black in light mode, white in dark mode
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [headerView addSubview:titleLabel];

    // Theme toggle switch (before mode pill) - aligned with mode pill height
    UISwitch *themeSwitch = [[UISwitch alloc] init];
    themeSwitch.transform = CGAffineTransformMakeScale(0.65, 0.65); // Scale down to match mode pill height (21pt)
    themeSwitch.frame = CGRectMake(self.view.bounds.size.width - 145, 7, 51 * 0.65, 31 * 0.65);
    themeSwitch.on = (self.view.window.overrideUserInterfaceStyle == UIUserInterfaceStyleDark);
    [themeSwitch addTarget:self action:@selector(toggleTheme:) forControlEvents:UIControlEventValueChanged];
    [headerView addSubview:themeSwitch];

    // Add sun icon on left side of switch (SF Symbol)
    UIImageView *sunIcon = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 145 + 4, 9.5, 12, 12)];
    sunIcon.image = [UIImage systemImageNamed:@"sun.max.fill"];
    sunIcon.tintColor = [UIColor systemYellowColor];
    sunIcon.alpha = themeSwitch.isOn ? 0.3 : 1.0; // Dim when in dark mode
    sunIcon.tag = 999; // Tag to find later
    [headerView addSubview:sunIcon];

    // Add moon icon on right side of switch (SF Symbol)
    UIImageView *moonIcon = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 145 + 51 * 0.65 - 16, 9.5, 12, 12)];
    moonIcon.image = [UIImage systemImageNamed:@"moon.fill"];
    moonIcon.tintColor = [UIColor systemYellowColor];
    moonIcon.alpha = themeSwitch.isOn ? 1.0 : 0.3; // Dim when in light mode
    moonIcon.tag = 998; // Tag to find later
    [headerView addSubview:moonIcon];

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

- (void)toggleTheme:(UISwitch *)sender {
    UIWindow *window = self.view.window;
    if (sender.isOn) {
        window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    } else {
        window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    }

    // Update sun/moon icon alpha based on switch state
    UIImageView *sunIcon = (UIImageView *)[self.view viewWithTag:999];
    UIImageView *moonIcon = (UIImageView *)[self.view viewWithTag:998];
    sunIcon.alpha = sender.isOn ? 0.3 : 1.0;
    moonIcon.alpha = sender.isOn ? 1.0 : 0.3;
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

    // Camera view fills the container
    self.cameraView.frame = self.cameraContainer.bounds;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateCameraFrame:nil]; // Ensure the latest frame is displayed when switching tabs
}

- (void)updateCameraFrame:(NSNotification *)notification {
    UIImage *latestFrame = notification.userInfo[@"frame"];
    if (!latestFrame)
        return;

    // Draw the detected corners on the frame
    UIImage *processedImage = [self drawPolygonOnImage:latestFrame corners:self.corners];

    // Update UI on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        self.cameraView.image = processedImage;
    });
}

- (void)updateCorners:(NSNotification *)notification {
    NSArray *corners = notification.userInfo[@"corners"];
    if (!corners)
        return;

    self.corners = [corners copy];
}

// Draws detected corners onto the frame
- (UIImage *)drawPolygonOnImage:(UIImage *)image corners:(NSArray<NSValue *> *)corners {
    if (!image || corners.count < 4) return image;

    UIGraphicsBeginImageContextWithOptions(image.size, NO, 0);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor greenColor].CGColor);
    CGContextSetLineWidth(context, 5.0);

    CGPoint p1 = [corners[0] CGPointValue];
    CGPoint p2 = [corners[1] CGPointValue];
    CGPoint p3 = [corners[2] CGPointValue];
    CGPoint p4 = [corners[3] CGPointValue];

    // For some reason, these need to be flipped in both X and Y...
    p1.x = image.size.width-1 - p1.x; p1.y = image.size.height-1 - p1.y;
    p2.x = image.size.width-1 - p2.x; p2.y = image.size.height-1 - p2.y;
    p3.x = image.size.width-1 - p3.x; p3.y = image.size.height-1 - p3.y;
    p4.x = image.size.width-1 - p4.x; p4.y = image.size.height-1 - p4.y;

    CGContextMoveToPoint(   context, p1.x, p1.y);
    CGContextAddLineToPoint(context, p2.x, p2.y);
    CGContextAddLineToPoint(context, p3.x, p3.y);
    CGContextAddLineToPoint(context, p4.x, p4.y);
    CGContextClosePath(context);
    CGContextStrokePath(context);

    UIImage *output = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return output;
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
