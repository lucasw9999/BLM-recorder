#import "MiniGameEndViewController.h"
#import "Theme.h"

@interface MiniGameEndViewController ()

@property (nonatomic, strong) UILabel *scoreLabel;
@property (nonatomic, strong) UIButton *replayButton;
@property (nonatomic, strong) UIButton *exitButton;

@end

@implementation MiniGameEndViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Use a semi-transparent dark background so the modal stands out
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    
    // Container view for the content
    UIView *containerView = [[UIView alloc] init];
    containerView.backgroundColor = APP_COLOR_BG;
    containerView.layer.cornerRadius = 10.0;
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:containerView];
    
    // Center container view in the modal view
    [NSLayoutConstraint activateConstraints:@[
        [containerView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [containerView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [containerView.widthAnchor constraintEqualToConstant:400],
        [containerView.heightAnchor constraintEqualToConstant:400]
    ]];
    
    // Score label: "Final score: <score>"
    UILabel *scoreLabel = [[UILabel alloc] init];
    scoreLabel.translatesAutoresizingMaskIntoConstraints = NO;
    scoreLabel.textAlignment = NSTextAlignmentCenter;
    scoreLabel.font = [UIFont boldSystemFontOfSize:24];
    scoreLabel.text = [NSString stringWithFormat:@"Final score: %@", self.finalScoreString];
    [containerView addSubview:scoreLabel];
    
    // Create the single button (for example, "OK")
    UIButton *actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [actionButton setTitle:@"Finish" forState:UIControlStateNormal];
    actionButton.titleLabel.font = [UIFont systemFontOfSize:18];
    actionButton.backgroundColor = APP_COLOR_ACCENT;
    [actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    actionButton.layer.cornerRadius = 4.0;
    [actionButton addTarget:self action:@selector(finishButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [containerView addSubview:actionButton];
    
    // Layout constraints for score label and button
    [NSLayoutConstraint activateConstraints:@[
        // Score label at the top of the container with padding
        [scoreLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:20],
        [scoreLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:20],
        [scoreLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-20],
        
        // Center the action button horizontally below the label
        [actionButton.topAnchor constraintEqualToAnchor:scoreLabel.bottomAnchor constant:30],
        [actionButton.centerXAnchor constraintEqualToAnchor:containerView.centerXAnchor],
        [actionButton.widthAnchor constraintEqualToConstant:100],
        [actionButton.heightAnchor constraintEqualToConstant:44]
    ]];
}

- (void)finishButtonTapped {
    // Dismiss the modal and perform any exit logic if needed
    [self dismissViewControllerAnimated:YES completion:^{
    }];
}

@end
