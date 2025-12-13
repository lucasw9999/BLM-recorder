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

@interface SettingsViewController () <UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UIPickerView *stimpPicker;
@property (nonatomic, strong) NSArray<NSNumber *> *stimpValues;
@property (nonatomic, assign) NSInteger selectedStimpIndex;

// New: A rounded text field for stimp (instead of placing the picker directly)
@property (nonatomic, strong) UITextField *stimpField;

@property (nonatomic, strong) UISegmentedControl *fairwayControl;
@property (nonatomic, strong) UITextField *ipField;
@property (nonatomic, strong) UILabel *connectionStateLabel;

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
    cardView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    cardView.layer.cornerRadius = 8.0;
    cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    cardView.layer.shadowOffset = CGSizeMake(0, 1);
    cardView.layer.shadowOpacity = 0.2;
    cardView.layer.shadowRadius = 2.0;

    // Add card title label
    if (title) {
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, frame.size.width - 20, 18)];
        titleLabel.text = title;
        titleLabel.font = [UIFont boldSystemFontOfSize:14];
        titleLabel.textColor = APP_COLOR_ACCENT;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.8;
        [cardView addSubview:titleLabel];
    }

    return cardView;
}

- (void)setupCardLayout {
    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat cardMargin = 15;
    CGFloat cardWidth = screenWidth - cardMargin * 2;
    CGFloat startY = 65; // Below header

    // Card 1: Golf Settings
    UIView *golfCard = [self createCardWithTitle:@"GOLF SETTINGS" frame:CGRectMake(cardMargin, startY, cardWidth, 140)];
    [self.view addSubview:golfCard];

    // Fairway speed label
    UILabel *fairwayLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 35, 120, 30)];
    fairwayLabel.text = @"Fairway Speed";
    fairwayLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    fairwayLabel.font = [UIFont systemFontOfSize:14];
    [golfCard addSubview:fairwayLabel];

    // Fairway control
    self.fairwayControl = [[UISegmentedControl alloc] initWithItems:@[@"Slow", @"Medium", @"Fast", @"Links"]];
    self.fairwayControl.frame = CGRectMake(15, 65, cardWidth - 30, 32);
    self.fairwayControl.selectedSegmentIndex = 1;
    [self.fairwayControl addTarget:self action:@selector(fairwayControlChanged:) forControlEvents:UIControlEventValueChanged];
    [golfCard addSubview:self.fairwayControl];

    // Stimp label
    UILabel *stimpLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 107, 100, 26)];
    stimpLabel.text = @"Putting Stimp";
    stimpLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    stimpLabel.font = [UIFont systemFontOfSize:14];
    [golfCard addSubview:stimpLabel];

    // Stimp text field
    self.stimpField = [[UITextField alloc] initWithFrame:CGRectMake(cardWidth - 115, 107, 100, 26)];
    self.stimpField.borderStyle = UITextBorderStyleRoundedRect;
    self.stimpField.textAlignment = NSTextAlignmentCenter;
    self.stimpField.font = [UIFont systemFontOfSize:14];
    [golfCard addSubview:self.stimpField];

    // Create the UIPickerView for stimp
    self.stimpPicker = [[UIPickerView alloc] init];
    self.stimpPicker.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.stimpPicker.dataSource = self;
    self.stimpPicker.delegate = self;
    self.stimpField.inputView = self.stimpPicker;

    // Add toolbar with Done button for stimpField
    UIToolbar *stimpToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    stimpToolbar.barStyle = UIBarStyleBlack;
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    stimpToolbar.items = @[flexSpace, doneButton];
    [stimpToolbar sizeToFit];
    self.stimpField.inputAccessoryView = stimpToolbar;

    // Card 2: GSPro Connection
    CGFloat card2Y = startY + 140 + 8;
    UIView *gsproCard = [self createCardWithTitle:@"GSPRO CONNECTION" frame:CGRectMake(cardMargin, card2Y, cardWidth, 110)];
    [self.view addSubview:gsproCard];

    // IP label
    UILabel *ipLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 35, 80, 30)];
    ipLabel.text = @"IP Address";
    ipLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    ipLabel.font = [UIFont systemFontOfSize:14];
    [gsproCard addSubview:ipLabel];

    // IP text field
    self.ipField = [[UITextField alloc] initWithFrame:CGRectMake(15, 65, 150, 32)];
    self.ipField.borderStyle = UITextBorderStyleRoundedRect;
    self.ipField.placeholder = @"192.168.x.x";
    self.ipField.keyboardType = UIKeyboardTypeDecimalPad;
    self.ipField.delegate = self;
    self.ipField.font = [UIFont systemFontOfSize:14];

    // Add accessory toolbar for IP field
    UIToolbar *ipToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    ipToolbar.barStyle = UIBarStyleBlack;
    UIBarButtonItem *ipFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *ipDoneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
    ipToolbar.items = @[ipFlex, ipDoneButton];
    [ipToolbar sizeToFit];
    self.ipField.inputAccessoryView = ipToolbar;
    [gsproCard addSubview:self.ipField];

    // Connection state label
    self.connectionStateLabel = [[UILabel alloc] initWithFrame:CGRectMake(175, 65, 180, 32)];
    self.connectionStateLabel.font = [UIFont systemFontOfSize:14];
    self.connectionStateLabel.textAlignment = NSTextAlignmentLeft;
    [gsproCard addSubview:self.connectionStateLabel];
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
    modeLabel.text = @"SETTINGS";
    modeLabel.textColor = [UIColor whiteColor];
    modeLabel.font = [UIFont systemFontOfSize:8 weight:UIFontWeightSemibold];
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
    }
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

@end
