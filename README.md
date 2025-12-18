# BLM-recorder

An iOS app for the Bushnell Launch Pro golf launch monitor that provides real-time OCR processing, unified data display, mini-games, and GSPro integration.

## Features

- **Unified Data Display**: Ball and club data on one screen
- **Mini-Game Mode**: Score shots based on proximity to targets
- **Estimated Metrics**: Total distance, offline distance, apex height
- **GSPro Integration**: Real-time data sharing via OpenConnect
- **Optimized Performance**: 60-70% reduced CPU usage for better battery life

## Installation

### Requirements

- macOS with Xcode
- iPhone (tested and working on: iPhone 15 Pro, iPhone 16, iPhone 16 Plus, iPhone 17 Pro Max)
- Phone mount (recommended for best OCR accuracy)

### Setup

1. **Clone or download this repository**

2. **Install OpenCV Framework** (~524MB, not included in repo)

   ```bash
   cd BLM-recorder
   curl -L https://github.com/opencv/opencv/releases/download/4.8.0/opencv-4.8.0-ios-framework.zip -o opencv.zip
   unzip opencv.zip
   mkdir -p opencv-ios-framework
   mv opencv2.framework opencv-ios-framework/
   rm opencv.zip
   ```

   Verify:
   ```bash
   ls opencv-ios-framework/opencv2.framework/
   # Should show: Headers  Info.plist  Modules  opencv2
   ```

3. **Open in Xcode**
   - Open `BLM-recorder.xcodeproj`
   - Connect your iPhone
   - Select your device in the top bar

4. **Configure Signing**
   - Go to "Signing & Capabilities"
   - Select your Apple ID
   - Change Bundle Identifier to something unique (e.g., `com.yourname.blm-recorder`)

5. **Build and Run**
   - Press ▶️ to build and install
   - On first run: **Settings → General → VPN & Device Management** → Trust your developer profile

## Quick Start

1. Mount your iPhone on the launch monitor
2. Launch the app
3. Take a shot - data appears automatically

## Usage

- **Play Page**: View last shot's ball and club data, start mini-games
- **Monitor Page**: See captured launch monitor screen images
- **Settings Page**: Configure golf settings (fairway condition, green speed), GSPro IP, and Redis (optional)

## Documentation

For detailed information, see the [`/doc`](./doc) folder:
- **[Development History](./doc/development-history.md)**: Latest updates, changelog, and project timeline
- **[Technical Reference](./doc/technical-reference.md)**: Architecture, design patterns, and visual diagrams
- **[Performance](./doc/performance.md)**: Optimization details and configuration
- **[Troubleshooting](./doc/troubleshooting.md)**: Build issues, failed attempts, and quick reference

## Known Limitations

- Compatible with most newer iPhones (tested on iPhone 15 Pro, 16, 16 Plus, 17 Pro Max)
- Requires default launch monitor display settings (MPH for speed, yards for distance)
- May not work in bright outdoor sunlight
- Phone mount recommended for stable positioning and best OCR accuracy

## Technical Details

- **Language**: Objective-C with OpenCV
- **Frameworks**: Vision (OCR), CoreML (6 classification + 3 physics models), AVFoundation
- **Processing**: 10 FPS optimized OCR rate
- **Performance**: 60-70% CPU reduction vs original implementation

## License

See [LICENSE](./LICENSE) file.
