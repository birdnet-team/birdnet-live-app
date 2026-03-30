# Building

Build instructions for Android, iOS, and Windows.

## Android

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

The release APK is at `build/app/outputs/flutter-apk/app-release.apk`.

## iOS

Requires macOS with Xcode 15+:

```bash
cd ios && pod install && cd ..
flutter build ios --release
```

Open `ios/Runner.xcworkspace` in Xcode for archive and distribution.

## Windows

Requires Visual Studio 2022 with C++ desktop workload:

```bash
flutter build windows --release
```

## Notes

- The ONNX model (~259 MB) is bundled as a Flutter asset. APK/IPA sizes will be large.
- ONNX Runtime native libraries are platform-specific and handled by the `onnxruntime` package.
