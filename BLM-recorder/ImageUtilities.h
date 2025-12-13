
#import <UIKit/UIKit.h>
#import <CoreML/CoreML.h>
#import <Vision/Vision.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageUtilities : NSObject

+ (NSArray<NSValue *> *)orderPoints:(NSArray<NSValue *> *)points;

// Perspective Warp
+ (nullable UIImage *)warpPerspective:(UIImage *)inputImage
                           withPoints:(NSArray<NSValue *> *)points;

// Crop
+ (nullable UIImage *)cropImage:(UIImage *)inputImage toRect:(CGRect)rect;

// OCR
+ (nullable NSString *)performOCR:(UIImage *)inputImage
                 regionOfInterest:(CGRect)roi
                      customWords:(nullable NSArray<NSString *> *)customWords
                    addSuffixHack:(bool)useSuffixHack
                 recognitionLevel:(VNRequestTextRecognitionLevel)recognitionLevel
                   processedImage:(UIImage * _Nullable * _Nullable)processedImage
                            error:(NSError * _Nullable * _Nullable)error;

// Grayscale Conversion
+ (nullable UIImage *)convertToGrayscale:(UIImage *)inputImage;

// Draw Rectangle
+ (nullable UIImage *)drawRectangleOnImage:(UIImage *)inputImage
                                 rectangle:(CGRect)rectangle
                                     color:(UIColor *)color
                                 thickness:(CGFloat)thickness;

// Draw Circle
+ (nullable UIImage *)drawCircleOnImage:(UIImage *)inputImage
                                 center:(CGPoint)center
                                 radius:(CGFloat)radius
                                  color:(UIColor *)color
                              thickness:(CGFloat)thickness;

// Save image to disk
+ (nullable NSString *)saveImageDebug:(UIImage *)image
                             withName:(NSString *)name
                          inDirectory:(nullable NSString *)directory;

+ (nullable NSString *)saveImageOnDevice:(UIImage *)image
                                withName:(NSString *)name;


+ (void)saveImageToDocuments:(UIImage *)image
                    fileName:(NSString *)fileName;

// Detect Screen (Custom Algorithm)
+ (nullable NSArray<NSValue *> *)detectScreenInImage:(UIImage *)inputImage;


+ (nullable NSString*)runInference:(UIImage *)image
                             model:(VNCoreMLModel*) model
                  regionOfInterest:(CGRect)roi
                        confidenc:(float * _Nullable)confidence
                    processedImage:(UIImage * _Nullable * _Nullable)processedImage
                             error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
