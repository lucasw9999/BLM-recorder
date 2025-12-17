#import "ImagesViewController.h"
#import "Theme.h"
#import "ScreenDataProcessor.h"
#import "DataModel.h"
#import "MainContainerViewController.h"

@interface ImagesViewController ()
@property (nonatomic, strong) UIImageView *ballDataImageView;
@property (nonatomic, strong) UIImageView *clubDataImageView;

// Data container and labels
@property (nonatomic, strong) UIView *dataContainer;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UILabel *> *valueLabels;

@end

@implementation ImagesViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = APP_COLOR_BG;

    // Initialize value labels dictionary
    self.valueLabels = [NSMutableDictionary dictionary];

    // Add header with title and mode
    [self setupHeader];

    // Initialize image views without setting their frames
    self.ballDataImageView = [[UIImageView alloc] init];
    self.ballDataImageView.backgroundColor = [UIColor blackColor];
    self.ballDataImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.ballDataImageView.image = [DataModel shared].currentShotBallImage;
    [self.view addSubview:self.ballDataImageView];

    self.clubDataImageView = [[UIImageView alloc] init];
    self.clubDataImageView.backgroundColor = [UIColor blackColor];
    self.clubDataImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.clubDataImageView.image = [DataModel shared].currentShotClubImage;
    [self.view addSubview:self.clubDataImageView];

    // Create data container for right side
    self.dataContainer = [[UIView alloc] init];
    self.dataContainer.backgroundColor = APP_COLOR_BG;
    [self.view addSubview:self.dataContainer];

    // Setup data cards in the container
    [self setupDataCards];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNewBallData:)
                                                 name:ScreenDataProcessorNewBallDataNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNewClubData:)
                                                 name:ScreenDataProcessorNewClubDataNotification
                                               object:nil];

    // Load initial data
    DataModel *dataModel = [DataModel sharedIfExists];
    if (dataModel) {
        [self setBallData:dataModel.currentShotBallData];
        [self setClubData:dataModel.currentShotClubData];
    }

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

    // Left side: Split vertically for ball (top) and club (bottom) images
    CGFloat imageHeight = availableHeight / 2;
    self.ballDataImageView.frame = CGRectMake(margin + safeInsets.left,
                                               headerHeight + margin + safeInsets.top,
                                               leftWidth,
                                               imageHeight);

    self.clubDataImageView.frame = CGRectMake(margin + safeInsets.left,
                                               headerHeight + margin + safeInsets.top + imageHeight,
                                               leftWidth,
                                               imageHeight);

    // Right side: Data container
    self.dataContainer.frame = CGRectMake(margin + safeInsets.left + leftWidth,
                                          headerHeight + margin + safeInsets.top,
                                          rightWidth,
                                          availableHeight);
}

#pragma mark - Helper Methods

- (UIView *)createCardWithTitle:(NSString *)title frame:(CGRect)frame {
    UIView *cardView = [[UIView alloc] initWithFrame:frame];
    cardView.backgroundColor = APP_COLOR_SECONDARY_BG;
    cardView.layer.cornerRadius = CARD_CORNER_RADIUS;

    // Subtle shadow
    cardView.layer.shadowColor = SHADOW_COLOR;
    cardView.layer.shadowOffset = SHADOW_OFFSET;
    cardView.layer.shadowOpacity = SHADOW_OPACITY;
    cardView.layer.shadowRadius = SHADOW_RADIUS;

    // Add card title
    if (title) {
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(4, 2, frame.size.width - 8, 12)];
        titleLabel.text = title;
        titleLabel.font = [UIFont systemFontOfSize:8 weight:UIFontWeightMedium];
        titleLabel.textColor = APP_COLOR_SECONDARY_TEXT;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.8;
        [cardView addSubview:titleLabel];
    }

    return cardView;
}

- (void)addValueLabel:(NSString *)header x:(int)x y:(int)y width:(int)width view:(UIView *)view {
    const int fontSize = 18;  // Smaller for compact layout
    const int headerSize = 8;

    UILabel *fieldLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y, width, headerSize)];
    fieldLabel.text = header;
    fieldLabel.font = [UIFont systemFontOfSize:headerSize];
    fieldLabel.textColor = APP_COLOR_ACCENT;
    fieldLabel.adjustsFontSizeToFitWidth = YES;
    fieldLabel.minimumScaleFactor = 0.7;
    [view addSubview:fieldLabel];

    // Value label
    UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y + headerSize, width, fontSize + 4)];
    valueLabel.text = @"--";
    valueLabel.font = [UIFont boldSystemFontOfSize:fontSize];
    valueLabel.textColor = [UIColor whiteColor];
    valueLabel.numberOfLines = 0;
    valueLabel.adjustsFontSizeToFitWidth = YES;
    valueLabel.minimumScaleFactor = 0.6;
    [view addSubview:valueLabel];

    self.valueLabels[header] = valueLabel;
}

