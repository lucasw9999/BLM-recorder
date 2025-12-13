#import "ScreenReader.h"
#import "ImageUtilities.h"
#import <Vision/Vision.h> // For VNRequestTextRecognitionLevel if needed
#import "ModelManager.h"

@interface ScreenReader ()
// An internal representation of the config array. Each item is a dictionary with keys:
//   @"name"   -> NSString
//   @"rect"   -> NSArray of 4 floats (x, y, w, h)
//   @"format" -> NSArray of NSStrings (optional, can be empty)
@property (nonatomic, strong, readonly) NSArray<NSDictionary *> *configItems;

@property (nonatomic, strong, readonly) NSString *configType;

@end

@implementation ScreenReader {
    // You could store the OCR results in a separate instance variable if you want to do lookups later.
    // But here we just return them directly in runOCROnImage:.
}

// MARK: - Initializer
- (instancetype)initWithJSONFile:(NSString *)filePath
                            type:(NSString *)configType
                           error:(NSError **)error {
    self = [super init];
    if (self) {
        BOOL success = [self loadConfigFromFile:filePath type:configType error:error];
        if (!success) {
            return nil;
        }
    }
    return self;
}

// MARK: - Load Config
- (BOOL)loadConfigFromFile:(NSString *)filePath
                      type:(NSString *)configType
                     error:(NSError **)error {
    // 1) Read raw data
    NSData *jsonData = [NSData dataWithContentsOfFile:filePath options:0 error:error];
    if (!jsonData) {
        // *error already set by dataWithContentsOfFile if it fails
        return NO;
    }
    
    // 2) Parse JSON into an NSArray of dictionaries
    id parsed = [NSJSONSerialization JSONObjectWithData:jsonData
                                                options:NSJSONReadingMutableContainers
                                                  error:error];
    if (!parsed || ![parsed isKindOfClass:[NSArray class]]) {
        return NO;
    }
    
    _configItems = (NSArray<NSDictionary *> *)parsed;
    _configType = configType;
    
    return YES;
}

// MARK: - Run OCR
- (NSDictionary<NSString *, NSString *> *)runOCROnImage:(UIImage *)image
                                                  error:(NSError **)error
{
    // This dictionary will hold name => recognized text
    NSMutableDictionary<NSString *, NSString *> *results = [NSMutableDictionary dictionary];
    
    results[@"type"] = self.configType;
    
    // For each item in config, read out name, rect, format
    for (NSDictionary *item in self.configItems) {
        NSString *name = item[@"name"];
        NSArray *rectArray = item[@"rect"];
        NSArray<NSString *> *customFormat = item[@"format"]; // optional
        NSString *modelName = item[@"model"];
        if (!name || !rectArray || rectArray.count < 4) {
            // skip invalid item
            continue;
        }
        
        // rect is [x, y, w, h] in normalized coords (0..1)
        CGFloat x = [rectArray[0] floatValue];
        CGFloat y = [rectArray[1] floatValue];
        CGFloat w = [rectArray[2] floatValue];
        CGFloat h = [rectArray[3] floatValue];
        
        CGRect roi = CGRectMake(x, y, w, h);
        
        UIImage* processedImage = [[UIImage alloc] init];
        
        if(modelName == nil) { // No model, just use OCR
            // For OCR, we can pass customFormat as customWords
            // We'll default to 'Accurate' recognition level
            NSString *recognized = [ImageUtilities performOCR:image
                                             regionOfInterest:roi
                                                  customWords:customFormat
                                                addSuffixHack:false
                                              recognitionLevel:VNRequestTextRecognitionLevelAccurate
                                               processedImage:&processedImage
                                                        error:error];
            
            if (*error) {
                return nil;
            }
            
            //[ImageUtilities saveImageToDocuments:processedImage fileName:[name stringByAppendingString:@".png"]];
            
            NSCharacterSet *whitespaceAndApostropheCharSet = [NSCharacterSet characterSetWithCharactersInString:@"\n\t '"];
            NSArray *components = [recognized componentsSeparatedByCharactersInSet:whitespaceAndApostropheCharSet];
            NSString* recognizedNoWhitespace = [components componentsJoinedByString:@""];
            
            // If recognized is nil but no error, it probably means no text found
            if (!recognizedNoWhitespace) {
                recognizedNoWhitespace = @"";
            }
            
            // If we found nothing, or we found numbers that are typically confused, then
            // try again, but add a suffix image which seems to help OCR detect things
            if ([recognizedNoWhitespace isEqualToString:@""] ||
                [recognizedNoWhitespace isEqualToString:@"6"] ||
                [recognizedNoWhitespace isEqualToString:@"9"]) {
                recognized = [ImageUtilities performOCR:image
                                       regionOfInterest:roi
                                            customWords:customFormat
                                          addSuffixHack:true // Important
                                       recognitionLevel:VNRequestTextRecognitionLevelAccurate
                                         processedImage:&processedImage
                                                  error:error];
                if (*error) {
                    return nil;
                }
                
                components = [recognized componentsSeparatedByCharactersInSet:whitespaceAndApostropheCharSet];
                recognizedNoWhitespace = [components componentsJoinedByString:@""];
                
                if (!recognizedNoWhitespace) {
                    recognizedNoWhitespace = @"";
                }
//                if ([recognizedNoWhitespace hasSuffix:@".1"]) { // Strip the .1 suffix that we added if it exists
//                    recognizedNoWhitespace = [recognizedNoWhitespace substringToIndex:recognizedNoWhitespace.length - 2];
//                }
                if ([recognizedNoWhitespace hasSuffix:@"0.5"]) { // Strip the .1 suffix that we added if it exists
                    recognizedNoWhitespace = [recognizedNoWhitespace substringToIndex:recognizedNoWhitespace.length - 3];
                }
                if ([recognizedNoWhitespace hasPrefix:@"0.5"]) { // Strip the .1 suffix that we added if it exists
                    recognizedNoWhitespace = [recognizedNoWhitespace substringFromIndex:3];
                }
                
                //NSLog(@"recognized: %@ | clean: %@", recognized, recognizedNoWhitespace);
            }
            
            results[name] = recognizedNoWhitespace;
            
        } else {
            VNCoreMLModel *model = [[ModelManager shared] modelWithName:modelName];
            if (!model) {
                NSLog(@"Model not found: %@", modelName);
                return nil;
            }
            
            float confidence = 0.0f;
            
            NSString *recognized = [ImageUtilities runInference:image
                                                          model:model
                                               regionOfInterest:roi
                                                      confidenc:&confidence
                                                 processedImage:&processedImage
                                                          error:error];
            
            results[name] = recognized;
        }

    }
    
    // Return a copy to avoid mutability concerns
    return [results copy];
}

@end
