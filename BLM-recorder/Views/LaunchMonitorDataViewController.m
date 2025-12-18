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

// Card views for Auto Layout
@property (nonatomic, strong) UIView *distanceCard;
@property (nonatomic, strong) UIView *launchCard;
@property (nonatomic, strong) UIView *clubCard;

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
        unitFont = [UIFont italicSystemFontOfSize:(fontSize / 2.0)]; // Half size units (34/2.0 = 17pt)
    } else {
        valueFont = [UIFont boldSystemFontOfSize:fontSize]; // Make values bold
        unitFont = [UIFont systemFontOfSize:(fontSize / 2.0)]; // Units half size (34/2.0 = 17pt)
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

- (UIView *)createCardWithTitle:(NSString *)title {
    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;

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
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.text = title;
        titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]; // Dynamic Type
        titleLabel.textColor = APP_COLOR_SECONDARY_TEXT;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.8;
        [cardView addSubview:titleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:SPACING_SMALL],
            [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:CARD_PADDING],
            [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-CARD_PADDING],
            [titleLabel.heightAnchor constraintEqualToConstant:20]
        ]];
    }

    return cardView;
}

- (UIView *)createValueLabelGroup:(NSString *)header {
    // Container view for header + value
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    // Header label with Dynamic Type
    UILabel *fieldLabel = [[UILabel alloc] init];
    fieldLabel.translatesAutoresizingMaskIntoConstraints = NO;
    fieldLabel.text = header;
    fieldLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]; // ~15pt, scales
    fieldLabel.textColor = APP_COLOR_ACCENT;
    fieldLabel.adjustsFontForContentSizeCategory = YES; // Enable Dynamic Type scaling
    fieldLabel.adjustsFontSizeToFitWidth = YES;
    fieldLabel.minimumScaleFactor = 0.7;
    [container addSubview:fieldLabel];

    // Value label with Dynamic Type (bold)
    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.text = @"--";
    // Create bold version of Large Title style (~34pt, scales)
    UIFontDescriptor *descriptor = [[UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleLargeTitle] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    valueLabel.font = [UIFont fontWithDescriptor:descriptor size:0]; // size:0 uses descriptor's size
    valueLabel.textColor = APP_COLOR_TEXT;
    valueLabel.adjustsFontForContentSizeCategory = YES; // Enable Dynamic Type scaling
    valueLabel.numberOfLines = 0; // Allow multiple lines
    valueLabel.adjustsFontSizeToFitWidth = YES;
    valueLabel.minimumScaleFactor = 0.6;
    [container addSubview:valueLabel];

    self.valueLabels[header] = valueLabel;

    // Layout constraints (no fixed heights - let Dynamic Type control sizing)
    [NSLayoutConstraint activateConstraints:@[
        [fieldLabel.topAnchor constraintEqualToAnchor:container.topAnchor],
        [fieldLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [fieldLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [valueLabel.topAnchor constraintEqualToAnchor:fieldLabel.bottomAnchor],
        [valueLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [valueLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    return container;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = APP_COLOR_BG;

    self.valueLabels = [NSMutableDictionary dictionary];

    // Navigation bar is provided by UINavigationController (HIG-compliant)
    // No custom header needed

    // Create card views
    self.distanceCard = [self createCardWithTitle:@"DISTANCE"];
    self.distanceCard.isAccessibilityElement = YES;
    self.distanceCard.accessibilityLabel = @"Distance data";
    self.distanceCard.accessibilityHint = @"Shows carry, total distance, and apex height";

    self.launchCard = [self createCardWithTitle:@"LAUNCH"];
    self.launchCard.isAccessibilityElement = YES;
    self.launchCard.accessibilityLabel = @"Launch data";
    self.launchCard.accessibilityHint = @"Shows vertical launch angle, horizontal launch angle, and ball speed";

    self.clubCard = [self createCardWithTitle:@"CLUB & SPIN"];
    self.clubCard.isAccessibilityElement = YES;
    self.clubCard.accessibilityLabel = @"Club and spin data";
    self.clubCard.accessibilityHint = @"Shows club speed, smash factor, club path, angle of attack, spin axis, and total spin";

    [self.view addSubview:self.distanceCard];
    [self.view addSubview:self.launchCard];
    [self.view addSubview:self.clubCard];

    // Create value label groups for Distance card
    UIView *carryGroup = [self createValueLabelGroup:@"Carry"];
    UIView *totalGroup = [self createValueLabelGroup:@"Total"];
    UIView *apexGroup = [self createValueLabelGroup:@"Apex"];

    UIStackView *distanceStack = [[UIStackView alloc] initWithArrangedSubviews:@[carryGroup, totalGroup, apexGroup]];
    distanceStack.axis = UILayoutConstraintAxisHorizontal;
    distanceStack.distribution = UIStackViewDistributionFillEqually;
    distanceStack.spacing = 5;
    distanceStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.distanceCard addSubview:distanceStack];

    // Create value label groups for Launch card
    UIView *vlaGroup = [self createValueLabelGroup:@"VLA"];
    UIView *hlaGroup = [self createValueLabelGroup:@"HLA"];
    UIView *ballGroup = [self createValueLabelGroup:@"Ball"];

    UIStackView *launchStack = [[UIStackView alloc] initWithArrangedSubviews:@[vlaGroup, hlaGroup, ballGroup]];
    launchStack.axis = UILayoutConstraintAxisHorizontal;
    launchStack.distribution = UIStackViewDistributionFillEqually;
    launchStack.spacing = 5;
    launchStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.launchCard addSubview:launchStack];

    // Create value label groups for Club & Spin card
    UIView *clubGroup = [self createValueLabelGroup:@"Club"];
    UIView *efficiencyGroup = [self createValueLabelGroup:@"Efficiency"];
    UIView *pathGroup = [self createValueLabelGroup:@"Path"];
    UIView *aoaGroup = [self createValueLabelGroup:@"AOA"];
    UIView *sideSpinGroup = [self createValueLabelGroup:@"Side Spin"];
    UIView *backSpinGroup = [self createValueLabelGroup:@"Back Spin"];

    UIStackView *clubStack = [[UIStackView alloc] initWithArrangedSubviews:@[clubGroup, efficiencyGroup, pathGroup, aoaGroup, sideSpinGroup, backSpinGroup]];
    clubStack.axis = UILayoutConstraintAxisHorizontal;
    clubStack.distribution = UIStackViewDistributionFillEqually;
    clubStack.spacing = 5;
    clubStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.clubCard addSubview:clubStack];

    // Create Mini Game Info View
    self.miniGameInfoView = [self createCardWithTitle:@"MINI GAME"];
    [self.view addSubview:self.miniGameInfoView];

    // Create value label groups for Mini Game
    UIView *targetGroup = [self createValueLabelGroup:@"Target"];
    UIView *lastScoreGroup = [self createValueLabelGroup:@"Last Score"];
    UIView *shotsLeftGroup = [self createValueLabelGroup:@"Shots Left"];
    UIView *totalScoreGroup = [self createValueLabelGroup:@"Total Score"];

    UIStackView *miniGameStack = [[UIStackView alloc] initWithArrangedSubviews:@[targetGroup, lastScoreGroup, shotsLeftGroup, totalScoreGroup]];
    miniGameStack.axis = UILayoutConstraintAxisHorizontal;
    miniGameStack.distribution = UIStackViewDistributionFillEqually;
    miniGameStack.spacing = 5;
    miniGameStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.miniGameInfoView addSubview:miniGameStack];

    // Create "End game" button within the mini game card
    UIButton *endGameButton = [UIButton buttonWithType:UIButtonTypeSystem];
    endGameButton.translatesAutoresizingMaskIntoConstraints = NO;
    [endGameButton setTitle:@"End" forState:UIControlStateNormal];
    [endGameButton setTitleColor:APP_COLOR_TEXT forState:UIControlStateNormal];
    endGameButton.backgroundColor = APP_COLOR_ACCENT;
    endGameButton.layer.cornerRadius = 4.0;
    endGameButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2]; // ~11pt, scales
    endGameButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    endGameButton.accessibilityLabel = @"End game";
    endGameButton.accessibilityHint = @"Ends the current mini game early";
    [endGameButton addTarget:self action:@selector(endMiniGameTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.miniGameInfoView addSubview:endGameButton];

    // Create "Start game" button
    self.miniGameButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.miniGameButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.miniGameButton setTitle:@"Start Game" forState:UIControlStateNormal];
    [self.miniGameButton setTitleColor:APP_COLOR_TEXT forState:UIControlStateNormal];
    self.miniGameButton.backgroundColor = APP_COLOR_ACCENT;
    self.miniGameButton.layer.cornerRadius = 8.0;
    self.miniGameButton.accessibilityLabel = @"Start mini game";
    self.miniGameButton.accessibilityHint = @"Opens settings to configure and start a new mini game";
    [self.miniGameButton addTarget:self action:@selector(startMiniGameTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.miniGameButton];

    // Auto Layout constraints
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    CGFloat cardMargin = 15;
    CGFloat cardSpacing = 8;

    [NSLayoutConstraint activateConstraints:@[
        // Row 1: Distance and Launch cards (side by side, equal heights)
        [self.distanceCard.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:10],
        [self.distanceCard.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:cardMargin],

        [self.launchCard.topAnchor constraintEqualToAnchor:self.distanceCard.topAnchor],
        [self.launchCard.leadingAnchor constraintEqualToAnchor:self.distanceCard.trailingAnchor constant:cardSpacing],
        [self.launchCard.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-cardMargin],
        [self.launchCard.widthAnchor constraintEqualToAnchor:self.distanceCard.widthAnchor],
        [self.launchCard.heightAnchor constraintEqualToAnchor:self.distanceCard.heightAnchor],

        // Row 2: Club & Spin card (full width, equal height to distance/launch cards)
        [self.clubCard.topAnchor constraintEqualToAnchor:self.distanceCard.bottomAnchor constant:cardSpacing],
        [self.clubCard.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:cardMargin],
        [self.clubCard.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-cardMargin],
        [self.clubCard.heightAnchor constraintEqualToAnchor:self.distanceCard.heightAnchor],

        // Start Game button - pin to bottom to force cards to expand
        [self.miniGameButton.topAnchor constraintEqualToAnchor:self.clubCard.bottomAnchor constant:16],
        [self.miniGameButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.miniGameButton.widthAnchor constraintEqualToConstant:120],
        [self.miniGameButton.heightAnchor constraintEqualToConstant:40],
        [self.miniGameButton.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-16],

        // Mini Game Info View (initially hidden)
        [self.miniGameInfoView.topAnchor constraintEqualToAnchor:self.clubCard.bottomAnchor constant:8],
        [self.miniGameInfoView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:cardMargin],
        [self.miniGameInfoView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-cardMargin],
        [self.miniGameInfoView.heightAnchor constraintEqualToConstant:120],
        [self.miniGameInfoView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-8],

        // Distance card stack
        [distanceStack.leadingAnchor constraintEqualToAnchor:self.distanceCard.leadingAnchor constant:10],
        [distanceStack.trailingAnchor constraintEqualToAnchor:self.distanceCard.trailingAnchor constant:-10],
        [distanceStack.topAnchor constraintEqualToAnchor:self.distanceCard.topAnchor constant:30],
        [distanceStack.bottomAnchor constraintEqualToAnchor:self.distanceCard.bottomAnchor constant:-10],

        // Launch card stack
        [launchStack.leadingAnchor constraintEqualToAnchor:self.launchCard.leadingAnchor constant:10],
        [launchStack.trailingAnchor constraintEqualToAnchor:self.launchCard.trailingAnchor constant:-10],
        [launchStack.topAnchor constraintEqualToAnchor:self.launchCard.topAnchor constant:30],
        [launchStack.bottomAnchor constraintEqualToAnchor:self.launchCard.bottomAnchor constant:-10],

        // Club card stack
        [clubStack.leadingAnchor constraintEqualToAnchor:self.clubCard.leadingAnchor constant:10],
        [clubStack.trailingAnchor constraintEqualToAnchor:self.clubCard.trailingAnchor constant:-10],
        [clubStack.topAnchor constraintEqualToAnchor:self.clubCard.topAnchor constant:25],
        [clubStack.bottomAnchor constraintEqualToAnchor:self.clubCard.bottomAnchor constant:-10],

        // Mini game stack
        [miniGameStack.leadingAnchor constraintEqualToAnchor:self.miniGameInfoView.leadingAnchor constant:5],
        [miniGameStack.trailingAnchor constraintEqualToAnchor:self.miniGameInfoView.trailingAnchor constant:-5],
        [miniGameStack.topAnchor constraintEqualToAnchor:self.miniGameInfoView.topAnchor constant:25],
        [miniGameStack.bottomAnchor constraintEqualToAnchor:self.miniGameInfoView.bottomAnchor constant:-10],

        // End game button
        [endGameButton.trailingAnchor constraintEqualToAnchor:self.miniGameInfoView.trailingAnchor constant:-10],
        [endGameButton.topAnchor constraintEqualToAnchor:self.miniGameInfoView.topAnchor constant:5],
        [endGameButton.widthAnchor constraintEqualToConstant:60],
        [endGameButton.heightAnchor constraintEqualToConstant:20]
    ]];

    // Set initial visibility
    BOOL miniGameExists = NO;
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
    [vlaAttr addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:34] range:NSMakeRange(0, vlaValue.length)];
    [vlaAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_TEXT range:NSMakeRange(0, vlaValue.length)];  // Adaptive
    // Unit (°): same as other units
    [vlaAttr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:18] range:NSMakeRange(vlaValue.length, 1)];
    [vlaAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:NSMakeRange(vlaValue.length, 1)];  // Adaptive gray
    self.valueLabels[@"VLA"].attributedText = vlaAttr;

    // Apex (height) - numbers big, units small
    self.valueLabels[@"Apex"].attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%.0f", 3.0f * [data[@"Height"] floatValue]] unit:@" ft" fontSize:34];

    // Carry distance with decimal (like "2.0 yd")
    float carryDistance = [data[@"CarryDistance"] floatValue];
    float carryOffline = [data[@"CarryOffline"] floatValue];
    NSString *carryValue = [NSString stringWithFormat:@"%.1f", carryDistance];
    NSString *carryUnit = [NSString stringWithFormat:@" %@ •%.0f", distanceUnits, fabs(carryOffline)];
    self.valueLabels[@"Carry"].attributedText = [self attributedStringWithValue:carryValue unit:carryUnit fontSize:34];

    // Total distance with decimal (like "6.0 yd •4")
    float totalDistance = [data[@"TotalDistance"] floatValue];
    float totalOffline = [data[@"TotalOffline"] floatValue];
    NSString *totalValue = [NSString stringWithFormat:@"%.1f", totalDistance];
    NSString *totalUnit = [NSString stringWithFormat:@" %@ •%.0f", distanceUnits, fabs(totalOffline)];
    self.valueLabels[@"Total"].attributedText = [self attributedStringWithValue:totalValue unit:totalUnit fontSize:34];

    // HLA with direction - direction symbol same as units, numbers big, units small
    float hla = [data[@"HLA"] floatValue];
    NSString *hlaDirection = hla < 0 ? @"<" : @">";
    NSString *hlaValue = [NSString stringWithFormat:@"%.1f", fabs(hla)];
    NSString *hlaFull = [NSString stringWithFormat:@"%@%@°", hlaDirection, hlaValue];

    NSMutableAttributedString *hlaAttr = [[NSMutableAttributedString alloc] initWithString:hlaFull];
    // Direction symbol: same as units
    [hlaAttr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:18] range:NSMakeRange(0, 1)];
    [hlaAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:NSMakeRange(0, 1)];  // Adaptive gray
    // Number: large and bold
    [hlaAttr addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:34] range:NSMakeRange(1, hlaValue.length)];
    [hlaAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_TEXT range:NSMakeRange(1, hlaValue.length)];  // Adaptive
    // Unit (°): same as other units
    [hlaAttr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:18] range:NSMakeRange(1 + hlaValue.length, 1)];
    [hlaAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:NSMakeRange(1 + hlaValue.length, 1)];  // Adaptive gray
    self.valueLabels[@"HLA"].attributedText = hlaAttr;

    // Ball speed - numbers big, units small
    NSString *ballValue = [NSString stringWithFormat:@"%.1f", [data[@"Speed"] floatValue]];
    self.valueLabels[@"Ball"].attributedText = [self attributedStringWithValue:ballValue unit:@" mph" fontSize:34];

    // Path with direction (like "<0.51°")
    // Note: Path data comes from club data, so we'll set this in setClubData

    // Side Spin - value from launch monitor (e.g., 58 or -58 for L)
    float sideSpin = [data[@"SideSpin"] floatValue];
    NSString *sideSpinDirection = sideSpin < 0 ? @"L" : @"R";
    NSString *sideSpinString = [NSString stringWithFormat:@"%.0f", fabs(sideSpin)];
    self.valueLabels[@"Side Spin"].attributedText = [self attributedStringWithValue:sideSpinString unit:[NSString stringWithFormat:@"%@ rpm", sideSpinDirection] fontSize:34];

    // Back Spin - value from launch monitor (e.g., 560)
    float backSpin = [data[@"BackSpin"] floatValue];
    NSString *backSpinString = [NSString stringWithFormat:@"%.0f", backSpin];
    self.valueLabels[@"Back Spin"].attributedText = [self attributedStringWithValue:backSpinString unit:@" rpm" fontSize:34];

    if([data[@"IsPutt"] boolValue] == YES) {
        self.valueLabels[@"Carry"].attributedText = [self attributedStringWithValue:@"--" unit:@" ft" fontSize:34];
        self.valueLabels[@"VLA"].text = @"--";
        self.valueLabels[@"Apex"].attributedText = [self attributedStringWithValue:@"--" unit:@" ft" fontSize:34];
        self.valueLabels[@"Back Spin"].attributedText = [self attributedStringWithValue:@"--" unit:@" rpm" fontSize:34];
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
    self.valueLabels[@"Club"].attributedText = [self attributedStringWithValue:clubValue unit:@" mph" fontSize:34];

    // Efficiency: just the efficiency ratio
    float efficiency = [data[@"Efficiency"] floatValue];
    NSString *efficiencyValue = [NSString stringWithFormat:@"%.2f", efficiency];
    self.valueLabels[@"Efficiency"].attributedText = [self attributedStringWithValue:efficiencyValue unit:@"x" fontSize:34];

    // Path with direction - direction symbol same as units, numbers big, units small
    float path = [data[@"Path"] floatValue];
    NSString *pathDirection = path < 0 ? @"<" : @">";
    NSString *pathValue = [NSString stringWithFormat:@"%.2f", fabs(path)];
    NSString *pathFull = [NSString stringWithFormat:@"%@%@°", pathDirection, pathValue];

    if (self.valueLabels[@"Path"]) {
        NSMutableAttributedString *pathAttr = [[NSMutableAttributedString alloc] initWithString:pathFull];
        // Direction symbol: same as units
        [pathAttr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:18] range:NSMakeRange(0, 1)];
        [pathAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:NSMakeRange(0, 1)];  // Adaptive gray
        // Number: large and bold
        [pathAttr addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:34] range:NSMakeRange(1, pathValue.length)];
        [pathAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_TEXT range:NSMakeRange(1, pathValue.length)];  // Adaptive
        // Unit (°): same as other units
        [pathAttr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:18] range:NSMakeRange(1 + pathValue.length, 1)];
        [pathAttr addAttribute:NSForegroundColorAttributeName value:APP_COLOR_SECONDARY_TEXT range:NSMakeRange(1 + pathValue.length, 1)];  // Adaptive gray
        self.valueLabels[@"Path"].attributedText = pathAttr;
    }

    // AOA: angle of attack with direction - numbers big, symbols small
    float aoa = [data[@"AngleOfAttack"] floatValue];
    NSString *aoaArrow = aoa < 0 ? @"↓" : @"↑";
    NSString *aoaValue = [NSString stringWithFormat:@"%.2f°", fabs(aoa)];
    self.valueLabels[@"AOA"].attributedText = [self attributedStringWithValue:aoaValue unit:aoaArrow fontSize:34];
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
        self.valueLabels[@"Target"].attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%ld", targetDistanceForCurrentShot] unit:distanceUnits fontSize:34];
        self.valueLabels[@"Last Score"].attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%ld", mostRecentShotScore] unit:[NSString stringWithFormat:@"(%@)", formattedStringFromInteger(mostRecentShotToPar)] fontSize:34];
        self.valueLabels[@"Shots Left"].attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%ld", shotsRemaining] unit:@"" fontSize:34];
        self.valueLabels[@"Total Score"].attributedText = [self attributedStringWithValue:[NSString stringWithFormat:@"%ld", totalScore] unit:[NSString stringWithFormat:@"(%@)", formattedStringFromInteger(totalToPar)] fontSize:34];
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