- (NSMutableAttributedString *)attributedStringWithValue:(NSString *)value unit:(NSString *)unit fontSize:(CGFloat)fontSize {
    NSString *fullString = [NSString stringWithFormat:@"%@%@", value, unit];
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:fullString];

    UIFont *valueFont = [UIFont boldSystemFontOfSize:fontSize];
    UIFont *unitFont = [UIFont systemFontOfSize:(fontSize / 2.0)];

    NSRange valueRange = NSMakeRange(0, [value length]);
    [attributedString addAttribute:NSFontAttributeName value:valueFont range:valueRange];
    [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:valueRange];

    NSRange unitRange = NSMakeRange([value length], [unit length]);
    [attributedString addAttribute:NSFontAttributeName value:unitFont range:unitRange];
    [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithWhite:0.5 alpha:1.0] range:unitRange];

    return attributedString;
}

- (void)setupDataCards {
    // Get actual available height for data container
    CGFloat containerHeight = self.view.bounds.size.height - 55 - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom;
    CGFloat cardWidth = self.view.bounds.size.width * 0.4 - 8; // Account for margins

    // Calculate card heights to fit the available space
    // 3 cards with spacing: total spacing = 16pt (4pt margin top, 3x4pt spacing)
    // Remaining height divided into 3 cards proportionally
    CGFloat totalSpacing = 16;
    CGFloat availableCardHeight = containerHeight - totalSpacing;
    CGFloat cardHeight1 = availableCardHeight * 0.30; // Distance: 30%
    CGFloat cardHeight2 = availableCardHeight * 0.30; // Launch: 30%
    CGFloat cardHeight3 = availableCardHeight * 0.40; // Club & Spin: 40%

    CGFloat cardSpacing = 4;
    CGFloat startY = 4;

    // Distance card
    UIView *distanceCard = [self createCardWithTitle:@"DISTANCE" frame:CGRectMake(4, startY, cardWidth, cardHeight1)];
    [self.dataContainer addSubview:distanceCard];

    CGFloat itemWidth = (cardWidth - 8) / 3;
    [self addValueLabel:@"Carry" x:4 y:14 width:itemWidth view:distanceCard];
    [self addValueLabel:@"Total" x:4 + itemWidth y:14 width:itemWidth view:distanceCard];
    [self addValueLabel:@"Apex" x:4 + itemWidth * 2 y:14 width:itemWidth view:distanceCard];

    // Launch card
    CGFloat card2Y = startY + cardHeight1 + cardSpacing;
    UIView *launchCard = [self createCardWithTitle:@"LAUNCH" frame:CGRectMake(4, card2Y, cardWidth, cardHeight2)];
    [self.dataContainer addSubview:launchCard];

    [self addValueLabel:@"VLA" x:4 y:14 width:itemWidth view:launchCard];
    [self addValueLabel:@"HLA" x:4 + itemWidth y:14 width:itemWidth view:launchCard];
    [self addValueLabel:@"Ball" x:4 + itemWidth * 2 y:14 width:itemWidth view:launchCard];

    // Club & Spin card (taller for 5 items in 2 rows)
    CGFloat card3Y = card2Y + cardHeight2 + cardSpacing;
    UIView *clubCard = [self createCardWithTitle:@"CLUB & SPIN" frame:CGRectMake(4, card3Y, cardWidth, cardHeight3)];
    [self.dataContainer addSubview:clubCard];

    CGFloat clubItemWidth = (cardWidth - 8) / 2;
    CGFloat rowHeight = (cardHeight3 - 14) / 3; // 3 rows after title
    [self addValueLabel:@"Club" x:4 y:14 width:clubItemWidth view:clubCard];
    [self addValueLabel:@"Path" x:4 + clubItemWidth y:14 width:clubItemWidth view:clubCard];
    [self addValueLabel:@"AOA" x:4 y:14 + rowHeight width:clubItemWidth view:clubCard];
    [self addValueLabel:@"Side" x:4 + clubItemWidth y:14 + rowHeight width:clubItemWidth view:clubCard];
    [self addValueLabel:@"Back" x:4 y:14 + rowHeight * 2 width:clubItemWidth view:clubCard];
}

