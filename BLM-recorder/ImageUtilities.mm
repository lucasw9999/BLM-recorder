
#import "ImageUtilities.h"
#import <CoreImage/CoreImage.h>
#import <Vision/Vision.h>
#import <CoreGraphics/CoreGraphics.h>

#undef NO //Conflicts with opencv c++ defines
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/imgproc/types_c.h>


// Helpers -----------------------------------------------
cv::Mat loadImageFromAssets(NSString *imageName) {
    // Load UIImage from assets
    UIImage *uiImage = [UIImage imageNamed:imageName];
    if (!uiImage) {
        NSLog(@"Failed to load image from assets: %@", imageName);
        return cv::Mat();
    }

    // Convert UIImage to cv::Mat
    cv::Mat cvImage;
    UIImageToMat(uiImage, cvImage);

    // Convert from RGBA to BGR (since OpenCV uses BGR format)
    cv::cvtColor(cvImage, cvImage, cv::COLOR_RGBA2BGR);

    return cvImage;
}

cv::Mat concatImagesHorizontally(cv::Mat img1, cv::Mat img2) {
    // Ensure both images have the same height
    if (img1.rows != img2.rows) {
        int newHeight = std::min(img1.rows, img2.rows);
        double scale1 = (double)newHeight / img1.rows;
        double scale2 = (double)newHeight / img2.rows;

        cv::resize(img1, img1, cv::Size(img1.cols * scale1, newHeight));
        cv::resize(img2, img2, cv::Size(img2.cols * scale2, newHeight));
    }

    // Concatenate images horizontally
    cv::Mat result;
    cv::hconcat(img1, img2, result);

    return result;
}

// ImageUtilities -----------------------------------------------

@implementation ImageUtilities
+ (NSArray<NSValue *> *)orderPoints:(NSArray<NSValue *> *)points {
    if (points.count != 4) {
        NSLog(@"Error: Exactly 4 points are required for ordering.");
        return nil;
    }

    // Step 1: Find top-left (closest to (0,0)) and bottom-right (farthest from (0,0))
    NSValue *topLeftValue = points[0];
    NSValue *bottomRightValue = points[0];
    CGFloat topLeftDistance = CGFLOAT_MAX;
    CGFloat bottomRightDistance = -CGFLOAT_MAX;

    for (NSValue *value in points) {
        CGPoint point = [value CGPointValue];
        CGFloat distance = sqrt(point.x * point.x + point.y * point.y);
        
        if (distance < topLeftDistance) {
            topLeftDistance = distance;
            topLeftValue = value;
        }
        if (distance > bottomRightDistance) {
            bottomRightDistance = distance;
            bottomRightValue = value;
        }
    }

    // Step 2: Remove top-left and bottom-right
    NSMutableArray<NSValue *> *remainingPoints = [points mutableCopy];
    [remainingPoints removeObject:topLeftValue];
    [remainingPoints removeObject:bottomRightValue];

    // Step 3: Determine top-right and bottom-left based on x-coordinate
    NSValue *topRightValue = remainingPoints[0];
    NSValue *bottomLeftValue = remainingPoints[1];
    CGPoint topRight = [topRightValue CGPointValue];
    CGPoint bottomLeft = [bottomLeftValue CGPointValue];

    if (topRight.x < bottomLeft.x) {
        topRightValue = remainingPoints[1];
        bottomLeftValue = remainingPoints[0];
    }

    // Step 4: Return points in order: top-left, top-right, bottom-right, bottom-left
    return @[topLeftValue, topRightValue, bottomRightValue, bottomLeftValue];
}


