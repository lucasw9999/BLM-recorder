#import "LaunchMonitorDataViewController.h"
#import "Theme.h"
#import "ScreenDataProcessor.h"
#import "DataModel.h"
#import "MiniGameSettingsViewController.h"
#import "MiniGameEndViewController.h"
#import "MainContainerViewController.h"


NSString *formattedStringFromInteger(NSInteger value) {
    if (value == 0) {
        return @"E";
    } else if (value > 0) {
        return [NSString stringWithFormat:@"+%ld", (long)value];
    } else {
        return [NSString stringWithFormat:@"%ld", (long)value];
    }
}

@interface LaunchMonitorDataViewController ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, UILabel *> *valueLabels;

@property (nonatomic, strong) UIButton *miniGameButton;
@property (nonatomic, strong) UIView *miniGameInfoView;

@property (nonatomic, strong) UIView *loadingView;

@end

@implementation LaunchMonitorDataViewController

- (NSMutableAttributedString *)attributedStringWithValue:(NSString *)value
                                                     unit:(NSString *)unit
                                                 fontSize:(CGFloat)fontSize
                                               italicized:(bool)italicized
{
    // Combine the strings
    NSString *fullString = [NSString stringWithFormat:@"%@%@", value, unit];
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:fullString];

    // Decide on the fonts (italicized or regular)
    UIFont *valueFont;
    UIFont *unitFont;

    if (italicized) {
        valueFont = [UIFont italicSystemFontOfSize:fontSize];
        unitFont = [UIFont italicSystemFontOfSize:(fontSize / 2.0)]; // Half size units (32/2.0 = 16pt)
    } else {
        valueFont = [UIFont boldSystemFontOfSize:fontSize]; // Make values bold
        unitFont = [UIFont systemFontOfSize:(fontSize / 2.0)]; // Units half size (32/2.0 = 16pt)
    }

    // Apply the chosen fonts and colors to the respective ranges
    NSRange valueRange = NSMakeRange(0, [value length]);
    [attributedString addAttribute:NSFontAttributeName value:valueFont range:valueRange];
    [attributedString addAttribute:NSForegroundColorAttributeName value:APP_COLOR_TEXT range:valueRange]; // Adaptive: black in light mode, white in dark mode

    NSRange unitRange = NSMakeRange([value length], [unit length]);
    [attributedString addAttribute:NSFontAttributeName value:unitFont range:unitRange];
    [attributedString addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:unitRange]; // Adaptive gray

    return attributedString;
}

- (NSMutableAttributedString *)attributedStringWithValue:(NSString *)value
                                                     unit:(NSString *)unit
                                                 fontSize:(CGFloat)fontSize
{
    // Default "italicized" to NO
    return [self attributedStringWithValue:value unit:unit fontSize:fontSize italicized:NO];
}

- (UIView *)createCardWithTitle:(NSString *)title frame:(CGRect)frame {
    UIView *cardView = [[UIView alloc] initWithFrame:frame];

    // Use iOS semantic colors for automatic dark mode support
    cardView.backgroundColor = APP_COLOR_SECONDARY_BG;
    cardView.layer.cornerRadius = CARD_CORNER_RADIUS; // 10pt per iOS standards

    // Subtle shadow per Apple HIG
    cardView.layer.shadowColor = SHADOW_COLOR;
    cardView.layer.shadowOffset = SHADOW_OFFSET;
    cardView.layer.shadowOpacity = SHADOW_OPACITY;
    cardView.layer.shadowRadius = SHADOW_RADIUS;

    // Add card title label with Dynamic Type support
    if (title) {
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING,
                                                                          SPACING_SMALL,
                                                                          frame.size.width - (CARD_PADDING * 2),
                                                                          20)];
        titleLabel.text = title;
        titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]; // Dynamic Type
        titleLabel.textColor = APP_COLOR_SECONDARY_TEXT;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.8;
        [cardView addSubview:titleLabel];
    }

    return cardView;
}

