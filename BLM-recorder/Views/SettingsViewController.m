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

// Section indices
typedef NS_ENUM(NSInteger, SettingsSection) {
    SettingsSectionRedis = 0,
    SettingsSectionGSPro = 1,
    SettingsSectionGolf = 2,
    SettingsSectionCount
};

// Row indices for each section
typedef NS_ENUM(NSInteger, GolfRow) {
    GolfRowFairwayCondition = 0,
    GolfRowGreenSpeed = 1,
    GolfRowCount
};

typedef NS_ENUM(NSInteger, GSProRow) {
    GSProRowIP = 0,
    GSProRowStatus = 1,
    GSProRowCount
};

typedef NS_ENUM(NSInteger, RedisRow) {
    RedisRowHost = 0,
    RedisRowPortAndPassword = 1,
    RedisRowTestButton = 2,
    RedisRowCount
};

@interface SettingsViewController () <UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UIPickerView *stimpPicker;
@property (nonatomic, strong) NSArray<NSNumber *> *stimpValues;
@property (nonatomic, assign) NSInteger selectedStimpIndex;

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

@end

@implementation SettingsViewController

- (instancetype)init {
    // Use insetGrouped style for modern iOS settings appearance
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = @"Settings";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Configure table view appearance
    self.tableView.backgroundColor = APP_COLOR_BG;

    // Build stimp values: 5 to 15
    NSMutableArray<NSNumber *> *values = [NSMutableArray array];
    for (NSInteger i = 5; i <= 15; i++) {
        [values addObject:@(i)];
    }
    self.stimpValues = [values copy];
    self.selectedStimpIndex = 5; // default (stimp=10)

    // Setup picker view for stimp
    self.stimpPicker = [[UIPickerView alloc] init];
    self.stimpPicker.backgroundColor = APP_COLOR_SECONDARY_BG;
    self.stimpPicker.dataSource = self;
    self.stimpPicker.delegate = self;

    // Observe GSPro connection state notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleGSProConnectionState:)
                                                 name:GSProConnectionStateNotification
                                               object:nil];

    [self setConnectionStateFromGsProConnector:nil];

    // Remove swipe gestures - we'll use tab bar only (HIG compliant)
    // Swipe gestures conflict with system gestures
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionGolf:
            return GolfRowCount;
        case SettingsSectionGSPro:
            return GSProRowCount;
        case SettingsSectionRedis:
            return RedisRowCount;
        default:
            return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionGolf:
            return @"Golf Settings";
        case SettingsSectionGSPro:
            return @"GSPro";
        case SettingsSectionRedis:
            return @"Redis (Optional)";
        default:
            return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == SettingsSectionRedis) {
        RedisManager *redis = [RedisManager shared];
        if ([redis isConfigured]) {
            NSString *lastError = [redis getLastError];
            if (lastError) {
                return lastError;
            }
            return @"Configured - tap Test Connection to verify";
        } else {
            return @"Not configured";
        }
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;

    switch (indexPath.section) {
        case SettingsSectionGolf:
            cell = [self golfCellForRow:indexPath.row];
            break;
        case SettingsSectionGSPro:
            cell = [self gsproCellForRow:indexPath.row];
            break;
        case SettingsSectionRedis:
            cell = [self redisCellForRow:indexPath.row];
            break;
    }

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    }

    return cell;
}

#pragma mark - Cell Creation

- (UITableViewCell *)golfCellForRow:(NSInteger)row {
    if (row == GolfRowFairwayCondition) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        // Fairway Condition label
        UILabel *fairwayLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, 140, 28)];
        fairwayLabel.text = @"Fairway Condition";
        fairwayLabel.textColor = APP_COLOR_TEXT;
        fairwayLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        [cell.contentView addSubview:fairwayLabel];

        // Fairway Condition segmented control
        self.fairwayControl = [[UISegmentedControl alloc] initWithItems:@[@"Slow", @"Med", @"Fast", @"Links"]];
        self.fairwayControl.frame = CGRectMake(165, 8, 280, 28);
        // Load saved value
        SettingsManager *mgr = [SettingsManager shared];
        self.fairwayControl.selectedSegmentIndex = mgr.fairwaySpeedIndex;
        [self.fairwayControl addTarget:self action:@selector(fairwayControlChanged:) forControlEvents:UIControlEventValueChanged];
        [cell.contentView addSubview:self.fairwayControl];

        return cell;
    } else if (row == GolfRowGreenSpeed) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        // Green Speed label
        UILabel *stimpLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, 140, 28)];
        stimpLabel.text = @"Green Speed";
        stimpLabel.textColor = APP_COLOR_TEXT;
        stimpLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        [cell.contentView addSubview:stimpLabel];

        // Green Speed text field
        self.stimpField = [[UITextField alloc] initWithFrame:CGRectMake(165, 8, 60, 28)];
        self.stimpField.borderStyle = UITextBorderStyleRoundedRect;
        self.stimpField.textAlignment = NSTextAlignmentCenter;
        self.stimpField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        self.stimpField.inputView = self.stimpPicker;
        // Load saved value
        self.stimpField.text = [NSString stringWithFormat:@"%@", self.stimpValues[self.selectedStimpIndex]];

        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
        UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
        toolbar.items = @[flex, done];
        self.stimpField.inputAccessoryView = toolbar;
        [cell.contentView addSubview:self.stimpField];

        return cell;
    }
    return nil;
}