#pragma mark - Perspective Warp
+ (UIImage *)warpPerspective:(UIImage *)inputImage withPoints:(NSArray<NSValue *> *)points {
    // Ensure we have exactly 4 points
    if (points.count != 4) {
        NSLog(@"Error: Input points must contain exactly 4 points.");
        return nil;
    }
    
    NSArray<NSValue *> *orderedPointsNS = [ImageUtilities orderPoints:points];
    
    // Step 1: Convert NSArray<NSValue *> to std::vector<cv::Point2f>
    std::vector<cv::Point2f> orderedPoints;
    for (NSValue *value in orderedPointsNS) {
        CGPoint cgPoint = [value CGPointValue];
        orderedPoints.push_back(cv::Point2f(cgPoint.x, cgPoint.y));
    }
//
//    for (int i = 0; i < 4; i++) {
//        NSLog(@"Points B: (%f, %f)", orderedPoints[i].x, orderedPoints[i].y);
//    }


    // Step 3: Define destination points for the fixed resolution/aspect ratio
    float width = 900.0;  // Desired width
    float height = 450.0; // Desired height
    std::vector<cv::Point2f> dstPoints = {
        cv::Point2f(width, height),        // Bottom-right
        cv::Point2f(0, height),             // Bottom-left
        cv::Point2f(0, 0),                  // Top-left
        cv::Point2f(width, 0),             // Top-right
    };

    // Step 4: Compute the perspective transformation matrix
    cv::Mat transformMatrix = cv::getPerspectiveTransform(orderedPoints, dstPoints);

    // Step 5: Convert UIImage to cv::Mat
    cv::Mat inputMat;
    UIImageToMat(inputImage, inputMat);

    if (inputMat.empty()) {
        NSLog(@"Error: Failed to convert UIImage to cv::Mat.");
        return nil;
    }

    // Step 6: Apply perspective warp
    cv::Mat warpedMat;
    cv::warpPerspective(inputMat, warpedMat, transformMatrix, cv::Size(width, height));

    // Step 7: Convert the warped cv::Mat back to UIImage
    UIImage *warpedImage = MatToUIImage(warpedMat);
    return warpedImage;
}



#pragma mark - Crop
+ (UIImage *)cropImage:(UIImage *)inputImage toRect:(CGRect)rect {
    CGImageRef croppedImageRef = CGImageCreateWithImageInRect(inputImage.CGImage, rect);
    UIImage *croppedImage = [UIImage imageWithCGImage:croppedImageRef];
    CGImageRelease(croppedImageRef);
    return croppedImage;
}

+ (void)saveImageToDocuments:(UIImage *)image fileName:(NSString *)fileName {
    NSData *imageData = UIImagePNGRepresentation(image);
    
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:fileName];

    [imageData writeToFile:filePath atomically:YES];
}

