#import <CoreFoundation/CoreFoundation.h>

// Use this flag to save data out for training models and debugging issues
#define SAVE_DEBUG_DATA 0 // Set to 1 to enable, 0 to disable

// Performance timing logs
#define ENABLE_PERFORMANCE_LOGGING 1 // Set to 1 to enable timing logs, 0 to disable

#if SAVE_DEBUG_DATA
    #define DEBUG_SAVE_SHOT_DATA(image, data, shotNumber) \
        [self DEBUG_saveShotImage:(image) withData:(data) andShotNumber:(shotNumber)]
#else
    #define DEBUG_SAVE_SHOT_DATA(image, data, shotNumber)
#endif

#if ENABLE_PERFORMANCE_LOGGING
    #define PERF_LOG_START(operation) \
        CFAbsoluteTime perfTimer_##operation = CFAbsoluteTimeGetCurrent(); \
        NSLog(@"[PERF] Starting %s", #operation)
    #define PERF_LOG_END(operation) \
        CFAbsoluteTime perfElapsed_##operation = (CFAbsoluteTimeGetCurrent() - perfTimer_##operation) * 1000.0; \
        NSLog(@"[PERF] Finished %s (%.2f ms)", #operation, perfElapsed_##operation)
#else
    #define PERF_LOG_START(operation)
    #define PERF_LOG_END(operation)
#endif

// Number of same detections required in a row to count as a successful/correct result
#define NUM_CONSISTENCY_CHECKS 3

// Tiered consistency checking for different data types
#define NUM_CONSISTENCY_CHECKS_BALL_DATA 3      // Keep high for accuracy
#define NUM_CONSISTENCY_CHECKS_CLUB_DATA 2      // Reduce for performance
#define NUM_CONSISTENCY_CHECKS_SCREEN_DETECTION 2

// Time to wait between running OCR on the camera stream
#define OCR_RATE_SECONDS 0.100
