<!-- TRANSLATION TODO (it) -->

# Developer Getting Started

Set up your development environment.

## Prerequisites

- **Flutter SDK** 3.27 or later, with **Dart 3.7** or later
- **Git** and **Git LFS** for the large ONNX model files
- **Android Studio** or **VS Code** with Flutter/Dart extensions

### Platform-Specific

- **Android**: Android SDK, NDK (for ONNX native libraries)
- **iOS**: Xcode 15+, CocoaPods
- **Windows**: Visual Studio 2022 with C++ desktop workload

## Setup

```bash
# Clone the repository
git clone https://github.com/birdnet-team/birdnet-live-app.git
cd birdnet-live-app

# Pull the real ONNX model files tracked by Git LFS
git lfs install
git lfs pull

# Install Flutter dependencies and generate localizations
flutter pub get
flutter gen-l10n

# Verify setup
flutter doctor
```

Do not skip the LFS step on a fresh clone. The `.onnx` files in `assets/models/` are required at runtime; Git LFS pointer files can let a build start but model loading will fail when the app tries to initialize inference.

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
flutter analyze --no-pub # Static analysis after dependencies are installed
flutter test             # Run all unit tests
flutter gen-l10n         # Regenerate localization (auto on build)
flutter build apk --debug # Build Android debug APK
flutter build ios        # Build iOS (requires macOS)
```

## Model Assets

BirdNET Live ships two ONNX models in `assets/models/`: the BirdNET+ audio classifier (~152 MB) and the BirdNET geo-model (~6 MB). Both are tracked with Git LFS and are bundled with local builds after `git lfs pull`.

You only need the Python model build pipeline in `dev/` when updating or rebuilding the models themselves. Normal app development uses the checked-in LFS model artifacts.
