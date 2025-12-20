# Snow Edge AI - Flutter (Offline TTS)

> **Status**: 🚧 Under Active Development

Truly offline text-to-speech application powered by ONNX Runtime and the official Supertonic TTS models. This Flutter app runs AI inference entirely on-device with zero internet dependency.

## 🎯 Features

- ✅ **100% Offline**: All AI models bundled in the app
- ✅ **Cross-Platform**: iOS, Android, macOS, Windows, Linux
- ✅ **Premium UI**: Modern light theme with Snow Edge branding
- ✅ **Multiple Voices**: Male (M1, M2) and Female (F1, F2) voice options
- ✅ **Quality Controls**: Adjustable generation steps and speed
- ✅ **Real-time Playback**: Integrated audio player

## 📱 Platform Status

| Platform | Status | Notes |
|----------|--------|-------|
| **macOS** | ✅ Working | Fully functional, tested on macOS 26.1 |
| **Android** | ✅ Built | APK ready (347.5 MB), requires testing on device |
| **iOS** | ⚠️ Known Issue | Crashes due to memory limit (see below) |
| **Windows** | 🚧 Not Tested | Should work with flutter_onnxruntime |
| **Linux** | 🚧 Not Tested | Should work with flutter_onnxruntime |

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.38.3 or higher
- Xcode 16.4+ (for iOS/macOS)
- Android Studio with SDK 36+ (for Android)
- ONNX models (see Setup)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/franckoj/snowedge_ai.git
   cd snowedge_ai/flutter
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up ONNX models**
   
   The app requires ONNX models in `assets/`. Due to size (~350MB), they're excluded from git.
   
   **Option A**: Download from [Supertonic Repository](https://github.com/supertone-inc/supertonic)
   
   **Option B**: Symlink to backend assets
   ```bash
   ln -s ../backend/assets assets
   ```

4. **Run the app**
   
   #### Quick Start Commands
   
   **iOS**
   ```bash
   flutter run -d ios
   ```
   
   **Android**
   ```bash
   flutter run -d android
   ```
   
   **macOS**
   ```bash
   flutter run -d macos
   ```
   
   *For specific devices, use `flutter devices` to find the device ID.*
   
   **Full Platform Commands:**
   ```bash
   # macOS
   flutter run -d macos
   
   # iOS (requires code signing)
   flutter run -d <device-id>
   
   # Android
   flutter run -d <device-id>
   ```

## 🛠️ Building

### macOS
```bash
flutter build macos --release
```
Output: `build/macos/Build/Products/Release/flutter_sdk.app`

### Android APK
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk` (347.5 MB)

### iOS
```bash
flutter build ios --release
```
Requires Apple Developer account and code signing.

## ⚙️ Configuration

### iOS Requirements
- **Minimum iOS Version**: 16.0 (required by `flutter_onnxruntime`)
- **Code Signing**: Update `PRODUCT_BUNDLE_IDENTIFIER` in Xcode
- **Permissions**: Background audio mode enabled in `Info.plist`

### Android Requirements
- **Minimum SDK**: API 36
- **Permissions**: Internet, storage (declared in `AndroidManifest.xml`)

## ⚠️ Known Issues

### iOS Memory Crash
**Problem**: App crashes with `EXC_RESOURCE (RESOURCE_TYPE_MEMORY)` on iPhone

**Cause**: Loading all ONNX models (~350MB × 4) exceeds iOS memory limit (3.4 GB)

**Workarounds**:
1. **Lazy Loading** (recommended): Load models on-demand instead of at startup
2. **Model Quantization**: Use INT8 quantized models (smaller footprint)
3. **Single Model**: Only load one voice variant at a time

### Android Emulator
- First installation may be slow due to large APK size
- Requires emulator with sufficient RAM (8GB+ recommended)

## 📂 Project Structure

```
lib/
├── main.dart                 # App entry point
├── theme/
│   └── app_theme.dart        # Snow Edge design system
├── screens/
│   ├── home_screen.dart      # Landing page with feature cards
│   └── tts_screen.dart       # TTS generation interface
└── widgets/
    ├── feature_card.dart     # Home screen components
    ├── voice_selector.dart   # Male/Female voice toggle
    ├── quality_slider.dart   # Steps/Speed sliders
    ├── generate_button.dart  # Primary action button
    └── audio_player_widget.dart  # Playback controls

assets/
├── onnx/                     # ONNX AI models (gitignored)
│   ├── text_encoder.onnx
│   ├── duration_predictor.onnx
│   ├── vector_estimator.onnx
│   └── vocoder.onnx
└── voice_styles/             # Voice style JSON files
    ├── F1.json
    ├── F2.json
    ├── M1.json
    └── M2.json
```

## 🧰 Dependencies

- **flutter_onnxruntime**: Official Supertonic ONNX runtime
- **just_audio**: Cross-platform audio playback
- **path_provider**: File system access
- **logger**: Debugging and logging

## 🎨 Design System

**Theme**: Light mode with white, grey, and yellow accent

**Typography**: System fonts (.SF Pro Text on iOS/macOS)

**Components**: Material 3 with custom styling

## 🔧 Development

### Adding New Voice Styles
1. Add JSON file to `assets/voice_styles/`
2. Update `pubspec.yaml` assets section
3. Modify `VoiceSelector` widget to include new option

### Debugging
```bash
# Run with verbose logging
flutter run -d macos -v

# Hot reload during development
# Press 'r' in terminal
```

## 📝 License

Copyright © 2025 Francis Joseph. All rights reserved.

## 🤝 Contributing

This is a personal project under active development. Contributions welcome after initial release.

## 📞 Support

For issues or questions about the Snow Edge AI Flutter app, please file an issue on GitHub.

---

**Note**: This app uses the official [Supertonic](https://github.com/supertone-inc/supertonic) TTS models by Supertone Inc. ONNX models must be obtained separately and are not included in this repository due to size constraints.
# snow_edgeai
# snow_edgeai
# snow_edgeai
# snow_edgeai
# snow_edgeai
