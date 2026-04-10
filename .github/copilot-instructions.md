# BirdNET Live — Copilot Instructions

## Project Overview

BirdNET Live is a Flutter mobile app (Android/iOS/Windows) for real-time bird species identification using on-device ONNX inference. It detects bird calls from microphone audio and shows results alongside a live spectrogram.

## Tech Stack

- **Flutter 3.6.2+** / **Dart ^3.6.2**
- **flutter_riverpod 2.6.1** — state management (providers, StateNotifier)
- **onnxruntime 1.4.1** — on-device ONNX model inference (audio classifier + geo-model)
- **geolocator 13.0.2** — GPS location
- **cached_network_image 3.4.1** — species image caching
- **just_audio** — audio playback
- **shared_preferences** — settings persistence

## Architecture

Feature-based architecture under `lib/`:

```
lib/
  core/          # App-wide constants, services, themes
  shared/        # Shared models, providers, services (not feature-specific)
  features/      # Feature modules (each with screen, providers, widgets)
    live/        # Live identification mode
    explore/     # Species exploration by location
    inference/   # ONNX model wrappers (classifier, geo-model)
    audio/       # Audio capture, ring buffer, spectrogram
    settings/    # Settings screen
    home/        # Home screen / main menu
    ...
  l10n/          # ARB localization files (EN, DE)
```

### Key Patterns

- **Riverpod providers** connect services to UI. Settings use generic `StateNotifierProvider` (DoubleSettingNotifier, IntSettingNotifier, etc.) backed by `SharedPreferences`.
- **PrefKeys** in `core/constants/app_constants.dart` — all `SharedPreferences` key strings are centralized here.
- **Model config** is JSON-driven (`assets/models/model_config.json`). No model parameters are hardcoded.
- **ONNX inference** runs in a background isolate (audio classifier) or on the main thread (geo-model). Models are extracted from assets to disk on first launch.
- **Species filter** (`features/inference/species_filter.dart`) applies geographic or custom filtering to audio detections. Modes: off, geoExclude, geoMerge, customList.

## Models & Data

| Asset | Purpose | Size |
|-------|---------|------|
| `BirdNET+_V3.0-preview3_Global_5K-pruned_FP16.onnx` | Audio classifier (5,250 species, pruned) | ~152 MB |
| `BirdNET+_Geomodel_V3.0.1_Global_5K-pruned_FP16.onnx` | Location-based species prediction | ~6 MB |
| `labels.csv` | Audio classifier labels (semicolon-delimited, UTF-8 BOM) | |
| `BirdNET+_Geomodel_V3.0.1_Global_5K-pruned_Labels.txt` | Geo-model labels (tab-delimited: `id\tsci_name\tcom_name`) | |
| `taxonomy.csv` | Rich species metadata (comma-delimited with header) | |
| `model_config.json` | JSON config for both ONNX models | |

### Model Build Pipeline

The `.onnx` files in `assets/models/` are **not checked in** (gitignored). They are built from raw source models in `dev/models/` using a Python pipeline:

```bash
python dev/build_models.py          # prune species + fix for ARM64 ORT 1.15
```

This runs three steps: (1) prune to 5,250-species intersection, (2) fix audio model for ARM64 FP16 precision & ORT 1.15 opset compatibility, (3) decompose geo model LayerNorm. See **`dev/MODELS.md`** for full details on what each script does and why.

**Key constraint**: Android ORT 1.15.1 (`flutter_onnxruntime 1.4.1`) uses native FP16 NEON on ARM64, causing precision loss in deep CNNs. The audio model stores weights as FP16 but runs all compute in FP32 via inserted Cast nodes.

### Taxonomy API

Species images and descriptions come from `https://birdnet.cornell.edu/taxonomy/api/`:

- `GET /api/image/{sci_name}?size=thumb` — 150×100 WebP thumbnail (4:3)
- `GET /api/image/{sci_name}?size=medium` — 480×320 WebP image (4:3)
- `GET /api/species/{sci_name}` — Full species record (descriptions, Wikipedia, links)

## Coding Conventions

- **American English**: All code, comments, documentation, and user-facing strings must use American English spelling (e.g., "color" not "colour", "initialize" not "initialise", "behavior" not "behaviour", "analyze" not "analyse", "center" not "centre", "serialize" not "serialise").
- **Localization**: All user-facing strings go in `lib/l10n/app_en.arb` (English) and `app_de.arb` (German). Use `l10n.keyName` in widgets.
- **Settings**: Add new settings via `PrefKeys` constant + provider in `settings_providers.dart` + UI in `settings_screen.dart` with `_sectionContexts` mapping.
- **File headers**: Each Dart file has a `// ===...` block comment explaining purpose, usage, and design rationale.
- **Tests**: Unit tests mirror the `lib/` structure under `test/`. Use `flutter test` to run.
- **No hardcoded values**: Model parameters, API URLs, and thresholds come from config or constants.
- **Version bumping**: Bump the patch version in `pubspec.yaml` (e.g. `0.1.24` → `0.1.25`) with each user-facing change set. The build number tracks the patch number (e.g. `0.1.25+25`).

## Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Static analysis
flutter test             # Run unit tests
flutter gen-l10n         # Regenerate localization (auto on build)
flutter run              # Run on connected device
flutter build apk --release   # Release APK (~185 MB)
flutter build appbundle       # Android App Bundle (preferred for Play Store)
```

### Release Build Notes

- **Release APK is ~185 MB** (vs ~420 MB debug). The audio ONNX model (145 MB, stored uncompressed for memory-mapping) accounts for ~78%.
- **ABI filter**: Only `arm64-v8a` is included (`android/app/build.gradle`). No 32-bit ARM or x86 native libs are shipped.
- **R8 shrink + minify** is enabled for release builds. ProGuard rules in `android/app/proguard-rules.pro` keep ONNX Runtime JNI bindings.
- **Test fixtures** (`assets/test_fixtures/`) are **not bundled** in the APK. For integration tests, push them to the device first:
  ```bash
  adb push assets/test_fixtures /data/local/tmp/test_fixtures
  flutter test integration_test/geo_soundscape_test.dart -d <device_id>
  ```
- **App Bundle**: Use `flutter build appbundle` for Play Store — delivers only the user's architecture, reducing download size further.
