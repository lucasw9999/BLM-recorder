#import <XCTest/XCTest.h>
#import "ImageUtilities.h"
#import "ScreenReader.h"

//#define TEST_IMAGE_NAME @"20250314_1926-0000-ball"
#define TEST_IMAGE_NAME @"20250314_1926-0073-ball"

bool fuzzyEquals(float x, float y) {
    return fabs(x-y) < 0.1f;
}

float translateDirection(float value, NSString* direction) {
    if([direction isEqualToString:@"L"] || [direction isEqualToString:@"OUT-IN"] || [direction isEqualToString:@"DOWN"])
        return -value;
    else if([direction isEqualToString:@"R"] || [direction isEqualToString:@"IN-OUT"] || [direction isEqualToString:@"UP"])
        return value;
    else
        return 0;
}

@interface ImageUtilitiesTests : XCTestCase

@end

@implementation ImageUtilitiesTests



#pragma mark - Helper to load images
/// Helper method to load an image from the test bundle by name (without extension).
- (UIImage *)loadTestImageNamed:(NSString *)imageName
                          ofType:(NSString *)extension
{
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [testBundle pathForResource:imageName ofType:extension];
    XCTAssertNotNil(path, @"Image path should not be nil for %@", imageName);

    UIImage *image = [UIImage imageWithContentsOfFile:path];
    XCTAssertNotNil(image, @"Failed to load image %@", imageName);

    return image;
}

- (NSDictionary *)loadJSONFileNamed:(NSString *)fileName
                             ofType:(NSString *)extension
{
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [testBundle pathForResource:fileName ofType:extension];
    XCTAssertNotNil(path, @"JSON file path should not be nil for %@", fileName);

    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(data, @"Failed to load JSON data for %@", fileName);

    NSError *error = nil;
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    XCTAssertNil(error, @"Error parsing JSON for %@: %@", fileName, error);
    XCTAssertNotNil(jsonDictionary, @"Parsed JSON dictionary is nil for %@", fileName);

    return jsonDictionary;
}


- (void)testOrderPoints
{
    // Suppose these are 4 points in some random order.
    NSArray<NSValue *> *points = @[
        [NSValue valueWithCGPoint:CGPointMake(300, 300)],  // This might become bottom-right
        [NSValue valueWithCGPoint:CGPointMake(10, 10)],    // This might become top-left
        [NSValue valueWithCGPoint:CGPointMake(300, 10)],   // This might become top-right
        [NSValue valueWithCGPoint:CGPointMake(10, 300)]    // This might become bottom-left
    ];

    NSArray<NSValue *> *orderedPoints = [ImageUtilities orderPoints:points];
    XCTAssertEqual(orderedPoints.count, 4, @"Should return exactly 4 points");

    // Check that the first point is indeed the top-left, etc.
    CGPoint topLeft = [orderedPoints[0] CGPointValue];
    CGPoint topRight = [orderedPoints[1] CGPointValue];
    CGPoint bottomRight = [orderedPoints[2] CGPointValue];
    CGPoint bottomLeft = [orderedPoints[3] CGPointValue];

    // top-left should be (10,10), top-right ~ (300,10), bottom-right ~ (300,300), bottom-left ~ (10,300)
    XCTAssertEqual(topLeft.x, 10);
    XCTAssertEqual(topLeft.y, 10);

    XCTAssertEqual(topRight.x, 300);
    XCTAssertEqual(topRight.y, 10);

    XCTAssertEqual(bottomRight.x, 300);
    XCTAssertEqual(bottomRight.y, 300);

    XCTAssertEqual(bottomLeft.x, 10);
    XCTAssertEqual(bottomLeft.y, 300);
}