- (UITableViewCell *)gsproCellForRow:(NSInteger)row {
    if (row == GSProRowIP) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, 50, 20)];
        label.text = @"IP";
        label.textColor = APP_COLOR_TEXT;
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        [cell.contentView addSubview:label];

        self.ipField = [[UITextField alloc] initWithFrame:CGRectMake(70, 8, 200, 28)];
        self.ipField.borderStyle = UITextBorderStyleRoundedRect;
        self.ipField.placeholder = @"192.168.x.x";
        self.ipField.keyboardType = UIKeyboardTypeDecimalPad;
        self.ipField.delegate = self;
        self.ipField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        // Load saved value
        SettingsManager *mgr = [SettingsManager shared];
        self.ipField.text = mgr.gsProIP;

        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
        UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
        toolbar.items = @[flex, done];
        self.ipField.inputAccessoryView = toolbar;
        [cell.contentView addSubview:self.ipField];

        return cell;
    } else if (row == GSProRowStatus) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = @"Connection Status";
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];

        self.connectionStateLabel = cell.detailTextLabel;
        self.connectionStateLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        [self setConnectionStateFromGsProConnector:nil];

        return cell;
    }
    return nil;
}

- (UITableViewCell *)redisCellForRow:(NSInteger)row {
    if (row == RedisRowHost) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, 50, 20)];
        label.text = @"Host";
        label.textColor = APP_COLOR_TEXT;
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        [cell.contentView addSubview:label];

        self.redisHostField = [[UITextField alloc] initWithFrame:CGRectMake(70, 8, cell.contentView.bounds.size.width - 86, 28)];
        self.redisHostField.borderStyle = UITextBorderStyleRoundedRect;
        self.redisHostField.placeholder = @"redis-xxxxx.xxx.cloud.redislabs.com";
        self.redisHostField.keyboardType = UIKeyboardTypeURL;
        self.redisHostField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.redisHostField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.redisHostField.delegate = self;
        self.redisHostField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];

        // Load saved value
        RedisManager *redis = [RedisManager shared];
        self.redisHostField.text = [redis getRedisHost];

        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
        UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
        toolbar.items = @[flex, done];
        self.redisHostField.inputAccessoryView = toolbar;
        [cell.contentView addSubview:self.redisHostField];

        return cell;
    } else if (row == RedisRowPortAndPassword) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        // Port
        UILabel *portLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, 50, 20)];
        portLabel.text = @"Port";
        portLabel.textColor = APP_COLOR_TEXT;
        portLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        [cell.contentView addSubview:portLabel];

        self.redisPortField = [[UITextField alloc] initWithFrame:CGRectMake(70, 8, 70, 28)];
        self.redisPortField.borderStyle = UITextBorderStyleRoundedRect;
        self.redisPortField.placeholder = @"12647";
        self.redisPortField.keyboardType = UIKeyboardTypeNumberPad;
        self.redisPortField.delegate = self;
        self.redisPortField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        self.redisPortField.textAlignment = NSTextAlignmentCenter;

        // Load saved value
        RedisManager *redis = [RedisManager shared];
        NSInteger port = [redis getRedisPort];
        if (port > 0) {
            self.redisPortField.text = [NSString stringWithFormat:@"%ld", (long)port];
        }

        UIToolbar *portToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
        UIBarButtonItem *portFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *portDone = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
        portToolbar.items = @[portFlex, portDone];
        self.redisPortField.inputAccessoryView = portToolbar;
        [cell.contentView addSubview:self.redisPortField];

        // Password
        UILabel *passLabel = [[UILabel alloc] initWithFrame:CGRectMake(150, 12, 50, 20)];
        passLabel.text = @"Pass";
        passLabel.textColor = APP_COLOR_TEXT;
        passLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        [cell.contentView addSubview:passLabel];

        self.redisPasswordField = [[UITextField alloc] initWithFrame:CGRectMake(205, 8, cell.contentView.bounds.size.width - 221, 28)];
        self.redisPasswordField.borderStyle = UITextBorderStyleRoundedRect;
        self.redisPasswordField.placeholder = @"password";
        self.redisPasswordField.secureTextEntry = YES;
        self.redisPasswordField.delegate = self;
        self.redisPasswordField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];

        // Load saved value
        if ([redis hasRedisPassword]) {
            self.redisPasswordField.text = @"••••••••";
        }

        UIToolbar *passToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
        UIBarButtonItem *passFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *passDone = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)];
        passToolbar.items = @[passFlex, passDone];
        self.redisPasswordField.inputAccessoryView = passToolbar;
        [cell.contentView addSubview:self.redisPasswordField];

        return cell;
    } else if (row == RedisRowTestButton) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        self.redisTestButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.redisTestButton.frame = CGRectMake(16, 8, cell.contentView.bounds.size.width - 32, 28);
        [self.redisTestButton setTitle:@"Test Connection" forState:UIControlStateNormal];
        self.redisTestButton.backgroundColor = APP_COLOR_ACCENT;
        [self.redisTestButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.redisTestButton.layer.cornerRadius = BUTTON_CORNER_RADIUS;
        self.redisTestButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        [self.redisTestButton addTarget:self action:@selector(testRedisConnection:) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:self.redisTestButton];

        return cell;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case SettingsSectionGolf:
            return 44; // Standard height for both Fairway Condition and Green Speed rows
        case SettingsSectionGSPro:
            return 44;
        case SettingsSectionRedis:
            return 44;
        default:
            return 44;
    }
}

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Load settings from SettingsManager
    SettingsManager *mgr = [SettingsManager shared];

    // Update stimp picker selection
    NSInteger stimp = mgr.stimp;
    NSInteger rowIndex = [self.stimpValues indexOfObject:@(stimp)];
    if (rowIndex == NSNotFound) {
        rowIndex = 5; // default stimp=10
    }
    self.selectedStimpIndex = rowIndex;
    [self.stimpPicker selectRow:rowIndex inComponent:0 animated:NO];

    // Reload table - cells will load their own values from managers
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // Save any pending text field values when leaving settings
    [self saveTextFieldValues];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Keyboard

