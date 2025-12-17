//
//  SettingsViewController.m
//  BLM-recorder
//
//  Created by Lucas on 2025.
//

#import "SettingsViewController.h"
#import "Theme.h"
#import "SettingsManager.h"
#import "GSProConnector.h"
#import "DataModel.h"
#import "MainContainerViewController.h"
#import "RedisManager.h"

@interface SettingsViewController () <UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UIPickerView *stimpPicker;
@property (nonatomic, strong) NSArray<NSNumber *> *stimpValues;
@property (nonatomic, assign) NSInteger selectedStimpIndex;

// New: A rounded text field for stimp (instead of placing the picker directly)
@property (nonatomic, strong) UITextField *stimpField;

@property (nonatomic, strong) UISegmentedControl *fairwayControl;
@property (nonatomic, strong) UITextField *ipField;
@property (nonatomic, strong) UILabel *connectionStateLabel;

// Redis settings
@property (nonatomic, strong) UITextField *redisHostField;
@property (nonatomic, strong) UITextField *redisPortField;
@property (nonatomic, strong) UITextField *redisPasswordField;
@property (nonatomic, strong) UILabel *redisStatusLabel;
@property (nonatomic, strong) UIButton *redisTestButton;

@property (nonatomic, assign) CGRect originalFrame;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = APP_COLOR_BG;

    self.originalFrame = self.view.frame;

    // Add header with title and mode
    [self setupHeader];

    // Build stimpValues: values from 5 to 15.
    NSMutableArray<NSNumber *> *values = [NSMutableArray array];
    for (NSInteger i = 5; i <= 15; i++) {
        [values addObject:@(i)];
    }
    self.stimpValues = [values copy];

    // Temporarily set selectedStimpIndex; the real value is loaded in viewWillAppear.
    self.selectedStimpIndex = 5; // default (e.g. stimp=10)

    // Create compact card-based layout that fits on one page
    [self setupCardLayout];

    // Observe keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    // Observe GSPro connection state notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleGSProConnectionState:)
                                                 name:GSProConnectionStateNotification
                                               object:nil];

    [self setConnectionStateFromGsProConnector:nil];

    // Add swipe gestures for tab switching (only when not scrolling)
    [self setupSwipeGestures];
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

