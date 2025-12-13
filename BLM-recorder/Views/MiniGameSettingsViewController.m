//
//  MiniGameSettingsViewController.m
//
//  Example implementation with two separate saved states:
//  1) “Swings” settings
//  2) “Putting” settings
//

#import "MiniGameSettingsViewController.h"
#import "Theme.h"
#import "MiniGameManager.h"
#import "MiniGameSettingsStore.h" // <-- Make sure this matches your actual store class name

@interface MiniGameSettingsViewController () <UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate>

// Left side: instructions
@property (nonatomic, strong) UITextView *instructionsTextView;

// Right side: non-scrollable view with form controls
@property (nonatomic, strong) UIView *formView;

// Controls
@property (nonatomic, strong) UISegmentedControl *typeSegment;
@property (nonatomic, strong) UITextField *minDistanceField;
@property (nonatomic, strong) UITextField *maxDistanceField;
@property (nonatomic, strong) UISegmentedControl *formatSegment;
@property (nonatomic, strong) UITextField *numShotsField;
@property (nonatomic, strong) UIPickerView *shotsPicker;
@property (nonatomic, strong) NSArray<NSNumber *> *shotsOptions;

// Buttons (styled like miniGameButton)
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *okButton;

@end

@implementation MiniGameSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    //
    // 1. Instructions Text View (will size in viewDidLayoutSubviews)
    //
    self.instructionsTextView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.instructionsTextView.textColor = [UIColor labelColor];
    self.instructionsTextView.font = [UIFont systemFontOfSize:16];
    self.instructionsTextView.editable = NO; // Read-only instructions
    
    // Placeholder instructions text
    self.instructionsTextView.text =
    @"\nMini Game Instructions:\n\n"
    @"1. Goal:\n"
    @"   Hit your shot as close as possible to the target distance.\n"
    @"2. Format:\n"
    @"   - Incremental: The target distance starts at the minimum and increments each shot.\n"
    @"   - Random: The distance is randomly chosen between the min and max.\n\n"
    @"3. Scoring:\n"
    @"   - Each shot can earn up to 100 points (100 = exact yardage).\n"
    @"   - \"To Par\" for each shot:\n"
    @"       • ≥ 90 points = Birdie (–1)\n"
    @"       • ≥ 80 points = Par (+0)\n"
    @"       • < 80 points = Bogey (+1)\n"
    @"4. Shots:\n"
    @"   The game ends after the number of shots you selected.\n\n"
    @"5. Type:\n"
    @"   Choose between Putting or Swings (full shots, chips, pitches, etc).\n"
    @"   Putting uses total distance, Swings uses carry distance\n";

    
    [self.view addSubview:self.instructionsTextView];
    
    //
    // 2. Form View (non-scrollable)
    //
    self.formView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.formView];
    
    // Optional: Dismiss keyboard by tapping in the form area
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.formView addGestureRecognizer:tap];
    
    //
    // 3. Shots picker data
    //
    self.shotsOptions = @[@5, @10, @15, @20, @25, @30, @35, @40, @45, @50];
    
    //
    // 4. Build the controls (same frames, but added to formView)
    //
    CGFloat margin = 20;
    CGFloat labelHeight = 20;
    CGFloat controlHeight = 30;
    CGFloat currentY = margin; // some top offset for the controls
    
    // --- TYPE ---
    UILabel *typeLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, currentY, 100, labelHeight)];
    typeLabel.text = @"Game type:";
    [self.formView addSubview:typeLabel];
    currentY += (labelHeight + 5);
    
    self.typeSegment = [[UISegmentedControl alloc] initWithItems:@[@"Swings", @"Putting"]];
    self.typeSegment.frame = CGRectMake(margin, currentY, 200, controlHeight);
    self.typeSegment.selectedSegmentIndex = 0; // default to Swings
    [self.formView addSubview:self.typeSegment];
    currentY += (controlHeight + 20);
    
    // Add an action so that whenever “Swings”/“Putting” is tapped,
    // we reload the appropriate settings from user defaults
    [self.typeSegment addTarget:self
                         action:@selector(typeSegmentValueChanged:)
               forControlEvents:UIControlEventValueChanged];
    
    // --- MIN DISTANCE ---
    UILabel *minLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, currentY, 250, labelHeight)];
    minLabel.text = @"Distance: Min - Max";
    [self.formView addSubview:minLabel];
    currentY += (labelHeight + 5);
    
    self.minDistanceField = [[UITextField alloc] initWithFrame:CGRectMake(margin, currentY, 60, controlHeight)];
    self.minDistanceField.text = @"20";
    self.minDistanceField.borderStyle = UITextBorderStyleRoundedRect;
    self.minDistanceField.keyboardType = UIKeyboardTypeNumberPad;
    self.minDistanceField.delegate = self;
    self.minDistanceField.inputAccessoryView = [self createAccessoryToolbar];
    [self.formView addSubview:self.minDistanceField];
    
    self.maxDistanceField = [[UITextField alloc] initWithFrame:CGRectMake(margin + 100, currentY, 60, controlHeight)];
    self.maxDistanceField.text = @"100";
    self.maxDistanceField.borderStyle = UITextBorderStyleRoundedRect;
    self.maxDistanceField.keyboardType = UIKeyboardTypeNumberPad;
    self.maxDistanceField.delegate = self;
    self.maxDistanceField.inputAccessoryView = [self createAccessoryToolbar];
    [self.formView addSubview:self.maxDistanceField];
    currentY += (controlHeight + 20);
    
    // --- FORMAT ---
    UILabel *formatLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, currentY, 120, labelHeight)];
    formatLabel.text = @"Format:";
    [self.formView addSubview:formatLabel];
    currentY += (labelHeight + 5);
    
    self.formatSegment = [[UISegmentedControl alloc] initWithItems:@[@"Incremental", @"Random"]];
    self.formatSegment.frame = CGRectMake(margin, currentY, 200, controlHeight);
    self.formatSegment.selectedSegmentIndex = 0; // default
    [self.formView addSubview:self.formatSegment];
    currentY += (controlHeight + 20);
    
    // --- NUMBER OF SHOTS ---
    UILabel *shotsLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, currentY, 200, labelHeight)];
    shotsLabel.text = @"Number of shots:";
    [self.formView addSubview:shotsLabel];
    currentY += (labelHeight + 5);
    
    self.numShotsField = [[UITextField alloc] initWithFrame:CGRectMake(margin, currentY, 100, controlHeight)];
    self.numShotsField.borderStyle = UITextBorderStyleRoundedRect;
    [self.formView addSubview:self.numShotsField];
    currentY += (controlHeight + 20);
    
    // Configure picker for numberOfShots field
    self.shotsPicker = [[UIPickerView alloc] init];
    self.shotsPicker.delegate = self;
    self.shotsPicker.dataSource = self;
    self.numShotsField.inputView = self.shotsPicker;
    self.numShotsField.inputAccessoryView = [self createAccessoryToolbar];
    
    // Default number of shots to 10
    NSUInteger defaultIndex = [self.shotsOptions indexOfObject:@10];
    if (defaultIndex != NSNotFound) {
        [self.shotsPicker selectRow:defaultIndex inComponent:0 animated:NO];
        self.numShotsField.text = [NSString stringWithFormat:@"%@", self.shotsOptions[defaultIndex]];
    }
    
    // --- CANCEL / OK Buttons (styled like miniGameButton) ---
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    self.cancelButton.frame = CGRectMake(margin, currentY, 120, 40);
    
    // Match miniGameButton style
    [self.cancelButton setTitleColor:APP_COLOR_TEXT forState:UIControlStateNormal];
    self.cancelButton.backgroundColor = APP_COLOR_ACCENT;
    self.cancelButton.layer.cornerRadius = 4.0;
    
    [self.cancelButton addTarget:self action:@selector(cancelPressed:)
                forControlEvents:UIControlEventTouchUpInside];
    [self.formView addSubview:self.cancelButton];
    
    self.okButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.okButton setTitle:@"Start Game" forState:UIControlStateNormal];
    self.okButton.frame = CGRectMake(CGRectGetMaxX(self.cancelButton.frame) + 30, currentY, 120, 40);
    
    // Match miniGameButton style
    [self.okButton setTitleColor:APP_COLOR_TEXT forState:UIControlStateNormal];
    self.okButton.backgroundColor = APP_COLOR_ACCENT;
    self.okButton.layer.cornerRadius = 4.0;
    
    [self.okButton addTarget:self action:@selector(okPressed:)
            forControlEvents:UIControlEventTouchUpInside];
    [self.formView addSubview:self.okButton];
    currentY += (40 + 20);
    
    // Load the settings for the initial segment (Swings if selectedSegmentIndex == 0).
    [self loadSettingsForCurrentSegment];
}