- (void) addValueLabel:(NSString *) header
                     x:(int) x
                     y:(int) y
                 width:(int) width
                  view:(UIView *)view
{
    const int fontSize = 32;  // Consistent readable size
    const int headerSize = 13;
    UILabel *fieldLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y, width, headerSize)];
    fieldLabel.text = header;
    fieldLabel.font = [UIFont systemFontOfSize:headerSize];
    fieldLabel.textColor = APP_COLOR_ACCENT; // Blue headers like in mockup
    fieldLabel.adjustsFontSizeToFitWidth = YES; // Auto-resize to fit
    fieldLabel.minimumScaleFactor = 0.7;
    [view addSubview:fieldLabel];

    // Value label (bigger, just under the field label) - default to "--"
    UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y+headerSize, width, fontSize+8)];

    // Set default value to just "--" (no units until data arrives)
    valueLabel.text = @"--";

    valueLabel.font = [UIFont boldSystemFontOfSize:fontSize];
    valueLabel.textColor = APP_COLOR_TEXT;  // Adaptive: black in light mode, white in dark mode
    valueLabel.numberOfLines = 0; // Allow multiple lines for compact display
    valueLabel.adjustsFontSizeToFitWidth = YES; // Auto-resize to fit
    valueLabel.minimumScaleFactor = 0.6;
    [view addSubview:valueLabel];

    self.valueLabels[header] = valueLabel;
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
    themeSwitch.frame = CGRectMake(self.view.bounds.size.width - 140, 7, 51 * 0.65, 31 * 0.65);
    themeSwitch.on = (self.view.window.overrideUserInterfaceStyle == UIUserInterfaceStyleDark);
    [themeSwitch addTarget:self action:@selector(toggleTheme:) forControlEvents:UIControlEventValueChanged];
    [headerView addSubview:themeSwitch];

    // Add sun icon on left side of switch (SF Symbol)
    UIImageView *sunIcon = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 140 + 5, 9.5, 12, 12)];
    sunIcon.image = [UIImage systemImageNamed:@"sun.max.fill"];
    sunIcon.tintColor = [UIColor systemYellowColor];
    sunIcon.alpha = themeSwitch.isOn ? 0.3 : 1.0; // Dim when in dark mode
    sunIcon.tag = 999; // Tag to find later
    [headerView addSubview:sunIcon];

    // Add moon icon on right side of switch (SF Symbol)
    // Position at far right: switch_x + switch_width - icon_width - 3px padding
    UIImageView *moonIcon = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 140 + (51 * 0.65) - 15, 9.5, 12, 12)];
    moonIcon.image = [UIImage systemImageNamed:@"moon.fill"];
    moonIcon.tintColor = [UIColor systemYellowColor];
    moonIcon.alpha = themeSwitch.isOn ? 1.0 : 0.3; // Dim when in light mode
    moonIcon.tag = 998; // Tag to find later
    [headerView addSubview:moonIcon];

    // Mode pill (right) - smaller and adjusted position
    UIView *modePill = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 70, 7, 50, 21)];
    modePill.backgroundColor = APP_COLOR_ACCENT;
    modePill.layer.cornerRadius = 10;
    [headerView addSubview:modePill];

    UILabel *modeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 21)];
    modeLabel.text = @"PLAY";
    modeLabel.textColor = [UIColor whiteColor];
    modeLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
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


- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"[STARTUP] LaunchMonitorDataViewController viewDidLoad starting");
    self.view.backgroundColor = APP_COLOR_BG;

    self.valueLabels = [NSMutableDictionary dictionary];

    // Add header with title and mode
    [self setupHeader];

    // Add swipe gestures for tab switching (not model switching)
    [self setupSwipeGestures];

    // Create responsive card-based layout that fits iPhone screens
    CGFloat screenWidth = self.view.bounds.size.width;

    CGFloat cardMargin = 15;
    CGFloat cardSpacing = 8; // Reduced spacing to optimize layout
    CGFloat cardWidth = (screenWidth - cardMargin * 2 - cardSpacing) / 2;
    CGFloat cardHeight = 110; // Reduced to avoid cutting off button

    // Start lower to account for smaller header
    CGFloat startY = 65;

    // Row 1: Distance and Launch cards (side by side)
    UIView *distanceCard = [self createCardWithTitle:@"DISTANCE" frame:CGRectMake(cardMargin, startY, cardWidth, cardHeight)];
    [self.view addSubview:distanceCard];

    CGFloat itemWidth = (cardWidth - 30) / 3; // 3 items per card
    [self addValueLabel:@"Carry" x:10 y:30 width:itemWidth view:distanceCard];
    [self addValueLabel:@"Total" x:10 + itemWidth y:30 width:itemWidth view:distanceCard];
    [self addValueLabel:@"Apex" x:10 + itemWidth * 2 y:30 width:itemWidth view:distanceCard];

    UIView *launchCard = [self createCardWithTitle:@"LAUNCH" frame:CGRectMake(cardMargin + cardWidth + cardSpacing, startY, cardWidth, cardHeight)];
    [self.view addSubview:launchCard];

    CGFloat launchItemWidth = (cardWidth - 30) / 3; // 3 items per card
    [self addValueLabel:@"VLA" x:10 y:30 width:launchItemWidth view:launchCard];
    [self addValueLabel:@"HLA" x:10 + launchItemWidth y:30 width:launchItemWidth view:launchCard];
    [self addValueLabel:@"Ball" x:10 + launchItemWidth * 2 y:30 width:launchItemWidth view:launchCard];

    // Row 2: Club & Spin card (full width, horizontal layout)
    CGFloat row2Y = startY + cardHeight + cardSpacing;
    CGFloat clubCardHeight = 110; // Reduced to match other cards
    UIView *clubCard = [self createCardWithTitle:@"CLUB & SPIN" frame:CGRectMake(cardMargin, row2Y, cardWidth * 2 + cardSpacing, clubCardHeight)];
    [self.view addSubview:clubCard];

    CGFloat clubItemWidth = (clubCard.frame.size.width - 30) / 6; // 6 items across
    [self addValueLabel:@"Club" x:10 y:25 width:clubItemWidth view:clubCard];
    [self addValueLabel:@"Efficiency" x:10 + clubItemWidth y:25 width:clubItemWidth view:clubCard];
    [self addValueLabel:@"Path" x:10 + clubItemWidth * 2 y:25 width:clubItemWidth view:clubCard];
    [self addValueLabel:@"AOA" x:10 + clubItemWidth * 3 y:25 width:clubItemWidth view:clubCard];
    [self addValueLabel:@"Spin Axis" x:10 + clubItemWidth * 4 y:25 width:clubItemWidth view:clubCard];
    [self addValueLabel:@"Total Spin" x:10 + clubItemWidth * 5 y:25 width:clubItemWidth view:clubCard];

    // Row 3: Mini Game section - reduced spacing for better layout
    CGFloat miniGameY = row2Y + clubCardHeight + 6; // Reduced spacing
    CGFloat miniGameCardHeight = 100; // Increased height for better proportions

    // Position button with proper spacing after mini game area
    CGFloat buttonY = miniGameY + 8; // Small gap between cards and button

    // --- Create "Start game" button ---
    self.miniGameButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.miniGameButton setTitle:@"Start Game" forState:UIControlStateNormal];
    [self.miniGameButton setTitleColor:APP_COLOR_TEXT forState:UIControlStateNormal];
    self.miniGameButton.backgroundColor = APP_COLOR_ACCENT;
    self.miniGameButton.layer.cornerRadius = 8.0;
    self.miniGameButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.miniGameButton addTarget:self action:@selector(startMiniGameTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.miniGameButton];

    // --- Create Mini Game Card (compact) ---
    self.miniGameInfoView = [self createCardWithTitle:@"MINI GAME" frame:CGRectMake(cardMargin, miniGameY, cardWidth * 2 + cardSpacing, miniGameCardHeight)];
    [self.view addSubview:self.miniGameInfoView];

    // Mini-game data layout within the compact card
    CGFloat miniGameItemWidth = (self.miniGameInfoView.frame.size.width - 20) / 4;
    [self addValueLabel:@"Target" x:5 y:25 width:miniGameItemWidth - 5 view:self.miniGameInfoView];
    [self addValueLabel:@"Last Score" x:5 + miniGameItemWidth y:25 width:miniGameItemWidth - 5 view:self.miniGameInfoView];
    [self addValueLabel:@"Shots Left" x:5 + miniGameItemWidth * 2 y:25 width:miniGameItemWidth - 5 view:self.miniGameInfoView];
    [self addValueLabel:@"Total Score" x:5 + miniGameItemWidth * 3 y:25 width:miniGameItemWidth - 5 view:self.miniGameInfoView];

    // Create the "End game" button within the card (smaller)
    UIButton *endGameButton = [UIButton buttonWithType:UIButtonTypeSystem];
    endGameButton.frame = CGRectMake(self.miniGameInfoView.frame.size.width - 70, 5, 60, 20);
    [endGameButton setTitle:@"End" forState:UIControlStateNormal];
    [endGameButton setTitleColor:APP_COLOR_TEXT forState:UIControlStateNormal];
    endGameButton.backgroundColor = APP_COLOR_ACCENT;
    endGameButton.layer.cornerRadius = 4.0;
    endGameButton.titleLabel.font = [UIFont systemFontOfSize:10];
    [endGameButton addTarget:self action:@selector(endMiniGameTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.miniGameInfoView addSubview:endGameButton];

    // --- Set the initial visibility ---
    // For example, if no mini game exists, show the start button; otherwise show the info row.
    BOOL miniGameExists = NO; // <-- Replace with your own logic

    // Set layout constraints for the start button
    [NSLayoutConstraint activateConstraints:@[
        [self.miniGameButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.miniGameButton.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:buttonY],
        [self.miniGameButton.widthAnchor constraintEqualToConstant:120],
        [self.miniGameButton.heightAnchor constraintEqualToConstant:40]
    ]];

    self.miniGameButton.hidden = miniGameExists;
    self.miniGameInfoView.hidden = !miniGameExists;

    // Listen for data changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNewBallData:)
                                                 name:ScreenDataProcessorNewBallDataNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNewClubData:)
                                                 name:ScreenDataProcessorNewClubDataNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMiniGameStatusChanged:)
                                                 name:MiniGameStatusChangedNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleModelsLoaded:)
                                                 name:ModelsLoadedNotification
                                               object:nil];


    // Only access DataModel if it's already initialized (don't force initialization)
    DataModel *dataModel = [DataModel sharedIfExists];
    if (dataModel) {
        [self updateMiniGameData:[dataModel getMiniGameManager]];
        [self setBallData:dataModel.currentShotBallData];
        [self setClubData:dataModel.currentShotClubData];

        // Create loading view if models aren't loaded yet
        if (!dataModel.modelsLoaded) {
            dispatch_async(dispatch_get_main_queue(), ^{
                DataModel *dm = [DataModel sharedIfExists];
                if (dm && !dm.modelsLoaded && !self.loadingView) {
                    [self createLoadingView];
                }
            });
        }
    } else {
        // DataModel not initialized yet - will get data via notifications when it's ready
        NSLog(@"[STARTUP] DataModel not yet initialized, waiting for notifications");
    }
    
    // DEBUG ONLY
    /*
    self.valueLabels[@"VLA"].attributedText = [self attributedStringWithValue:@"30.2°" unit:@"" fontSize:48];
    self.valueLabels[@"HLA"].attributedText = [self attributedStringWithValue:@"←24°" unit:@"" fontSize:48];
    self.valueLabels[@"Spin"].attributedText = [self attributedStringWithValue:@"24°→ 12789" unit:@"rpm" fontSize:40];
    
    self.valueLabels[@"Apex"].attributedText = [self attributedStringWithValue:@"81" unit:@"ft" fontSize:48 italicized:YES];
    self.valueLabels[@"Carry"].attributedText = [self attributedStringWithValue:@"299" unit:@"yd → 15" fontSize:48];
    self.valueLabels[@"Total"].attributedText = [self attributedStringWithValue:@"399" unit:@"yd ← 29" fontSize:48 italicized:YES];
    
    self.valueLabels[@"Ball"].attributedText = [self attributedStringWithValue:@"185" unit:@"mph" fontSize:48];
    self.valueLabels[@"Club"].attributedText = [self attributedStringWithValue:@"119" unit:@"mph / 1.49x" fontSize:48];
    self.valueLabels[@"Path"].attributedText = [self attributedStringWithValue:@"←17.2°" unit:@"" fontSize:48];
    self.valueLabels[@"AOA"].attributedText = [self attributedStringWithValue:@"17.2° ↑" unit:@"" fontSize:48];
    
    self.valueLabels[@"Target"].attributedText = [self attributedStringWithValue:@"129" unit:@"yd" fontSize:48];
    self.valueLabels[@"Last Score"].attributedText = [self attributedStringWithValue:@"100" unit:@"(+1)" fontSize:48];
    self.valueLabels[@"Shots Left"].attributedText = [self attributedStringWithValue:@"39" unit:@"" fontSize:48];
    self.valueLabels[@"Total Score"].attributedText = [self attributedStringWithValue:@"100" unit:@"(-13)" fontSize:48];
    
    [self showMiniGamePanel:YES];
     */
    // DEBUG ONLY

    NSLog(@"[STARTUP] LaunchMonitorDataViewController viewDidLoad completed");
}

