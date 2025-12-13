# BLM-recorder

An iOS app for the Bushnell Launch Pro (BLP) golf launch monitor that provides real-time OCR processing, unified data display, mini-games, and GSPro integration.

## Features

- **Unified Data Display**: Ball and club data on one screen
- **Mini-Game Mode**: Score shots based on proximity to targets
- **Estimated Metrics**: Total distance, offline distance, apex height
- **GSPro Integration**: Real-time data sharing via OpenConnect
- **Optimized Performance**: 60-70% reduced CPU usage for better battery life

## Installation

### Requirements

- macOS with Xcode
- iPhone (tested on iPhone 15 Pro)
- [3D printed phone mount](https://makerworld.com/en/models/1300907-bushnell-launch-pro-blm-recorder-iphone-holder#profileId-1333225) (recommended)

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

1. Mount your iPhone on the BLP using the 3D printed holder
2. Launch the app
3. Take a shot - data appears automatically

## Usage

- **Data Page**: View last shot's ball and club data, start mini-games
- **Screens Page**: See captured BLP screen images
- **Camera Page**: Live view with detection debugging (green box = detected)
- **Settings Page**: Adjust fairway/green speeds, configure GSPro IP

## Documentation

For detailed information, see the [`/doc`](./doc) folder:
- **[Architecture](./doc/architecture.md)**: Technical design and ML models
- **[Performance](./doc/performance-optimization.md)**: Optimization details and configuration
- **[Build Issues](./doc/build-troubleshooting.md)**: Troubleshooting guide
- **[Project History](./doc/project-history.md)**: Development timeline and decisions

## Known Limitations

- iPhone 15 Pro only (not tested on other models)
- Requires default BLP settings: MPH, yards, spin axis/rate
- May not work in bright outdoor sunlight
- 3D printed mount strongly recommended for best OCR accuracy

## Technical Details

- **Language**: Objective-C with OpenCV
- **Frameworks**: Vision (OCR), CoreML (7 classification + 3 physics models), AVFoundation
- **Processing**: 10 FPS optimized OCR rate
- **Performance**: 60-70% CPU reduction vs original implementation

## License

See [LICENSE](./LICENSE) file.