#pragma mark - Layout with Safe Area

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    // Safely lay out subviews so they're not cut off by notches / corners
    UIEdgeInsets safeArea = self.view.safeAreaInsets;
    
    CGFloat totalWidth  = self.view.bounds.size.width  - (safeArea.left + safeArea.right);
    CGFloat totalHeight = self.view.bounds.size.height - (safeArea.top + safeArea.bottom);
    CGFloat halfWidth   = totalWidth * 0.5;
    
    // Left half for instructions
    self.instructionsTextView.frame = CGRectMake(
        safeArea.left,
        safeArea.top,
        halfWidth,
        totalHeight
    );
    
    // Right half for form
    self.formView.frame = CGRectMake(
        safeArea.left + halfWidth,
        safeArea.top,
        halfWidth,
        totalHeight
    );
}

#pragma mark - Type Segment Handling

- (void)typeSegmentValueChanged:(UISegmentedControl *)sender {
    [self loadSettingsForCurrentSegment];
}

// Load either "Swings" or "Putting" settings from user defaults and populate fields.
- (void)loadSettingsForCurrentSegment {
    // If index=0 => "Swings", else => "Putting"
    NSString *type = (self.typeSegment.selectedSegmentIndex == 0) ? @"Swings" : @"Putting";
    
    NSDictionary *saved = [MiniGameSettingsStore loadSettingsForType:type];
    if (saved.count > 0) {
        // We have stored settings
        NSInteger minDist = [saved[@"minDistance"] integerValue];
        NSInteger maxDist = [saved[@"maxDistance"] integerValue];
        NSString *format  = saved[@"format"];
        NSInteger shots   = [saved[@"numShots"] integerValue];
        
        self.minDistanceField.text = [NSString stringWithFormat:@"%ld", (long)minDist];
        self.maxDistanceField.text = [NSString stringWithFormat:@"%ld", (long)maxDist];
        
        if ([format isEqualToString:@"Incremental"]) {
            self.formatSegment.selectedSegmentIndex = 0;
        } else {
            self.formatSegment.selectedSegmentIndex = 1;
        }
        
        self.numShotsField.text = [NSString stringWithFormat:@"%ld", (long)shots];
        NSUInteger index = [self.shotsOptions indexOfObject:@(shots)];
        if (index != NSNotFound) {
            [self.shotsPicker selectRow:index inComponent:0 animated:NO];
        }
    } else {
        // Nothing saved for this type; use your defaults
        if ([type isEqualToString:@"Swings"]) {
            self.minDistanceField.text = @"20";
            self.maxDistanceField.text = @"100";
            self.formatSegment.selectedSegmentIndex = 0;
            self.numShotsField.text = @"10";
            NSUInteger defaultIndex = [self.shotsOptions indexOfObject:@10];
            if (defaultIndex != NSNotFound) {
                [self.shotsPicker selectRow:defaultIndex inComponent:0 animated:NO];
            }
        } else {
            // For Putting, possibly different defaults
            self.minDistanceField.text = @"5";
            self.maxDistanceField.text = @"50";
            self.formatSegment.selectedSegmentIndex = 0;
            self.numShotsField.text = @"10";
            NSUInteger defaultIndex = [self.shotsOptions indexOfObject:@10];
            if (defaultIndex != NSNotFound) {
                [self.shotsPicker selectRow:defaultIndex inComponent:0 animated:NO];
            }
        }
    }
}

