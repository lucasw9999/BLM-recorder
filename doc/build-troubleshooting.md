# Build Fixes and Technical Issues

## Overview

This document provides a comprehensive troubleshooting guide for BLM-recorder, covering all build issues encountered during development, their root causes, solutions, and prevention strategies. This serves as both a historical record and a troubleshooting reference for future development.

## Build Environment Issues

### Issue 1: OpenCV Framework Missing

**Error Message**:
```
'opencv2/opencv.hpp' file not found
```

**Symptoms**:
- Build fails during compilation of `ImageUtilities.mm`
- Objective-C++ files cannot find OpenCV headers
- Linker errors for OpenCV functions

**Root Cause**:
OpenCV iOS framework not included in project structure

**Investigation Process**:
```bash
# Check if framework exists
ls opencv-ios-framework/
# Result: Directory not found

# Check Xcode framework search paths
# Build Settings → Framework Search Paths
# Result: Path references non-existent directory
```

**Solution**:
```bash
# 1. Download OpenCV 4.8.0 iOS Framework
wget https://github.com/opencv/opencv/releases/download/4.8.0/opencv-4.8.0-ios-framework.zip

# 2. Extract to project directory
unzip opencv-4.8.0-ios-framework.zip
mv opencv2.framework opencv-ios-framework/

# 3. Verify structure
ls opencv-ios-framework/opencv2.framework/
# Headers/  Info.plist  Modules/  opencv2*
```

**Xcode Configuration**:
```
Framework Search Paths: $(PROJECT_DIR)/opencv-ios-framework
Header Search Paths: $(PROJECT_DIR)/opencv-ios-framework/opencv2.framework/Headers
```

**Prevention**:
- Document OpenCV dependency in README
- Include framework verification in setup instructions
- Consider adding framework to repository (if licensing allows)

### Issue 2: iOS Signing Certificate Problems

**Error Messages**:
```
Multiple keychain dialogs appearing
"codesign wants to use your confidential information stored in your keychain"
Build hanging indefinitely
```

**Symptoms**:
- Xcode build process stalls
- Multiple authentication dialogs
- Build never completes

**Root Cause Analysis**:
```
Keychain Access Issues:
1. Multiple provisioning profiles with same bundle ID
2. Expired certificates in keychain
3. Keychain access permissions corrupted
4. SecurityAgent processes stuck
```

**Diagnostic Commands**:
```bash
# Check running SecurityAgent processes
ps aux | grep SecurityAgent

# Check codesign processes
ps aux | grep codesign

# Check keychain status
security list-keychains
security dump-keychain login.keychain
```

**Solution**:
```bash
# 1. Kill stuck processes
killall SecurityAgent
killall codesign

# 2. Clean Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 3. Reset keychain access
security unlock-keychain ~/Library/Keychains/login.keychain-db

# 4. Update bundle identifier to avoid conflicts
# In Xcode: Signing & Capabilities → Bundle Identifier
```

**Long-term Fix**:
- Use unique bundle identifier per developer
- Clean expired certificates from keychain
- Use automatic provisioning when possible

### Issue 3: Bundle Identifier Conflicts

**Error Message**:
```
No profiles for 'com.lucas.BLM-recorder' were found
```

**Symptoms**:
- Build fails during signing phase
- Cannot install on device
- Provisioning profile errors

**Root Cause**:
Bundle identifier tied to different Apple Developer account

**Investigation**:
```xml
<!-- In Info.plist -->
<key>CFBundleIdentifier</key>
<string>com.lucas.BLM-recorder</string>

<!-- Account mismatch -->
Developer Account: luyaowu@example.com
Bundle ID registered to: luyaowu@example.com
```

**Solution**:
```xml
<!-- Updated bundle identifier -->
<key>CFBundleIdentifier</key>
<string>com.luyaowu.blm-recorder</string>
```

**Xcode Configuration**:
```
Target Settings:
- Bundle Identifier: com.luyaowu.blm-recorder
- Team: [Your Apple ID]
- Provisioning Profile: Automatic
```

**Prevention**:
- Use consistent naming convention: com.{developer}.{app}
- Document bundle ID requirements
- Use automatic provisioning for development builds

## Project Structure Issues

### Issue 4: Info.plist Path Error

**Error Message**:
```
Build input file cannot be found: '/Users/.../BLM-recorder/Info.plist'
Did you forget to declare this file as an output of a script phase or custom build rule?
```

**Symptoms**:
- Build fails at Info.plist processing stage
- References incorrect directory structure
- Path configuration mismatch

**Root Cause**:
Project configuration file has incorrect path references

**Investigation**:
```bash
# Search for path references
grep -r "Info.plist" BLM-recorder.xcodeproj/
# Result: Found references in project.pbxproj

# Check actual file location
find . -name "Info.plist" -type f
# Result: ./BLM-recorder/Info.plist
```

