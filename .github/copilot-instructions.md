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
- **PrefKeys** in `core/constants/app_constants.dart` — all `SharedPreferences` key strings are centralised here.
- **Model config** is JSON-driven (`assets/models/model_config.json`). No model parameters are hardcoded.
- **ONNX inference** runs in a background isolate (audio classifier) or on the main thread (geo-model). Models are extracted from assets to disk on first launch.
- **Species filter** (`features/inference/species_filter.dart`) applies geographic or custom filtering to audio detections. Modes: off, geoExclude, geoMerge, customList.

## Models & Data

| Asset | Purpose | Size |
|-------|---------|------|
| `BirdNET+_V3.0-preview3_Global_11K_FP16.onnx` | Audio classifier (11,560 species) | ~259 MB |
| `BirdNET+_Geomodel_V3.0.1_Global_12K_FP16.onnx` | Location-based species prediction | ~7 MB |
| `labels.csv` | Audio classifier labels (comma-delimited) | |
| `BirdNET+_Geomodel_V3.0.1_Global_12K_Labels.txt` | Geo-model labels (tab-delimited: `id\tsci_name\tcom_name`) | |
| `taxonomy.csv` | Rich species metadata (13,968 species, comma-delimited with header) | |
| `model_config.json` | JSON config for both ONNX models | |

### Taxonomy API

Species images and descriptions come from `https://birdnet.cornell.edu/taxonomy/api/`:

- `GET /api/image/{sci_name}?size=thumb` — 150×100 WebP thumbnail (4:3)
- `GET /api/image/{sci_name}?size=medium` — 480×320 WebP image (4:3)
- `GET /api/species/{sci_name}` — Full species record (descriptions, Wikipedia, links)

## Coding Conventions

- **Localization**: All user-facing strings go in `lib/l10n/app_en.arb` (English) and `app_de.arb` (German). Use `l10n.keyName` in widgets.
- **Settings**: Add new settings via `PrefKeys` constant + provider in `settings_providers.dart` + UI in `settings_screen.dart` with `_sectionContexts` mapping.
- **File headers**: Each Dart file has a `// ===...` block comment explaining purpose, usage, and design rationale.
- **Tests**: Unit tests mirror the `lib/` structure under `test/`. Use `flutter test` to run.
- **No hardcoded values**: Model parameters, API URLs, and thresholds come from config or constants.

## Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Static analysis
flutter test             # Run unit tests
flutter gen-l10n         # Regenerate localisation (auto on build)
flutter run              # Run on connected device
```
