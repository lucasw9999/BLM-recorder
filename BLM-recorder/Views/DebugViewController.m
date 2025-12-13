#import "DebugViewController.h"
#import "CameraManager.h"
#import "DataModel.h"
#import "ImageUtilities.h"
#import "MainContainerViewController.h"
#import "Theme.h"

@interface DebugViewController ()
@property (nonatomic, strong) UIImageView *cameraView;
@property (nonatomic, strong) NSArray<NSValue *> *corners;
@end

@implementation DebugViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = APP_COLOR_BG;

    // Add header with title and mode
    [self setupHeader];

    // UIImageView for displaying the latest processed frame (adjusted for smaller header)
    CGFloat headerHeight = 55; // 20 for top offset + 35 for smaller header height
    CGRect cameraFrame = CGRectMake(0, headerHeight, self.view.bounds.size.width, self.view.bounds.size.height - headerHeight);
    self.cameraView = [[UIImageView alloc] initWithFrame:cameraFrame];
    self.cameraView.contentMode = UIViewContentModeScaleAspectFit;
    self.cameraView.clipsToBounds = YES;
    [self.view addSubview:self.cameraView];

    // Listen for new frames and new corners
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateFrame:)
                                                 name:CameraManagerNewFrameNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCorners:)
                                                 name:ScreenDataProcessorNewCornersNotification
                                               object:nil];

    self.corners = [[DataModel shared].screenCorners copy];

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
    UIView *modePill = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 70, 7, 50, 21)];
    modePill.backgroundColor = APP_COLOR_ACCENT;
    modePill.layer.cornerRadius = 10;
    [headerView addSubview:modePill];

    UILabel *modeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 21)];
    modeLabel.text = @"CAMERA";
    modeLabel.textColor = [UIColor whiteColor];
    modeLabel.font = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
    modeLabel.textAlignment = NSTextAlignmentCenter;
    [modePill addSubview:modeLabel];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateFrame:nil]; // Ensure the latest frame is displayed when switching tabs
}

- (void)updateFrame:(NSNotification *)notification {
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