- (NSString*) getLeftRightArrowFromValue:(float) value {
    return value < 0 ? @"←" : @"→";
}

- (NSString*) getUpDownArrowFromValue:(float) value {
    return value < 0 ? @"↓" : @"↑";
}

- (NSString*) degreesWithLeftRightDirection:(NSString*) degreesValue {
    float degrees = [degreesValue floatValue];
    NSString* maybeLeftArrow = degrees < 0 ? @"←" : @"";
    NSString* maybeRightArrow = degrees > 0 ? @"→" : @"";
    return [NSString stringWithFormat:@"%@%@°%@", maybeLeftArrow, degreesValue, maybeRightArrow];
}

- (void)setBallData:(NSDictionary *)data {
    if(!data)
        return;

    bool isPutt = [data[@"IsPutt"] boolValue];
    NSString* distanceUnits = isPutt ? @"ft" : @"yd";

    // VLA (Vertical Launch Angle) - numbers big, units small
    NSString *vlaValue = [NSString stringWithFormat:@"%.1f", [data[@"VLA"] floatValue]];
    NSString *vlaFull = [NSString stringWithFormat:@"%@°", vlaValue];

    NSMutableAttributedString *vlaAttr = [[NSMutableAttributedString alloc] initWithString:vlaFull];
    // Number: large and bold
    [vlaAttr addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:32] range:NSMakeRange(0, vlaValue.length)];
    [vlaAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_TEXT range:NSMakeRange(0, vlaValue.length)];  // Adaptive
    // Unit (°): same as other units
    [vlaAttr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:16] range:NSMakeRange(vlaValue.length, 1)];
    [vlaAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:NSMakeRange(vlaValue.length, 1)];  // Adaptive gray
    self.valueLabels[@"VLA"].attributedText = vlaAttr;

    // Apex (height) - numbers big, units small
    self.valueLabels[@"Apex"].attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%.0f", 3.0f * [data[@"Height"] floatValue]] unit:@" ft" fontSize:32];

    // Carry distance with decimal (like "2.0 yd")
    float carryDistance = [data[@"CarryDistance"] floatValue];
    float carryOffline = [data[@"CarryOffline"] floatValue];
    NSString *carryValue = [NSString stringWithFormat:@"%.1f", carryDistance];
    NSString *carryUnit = [NSString stringWithFormat:@" %@ •%.0f", distanceUnits, fabs(carryOffline)];
    self.valueLabels[@"Carry"].attributedText = [self attributedStringWithValue:carryValue unit:carryUnit fontSize:32];

    // Total distance with decimal (like "6.0 yd •4")
    float totalDistance = [data[@"TotalDistance"] floatValue];
    float totalOffline = [data[@"TotalOffline"] floatValue];
    NSString *totalValue = [NSString stringWithFormat:@"%.1f", totalDistance];
    NSString *totalUnit = [NSString stringWithFormat:@" %@ •%.0f", distanceUnits, fabs(totalOffline)];
    self.valueLabels[@"Total"].attributedText = [self attributedStringWithValue:totalValue unit:totalUnit fontSize:32];

    // HLA with direction - direction symbol same as units, numbers big, units small
    float hla = [data[@"HLA"] floatValue];
    NSString *hlaDirection = hla < 0 ? @"<" : @">";
    NSString *hlaValue = [NSString stringWithFormat:@"%.1f", fabs(hla)];
    NSString *hlaFull = [NSString stringWithFormat:@"%@%@°", hlaDirection, hlaValue];

    NSMutableAttributedString *hlaAttr = [[NSMutableAttributedString alloc] initWithString:hlaFull];
    // Direction symbol: same as units
    [hlaAttr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:16] range:NSMakeRange(0, 1)];
    [hlaAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:NSMakeRange(0, 1)];  // Adaptive gray
    // Number: large and bold
    [hlaAttr addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:32] range:NSMakeRange(1, hlaValue.length)];
    [hlaAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_TEXT range:NSMakeRange(1, hlaValue.length)];  // Adaptive
    // Unit (°): same as other units
    [hlaAttr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:16] range:NSMakeRange(1 + hlaValue.length, 1)];
    [hlaAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:NSMakeRange(1 + hlaValue.length, 1)];  // Adaptive gray
    self.valueLabels[@"HLA"].attributedText = hlaAttr;

    // Ball speed - numbers big, units small
    NSString *ballValue = [NSString stringWithFormat:@"%.1f", [data[@"Speed"] floatValue]];
    self.valueLabels[@"Ball"].attributedText = [self attributedStringWithValue:ballValue unit:@" mph" fontSize:32];

    // Path with direction (like "<0.51°")
    // Note: Path data comes from club data, so we'll set this in setClubData

    // Spin Axis - direction symbol same as units, numbers big, units small
    float spinAxis = [data[@"SpinAxis"] floatValue];
    NSString *sideSpinDirection = spinAxis < 0 ? @"<" : @">";
    NSString *sideSpinValue = [NSString stringWithFormat:@"%.2f", fabs(spinAxis)];
    NSString *sideSpinFull = [NSString stringWithFormat:@"%@%@°", sideSpinDirection, sideSpinValue];

    NSMutableAttributedString *sideSpinAttr = [[NSMutableAttributedString alloc] initWithString:sideSpinFull];
    // Direction symbol: same as units
    [sideSpinAttr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:16] range:NSMakeRange(0, 1)];
    [sideSpinAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:NSMakeRange(0, 1)];  // Adaptive gray
    // Number: large and bold
    [sideSpinAttr addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:32] range:NSMakeRange(1, sideSpinValue.length)];
    [sideSpinAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_TEXT range:NSMakeRange(1, sideSpinValue.length)];  // Adaptive
    // Unit (°): same as other units
    [sideSpinAttr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:16] range:NSMakeRange(1 + sideSpinValue.length, 1)];
    [sideSpinAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:NSMakeRange(1 + sideSpinValue.length, 1)];  // Adaptive gray
    self.valueLabels[@"Spin Axis"].attributedText = sideSpinAttr;

    // Total Spin - numbers big, units small
    float totalSpin = [data[@"TotalSpin"] floatValue];
    NSString *totalSpinValue = [NSString stringWithFormat:@"%.0f", totalSpin];
    self.valueLabels[@"Total Spin"].attributedText = [self attributedStringWithValue:totalSpinValue unit:@" rpm" fontSize:32];

    if([data[@"IsPutt"] boolValue] == YES) {
        self.valueLabels[@"Carry"].attributedText = [self attributedStringWithValue:@"--" unit:@" ft" fontSize:32];
        self.valueLabels[@"VLA"].text = @"--";
        self.valueLabels[@"Apex"].attributedText = [self attributedStringWithValue:@"--" unit:@" ft" fontSize:32];
        self.valueLabels[@"Total Spin"].attributedText = [self attributedStringWithValue:@"--" unit:@" rpm" fontSize:32];
    }
}

