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

    // Navigation bar is provided by UINavigationController (HIG-compliant)
    // No custom header needed

    // Left side: Monitor images (ball and club data)
    self.ballDataImageView = [[UIImageView alloc] init];
    self.ballDataImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.ballDataImageView.backgroundColor = [UIColor blackColor];
    self.ballDataImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.ballDataImageView.image = [DataModel shared].currentShotBallImage;
    self.ballDataImageView.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;
    self.ballDataImageView.layer.borderWidth = 1.0;
    self.ballDataImageView.isAccessibilityElement = YES;
    self.ballDataImageView.accessibilityLabel = @"Ball data image";
    self.ballDataImageView.accessibilityHint = @"Shows the GSPro screen capture with ball flight data";
    [self.view addSubview:self.ballDataImageView];

    self.clubDataImageView = [[UIImageView alloc] init];
    self.clubDataImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.clubDataImageView.backgroundColor = [UIColor blackColor];
    self.clubDataImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.clubDataImageView.image = [DataModel shared].currentShotClubImage;
    self.clubDataImageView.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;
    self.clubDataImageView.layer.borderWidth = 1.0;
    self.clubDataImageView.isAccessibilityElement = YES;
    self.clubDataImageView.accessibilityLabel = @"Club data image";
    self.clubDataImageView.accessibilityHint = @"Shows the GSPro screen capture with club path data";
    [self.view addSubview:self.clubDataImageView];

    // Right side: Camera view
    self.cameraContainer = [[UIView alloc] init];
    self.cameraContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.cameraContainer.backgroundColor = [UIColor blackColor];
    self.cameraContainer.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;
    self.cameraContainer.layer.borderWidth = 1.0;
    self.cameraContainer.isAccessibilityElement = YES;
    self.cameraContainer.accessibilityLabel = @"Live camera view";
    self.cameraContainer.accessibilityHint = @"Shows live camera feed with detected screen corners highlighted";
    [self.view addSubview:self.cameraContainer];

    // Camera image view for displaying live camera feed
    self.cameraView = [[UIImageView alloc] init];
    self.cameraView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cameraView.contentMode = UIViewContentModeScaleAspectFit;
    self.cameraView.clipsToBounds = YES;
    [self.cameraContainer addSubview:self.cameraView];

    // Auto Layout constraints
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    CGFloat gap = 4;

    [NSLayoutConstraint activateConstraints:@[
        // Ball image view (top left)
        [self.ballDataImageView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [self.ballDataImageView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [self.ballDataImageView.heightAnchor constraintEqualToAnchor:safeArea.heightAnchor multiplier:0.5],

        // Club image view (bottom left)
        [self.clubDataImageView.topAnchor constraintEqualToAnchor:self.ballDataImageView.bottomAnchor],
        [self.clubDataImageView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [self.clubDataImageView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
        [self.clubDataImageView.widthAnchor constraintEqualToAnchor:self.ballDataImageView.widthAnchor],

        // Camera container (right side, full height)
        [self.cameraContainer.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [self.cameraContainer.leadingAnchor constraintEqualToAnchor:self.ballDataImageView.trailingAnchor constant:gap],
        [self.cameraContainer.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
        [self.cameraContainer.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
        [self.cameraContainer.widthAnchor constraintEqualToAnchor:self.ballDataImageView.widthAnchor],

        // Camera view fills container
        [self.cameraView.topAnchor constraintEqualToAnchor:self.cameraContainer.topAnchor],
        [self.cameraView.bottomAnchor constraintEqualToAnchor:self.cameraContainer.bottomAnchor],
        [self.cameraView.leadingAnchor constraintEqualToAnchor:self.cameraContainer.leadingAnchor],
        [self.cameraView.trailingAnchor constraintEqualToAnchor:self.cameraContainer.trailingAnchor]
    ]];

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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
