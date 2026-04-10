# BirdNET Live

<p align="center">
  <img src="assets/images/logo-birdnet-circle.png" alt="BirdNET Live" width="250">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/flutter-%3E%3D3.0-blue.svg" alt="Flutter">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
  <img src="https://img.shields.io/badge/version-0.1.0--dev-orange.svg" alt="Version">
</p>

A Flutter app for on-device acoustic species identification using ONNX inference. Runs on Android, iOS, and Windows.

<p align="center">
  <img src="docs/assets/screenshots/live-mode.png" alt="Live Mode" width="150">
  <img src="docs/assets/screenshots/session-review.png" alt="Session Review" width="150">
  <img src="docs/assets/screenshots/explore.png" alt="Explore" width="150">
</p>

**NOTE: This is an early developer preview. The app is not yet feature-complete or fully polished. Expect bugs, crashes, and rough edges. Please report issues and contribute if you can!**

---

## Features

- **Live Mode** — Real-time scrolling spectrogram with species identification
- **Explore** — Browse species expected at your location using the geo-model
- **Session Library** — Review, edit, and export past sessions with audio playback
- **Export** — Raven Pro, CSV, JSON, and ZIP bundle formats
- **On-device inference** — BirdNET+ model (5,250 species), no internet required
- **FLAC recording** — Pure Dart encoder for compressed audio (50–60% reduction)
- **Survey Mode** — Background monitoring with GPS tracking *(planned)*
- **Point Count Mode** — Timed surveys with recording *(planned)*
- **File Analysis Mode** — Analyze existing audio files *(planned)*

## Quick Start

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>= 3.0)
- [Android Studio](https://developer.android.com/studio) (for Android SDK & emulator)
- Xcode (macOS only, for iOS development)

### Setup

```bash
git clone https://github.com/birdnet-team/birdnet-live-app.git
cd birdnet-live-app
flutter pub get
flutter gen-l10n
```

### Verify

```bash
flutter doctor    # Check Flutter setup
flutter test      # Run tests
flutter analyze   # Check for issues
```

## Deploy to Phone

### Android (USB — Windows / macOS / Linux)

1. **Enable Developer Options** on your phone: Settings → About phone → tap "Build number" 7 times.
2. **Enable USB debugging**: Settings → Developer options → USB debugging → On.
3. **Connect** phone via USB and accept the debugging prompt.
4. **Check** Flutter sees the device:
   ```bash
   flutter devices
   ```
5. **Run** (debug mode with hot reload):
   ```bash
   flutter run
   ```
   Or press `F5` in VS Code with the Flutter extension installed.

6. **Build release APK** (optional):
   ```bash
   flutter build apk --release
   ```
   The APK will be at `build/app/outputs/flutter-apk/app-release.apk`. Transfer it to your phone and install.

### Android (Wireless — Windows)

1. Complete steps 1–3 above (USB debugging on, phone connected via USB).
2. **Pair** over Wi-Fi (Android 11+):
   ```bash
   # On the phone: Developer options → Wireless debugging → Pair device with pairing code
   # Note the IP:port and pairing code shown
   adb pair <ip>:<port>
   # Enter the pairing code when prompted
   ```
3. **Connect** wirelessly:
   ```bash
   adb connect <ip>:<port>
   # Use the port shown under "Wireless debugging" (not the pairing port)
   ```
4. **Unplug** the USB cable. Run as usual:
   ```bash
   flutter run
   ```

### iOS (macOS only)

1. **Connect** iPhone via USB.
2. **Trust** the computer on the phone when prompted.
3. **Open** `ios/Runner.xcworkspace` in Xcode and set your signing team under Signing & Capabilities.
4. **Run**:
   ```bash
   flutter run
   ```
   Or press `F5` in VS Code.

### VS Code Tips

- Install the **Flutter** and **Dart** extensions.
- Select your target device in the status bar (bottom-right).
- `F5` to launch with debugger attached.
- `Ctrl+F5` to launch without debugger (faster startup).
- Use the hot reload button (⚡) or `r` in the terminal for quick iterations.
- `R` in the terminal for hot restart (resets state).

## Documentation

- **User & Developer Docs**: [GitHub Pages](https://birdnet-team.github.io/birdnet-live-app/) (MkDocs Material)

To preview the documentation locally:

```bash
pip install mkdocs-material
mkdocs serve # python -m mkdocs serve on Windows
```

Then open [http://127.0.0.1:8000](http://127.0.0.1:8000) in your browser.

## Project Structure

```
lib/
  core/           # Constants, theme, utilities, extensions
  features/       # Feature modules (audio, inference, spectrogram, live, survey, ...)
  l10n/           # Localization ARB files (en, de)
  shared/         # Providers, models, services, reusable widgets

docs/             # MkDocs source for GitHub Pages documentation
assets/           # App assets (models, species data, images, fonts)
test/             # Tests mirroring lib/ structure
```

## Development

```bash
flutter run          # Run with hot reload
flutter test         # Run tests
flutter analyze      # Static analysis
dart format .        # Format code
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

- **Source Code**: The source code for this project is licensed under the [MIT License](https://opensource.org/licenses/MIT).
- **Models**: The models used in this project are licensed under the [Creative Commons Attribution-ShareAlike 4.0 International License (CC BY-SA 4.0)](https://creativecommons.org/licenses/by-sa/4.0/).

Please ensure you review and adhere to the specific license terms provided with each model.

## Terms of Use

Please refer to the [TERMS OF USE](TERMS_OF_USE.md) file for detailed terms and conditions regarding the use of the BirdNET+ V3.0 developer preview models.

## Funding

Our work in the K. Lisa Yang Center for Conservation Bioacoustics is made possible by the generosity of K. Lisa Yang to advance innovative conservation technologies to inspire and inform the conservation of wildlife and habitats.

The development of BirdNET is supported by the German Federal Ministry of Research, Technology and Space (FKZ 01|S22072), the German Federal Ministry for the Environment, Climate Action, Nature Conservation and Nuclear Safety (FKZ 67KI31040E), the German Federal Ministry of Economic Affairs and Energy (FKZ 16KN095550), the Deutsche Bundesstiftung Umwelt (project 39263/01) and the European Social Fund.

## Partners

BirdNET is a joint effort of partners from academia and industry.
Without these partnerships, this project would not have been possible.
Thank you!

![Our partners](https://tuc.cloud/index.php/s/KSdWfX5CnSRpRgQ/download/box_logos.png)