- (void)handleNewBallData:(NSNotification *)notification {
    NSDictionary *data = notification.userInfo[@"data"];
    if (!data)
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self setBallData:data];
    });
}

- (void)setClubData:(NSDictionary *)data {
    if(!data)
        return;

    // Club: just speed - numbers big, units small
    float clubSpeed = [data[@"Speed"] floatValue];
    NSString *clubValue = [NSString stringWithFormat:@"%.1f", clubSpeed];
    self.valueLabels[@"Club"].attributedText = [self attributedStringWithValue:clubValue unit:@" mph" fontSize:32];

    // Efficiency: just the efficiency ratio
    float efficiency = [data[@"Efficiency"] floatValue];
    NSString *efficiencyValue = [NSString stringWithFormat:@"%.2f", efficiency];
    self.valueLabels[@"Efficiency"].attributedText = [self attributedStringWithValue:efficiencyValue unit:@"x" fontSize:32];

    // Path with direction - direction symbol same as units, numbers big, units small
    float path = [data[@"Path"] floatValue];
    NSString *pathDirection = path < 0 ? @"<" : @">";
    NSString *pathValue = [NSString stringWithFormat:@"%.2f", fabs(path)];
    NSString *pathFull = [NSString stringWithFormat:@"%@%@°", pathDirection, pathValue];

    if (self.valueLabels[@"Path"]) {
        NSMutableAttributedString *pathAttr = [[NSMutableAttributedString alloc] initWithString:pathFull];
        // Direction symbol: same as units
        [pathAttr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:16] range:NSMakeRange(0, 1)];
        [pathAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:NSMakeRange(0, 1)];  // Adaptive gray
        // Number: large and bold
        [pathAttr addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:32] range:NSMakeRange(1, pathValue.length)];
        [pathAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_TEXT range:NSMakeRange(1, pathValue.length)];  // Adaptive
        // Unit (°): same as other units
        [pathAttr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:16] range:NSMakeRange(1 + pathValue.length, 1)];
        [pathAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:NSMakeRange(1 + pathValue.length, 1)];  // Adaptive gray
        self.valueLabels[@"Path"].attributedText = pathAttr;
    }

    // AOA: angle of attack with direction - numbers big, symbols small
    float aoa = [data[@"AngleOfAttack"] floatValue];
    NSString *aoaArrow = aoa < 0 ? @"↓" : @"↑";
    NSString *aoaValue = [NSString stringWithFormat:@"%.2f°", fabs(aoa)];
    self.valueLabels[@"AOA"].attributedText = [self attributedStringWithValue:aoaValue unit:aoaArrow fontSize:32];
}

