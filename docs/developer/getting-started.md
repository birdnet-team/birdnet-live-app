# Developer Getting Started

Set up your development environment.

## Prerequisites

- **Flutter SDK** 3.6.2 or later
- **Dart SDK** ^3.6.2 (bundled with Flutter)
- **Android Studio** or **VS Code** with Flutter/Dart extensions
- **Git**

### Platform-Specific

- **Android**: Android SDK, NDK (for ONNX native libraries)
- **iOS**: Xcode 15+, CocoaPods
- **Windows**: Visual Studio 2022 with C++ desktop workload

## Setup

```bash
# Clone the repository
git clone https://github.com/birdnet-team/birdnet-live-app.git
cd birdnet-live-app

# Install dependencies
flutter pub get

# Verify setup
flutter doctor
```

## Running

```bash
# Run on connected device
flutter run

# Run with verbose logging
flutter run --verbose

# Run on a specific device
flutter devices          # List devices
flutter run -d <device>  # Target specific device
```

## Common Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Static analysis (zero warnings policy)
flutter test             # Run all unit tests
flutter gen-l10n         # Regenerate localization (auto on build)
flutter build apk        # Build Android APK
flutter build ios        # Build iOS (requires macOS)
```

## Model Assets

The ONNX model (~259 MB) is bundled in `assets/models/`. On first launch, it is extracted from the APK to the app's documents directory for direct file access by the inference isolate.