- (void)setupCardLayout {
    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat cardWidth = screenWidth - (CARD_MARGIN * 2);
    CGFloat startY = 60; // Below header

    // Card 1: Golf Settings
    // Height calculation: title(20) + spacing(8) + fairway_row(28) + spacing(8) + stimp_row(28) + bottom_padding(8) = 100pt
    UIView *golfCard = [self createCardWithTitle:@"GOLF SETTINGS"
                                           frame:CGRectMake(CARD_MARGIN, startY,
                                                           cardWidth, 100)];
    [self.view addSubview:golfCard];

    // Fairway - label and control on same row
    // Starting at y=28 (title 20 + spacing 8)
    UILabel *fairwayLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 28, 60, 28)];
    fairwayLabel.text = @"Fairway";
    fairwayLabel.textColor = APP_COLOR_SECONDARY_TEXT;
    fairwayLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    [golfCard addSubview:fairwayLabel];

    self.fairwayControl = [[UISegmentedControl alloc] initWithItems:@[@"Slow", @"Med", @"Fast", @"Links"]];
    self.fairwayControl.frame = CGRectMake(70, 28, cardWidth - 70 - CARD_PADDING, 28);
    self.fairwayControl.selectedSegmentIndex = 1;
    [self.fairwayControl addTarget:self action:@selector(fairwayControlChanged:) forControlEvents:UIControlEventValueChanged];
    [golfCard addSubview:self.fairwayControl];

    // Stimp - label and field on same row
    // Starting at y=64 (28 + 28 + spacing 8)
    UILabel *stimpLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 64, 90, 28)];
    stimpLabel.text = @"Putting Stimp";
    stimpLabel.textColor = APP_COLOR_SECONDARY_TEXT;
    stimpLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    [golfCard addSubview:stimpLabel];

    self.stimpField = [[UITextField alloc] initWithFrame:CGRectMake(cardWidth - CARD_PADDING - 80, 64, 80, 28)];
    self.stimpField.borderStyle = UITextBorderStyleRoundedRect;
    self.stimpField.textAlignment = NSTextAlignmentCenter;
    self.stimpField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    [golfCard addSubview:self.stimpField];

    self.stimpPicker = [[UIPickerView alloc] init];
    self.stimpPicker.backgroundColor = APP_COLOR_SECONDARY_BG;
    self.stimpPicker.dataSource = self;
    self.stimpPicker.delegate = self;
    self.stimpField.inputView = self.stimpPicker;

    UIToolbar *stimpToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 44)];
    stimpToolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    stimpToolbar.items = @[flexSpace, doneButton];
    [stimpToolbar sizeToFit];
    self.stimpField.inputAccessoryView = stimpToolbar;

    // Card 2: GSPro
    // Height calculation: title(20) + spacing(8) + ip_row(28) + bottom_padding(8) = 64pt
    CGFloat card2Y = startY + 100 + SPACING_SMALL;
    UIView *gsproCard = [self createCardWithTitle:@"GSPRO"
                                            frame:CGRectMake(CARD_MARGIN, card2Y,
                                                            cardWidth, 64)];
    [self.view addSubview:gsproCard];

    // IP label, field, and status all on same row
    // Starting at y=28 (title 20 + spacing 8)
    UILabel *ipLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 28, 25, 28)];
    ipLabel.text = @"IP";
    ipLabel.textColor = APP_COLOR_SECONDARY_TEXT;
    ipLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    [gsproCard addSubview:ipLabel];

    self.ipField = [[UITextField alloc] initWithFrame:CGRectMake(35, 28, 140, 28)];
    self.ipField.borderStyle = UITextBorderStyleRoundedRect;
    self.ipField.placeholder = @"192.168.x.x";
    self.ipField.keyboardType = UIKeyboardTypeDecimalPad;
    self.ipField.delegate = self;
    self.ipField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];

    UIToolbar *ipToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 44)];
    ipToolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *ipFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *ipDone = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    ipToolbar.items = @[ipFlex, ipDone];
    [ipToolbar sizeToFit];
    self.ipField.inputAccessoryView = ipToolbar;
    [gsproCard addSubview:self.ipField];

    self.connectionStateLabel = [[UILabel alloc] initWithFrame:CGRectMake(180, 30, cardWidth - 180 - CARD_PADDING, 24)];
    self.connectionStateLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    self.connectionStateLabel.textAlignment = NSTextAlignmentLeft;
    [gsproCard addSubview:self.connectionStateLabel];

    // Card 3: Redis
    // Height calculation: title(20) + spacing(8) + host_row(28) + spacing(8) + port_pass_row(28) + spacing(8) + button(28) + spacing(4) + status(10) + bottom_padding(4) = 146pt
    CGFloat card3Y = card2Y + 64 + SPACING_SMALL;
    UIView *redisCard = [self createCardWithTitle:@"REDIS (OPTIONAL)"
                                            frame:CGRectMake(CARD_MARGIN, card3Y,
                                                            cardWidth, 146)];
    [self.view addSubview:redisCard];

    // Host - label and field on same row
    // Starting at y=28 (title 20 + spacing 8)
    UILabel *hostLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 28, 40, 28)];
    hostLabel.text = @"Host";
    hostLabel.textColor = APP_COLOR_SECONDARY_TEXT;
    hostLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    [redisCard addSubview:hostLabel];

    self.redisHostField = [[UITextField alloc] initWithFrame:CGRectMake(50, 28,
                                                                         cardWidth - 50 - CARD_PADDING, 28)];
    self.redisHostField.borderStyle = UITextBorderStyleRoundedRect;
    self.redisHostField.placeholder = @"redis-xxxxx.xxx.cloud.redislabs.com";
    self.redisHostField.keyboardType = UIKeyboardTypeURL;
    self.redisHostField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.redisHostField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.redisHostField.delegate = self;
    self.redisHostField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];

    UIToolbar *hostToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 44)];
    hostToolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *hostFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *hostDone = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    hostToolbar.items = @[hostFlex, hostDone];
    [hostToolbar sizeToFit];
    self.redisHostField.inputAccessoryView = hostToolbar;
    [redisCard addSubview:self.redisHostField];

    // Port and Password on same row
    // Starting at y=64 (28 + 28 + spacing 8)
    UILabel *portLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 64, 30, 28)];
    portLabel.text = @"Port";
    portLabel.textColor = APP_COLOR_SECONDARY_TEXT;
    portLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    [redisCard addSubview:portLabel];

    self.redisPortField = [[UITextField alloc] initWithFrame:CGRectMake(40, 64, 70, 28)];
    self.redisPortField.borderStyle = UITextBorderStyleRoundedRect;
    self.redisPortField.placeholder = @"12647";
    self.redisPortField.keyboardType = UIKeyboardTypeNumberPad;
    self.redisPortField.delegate = self;
    self.redisPortField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.redisPortField.textAlignment = NSTextAlignmentCenter;

    UIToolbar *portToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 44)];
    portToolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *portFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *portDone = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    portToolbar.items = @[portFlex, portDone];
    [portToolbar sizeToFit];
    self.redisPortField.inputAccessoryView = portToolbar;
    [redisCard addSubview:self.redisPortField];

    UILabel *passLabel = [[UILabel alloc] initWithFrame:CGRectMake(120, 64, 35, 28)];
    passLabel.text = @"Pass";
    passLabel.textColor = APP_COLOR_SECONDARY_TEXT;
    passLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    [redisCard addSubview:passLabel];

    self.redisPasswordField = [[UITextField alloc] initWithFrame:CGRectMake(160, 64,
                                                                             cardWidth - 160 - CARD_PADDING, 28)];
    self.redisPasswordField.borderStyle = UITextBorderStyleRoundedRect;
    self.redisPasswordField.placeholder = @"password";
    self.redisPasswordField.secureTextEntry = YES;
    self.redisPasswordField.delegate = self;
    self.redisPasswordField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];

    UIToolbar *passToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 44)];
    passToolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *passFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *passDone = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    passToolbar.items = @[passFlex, passDone];
    [passToolbar sizeToFit];
    self.redisPasswordField.inputAccessoryView = passToolbar;
    [redisCard addSubview:self.redisPasswordField];

    // Test button
    // Starting at y=100 (64 + 28 + spacing 8)
    self.redisTestButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.redisTestButton.frame = CGRectMake(CARD_PADDING, 100, cardWidth - (CARD_PADDING * 2), 28);
    [self.redisTestButton setTitle:@"Test Connection" forState:UIControlStateNormal];
    self.redisTestButton.backgroundColor = APP_COLOR_ACCENT;
    [self.redisTestButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.redisTestButton.layer.cornerRadius = BUTTON_CORNER_RADIUS;
    self.redisTestButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    [self.redisTestButton addTarget:self action:@selector(testRedisConnection:) forControlEvents:UIControlEventTouchUpInside];
    [redisCard addSubview:self.redisTestButton];

    // Status label at bottom
    // Starting at y=132 (100 + 28 + spacing 4)
    self.redisStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 132,
                                                                       cardWidth - (CARD_PADDING * 2), 10)];
    self.redisStatusLabel.font = [UIFont systemFontOfSize:8];
    self.redisStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.redisStatusLabel.textColor = APP_COLOR_TERTIARY_TEXT;
    self.redisStatusLabel.text = @"";
    [redisCard addSubview:self.redisStatusLabel];
}