- (void)handleNewClubData:(NSNotification *)notification {
    NSDictionary *data = notification.userInfo[@"data"];
    if (!data)
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setClubData:data];
    });
}

- (void)startMiniGameTapped {
    // Create the modal view controller
    MiniGameSettingsViewController *settingsVC = [[MiniGameSettingsViewController alloc] init];
    settingsVC.modalPresentationStyle = UIModalPresentationFormSheet;
    // or UIModalPresentationOverFullScreen, or UIModalPresentationFullScreen, etc.
    
    // Present it
    [self presentViewController:settingsVC animated:YES completion:nil];
}


- (void)endMiniGameTapped {
    [[DataModel shared] endMiniGameEarly];
    [self updateMiniGameData:nil];
}

- (void)showMiniGamePanel:(bool)visible {
    bool miniGameExists = visible;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.miniGameButton.hidden = miniGameExists;
        self.miniGameInfoView.hidden = !miniGameExists;
    });
}

- (void)updateMiniGameData:(MiniGameManager *)miniGameManager {
    // Mini game not started or over
    if(!miniGameManager || [miniGameManager getShotsRemaining] == 0) {
        [self showMiniGamePanel:NO];
        return;
    }

    [self showMiniGamePanel:YES];

    NSInteger targetDistanceForCurrentShot = [miniGameManager getTargetDistanceForCurrentShot];
    NSInteger mostRecentShotScore = [miniGameManager getMostRecentShotScore];
    NSInteger mostRecentShotToPar = [miniGameManager getMostRecentShotToPar];
    NSInteger shotsRemaining = [miniGameManager getShotsRemaining];
    NSInteger totalScore = [miniGameManager getTotalScore];
    NSInteger totalToPar = [miniGameManager getTotalToPar];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* distanceUnits = [miniGameManager.gameType isEqualToString:@"Putting"] ? @"ft" : @"yd";
        self.valueLabels[@"Target"].attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%ld", targetDistanceForCurrentShot] unit:distanceUnits fontSize:32];
        self.valueLabels[@"Last Score"].attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%ld", mostRecentShotScore] unit:[NSString stringWithFormat:@"(%@)", formattedStringFromInteger(mostRecentShotToPar)] fontSize:32];
        self.valueLabels[@"Shots Left"].attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%ld", shotsRemaining] unit:@"" fontSize:32];
        self.valueLabels[@"Total Score"].attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%ld", totalScore] unit:[NSString stringWithFormat:@"(%@)", formattedStringFromInteger(totalToPar)] fontSize:32];
    });
}