+ (UIImage *)processImageForOCR:(UIImage *)inputImage
               regionOfInterest:(CGRect)roi
                      tightCrop:(bool)tightCrop
                  addSuffixHack:(bool)useSuffixHack
{
    // 1) Convert UIImage to OpenCV Mat
    cv::Mat matImage;
    UIImageToMat(inputImage, matImage);

    // 2) Convert ROI to grayscale
    cv::Rect roiRect(roi.origin.x * matImage.cols,
                     roi.origin.y * matImage.rows,
                     roi.size.width * matImage.cols,
                     roi.size.height * matImage.rows);
    
    cv::Mat roiMat = matImage(roiRect);
    cv::Mat grayMat;
    cv::cvtColor(roiMat, grayMat, cv::COLOR_BGR2GRAY);

    // Step 3: Normalize the Image
    cv::Mat normalizedMat;
    cv::normalize(grayMat, normalizedMat, 0, 255, cv::NORM_MINMAX);

    // Crops around the digits tightly based on threshold
    // I thought this would help OCR, but it does not seem to have an effect, so we don't use it
    if(tightCrop) {
        // 4) Apply Otsu's Thresholding
        cv::Mat thresholdMat;
//        cv::threshold(normalizedMat, thresholdMat, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);
        cv::threshold(normalizedMat, thresholdMat, 75, 255, cv::THRESH_BINARY);
        
        // 5) Invert the thresholded image (important content is black)
        cv::Mat invertedMat;
        cv::bitwise_not(thresholdMat, invertedMat);
        
        cv::imwrite("/Users/kevin/Desktop/invertedMat.png", invertedMat);

        // 6) Find bounding box of non-zero regions
        std::vector<std::vector<cv::Point>> contours;
        std::vector<cv::Vec4i> hierarchy;
        cv::findContours(invertedMat, contours, hierarchy, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

        if (!contours.empty()) {
            // We assume we're here ONLY for single digits, so we ignore any noise
            double largestArea = 0.0;
            size_t largestContourIndex = 0;
            for (size_t i = 0; i < contours.size(); i++) {
                double area = cv::contourArea(contours[i]);
                if (area > largestArea) {
                    largestArea = area;
                    largestContourIndex = i;
                }
            }
            cv::Rect largestBoundingBox = cv::boundingRect(contours[largestContourIndex]);
            
//            // Union of all countour bounding boxes (not used)
//            cv::Rect boundingBox = cv::boundingRect(contours[0]);
//            for (size_t i = 1; i < contours.size(); i++) {
//                boundingBox = boundingBox | cv::boundingRect(contours[i]);
//            }
            
            cv::Rect boundingBox = largestBoundingBox;
            
            // 7) Expand bounding box by 5 pixels on all sides
            int margin = 5;
            boundingBox.x = std::max(0, boundingBox.x - margin);
            boundingBox.y = std::max(0, boundingBox.y - margin);
            boundingBox.width = std::min(roiMat.cols - boundingBox.x, boundingBox.width + 2 * margin);
            boundingBox.height = std::min(roiMat.rows - boundingBox.y, boundingBox.height + 2 * margin);
            
            // 8) Crop the normalized image using the adjusted bounding box
            cv::Mat croppedMat = normalizedMat(boundingBox);
            normalizedMat = croppedMat.clone();
        }
    }
    
    cv::cvtColor(normalizedMat, roiMat, cv::COLOR_GRAY2BGR);
    
    // Add a ".1" image which seems to help apple's OCR...
    if(useSuffixHack) {
        static cv::Mat suffixImage;
        if(suffixImage.empty()) {
            suffixImage = loadImageFromAssets(@"decimal-suffix-helper2.png");
        }
        cv::Mat imageWithSuffix = concatImagesHorizontally(suffixImage, roiMat);
        cv::Mat imageWithSuffix2 = concatImagesHorizontally(imageWithSuffix, suffixImage);
        roiMat = imageWithSuffix2.clone();
    }
    
    UIImage *processedImage = MatToUIImage(roiMat);
    return processedImage;
}

+ (void)saveDebugImage:(UIImage *)debugImage
              withName:(NSString *)imageName
{
    static int counter = 0;
    counter++;
    
    NSString *tempPath = NSTemporaryDirectory();  // typically something like /Users/.../tmp
    NSString *filePath = [tempPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%d.png", imageName, counter]];

    BOOL success = [UIImagePNGRepresentation(debugImage) writeToFile:filePath atomically:YES];
    if(success)
        NSLog(@"[DEBUG] Image saved to: %@", filePath);
    else
        NSLog(@"[DEBUG] Failed to save debug image!");
}


#pragma mark - OCR
+ (NSString *)performOCR:(UIImage *)inputImage
        regionOfInterest:(CGRect)roi
             customWords:(nullable NSArray<NSString *> *)customWords
           addSuffixHack:(bool)useSuffixHack
        recognitionLevel:(VNRequestTextRecognitionLevel)recognitionLevel
          processedImage:(UIImage **)processedResult
                   error:(NSError **)error
{
    UIImage* processedImage = nil;
    if(!useSuffixHack) {
        processedImage = [ImageUtilities processImageForOCR:inputImage regionOfInterest:roi tightCrop:false addSuffixHack:false];
    } else {
        processedImage = [ImageUtilities processImageForOCR:inputImage regionOfInterest:roi tightCrop:false addSuffixHack:true];
    }
    
    if(processedResult)
        *processedResult = processedImage;
    
    //[self saveDebugImage:processedImage withName:@"tmp"];
    
    // 1) Create a VNImageRequestHandler using the CGImage
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc]
                                      initWithCGImage:processedImage.CGImage
                                      options:@{}];
    
    // 2) Create the text request
    VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc] init];
    request.recognitionLevel = recognitionLevel;
    
    // 3) If customWords is nonempty, set it and enable correction
    if (customWords != nil && customWords.count > 0) {
        request.customWords = customWords;
        request.usesLanguageCorrection = 1;
    } else {
        // Otherwise, disable correction and leave customWords alone
        request.usesLanguageCorrection = 0;
    }
    
    // 4) Other params
    //request.regionOfInterest = roi; // roi already applied during processImageForOCR
    request.minimumTextHeight = 0.5; // Assumes the text occupies at least half of the image height
    request.recognitionLanguages = @[@"en-US"];
    
    // 5) Perform the request
    [handler performRequests:@[request] error:error];
    if (*error) {
        return nil;
    }
    
    // 6) Parse results
    NSMutableString *recognizedText = [NSMutableString string];
    for (VNRecognizedTextObservation *observation in request.results) {
        NSArray<VNRecognizedText *> *topCandidates = [observation topCandidates:1];
        if (topCandidates.count > 0) {
            [recognizedText appendString:topCandidates.firstObject.string];
            [recognizedText appendString:@"\n"];
        }
    }
    
    return [recognizedText copy];
}