- (void)setupHeader {
    // Header container with proper safe area consideration
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 20, self.view.bounds.size.width, 35)];
    headerView.backgroundColor = APP_COLOR_BG; // Adaptive background
    [self.view addSubview:headerView];

    // BLM Recorder title (left) - Dynamic Type
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(SPACING_LARGE, 5, 200, 25)];
    titleLabel.text = @"BLM Recorder";
    titleLabel.textColor = APP_COLOR_TEXT; // Adaptive text color
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]; // Dynamic Type
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

    // Mode pill (right) - Improved styling
    UIView *modePill = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 75, 7, 55, 21)];
    modePill.backgroundColor = APP_COLOR_ACCENT;
    modePill.layer.cornerRadius = 10;
    [headerView addSubview:modePill];

    UILabel *modeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 55, 21)];
    modeLabel.text = @"SETTINGS";
    modeLabel.textColor = [UIColor whiteColor];
    modeLabel.font = [UIFont systemFontOfSize:8 weight:UIFontWeightSemibold]; // Keep small for pill
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Load settings from SettingsManager
    SettingsManager *mgr = [SettingsManager shared];

    // Update stimp field value
    NSInteger stimp = mgr.stimp; // e.g. 10
    NSInteger rowIndex = [self.stimpValues indexOfObject:@(stimp)];
    if (rowIndex == NSNotFound) {
        rowIndex = 5; // default stimp=10
    }
    self.selectedStimpIndex = rowIndex;
    [self.stimpPicker selectRow:rowIndex inComponent:0 animated:NO];
    self.stimpField.text = [NSString stringWithFormat:@"%@", self.stimpValues[rowIndex]];

    // Update fairway control
    self.fairwayControl.selectedSegmentIndex = mgr.fairwaySpeedIndex;

    // Update IP field
    self.ipField.text = mgr.gsProIP;

    // Load Redis settings
    RedisManager *redis = [RedisManager shared];
    self.redisHostField.text = [redis getRedisHost];
    NSInteger port = [redis getRedisPort];
    if (port > 0) {
        self.redisPortField.text = [NSString stringWithFormat:@"%ld", (long)port];
    }
    if ([redis hasRedisPassword]) {
        self.redisPasswordField.text = @"••••••••"; // Show dots for existing password
    }

    // Update status
    [self updateRedisStatus];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Keyboard

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect kbFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    if (CGRectEqualToRect(self.view.frame, self.originalFrame)) {
        CGFloat shift = kbFrame.size.height / 2;
        self.view.frame = CGRectOffset(self.view.frame, 0, -shift);
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.view.frame = self.originalFrame;
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

#pragma mark - GSPro Connection

- (void)setConnectionStateFromGsProConnector:(NSString *)state {
    // Determine the connection string
    NSString *connectionString = (state != nil) ? state : [[GSProConnector shared] getConnectionState];
    
    // Update the label text
    self.connectionStateLabel.text = connectionString;
    
    // Set the appropriate text color based on connection state
    if ([connectionString isEqualToString:@"Connected"]) {
        self.connectionStateLabel.textColor = APP_COLOR_GREEN;
    } else if ([connectionString isEqualToString:@"Connecting"]) {
        self.connectionStateLabel.textColor = APP_COLOR_YELLOW;
    } else {
        self.connectionStateLabel.textColor = APP_COLOR_DARK_TEXT;
    }
}

- (void)handleGSProConnectionState:(NSNotification *)notification {
    NSString *connectionState = notification.userInfo[@"connectionState"];
    if (!connectionState)
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setConnectionStateFromGsProConnector:connectionState];
    });
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == self.ipField) {
        SettingsManager *mgr = [SettingsManager shared];
        [mgr setGSProIP:textField.text];
        [mgr saveSettings];
    } else if (textField == self.redisHostField) {
        RedisManager *redis = [RedisManager shared];
        [redis setRedisHost:textField.text];
        [self updateRedisStatus];
    } else if (textField == self.redisPortField) {
        RedisManager *redis = [RedisManager shared];
        NSInteger port = [textField.text integerValue];
        if (port > 0) {
            [redis setRedisPort:port];
        }
        [self updateRedisStatus];
    } else if (textField == self.redisPasswordField) {
        // Only update password if it's not the dots placeholder
        if (![textField.text isEqualToString:@"••••••••"] && textField.text.length > 0) {
            RedisManager *redis = [RedisManager shared];
            [redis setRedisPassword:textField.text];
            [self updateRedisStatus];
        }
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (textField == self.redisPasswordField) {
        // Clear the placeholder dots when editing starts
        if ([textField.text isEqualToString:@"••••••••"]) {
            textField.text = @"";
        }
    }
    return YES;
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.stimpValues.count;
}