- (void)testWarpPerspective
{
    // 1. Load an image that we want to warp
    UIImage *testImage = [self loadTestImageNamed:TEST_IMAGE_NAME ofType:@"png"];
    XCTAssertNotNil(testImage);

    // 2. Provide 4 corner points for perspective transform (for example, entire image corners)
    // Here we pretend the entire image is something we want to warp. Typically you'd have real corner detection.
    NSArray<NSValue *> *points = @[
        [NSValue valueWithCGPoint:CGPointMake(0, 0)],   // top-left
        [NSValue valueWithCGPoint:CGPointMake(testImage.size.width, 0)], // top-right
        [NSValue valueWithCGPoint:CGPointMake(testImage.size.width, testImage.size.height)], // bottom-right
        [NSValue valueWithCGPoint:CGPointMake(0, testImage.size.height)] // bottom-left
    ];

    UIImage *warped = [ImageUtilities warpPerspective:testImage withPoints:points];
    XCTAssertNotNil(warped, @"Warped image should not be nil");
    // Check that the warped image has the expected size (900x450 as in the code)
    XCTAssertEqual(warped.size.width, 900);
    XCTAssertEqual(warped.size.height, 450);
}

- (void)testCropImage
{
    UIImage *testImage = [self loadTestImageNamed:TEST_IMAGE_NAME ofType:@"png"];
    CGSize originalSize = testImage.size;

    // Crop out a 100x100 area from the top-left corner.
    CGRect cropRect = CGRectMake(0, 0, 100, 100);
    UIImage *croppedImage = [ImageUtilities cropImage:testImage toRect:cropRect];
    XCTAssertNotNil(croppedImage, @"Cropped image should not be nil");
    XCTAssertEqual(croppedImage.size.width, 100);
    XCTAssertEqual(croppedImage.size.height, 100);

    // Make sure the original size didn't change
    XCTAssertEqual(originalSize.width, testImage.size.width);
    XCTAssertEqual(originalSize.height, testImage.size.height);
}

- (void)testConvertToGrayscale
{
    UIImage *testImage = [self loadTestImageNamed:TEST_IMAGE_NAME ofType:@"png"];
    UIImage *grayImage = [ImageUtilities convertToGrayscale:testImage];
    XCTAssertNotNil(grayImage, @"Grayscale image should not be nil");

    // We could do further checks on the pixel data if we want
}

- (void)testDrawRectangleOnImage
{
    UIImage *testImage = [self loadTestImageNamed:TEST_IMAGE_NAME ofType:@"png"];
    CGRect rectangle = CGRectMake(10, 10, 50, 50);
    UIImage *result = [ImageUtilities drawRectangleOnImage:testImage
                                                 rectangle:rectangle
                                                     color:[UIColor redColor]
                                                 thickness:2.0];
    XCTAssertNotNil(result, @"Resulting image should not be nil");
    // Optionally, confirm that pixel data changed in the region we drew
}

- (void)testSaveImageToDocuments
{
    UIImage *testImage = [self loadTestImageNamed:TEST_IMAGE_NAME ofType:@"png"];
    NSString *fileName = @"test_saved_image.png";

    // Call the utility method
    [ImageUtilities saveImageToDocuments:testImage fileName:fileName];

    // Check that the file now exists in the Documents directory
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:fileName];

    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
    XCTAssertTrue(fileExists, @"Saved image should exist in the documents directory");

    // Clean up if you like, so repeated runs don't keep old files
    // [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
}

//- (void)testDetectScreenInImage
//{
//    UIImage *testImage = [self loadTestImageNamed:@"testImage_screen" ofType:@"png"];
//    NSArray<NSValue *> *points = [ImageUtilities detectScreenInImage:testImage];
//    
//    // The detectScreenInImage method returns nil or 4 points
//    if (points) {
//        XCTAssertEqual(points.count, 4, @"Should detect exactly 4 corner points");
//    } else {
//        XCTFail(@"Expected to detect screen, but got nil");
//    }
//}

- (void)testBallScreenReader
{
    UIImage *testImage = [self loadTestImageNamed:TEST_IMAGE_NAME ofType:@"png"];
    
    NSError* error = nil;
    NSString *ballPath = [[NSBundle mainBundle] pathForResource:@"annotations-ball" ofType:@"json"];
    ScreenReader* ballDataReader = [[ScreenReader alloc] initWithJSONFile:ballPath type:@"ball-data" error:&error];
    if (error)
        XCTFail(@"Error loading ballDataReader: %@", error);
    
    NSDictionary* result = [ballDataReader runOCROnImage:testImage error:&error];
    if (error)
        XCTFail(@"Error in ballDataReader.runOCROnImage: %@", error);
    
    NSLog(@"Ball data: %@", result);
}