- (void)createLoadingView {
    // Create a semi-transparent overlay
    self.loadingView = [[UIView alloc] init];
    self.loadingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];

    // Create a container for the loading indicator and label
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    container.layer.cornerRadius = 20;
    container.layer.borderWidth = 1;
    container.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;

    // Add activity indicator
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.color = APP_COLOR_ACCENT;
    [spinner startAnimating];
    [container addSubview:spinner];

    // Add loading label
    UILabel *loadingLabel = [[UILabel alloc] init];
    loadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    loadingLabel.text = @"Loading AI models...\nThis may take a moment";
    loadingLabel.numberOfLines = 2;
    loadingLabel.textAlignment = NSTextAlignmentCenter;
    loadingLabel.textColor = [UIColor whiteColor];
    loadingLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]; // ~13pt, scales
    loadingLabel.adjustsFontForContentSizeCategory = YES;
    [container addSubview:loadingLabel];

    [self.loadingView addSubview:container];
    [self.view addSubview:self.loadingView];

    // Auto Layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Loading view fills entire screen
        [self.loadingView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.loadingView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.loadingView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.loadingView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        // Container centered
        [container.centerXAnchor constraintEqualToAnchor:self.loadingView.centerXAnchor],
        [container.centerYAnchor constraintEqualToAnchor:self.loadingView.centerYAnchor],
        [container.widthAnchor constraintEqualToConstant:180],
        [container.heightAnchor constraintEqualToConstant:180],

        // Spinner positioned
        [spinner.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [spinner.topAnchor constraintEqualToAnchor:container.topAnchor constant:50],

        // Loading label positioned
        [loadingLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:10],
        [loadingLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-10],
        [loadingLabel.topAnchor constraintEqualToAnchor:spinner.bottomAnchor constant:20],
        [loadingLabel.heightAnchor constraintEqualToConstant:50]
    ]];
}

- (void)handleModelsLoaded:(NSNotification *)notification {
    if (!self.loadingView) {
        return;
    }

    // Remove loading view with fade animation
    [UIView animateWithDuration:0.3 animations:^{
        self.loadingView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self.loadingView removeFromSuperview];
        self.loadingView = nil;
    }];
}

@end