#pragma mark - Grayscale
+ (UIImage *)convertToGrayscale:(UIImage *)inputImage {
    CIImage *ciImage = [[CIImage alloc] initWithImage:inputImage];
    CIFilter *grayscaleFilter = [CIFilter filterWithName:@"CIColorControls"];
    [grayscaleFilter setValue:ciImage forKey:kCIInputImageKey];
    [grayscaleFilter setValue:@0.0 forKey:@"inputSaturation"];
    
    CIImage *outputCIImage = grayscaleFilter.outputImage;
    if (!outputCIImage) return nil;
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:outputCIImage fromRect:outputCIImage.extent];
    UIImage *outputImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return outputImage;
}

#pragma mark - Draw Rectangle
+ (UIImage *)drawRectangleOnImage:(UIImage *)inputImage
                        rectangle:(CGRect)rectangle
                            color:(UIColor *)color
                        thickness:(CGFloat)thickness {
    UIGraphicsBeginImageContext(inputImage.size);
    [inputImage drawAtPoint:CGPointZero];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, thickness);
    CGContextStrokeRect(context, rectangle);
    
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return outputImage;
}

#pragma mark - Draw Circle
+ (UIImage *)drawCircleOnImage:(UIImage *)inputImage
                        center:(CGPoint)center
                        radius:(CGFloat)radius
                         color:(UIColor *)color
                     thickness:(CGFloat)thickness {
    UIGraphicsBeginImageContext(inputImage.size);
    [inputImage drawAtPoint:CGPointZero];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, thickness);
    CGContextStrokeEllipseInRect(context, CGRectMake(center.x - radius, center.y - radius, radius * 2, radius * 2));
    
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return outputImage;
}

#pragma mark - Save image to disk (debug)
+ (NSString *)saveImage:(UIImage *)image withName:(NSString *)name inDirectory:(NSString *)directory {
    // Determine the directory
    NSString *targetDirectory;
    if (directory) {
        targetDirectory = directory;
    } else {
        targetDirectory = NSTemporaryDirectory(); // Default to temporary directory
    }
    
    // Ensure the directory exists
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:targetDirectory]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:targetDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"Failed to create directory: %@", error.localizedDescription);
            return nil;
        }
    }
    
    // Create the full file path
    NSString *filePath = [targetDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", name]];
    
    // Convert UIImage to PNG data
    NSData *imageData = UIImagePNGRepresentation(image);
    if (!imageData) {
        NSLog(@"Failed to create PNG representation for image: %@", name);
        return nil;
    }
    
    // Write the image data to the file
    NSError *error = nil;
    if (![imageData writeToFile:filePath options:NSDataWritingAtomic error:&error]) {
        NSLog(@"Failed to save image at path %@: %@", filePath, error.localizedDescription);
        return nil;
    }
    
    NSLog(@"Image saved at path: %@", filePath);
    return filePath;
}