**Solution**:
```bash
# Update project.pbxproj references if needed
# Verify path in Xcode project settings
```

**Manual Fix in Xcode**:
```
Target Settings → Build Settings → Info.plist File:
Verify: BLM-recorder/Info.plist
```

**Verification**:
```bash
# Confirm correct references
grep -r "Info.plist" BLM-recorder.xcodeproj/
```

### Issue 5: Search Path Warnings

**Warning Message**:
```
ld: warning: search path '/Users/.../old-path' not found
```

**Symptoms**:
- Build completes but shows warnings
- References to incorrect directory structure
- Non-critical but indicates cleanup needed

**Root Cause**:
Build system caching old directory references

**Investigation**:
```bash
# Check build settings for path issues
grep -r "path" BLM-recorder.xcodeproj/project.pbxproj | grep -i search

# Check Xcode derived data
ls ~/Library/Developer/Xcode/DerivedData/
```

**Solution**:
```bash
# Clean build artifacts
xcodebuild -project BLM-recorder.xcodeproj -scheme BLM-recorder clean

# Remove derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/BLM-recorder-*
```

**Prevention**:
- Always clean build after major project structure changes
- Use relative paths instead of absolute paths where possible
- Regularly clean derived data during development

## Performance and Compilation Issues

### Issue 6: Objective-C++ Compilation Warnings

**Warning Messages**:
```
pointer is missing a nullability type specifier (_Nonnull, _Nullable, or _Null_unspecified)
double-quoted include in framework header, expected angle-bracketed instead
```

**Symptoms**:
- Multiple compiler warnings during build
- No build failures but verbose output
- Affects code quality metrics

**Root Cause Analysis**:
```
Nullability Warnings:
- Modern Objective-C requires explicit nullability annotations
- ImageUtilities.h methods lack proper annotations

OpenCV Warnings:
- Third-party framework using deprecated include style
- Cannot be fixed in project code (external dependency)
```

**Solutions**:

**For Nullability** (Optional - cosmetic improvement):
```objc
// Before
+ (NSArray<NSValue *> *)detectScreenInImage:(UIImage *)inputImage;

// After (if fixing warnings)
+ (nullable NSArray<NSValue *> *)detectScreenInImage:(nonnull UIImage *)inputImage;
```

**For OpenCV Warnings** (Cannot fix - external framework):
```c
// Suppress warnings if desired
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wquoted-include-in-framework-header"
#import <opencv2/opencv.hpp>
#pragma clang diagnostic pop
```

**Current Status**: Warnings are cosmetic and don't affect functionality

### Issue 7: Model Loading Performance

**Problem**:
App startup takes 2-3 seconds due to model loading

**Investigation**:
```objc
// Original implementation - blocking startup
- (instancetype)init {
    // Load all models synchronously at startup
    _modelHeight = [self loadCompiledModelNamed:@"trajectory_model_height_ft"];
    _modelLateralSpin = [self loadCompiledModelNamed:@"trajectory_model_lateral_spin_yd"];
    _modelRoll = [self loadCompiledModelNamed:@"trajectory_model_roll_yd"];
    // Total: ~600ms startup delay
}
```

**Solution**: Lazy loading optimization (documented in performance-optimization.md)

## Deployment Issues

### Issue 8: Device Installation Permissions

**Error Message**:
```
"BLM-recorder" cannot be opened because the developer cannot be verified
```

**Symptoms**:
- App installs but won't launch
- iOS security warning
- Occurs on first installation

**Root Cause**:
iOS requires explicit trust for non-App Store applications

**Solution**:
```
iOS Device Settings:
1. Settings → General → VPN & Device Management
2. Select Developer Profile (your Apple ID)
3. Tap "Trust [Your Name]"
4. Confirm trust decision
```

**Prevention**:
- Include trust instructions in README
- Document this as normal iOS behavior
- Consider enterprise distribution for organization use

### Issue 9: Camera Permissions

**Runtime Error**:
```
AVCaptureSession error: Camera access denied
```

**Symptoms**:
- App launches but camera doesn't work
- Black screen instead of camera view
- Permission prompt not shown

**Root Cause**:
Missing camera permission in Info.plist

**Investigation**:
```xml
<!-- Check Info.plist for camera permissions -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to read BLP launch monitor data</string>
```

**Solution** (if missing):
Add to Info.plist:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to capture and process BLP launch monitor screen data for shot analysis.</string>
```

## Performance Monitoring Issues

### Issue 10: Excessive Logging Impact

**Problem**:
Debug builds with extensive logging show performance degradation

**Investigation**:
```c
// Original debug logging
#define DEBUG_LOG(format, ...) NSLog(@"[DEBUG] " format, ##__VA_ARGS__)

