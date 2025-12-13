# Quick Reference - Startup Optimization

## Problem Fixed
Black screen delay on app launch (1-3 seconds before any UI appeared)

## Root Cause
- **524MB OpenCV framework** loading at OS level (unavoidable)
- DataModel blocking UI in viewDidLoad
- No visual feedback during loading

## Key Changes

### 1. Launch Screen
- **File**: `Base.lproj/LaunchScreen.storyboard`
- **Shows**: "BLM Recorder" title + "Loading..." text
- **Result**: Branded screen instead of black

### 2. Non-Blocking DataModel
- **Method**: `[DataModel sharedIfExists]` (returns nil if not initialized)
- **Usage**: Check in viewDidLoad to avoid blocking
```objc
DataModel *dm = [DataModel sharedIfExists];
if (dm) {
    // Safe to use
}
```

### 3. Deferred Initialization
- **File**: `AppDelegate.m`
- **Change**: DataModel initializes AFTER window is visible
- **Result**: UI appears immediately

## Performance

**Before:** 3-5s black screen → UI  
**After:** 0.5s launch screen → 1.5s UI → 4-6s fully loaded

## Viewing Logs

In Xcode console, filter by:
- `[STARTUP]` - App initialization steps
- `[MODEL LOADING]` - CoreML model loading

## Clearing Launch Screen Cache

```bash
# Method 1: Delete app from device and reinstall

# Method 2: Reset simulator
xcrun simctl erase all

# Method 3: Clean Xcode
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

## Future Optimization

**Reduce OpenCV size** from 524MB → 50-80MB:
- Build custom OpenCV with only required modules
- Expected: 2-2.5s faster launch time

## Key Files

| File | Purpose |
|------|---------|
| `AppDelegate.m` | Controls initialization order |
| `DataModel.m` | Deferred initialization, sharedIfExists |
| `LaunchMonitorDataViewController.m` | Non-blocking data access |
| `LaunchScreen.storyboard` | Visual feedback during load |
| `Info.plist` | Launch screen configuration |

## Common Issues

**Launch screen not showing?**
- Delete app completely and reinstall
- Check Info.plist has `UILaunchStoryboardName`

**UI still slow?**
- Check logs for `[STARTUP]` sequence
- Verify DataModel initializes async

**Models loading slowly?**
- Check `[MODEL LOADING]` time in logs
- Should be 2-5 seconds

## Documentation

- Full details: `doc/startup-optimization.md`
- Code changes: `doc/code-changes-summary.md`
- This file: `doc/quick-reference.md`