+ (NSString *)saveImageOnDevice:(UIImage *)image withName:(NSString *)name {
    // Get the Documents directory path
    NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [docsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", name]];

    // Convert the UIImage to PNG data
    NSData *imageData = UIImagePNGRepresentation(image);
    
    // Save the image data to the file
    if ([imageData writeToFile:filePath atomically:YES]) {
        NSLog(@"Image saved successfully at %@", filePath);
        return filePath; // Return the full file path
    } else {
        NSLog(@"Failed to save image.");
        return nil; // Return nil if saving fails
    }
}

+ (NSString *)saveImageDebug:(UIImage *)image
                    withName:(NSString *)name
                 inDirectory:(nullable NSString *)directory {
    // This is a wrapper around the existing saveImage method for debug purposes
    return [self saveImage:image withName:name inDirectory:directory];
}

+ (NSArray<NSValue *> *)detectScreenInImage:(UIImage *)inputImage {
    // Step 1: Convert UIImage to cv::Mat
    cv::Mat imageMat;
    UIImageToMat(inputImage, imageMat);
    if (imageMat.empty()) {
        NSLog(@"Failed to convert UIImage to cv::Mat");
        return nil;
    }

    // Step 2: Convert to Grayscale
    cv::Mat grayMat;
    cv::cvtColor(imageMat, grayMat, cv::COLOR_BGR2GRAY);

    // Step 3: Normalize the Image
    cv::Mat normalizedMat;
    cv::normalize(grayMat, normalizedMat, 0, 255, cv::NORM_MINMAX);

    // Step 4: Apply Otsu's Thresholding
    cv::Mat threshMat;
    cv::threshold(normalizedMat, threshMat, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);

    // Step 5: Morphological Opening
    cv::Mat openedMat;
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(11, 11));
    cv::morphologyEx(threshMat, openedMat, cv::MORPH_OPEN, kernel);

    // Step 6: Find Contours
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(openedMat, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    // Step 7: Approximate Contours to Polygons and Find a 4-Point Polygon
    for (const std::vector<cv::Point> &contour : contours) {
        // Approximate the contour to a polygon
        double epsilon = 0.02 * cv::arcLength(contour, true);
        std::vector<cv::Point> approxPolygon;
        cv::approxPolyDP(contour, approxPolygon, epsilon, true);

        // Check if the polygon has 4 points
        if (approxPolygon.size() == 4) {
            // Convert to NSArray of NSValue objects
            NSMutableArray<NSValue *> *polygonPoints = [NSMutableArray array];
            for (const cv::Point &point : approxPolygon) {
                [polygonPoints addObject:[NSValue valueWithCGPoint:CGPointMake(point.x, point.y)]];
            }
            return polygonPoints;
        }
    }

    return nil; // No valid screen contour found
}


+ (NSString*)runInference:(UIImage *)image
                    model:(VNCoreMLModel*) model
         regionOfInterest:(CGRect)roi
                confidenc:(float*)confidence
           processedImage:(UIImage **)processedResult
                    error:(NSError **)error {
    
    UIImage* processedImage = [ImageUtilities processImageForOCR:image regionOfInterest:roi tightCrop:false addSuffixHack:false];
    if(processedResult)
        *processedResult = processedImage;
    
    //[self saveDebugImage:processedImage withName:@"tmp"];
    
    // Prepare the request (no callback needed)
    VNCoreMLRequest *request = [[VNCoreMLRequest alloc] initWithModel:model];
    
    // Perform the request synchronously
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:processedImage.CGImage options:@{}];
    BOOL success = [handler performRequests:@[request] error:error];
    
    if ((!success || error) && *error) {
        NSLog(@"Error performing request: %@", (*error).localizedDescription);
        return nil;
    }

    // Ensure there are results before accessing
    if (request.results.count > 0) {
        id firstResult = request.results.firstObject;

        // Check if it's a VNClassificationObservation
        if ([firstResult isKindOfClass:[VNClassificationObservation class]]) {
            VNClassificationObservation *topResult = (VNClassificationObservation *)firstResult;
            
            if (confidence)
                *confidence = topResult.confidence;
            
            return topResult.identifier;
        } else {
            VNCoreMLFeatureValueObservation* topResult = (VNCoreMLFeatureValueObservation*)request.results.firstObject;
            NSLog(@"%@ - %@", topResult.featureName, topResult.featureValue);
            NSLog(@"Error: First result is not a VNClassificationObservation. It is a %@", [firstResult class]);
        }
    } else {
        NSLog(@"Error: No results from VNCoreMLRequest.");
    }

    return nil;
}


@end