// Called frequently in processing loop
DEBUG_LOG(@"Processing frame %d", frameCount);  // 10 times per second
```

**Performance Impact**:
```
NSLog Performance Cost:
- File I/O for each log statement
- String formatting overhead
- Console output processing
- Estimated: 5-10ms per log at 10 FPS = 50-100ms/second
```

**Solution**:
Conditional performance logging:
```c
#define ENABLE_PERFORMANCE_LOGGING 1

#if ENABLE_PERFORMANCE_LOGGING
    #define PERF_LOG_START(op) NSLog(@"[PERF] Starting %s", #op)
    #define PERF_LOG_END(op) NSLog(@"[PERF] Finished %s", #op)
#else
    #define PERF_LOG_START(op)
    #define PERF_LOG_END(op)
#endif
```

## Memory Management Issues

### Issue 11: OpenCV Memory Leaks

**Problem**:
Memory usage increases over time during extended use

**Investigation**:
```cpp
// Potential leak in image processing
cv::Mat processedMat;
UIImageToMat(inputImage, processedMat);
// Mat not explicitly released in some code paths
```

**Solution**:
```cpp
// Proper RAII usage
cv::Mat processedMat;
{
    UIImageToMat(inputImage, processedMat);
    // Process image
    // Mat automatically cleaned up at scope end
}

// Or explicit cleanup for long-lived objects
processedMat.release();
```

**Prevention**:
- Use RAII principles for OpenCV objects
- Implement memory pressure monitoring
- Regular memory profiling during development

## Troubleshooting Methodology

### Systematic Approach

**1. Error Classification**:
```
Build Errors:
- Compilation failures → Check dependencies, headers
- Linking errors → Check frameworks, libraries
- Signing errors → Check certificates, bundle IDs

Runtime Errors:
- Crashes → Check logs, debugger
- Performance issues → Profile with Instruments
- Functionality issues → Step debugging, logging
```

**2. Investigation Tools**:
```bash
# Build issues
xcodebuild -project Project.xcodeproj -scheme Scheme clean build

# Dependency issues
otool -L BLM-recorder.app/BLM-recorder

# Signing issues
codesign -dv --verbose=4 BLM-recorder.app

# Runtime debugging
lldb BLM-recorder.app/BLM-recorder
```

**3. Documentation Process**:
```
For each issue:
1. Record exact error message
2. Document symptoms and context
3. Trace root cause analysis
4. Document solution steps
5. Add prevention strategy
6. Update troubleshooting guide
```

## Quick Reference Guide

### Common Build Fixes

```bash
# Clean build environment
xcodebuild clean
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Fix signing issues
killall SecurityAgent
killall codesign

# Update bundle identifier
# Xcode → Target → Signing & Capabilities → Bundle Identifier

# Verify framework dependencies
ls opencv-ios-framework/opencv2.framework/Headers/
```

### Common Runtime Fixes

```bash
# Check device trust
# iOS Settings → General → VPN & Device Management → Trust Profile

# Reset app permissions
# iOS Settings → Privacy & Security → Camera → BLM-recorder → Enable

# Clear app data (if needed)
# Delete and reinstall app
```

### Performance Debugging

```c
// Enable performance logging
#define ENABLE_PERFORMANCE_LOGGING 1

// Monitor memory usage
// Xcode → Product → Profile → Allocations

// Check CPU usage
// Xcode → Product → Profile → Time Profiler
```

## Prevention Strategies

### Development Environment

1. **Consistent Setup**:
   - Document all dependencies
   - Use version-specific frameworks
   - Maintain setup scripts

2. **Regular Maintenance**:
   - Clean derived data weekly
   - Update certificates before expiration
   - Monitor build warning trends

3. **Testing Practices**:
   - Test on clean devices
   - Verify permission flows
   - Performance test on target hardware

### Code Quality

1. **Memory Management**:
   - Use ARC for Objective-C objects
   - Proper RAII for C++ objects
   - Regular memory profiling

2. **Performance Monitoring**:
   - Conditional logging systems
   - Regular performance benchmarking
   - Automated performance regression testing

3. **Error Handling**:
   - Graceful degradation strategies
   - Comprehensive error logging
   - User-friendly error messages

## Conclusion

The build fixes and technical issues documented here represent the complete troubleshooting knowledge for BLM-recorder development. Key takeaways:

1. **Systematic Approach**: Document everything for future reference
2. **Root Cause Analysis**: Don't just fix symptoms, understand causes
3. **Prevention Focus**: Implement strategies to avoid recurring issues
4. **Performance Awareness**: Balance functionality with performance impact

This documentation serves as both a historical record and a practical guide for future development, ensuring that solved problems don't resurface and new developers can quickly resolve common issues.