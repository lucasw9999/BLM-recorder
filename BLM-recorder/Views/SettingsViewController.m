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

    // Create card-based layout matching Play page
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

    // Add swipe gestures for tab switching
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
    CGFloat startY = 65; // Below header

    // Card 1: Golf Settings - Using HIG spacing constants
    UIView *golfCard = [self createCardWithTitle:@"GOLF SETTINGS"
                                           frame:CGRectMake(CARD_MARGIN, startY,
                                                           screenWidth - (CARD_MARGIN * 2), 140)];
    [self.view addSubview:golfCard];

    // Fairway speed label - using Dynamic Type
    UILabel *fairwayLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 35, 120, 30)];
    fairwayLabel.text = @"Fairway Speed";
    fairwayLabel.textColor = APP_COLOR_SECONDARY_TEXT;
    fairwayLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [golfCard addSubview:fairwayLabel];

    // Fairway control
    self.fairwayControl = [[UISegmentedControl alloc] initWithItems:@[@"Slow", @"Medium", @"Fast", @"Links"]];
    self.fairwayControl.frame = CGRectMake(CARD_PADDING, 65,
                                           screenWidth - (CARD_MARGIN * 2) - (CARD_PADDING * 2),
                                           MIN_TOUCH_TARGET - 12); // Proper touch target
    self.fairwayControl.selectedSegmentIndex = 1;
    [self.fairwayControl addTarget:self action:@selector(fairwayControlChanged:) forControlEvents:UIControlEventValueChanged];
    [golfCard addSubview:self.fairwayControl];

    // Stimp label
    UILabel *stimpLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 107, 100, 26)];
    stimpLabel.text = @"Putting Stimp";
    stimpLabel.textColor = APP_COLOR_SECONDARY_TEXT;
    stimpLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [golfCard addSubview:stimpLabel];

    // Stimp text field
    CGFloat cardWidth = screenWidth - (CARD_MARGIN * 2);
    self.stimpField = [[UITextField alloc] initWithFrame:CGRectMake(cardWidth - CARD_PADDING - 100, 107, 100, 26)];
    self.stimpField.borderStyle = UITextBorderStyleRoundedRect;
    self.stimpField.textAlignment = NSTextAlignmentCenter;
    self.stimpField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    [golfCard addSubview:self.stimpField];

    // Create the UIPickerView for stimp
    self.stimpPicker = [[UIPickerView alloc] init];
    self.stimpPicker.backgroundColor = APP_COLOR_SECONDARY_BG;
    self.stimpPicker.dataSource = self;
    self.stimpPicker.delegate = self;
    self.stimpField.inputView = self.stimpPicker;

    // Add toolbar with Done button for stimpField
    UIToolbar *stimpToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    stimpToolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    stimpToolbar.items = @[flexSpace, doneButton];
    [stimpToolbar sizeToFit];
    self.stimpField.inputAccessoryView = stimpToolbar;

    // Card 2: GSPro Connection - Using HIG spacing
    CGFloat card2Y = startY + 140 + CARD_SPACING;
    UIView *gsproCard = [self createCardWithTitle:@"GSPRO CONNECTION"
                                            frame:CGRectMake(CARD_MARGIN, card2Y,
                                                            screenWidth - (CARD_MARGIN * 2), 110)];
    [self.view addSubview:gsproCard];

    // IP label
    UILabel *ipLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 35, 80, 30)];
    ipLabel.text = @"IP Address";
    ipLabel.textColor = APP_COLOR_SECONDARY_TEXT;
    ipLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [gsproCard addSubview:ipLabel];

    // IP text field - proper touch target
    self.ipField = [[UITextField alloc] initWithFrame:CGRectMake(CARD_PADDING, 65, 150, 32)];
    self.ipField.borderStyle = UITextBorderStyleRoundedRect;
    self.ipField.placeholder = @"192.168.x.x";
    self.ipField.keyboardType = UIKeyboardTypeDecimalPad;
    self.ipField.delegate = self;
    self.ipField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];

    // Add accessory toolbar for IP field
    UIToolbar *ipToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    ipToolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *ipFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *ipDoneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    ipToolbar.items = @[ipFlex, ipDoneButton];
    [ipToolbar sizeToFit];
    self.ipField.inputAccessoryView = ipToolbar;
    [gsproCard addSubview:self.ipField];

    // Connection state label - Dynamic Type
    self.connectionStateLabel = [[UILabel alloc] initWithFrame:CGRectMake(175, 65, 180, 32)];
    self.connectionStateLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.connectionStateLabel.textAlignment = NSTextAlignmentLeft;
    [gsproCard addSubview:self.connectionStateLabel];

    // Card 3: Redis Settings - Using HIG spacing
    CGFloat card3Y = card2Y + 110 + CARD_SPACING;
    UIView *redisCard = [self createCardWithTitle:@"REDIS DATA STORAGE (OPTIONAL)"
                                            frame:CGRectMake(CARD_MARGIN, card3Y,
                                                            screenWidth - (CARD_MARGIN * 2), 200)];
    [self.view addSubview:redisCard];

    // Redis host label
    UILabel *redisHostLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 35, 80, 30)];
    redisHostLabel.text = @"Redis Host";
    redisHostLabel.textColor = APP_COLOR_SECONDARY_TEXT;
    redisHostLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [redisCard addSubview:redisHostLabel];

    // Redis host text field
    self.redisHostField = [[UITextField alloc] initWithFrame:CGRectMake(CARD_PADDING, 65,
                                                                         cardWidth - (CARD_PADDING * 2), 32)];
    self.redisHostField.borderStyle = UITextBorderStyleRoundedRect;
    self.redisHostField.placeholder = @"redis-xxxxx.xxx.cloud.redislabs.com";
    self.redisHostField.keyboardType = UIKeyboardTypeURL;
    self.redisHostField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.redisHostField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.redisHostField.delegate = self;
    self.redisHostField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];

    UIToolbar *hostToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    hostToolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *hostFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *hostDone = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    hostToolbar.items = @[hostFlex, hostDone];
    [hostToolbar sizeToFit];
    self.redisHostField.inputAccessoryView = hostToolbar;
    [redisCard addSubview:self.redisHostField];

    // Redis port label
    UILabel *redisPortLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 105, 80, 30)];
    redisPortLabel.text = @"Port";
    redisPortLabel.textColor = APP_COLOR_SECONDARY_TEXT;
    redisPortLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [redisCard addSubview:redisPortLabel];

    // Redis port text field
    self.redisPortField = [[UITextField alloc] initWithFrame:CGRectMake(100, 105, 80, 32)];
    self.redisPortField.borderStyle = UITextBorderStyleRoundedRect;
    self.redisPortField.placeholder = @"12647";
    self.redisPortField.keyboardType = UIKeyboardTypeNumberPad;
    self.redisPortField.delegate = self;
    self.redisPortField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.redisPortField.textAlignment = NSTextAlignmentCenter;

    UIToolbar *portToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    portToolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *portFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *portDone = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    portToolbar.items = @[portFlex, portDone];
    [portToolbar sizeToFit];
    self.redisPortField.inputAccessoryView = portToolbar;
    [redisCard addSubview:self.redisPortField];

    // Redis password label
    UILabel *redisPasswordLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 143, 80, 30)];
    redisPasswordLabel.text = @"Password";
    redisPasswordLabel.textColor = APP_COLOR_SECONDARY_TEXT;
    redisPasswordLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [redisCard addSubview:redisPasswordLabel];

    // Redis password text field
    self.redisPasswordField = [[UITextField alloc] initWithFrame:CGRectMake(100, 143,
                                                                             cardWidth - CARD_PADDING - 100, 32)];
    self.redisPasswordField.borderStyle = UITextBorderStyleRoundedRect;
    self.redisPasswordField.placeholder = @"Enter password";
    self.redisPasswordField.secureTextEntry = YES;
    self.redisPasswordField.delegate = self;
    self.redisPasswordField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];

    UIToolbar *passToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    passToolbar.barStyle = UIBarStyleDefault;
    UIBarButtonItem *passFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *passDone = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    passToolbar.items = @[passFlex, passDone];
    [passToolbar sizeToFit];
    self.redisPasswordField.inputAccessoryView = passToolbar;
    [redisCard addSubview:self.redisPasswordField];

    // Test connection button - iOS standard button style with proper touch target
    self.redisTestButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.redisTestButton.frame = CGRectMake(190, 105, 150, MIN_TOUCH_TARGET - 12);
    [self.redisTestButton setTitle:@"Test Connection" forState:UIControlStateNormal];
    self.redisTestButton.backgroundColor = APP_COLOR_ACCENT;
    [self.redisTestButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.redisTestButton.layer.cornerRadius = BUTTON_CORNER_RADIUS;
    self.redisTestButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    [self.redisTestButton addTarget:self action:@selector(testRedisConnection:) forControlEvents:UIControlEventTouchUpInside];
    [redisCard addSubview:self.redisTestButton];

    // Redis status label - Dynamic Type
    self.redisStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(CARD_PADDING, 180,
                                                                       cardWidth - (CARD_PADDING * 2), 15)];
    self.redisStatusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.redisStatusLabel.textAlignment = NSTextAlignmentLeft;
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