#pragma mark - UIPickerViewDataSource / UIPickerViewDelegate

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1; // single column
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.shotsOptions.count;
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component {
    return [NSString stringWithFormat:@"%@", self.shotsOptions[row]];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row
       inComponent:(NSInteger)component {
    self.numShotsField.text = [NSString stringWithFormat:@"%@", self.shotsOptions[row]];
}

#pragma mark - Keyboard Handling

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

#pragma mark - Create Toolbar ("Done" Button)

- (UIToolbar *)createAccessoryToolbar {
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0,
                                                                     self.view.frame.size.width,
                                                                     44)];
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc]
                                  initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                  target:nil
                                  action:nil];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                   target:self
                                   action:@selector(doneButtonTapped:)];
    [toolbar setItems:@[flexSpace, doneButton]];
    return toolbar;
}

- (void)doneButtonTapped:(id)sender {
    [self.view endEditing:YES]; // Hide the keyboard/picker
}

#pragma mark - Button Actions

- (void)cancelPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)okPressed:(id)sender {
    // Figure out which type is selected
    NSString *type = (self.typeSegment.selectedSegmentIndex == 0) ? @"Swings" : @"Putting";
    
    // Gather user’s inputs
    NSString *minDistString = self.minDistanceField.text ?: @"5";
    NSString *maxDistString = self.maxDistanceField.text ?: @"50";
    NSString *format = (self.formatSegment.selectedSegmentIndex == 0) ? @"Incremental" : @"Random";
    NSString *shotsString = self.numShotsField.text ?: @"10";
    
    NSInteger minDist = [minDistString integerValue];
    NSInteger maxDist = [maxDistString integerValue];
    NSInteger shots   = [shotsString integerValue];
    
    // Save to user defaults, so next time we load this type, we get these values
    [MiniGameSettingsStore saveSettingsForType:type
                                        format:format
                                   minDistance:minDist
                                   maxDistance:maxDist
                                     numShots:shots];
    
    // Then fire your notification or do whatever you did before
    NSDictionary *userInfo = @{
        @"gameType"   : type,
        @"minDistance": @(minDist),
        @"maxDistance": @(maxDist),
        @"format"     : format,
        @"numberOfShots": @(shots),
    };
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MiniGameStartNotification
                                                        object:nil
                                                      userInfo:userInfo];
    
    // Dismiss
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Cleanup

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