- (void)testVisionPipeline
{
    NSArray *fileBasenames = @[
        @"20250313_1532-0016-ball",
        @"20250313_1532-0020-ball",
        @"20250313_1532-0033-ball",
        @"20250313_1532-0034-ball",
        @"20250313_1532-0036-ball",
        @"20250313_1532-0051-ball",
        @"20250313_1532-0053-ball",
        @"20250313_1532-0058-ball",
        @"20250313_1532-0060-ball",
        @"20250313_1532-0062-ball",
        @"20250313_1532-0069-ball",
        @"20250313_1532-0079-club",
        @"20250314_1926-0000-ball",
        @"20250314_1926-0012-ball",
        @"20250314_1926-0023-club",
        @"20250314_1926-0024-ball",
        @"20250314_1926-0026-ball",
        @"20250314_1926-0038-club",
        @"20250314_1926-0039-club",
        @"20250314_1926-0042-club",
        @"20250314_1926-0045-club",
        @"20250314_1926-0046-ball",
        @"20250314_1926-0048-club",
        @"20250314_1926-0049-club",
        @"20250314_1926-0073-ball",
    ];
    
    NSError* error = nil;
    NSString *ballPath = [[NSBundle mainBundle] pathForResource:@"annotations-ball" ofType:@"json"];
    ScreenReader* ballDataReader = [[ScreenReader alloc] initWithJSONFile:ballPath type:@"ball-data" error:&error];
    if (error)
        XCTFail(@"Error loading ballDataReader: %@", error);
    
    error = nil;
    NSString *clubPath = [[NSBundle mainBundle] pathForResource:@"annotations-club" ofType:@"json"];
    ScreenReader* clubDataReader = [[ScreenReader alloc] initWithJSONFile:clubPath type:@"club-data" error:&error];
    if (error)
        XCTFail(@"Error loading clubDataReader: %@", error);
    
    for (NSString *basename in fileBasenames) {
        // Load the image (expects .png files)
        UIImage *image = [self loadTestImageNamed:basename ofType:@"png"];
        
        // Load the JSON dictionary (expects .json files)
        NSDictionary *data = [self loadJSONFileNamed:basename ofType:@"json"];
        
        // Check that both were loaded successfully
        if( ! (image && data) )
            XCTFail(@"Failed to load one or both resources for file base: %@", basename);
        
        NSLog(@"Testing: %@", basename);
        
        if ([basename hasSuffix:@"ball"]) {
            NSDictionary* result = [ballDataReader runOCROnImage:image error:&error];
            if (error)
                XCTFail(@"Error in ballDataReader.runOCROnImage: %@", error);
            
            XCTAssertTrue(fuzzyEquals([result[@"ball-speed"] floatValue], [data[@"Speed"] floatValue]), @"Mismatch: Speed");
            XCTAssertTrue(fuzzyEquals([result[@"carry"] floatValue], [data[@"CarryDistance"] floatValue]), @"Mismatch: CarryDistance");
            XCTAssertTrue(fuzzyEquals([result[@"vla"] floatValue], [data[@"VLA"] floatValue]), @"Mismatch: VLA");
            XCTAssertTrue(fuzzyEquals(translateDirection([result[@"hla"] floatValue], result[@"hla-direction"]), [data[@"HLA"] floatValue]), @"Mismatch: HLA");
            XCTAssertTrue(fuzzyEquals([result[@"total-spin"] floatValue], [data[@"TotalSpin"] floatValue]), @"Mismatch: TotalSpin");
            XCTAssertTrue(fuzzyEquals(translateDirection([result[@"spin-axis"] floatValue], result[@"spin-axis-direction"]), [data[@"SpinAxis"] floatValue]), @"Mismatch: SpinAxis");
            
            NSLog(@"-------------------\n BALL: %@\n%@", data, result);
            
        } else if ([basename hasSuffix:@"club"]) {
            NSDictionary* result = [clubDataReader runOCROnImage:image error:&error];
            if (error)
                XCTFail(@"Error in clubDataReader.runOCROnImage: %@", error);
            
            NSLog(@"------------------\n CLUB: %@\n%@", data, result);
            
        } else {
            XCTFail(@"Unknown data file (does not end in 'ball' or 'club': %@", basename);
        }
    }
}

@end