- (void)dismissKeyboard {
    // Save all text field values before dismissing keyboard
    [self saveTextFieldValues];
    [self.view endEditing:YES];
}

- (void)saveTextFieldValues {
    // Save IP field
    if (self.ipField.text.length > 0) {
        SettingsManager *mgr = [SettingsManager shared];
        [mgr setGSProIP:self.ipField.text];
        [mgr saveSettings];
    }

    // Save Redis host
    if (self.redisHostField.text.length > 0) {
        RedisManager *redis = [RedisManager shared];
        [redis setRedisHost:self.redisHostField.text];
    }

    // Save Redis port
    if (self.redisPortField.text.length > 0) {
        RedisManager *redis = [RedisManager shared];
        NSInteger port = [self.redisPortField.text integerValue];
        if (port > 0) {
            [redis setRedisPort:port];
        }
    }

    // Save Redis password
    if (self.redisPasswordField.text.length > 0 && ![self.redisPasswordField.text isEqualToString:@"••••••••"]) {
        RedisManager *redis = [RedisManager shared];
        [redis setRedisPassword:self.redisPasswordField.text];
    }

    // Reload table to update footer
    [self.tableView reloadData];
}

#pragma mark - GSPro Connection

- (void)setConnectionStateFromGsProConnector:(NSString *)state {
    NSString *connectionString = (state != nil) ? state : [[GSProConnector shared] getConnectionState];
    self.connectionStateLabel.text = connectionString;

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
        [self.tableView reloadData]; // Update footer
    } else if (textField == self.redisPortField) {
        RedisManager *redis = [RedisManager shared];
        NSInteger port = [textField.text integerValue];
        if (port > 0) {
            [redis setRedisPort:port];
        }
        [self.tableView reloadData]; // Update footer
    } else if (textField == self.redisPasswordField) {
        if (![textField.text isEqualToString:@"••••••••"] && textField.text.length > 0) {
            RedisManager *redis = [RedisManager shared];
            [redis setRedisPassword:textField.text];
            [self.tableView reloadData]; // Update footer
        }
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (textField == self.redisPasswordField) {
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

#pragma mark - Redis

- (void)testRedisConnection:(UIButton *)sender {
    // Save all text field values first
    [self saveTextFieldValues];

    sender.enabled = NO;
    [sender setTitle:@"Testing..." forState:UIControlStateNormal];
    [sender setNeedsLayout];
    [sender layoutIfNeeded];

    RedisManager *redis = [RedisManager shared];

    [redis testConnectionWithCompletion:^(BOOL success, NSString * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            sender.enabled = YES;
            [sender setTitle:@"Test Connection" forState:UIControlStateNormal];
            [sender setNeedsLayout];
            [sender layoutIfNeeded];

            // Reload table to show updated footer
            [self.tableView reloadData];

            // Show alert with result
            NSString *title = success ? @"Success" : @"Failed";
            NSString *message = success ? @"Connection successful!" : (error ?: @"Connection failed");
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}

@end
