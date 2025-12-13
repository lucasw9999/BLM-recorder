#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const CameraManagerNewFrameNotification;

@interface CameraManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong, readonly) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong, readonly) AVCaptureSession *captureSession;

// Singleton accessor
+ (instancetype)shared;

// Starts camera capture session.
- (void)startCamera;

// Stops camera capture session.
- (void)stopCamera;

@end

NS_ASSUME_NONNULL_END