#pragma mark - UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSNumber *value = self.stimpValues[row];
    return [value stringValue];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    self.selectedStimpIndex = row;
    NSInteger selectedStimp = [self.stimpValues[row] integerValue];
    self.stimpField.text = [NSString stringWithFormat:@"%ld", (long)selectedStimp];
    
    SettingsManager *mgr = [SettingsManager shared];
    mgr.stimp = selectedStimp;
    [mgr saveSettings];
}

#pragma mark - Fairway Control

- (void)fairwayControlChanged:(UISegmentedControl *)sender {
    SettingsManager *mgr = [SettingsManager shared];
    mgr.fairwaySpeedIndex = sender.selectedSegmentIndex;
    [mgr saveSettings];
}

- (void)exportButtonPressed {
    [[DataModel shared] exportShots];
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

#pragma mark - Redis

- (void)updateRedisStatus {
    RedisManager *redis = [RedisManager shared];

    if ([redis isConfigured]) {
        self.redisStatusLabel.text = @"Configured - tap Test Connection to verify";
        self.redisStatusLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    } else {
        self.redisStatusLabel.text = @"Not configured";
        self.redisStatusLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    }

    NSString *lastError = [redis getLastError];
    if (lastError) {
        self.redisStatusLabel.text = lastError;
        self.redisStatusLabel.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
    }
}

- (void)testRedisConnection:(UIButton *)sender {
    // Disable button during test
    sender.enabled = NO;
    [sender setTitle:@"Testing..." forState:UIControlStateNormal];

    RedisManager *redis = [RedisManager shared];

    self.redisStatusLabel.text = @"Connecting...";
    self.redisStatusLabel.textColor = APP_COLOR_YELLOW;

    [redis testConnectionWithCompletion:^(BOOL success, NSString * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            sender.enabled = YES;
            [sender setTitle:@"Test Connection" forState:UIControlStateNormal];

            if (success) {
                self.redisStatusLabel.text = @"✓ Connection successful!";
                self.redisStatusLabel.textColor = APP_COLOR_GREEN;
            } else {
                self.redisStatusLabel.text = error ?: @"Connection failed";
                self.redisStatusLabel.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
            }
        });
    }];
}

@end