- (void)handleMiniGameStatusChanged:(NSNotification *)notification {
    MiniGameManager *miniGameManager = notification.userInfo[@"miniGameManager"];
    if (!miniGameManager)
        return;
    
    [self updateMiniGameData:miniGameManager];
    
    //Handle end of game
    if(miniGameManager && [miniGameManager getShotsRemaining] == 0) {
        NSInteger totalScore = [miniGameManager getTotalScore];
        NSInteger totalToPar = [miniGameManager getTotalToPar];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Create and configure the end-of-game modal
            MiniGameEndViewController *endVC = [[MiniGameEndViewController alloc] init];
            // Pass in the final score from the miniGameManager
            endVC.finalScoreString = [NSString stringWithFormat:@"%ld (%@)", totalScore, formattedStringFromInteger(totalToPar)];
            endVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
            
            // Present the modal view controller
            [self presentViewController:endVC animated:YES completion:nil];
        });
    }
}

#pragma mark - Swipe Gestures

- (void)setupSwipeGestures {
    // Swipe up gesture (previous model)
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeUp:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:swipeUp];

    // Swipe down gesture (next model)
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

- (void)updateModelDisplay {
    // No longer needed - we're switching tabs, not models
}

- (void)createLoadingView {
    NSLog(@"Creating loading view overlay");

    // Create a semi-transparent overlay
    self.loadingView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.loadingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
    self.loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // Create a container for the loading indicator and label
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 180)];
    container.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    container.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    container.layer.cornerRadius = 20;

    // Add subtle border to make it more visible
    container.layer.borderWidth = 1;
    container.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;

    // Add activity indicator
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.center = CGPointMake(90, 70);
    spinner.color = APP_COLOR_ACCENT;
    [spinner startAnimating];
    [container addSubview:spinner];

    // Add loading label
    UILabel *loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 110, 160, 50)];
    loadingLabel.text = @"Loading AI models...\nThis may take a moment";
    loadingLabel.numberOfLines = 2;
    loadingLabel.textAlignment = NSTextAlignmentCenter;
    loadingLabel.textColor = [UIColor whiteColor];
    loadingLabel.font = [UIFont systemFontOfSize:13];
    [container addSubview:loadingLabel];

    [self.loadingView addSubview:container];
    [self.view addSubview:self.loadingView];

    NSLog(@"Loading view added to view hierarchy");
}

- (void)handleModelsLoaded:(NSNotification *)notification {
    NSLog(@"Models loaded notification received, removing loading view");

    if (!self.loadingView) {
        NSLog(@"No loading view to remove");
        return;
    }

    // Remove loading view with fade animation
    [UIView animateWithDuration:0.3 animations:^{
        self.loadingView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self.loadingView removeFromSuperview];
        self.loadingView = nil;
        NSLog(@"Loading view removed successfully");
    }];
}

@end
