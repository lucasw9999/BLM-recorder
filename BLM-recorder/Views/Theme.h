// =============================================================================
// APPLE HIG-COMPLIANT THEME
// Follows iOS Human Interface Guidelines for colors, spacing, and typography
// =============================================================================

// MARK: - Colors (Semantic, supports Dark Mode automatically)

// Background Colors
#define APP_COLOR_BG                [UIColor systemBackgroundColor]           // Adaptive background
#define APP_COLOR_SECONDARY_BG      [UIColor secondarySystemBackgroundColor]  // Cards/grouped content
#define APP_COLOR_TERTIARY_BG       [UIColor tertiarySystemBackgroundColor]   // Nested groups

// Text Colors (Adaptive)
#define APP_COLOR_TEXT              [UIColor labelColor]                      // Primary text
#define APP_COLOR_SECONDARY_TEXT    [UIColor secondaryLabelColor]             // Secondary text
#define APP_COLOR_TERTIARY_TEXT     [UIColor tertiaryLabelColor]              // Tertiary/placeholder
#define APP_COLOR_DARK_TEXT         [UIColor secondaryLabelColor]             // Legacy compatibility

// Accent Colors
#define APP_COLOR_ACCENT            [UIColor systemBlueColor]                 // Primary actions
#define APP_COLOR_ACCENT_2          [UIColor systemGrayColor]                 // Secondary actions

// Status Colors (Semantic)
#define APP_COLOR_GREEN             [UIColor systemGreenColor]                // Success/connected
#define APP_COLOR_YELLOW            [UIColor systemYellowColor]               // Warning/connecting
#define APP_COLOR_RED               [UIColor systemRedColor]                  // Error/danger

// Separator Colors
#define APP_COLOR_SEPARATOR         [UIColor separatorColor]                  // Standard separator
#define APP_COLOR_SEPARATOR_OPAQUE  [UIColor opaqueSeparatorColor]            // Opaque separator

// MARK: - Spacing (8pt Grid System)

#define SPACING_TINY        4.0     // Minimal spacing
#define SPACING_SMALL       8.0     // Compact spacing
#define SPACING_MEDIUM      12.0    // Standard spacing
#define SPACING_STANDARD    16.0    // Default margin
#define SPACING_LARGE       20.0    // Generous spacing
#define SPACING_XLARGE      24.0    // Section spacing
#define SPACING_XXLARGE     32.0    // Major section spacing

// MARK: - Layout Constants

#define CARD_CORNER_RADIUS  10.0    // iOS standard corner radius
#define BUTTON_CORNER_RADIUS 8.0    // Button corner radius
#define CARD_MARGIN         SPACING_STANDARD   // Card margins (16pt)
#define CARD_PADDING        SPACING_STANDARD   // Card internal padding (16pt)
#define CARD_SPACING        SPACING_MEDIUM     // Space between cards (12pt)

// MARK: - Touch Targets (Minimum 44x44pt per Apple HIG)

#define MIN_TOUCH_TARGET    44.0    // Minimum touch target size
#define BUTTON_HEIGHT       44.0    // Standard button height

// MARK: - Shadows (Subtle depth)

#define SHADOW_OFFSET       CGSizeMake(0, 2)
#define SHADOW_OPACITY      0.12
#define SHADOW_RADIUS       8.0
#define SHADOW_COLOR        [UIColor blackColor].CGColor

// MARK: - Typography (Using Dynamic Type - will be added to components)
