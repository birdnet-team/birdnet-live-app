<!-- TRANSLATION TODO (fr) -->

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
It is self-contained for sideloading and includes the ONNX models in `flutter_assets`.

For Play Store releases, use the app bundle. The `.onnx` files are moved into the install-time `models_pack` asset pack during AAB builds so the base module stays below Google Play's size limit while the installed app still works offline.

The local release helper wraps the Play Store build and copies the AAB, mapping file, symbols, and release-note stubs into `release/<version>/`:

```bash
dart dev/build_release.dart
```

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

- The two ONNX models are tracked with Git LFS. Run `git lfs pull` before building from a fresh clone.
- APK builds keep the models in `flutter_assets`; AAB builds ship them via the install-time `models_pack` asset pack.
- ONNX Runtime native libraries are platform-specific and handled by the `flutter_onnxruntime` package.
