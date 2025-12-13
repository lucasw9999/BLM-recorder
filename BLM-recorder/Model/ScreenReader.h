#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScreenReader : NSObject

// Creates the ScreenReader by loading a JSON file at the given path
- (instancetype)initWithJSONFile:(NSString *)filePath
                            type:(NSString *)configType
                           error:(NSError **)error;

// Optionally, you can provide a separate method to reload a config file:
- (BOOL)loadConfigFromFile:(NSString *)filePath
                      type:(NSString *)configType
                     error:(NSError **)error;

// Runs OCR for each item in configItems on the given image.
// Returns an NSDictionary where key = item[@"name"], value = recognized text.
// If an error occurs (e.g. Vision error), it returns nil and sets error.
- (nullable NSDictionary<NSString *, NSString *> *)runOCROnImage:(UIImage *)image
                                                           error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