- (void)setBallData:(NSDictionary *)data {
    if (!data) return;

    bool isPutt = [data[@"IsPutt"] boolValue];
    NSString *distanceUnits = isPutt ? @"ft" : @"yd";

    // VLA
    NSString *vlaValue = [NSString stringWithFormat:@"%.1f", [data[@"VLA"] floatValue]];
    self.valueLabels[@"VLA"].attributedText = [self attributedStringWithValue:vlaValue unit:@"°" fontSize:18];

    // Apex
    self.valueLabels[@"Apex"].attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%.0f", 3.0f * [data[@"Height"] floatValue]] unit:@" ft" fontSize:18];

    // Carry
    float carryDistance = [data[@"CarryDistance"] floatValue];
    NSString *carryValue = [NSString stringWithFormat:@"%.1f", carryDistance];
    self.valueLabels[@"Carry"].attributedText = [self attributedStringWithValue:carryValue unit:distanceUnits fontSize:18];

    // Total
    float totalDistance = [data[@"TotalDistance"] floatValue];
    NSString *totalValue = [NSString stringWithFormat:@"%.1f", totalDistance];
    self.valueLabels[@"Total"].attributedText = [self attributedStringWithValue:totalValue unit:distanceUnits fontSize:18];

    // HLA
    float hla = [data[@"HLA"] floatValue];
    NSString *hlaDirection = hla < 0 ? @"<" : @">";
    NSString *hlaValue = [NSString stringWithFormat:@"%@%.1f", hlaDirection, fabs(hla)];
    self.valueLabels[@"HLA"].attributedText = [self attributedStringWithValue:hlaValue unit:@"°" fontSize:18];

    // Ball speed
    NSString *ballValue = [NSString stringWithFormat:@"%.1f", [data[@"Speed"] floatValue]];
    self.valueLabels[@"Ball"].attributedText = [self attributedStringWithValue:ballValue unit:@"mph" fontSize:18];

    // Side Spin (Spin Axis)
    float spinAxis = [data[@"SpinAxis"] floatValue];
    NSString *sideSpinDirection = spinAxis < 0 ? @"<" : @">";
    NSString *sideSpinValue = [NSString stringWithFormat:@"%@%.1f", sideSpinDirection, fabs(spinAxis)];
    self.valueLabels[@"Side"].attributedText = [self attributedStringWithValue:sideSpinValue unit:@"°" fontSize:18];

    // Back Spin
    float totalSpin = [data[@"TotalSpin"] floatValue];
    NSString *totalSpinValue = [NSString stringWithFormat:@"%.0f", totalSpin];
    self.valueLabels[@"Back"].attributedText = [self attributedStringWithValue:totalSpinValue unit:@"rpm" fontSize:18];

    if (isPutt) {
        self.valueLabels[@"Carry"].text = @"--";
        self.valueLabels[@"VLA"].text = @"--";
        self.valueLabels[@"Apex"].text = @"--";
        self.valueLabels[@"Back"].text = @"--";
    }
}

- (void)setClubData:(NSDictionary *)data {
    if (!data) return;

    // Club speed
    float clubSpeed = [data[@"Speed"] floatValue];
    NSString *clubValue = [NSString stringWithFormat:@"%.1f", clubSpeed];
    self.valueLabels[@"Club"].attributedText = [self attributedStringWithValue:clubValue unit:@"mph" fontSize:18];

    // Path
    float path = [data[@"Path"] floatValue];
    NSString *pathDirection = path < 0 ? @"<" : @">";
    NSString *pathValue = [NSString stringWithFormat:@"%@%.1f", pathDirection, fabs(path)];
    self.valueLabels[@"Path"].attributedText = [self attributedStringWithValue:pathValue unit:@"°" fontSize:18];

    // AOA
    float aoa = [data[@"AngleOfAttack"] floatValue];
    NSString *aoaArrow = aoa < 0 ? @"↓" : @"↑";
    NSString *aoaValue = [NSString stringWithFormat:@"%.1f", fabs(aoa)];
    self.valueLabels[@"AOA"].attributedText = [self attributedStringWithValue:aoaValue unit:aoaArrow fontSize:18];
}

#pragma mark - Notification Handlers

- (void)handleNewBallData:(NSNotification *)notification {
    UIImage *image = notification.userInfo[@"image"];
    NSDictionary *data = notification.userInfo[@"data"];

    // Update UI on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        if (image) {
            self.ballDataImageView.image = image;
            self.clubDataImageView.image = nil;
        }
        if (data) {
            [self setBallData:data];
        }
    });
}

- (void)handleNewClubData:(NSNotification *)notification {
    UIImage *image = notification.userInfo[@"image"];
    NSDictionary *data = notification.userInfo[@"data"];

    // Update UI on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        if (image) {
            self.clubDataImageView.image = image;
        }
        if (data) {
            [self setClubData:data];
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
