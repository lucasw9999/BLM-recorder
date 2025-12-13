#import "CameraManager.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

NSString * const CameraManagerNewFrameNotification = @"CameraManagerNewFrameNotification";

@interface CameraManager ()

@property (nonatomic, assign) BOOL isProcessingFrame;

@property (nonatomic, strong, readwrite) AVCaptureSession *captureSession;
@property (nonatomic, strong, readwrite) AVCaptureVideoDataOutput *videoOutput;

@property (nonatomic, strong) dispatch_queue_t cameraQueue;
@property (nonatomic, assign) BOOL cameraIsRunning;

@end

@implementation CameraManager

+ (instancetype)shared {
    static CameraManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CameraManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Create a dedicated serial queue for camera setup & frames
        _cameraQueue = dispatch_queue_create("com.yourapp.CameraQueue", DISPATCH_QUEUE_SERIAL);
        _cameraIsRunning = NO;
    }
    return self;
}

#pragma mark - Public Methods

- (void)startCamera {
    if (self.cameraIsRunning) {
        NSLog(@"CameraManager: startCamera called but camera is already running.");
        return;
    }
    self.cameraIsRunning = YES;
    
    // Start camera setup on a background queue to avoid blocking main thread
    dispatch_async(self.cameraQueue, ^{
        [self setupCaptureSession];
    });
}

- (void)stopCamera {
    if (!self.cameraIsRunning) {
        NSLog(@"CameraManager: stopCamera called but camera is not running.");
        return;
    }
    self.cameraIsRunning = NO;
    
    dispatch_async(self.cameraQueue, ^{
        [self.captureSession stopRunning];
        self.captureSession = nil;
        self.videoOutput = nil;
        NSLog(@"CameraManager: Camera stopped");
    });
}

#pragma mark - Setup Capture Session

// Mimics your "ViewController" logic for ultra-wide, exposure, etc.
- (void)setupCaptureSession {
    NSLog(@"CameraManager: Setting up capture session on background thread.");
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPresetHigh;
    
    AVCaptureDevice *camera = [self getUltraWideCameraIfAvailable];
    if (!camera) {
        // fallback if no ultra-wide
        camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error];
    if (error) {
        NSLog(@"CameraManager: Error creating device input: %@", error.localizedDescription);
        return;
    }
    
    if ([session canAddInput:input]) {
        [session addInput:input];
    }
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    dispatch_queue_t sampleBufferQueue = dispatch_queue_create("VideoOutputQueue", DISPATCH_QUEUE_SERIAL);
    [output setSampleBufferDelegate:self queue:sampleBufferQueue];
    output.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
    
    if ([session canAddOutput:output]) {
        [session addOutput:output];
    }
    
    // Attempt to configure camera exposure
    if ([camera lockForConfiguration:&error]) {
        // If you want absolute exposure (uncomment for custom shutter/ISO):
        
        /*
        if ([camera isExposureModeSupported:AVCaptureExposureModeCustom]) {
            CMTime newDuration = CMTimeMake(20, 1000); // 1/125s or so
            float newISO = 100.0;
            [camera setExposureModeCustomWithDuration:newDuration
                                                  ISO:newISO
                                     completionHandler:nil];
        } else {
            NSLog(@"CameraManager: Custom exposure not supported on this device format.");
        }
        
        // Else use continuous + negative bias to make it darker
        if ([camera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            camera.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        }
        
        float desiredBias = -1.0f; // Negative => darker
        [camera setExposureTargetBias:desiredBias completionHandler:nil];
        */
        
        // Else use continuous + negative bias to make it darker
        if ([camera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            camera.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        }
        
        float desiredBias = -3.0f; // Negative => darker
        [camera setExposureTargetBias:desiredBias completionHandler:nil];
        
        [camera unlockForConfiguration];
    } else {
        NSLog(@"CameraManager: Error locking device for exposure: %@", error.localizedDescription);
    }
    
    self.captureSession = session;
    self.videoOutput = output;
    
    // Finally, start running
    [session startRunning];
    NSLog(@"CameraManager: Session started running.");
}

- (AVCaptureDevice *)getUltraWideCameraIfAvailable {
    AVCaptureDeviceDiscoverySession *discovery =
    [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInUltraWideCamera]
                                                           mediaType:AVMediaTypeVideo
                                                            position:AVCaptureDevicePositionBack];
    if (discovery.devices.count > 0) {
        return discovery.devices.firstObject;
    }
    return nil;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    // Simple guard so we don't process frames concurrently
    if (self.isProcessingFrame) {
        return;
    }
    self.isProcessingFrame = YES;
    
    @autoreleasepool {
        // Convert sampleBuffer -> UIImage
        UIImage *frame = [self imageFromSampleBuffer:sampleBuffer];
        if (!frame) {
            self.isProcessingFrame = NO;
            return;
        }
        
        NSDictionary *userInfo = @{@"frame": frame};
        [[NSNotificationCenter defaultCenter] postNotificationName:CameraManagerNewFrameNotification
                                                            object:nil
                                                          userInfo:userInfo];

        // Freed up for the next frame
        self.isProcessingFrame = NO;
    }
}

// Minimal method to convert CMSampleBuffer -> UIImage
- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress,
                                                 width,
                                                 height,
                                                 8,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    
    UIImage *image = [UIImage imageWithCGImage:quartzImage
                                         scale:1.0
                                   orientation:UIImageOrientationDown];
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(quartzImage);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    return image;
}

@end
