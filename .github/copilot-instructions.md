# BirdNET Live — Copilot Instructions

## Project Overview

BirdNET Live is a Flutter mobile app (Android/iOS/Windows) for real-time species identification using on-device ONNX inference. It detects bird and other animal calls from microphone audio and shows results alongside a live spectrogram. Modes include Live, Point Count, Survey (GPS transect), and File Analysis.

## Tech Stack

- **Flutter 3.27+** / **Dart ^3.7.0**
- **flutter_riverpod 3.3.1** — state management (providers, StateNotifier)
- **flutter_onnxruntime 1.7.0** — on-device ONNX model inference (audio classifier + geo-model)
- **geolocator 14.0.2** — GPS location
- **flutter_cache_manager 3.4.1** — image and tile cache management
- **just_audio** — audio playback
- **shared_preferences** — settings persistence

## Architecture

Feature-based architecture under `lib/`:

```
lib/
  core/          # App-wide constants, services, themes
  shared/        # Shared models, providers, services, widgets (not feature-specific)
  features/      # Feature modules (each with screen, providers, widgets)
    live/        # Live identification mode
    point_count/ # Timed point-count survey mode
    survey/      # Long-running transect survey mode
    explore/     # Species exploration by location
    inference/   # ONNX model wrappers (classifier, geo-model)
    audio/       # Audio capture, ring buffer, spectrogram
    file_analysis/ # Offline file analysis wizard
    history/     # Session persistence, library, review, export
    settings/    # Settings screen
    home/        # Home screen / main menu
    about/       # Credits, links, legal
  l10n/          # ARB localization files (en, de, cs, es, fr, it, pt)
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
| `BirdNET+_V3.0-preview3_Global_5K-pruned_Labels.csv` | Audio classifier labels (semicolon-delimited, UTF-8 BOM) | |
| `BirdNET+_Geomodel_V3.0.1_Global_5K-pruned_Labels.txt` | Geo-model labels (tab-delimited: `id\tsci_name\tcom_name`) | |
| `taxonomy.csv` | Rich species metadata (comma-delimited with header) | |
| `model_config.json` | JSON config for both ONNX models | |

### Model Build Pipeline

The `.onnx` files in `assets/models/` are tracked with Git LFS. On a fresh clone, run `git lfs install` and `git lfs pull` before building or running the app; pointer files may let compilation start but model loading will fail at runtime. The Python pipeline in `dev/` is only needed when updating or rebuilding the model artifacts:

```bash
python dev/build_models.py          # prune species + apply compatibility fixes
```

This runs three steps: (1) prune to the 5,250-species intersection, (2) fix audio model precision/opset compatibility, (3) decompose geo-model LayerNorm. See **`dev/MODELS.md`** for full details on what each script does and why.

**Key constraint**: Mobile ONNX Runtime builds and ARM64 FP16 behavior can differ from desktop reference runs. The audio model stores weights as FP16 but runs sensitive compute in FP32 via inserted Cast nodes to keep mobile results stable.

### Taxonomy API

Species images and descriptions come from `https://birdnet.cornell.edu/taxonomy/api/`:

- `GET /api/image/{sci_name}?size=thumb` — 150×100 WebP thumbnail (3:2)
- `GET /api/image/{sci_name}?size=medium` — 480×320 WebP image (3:2)
- `GET /api/species/{sci_name}` — Full species record (descriptions, Wikipedia, links)

## Coding Conventions

- **American English**: All code, comments, documentation, and user-facing strings must use American English spelling (e.g., "color" not "colour", "initialize" not "initialise", "behavior" not "behaviour", "analyze" not "analyse", "center" not "centre", "serialize" not "serialise").
- **Localization**: All user-facing strings go in all seven UI locale files: `app_en.arb`, `app_de.arb`, `app_cs.arb`, `app_es.arb`, `app_fr.arb`, `app_it.arb`, and `app_pt.arb`. Use `l10n.keyName` in widgets. Technical terms (Point Count, Survey, Session, Live Mode) and format identifiers (WAV, FLAC, CSV, JSON, GPX) stay in English in all locales.
- **Responsive layouts**: Screens support portrait and landscape orientations. Tablet screens use `ContentWidthConstraint` (600 dp max-width) from `shared/widgets/`.
- **Settings**: Add new settings via `PrefKeys` constant + provider in `settings_providers.dart` + UI in `settings_screen.dart` with `_sectionContexts` mapping. When adding or modifying settings, always update the user guide at `docs/user/settings.md` to explain the *intuition* behind the new setting so users understand *why* they might change it.
- **Icons**: Use `AppIcons` (`lib/shared/utils/app_icons.dart`) in feature/shared UI code instead of direct `Symbols.*` or `Icons.*`. Prefer neutral/base icon names for single-style constants; keep `...Outlined`/`...Rounded` names only when style distinction is intentional and both variants are part of the API.
- **File headers**: Each Dart file has a `// ===...` block comment explaining purpose, usage, and design rationale.
- **Tests**: Unit tests mirror the `lib/` structure under `test/`. Use `flutter test` to run.
- **No hardcoded values**: Model parameters, API URLs, and thresholds come from config or constants.
- **Version bumping**: `pubspec.yaml` is the **single source of truth** for the app version. Bump the patch version there (e.g. `0.1.27+27` → `0.1.28+28`) with each user-facing change set, then run `dart dev/sync_version.dart` to propagate the version to the README badge and any other files. The build number tracks the patch number.
- **Git commits**: Use one-line commit messages. Group related changes into logical commits (e.g., one commit per feature, one for refactors/extractions, one for version bumps + docs). Don't lump unrelated changes into a single commit.

## Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Static analysis
flutter test             # Run unit tests
flutter gen-l10n         # Regenerate localization (auto on build)
dart dev/sync_version.dart    # Propagate pubspec version to README and MkDocs badges
flutter run              # Run on connected device
flutter build apk --release   # Release APK (~253 MB)
flutter build appbundle       # Android App Bundle (preferred for Play Store)
```

### Release Build Notes

- **Release APK is ~253 MB** (App Bundle ~221 MB). The audio ONNX model (~152 MB, stored uncompressed for memory-mapping) plus bundled species images (~60 MB, 5,241 photos at 360×240 WebP, 3:2) and description data (~3 MB) account for most of the size.
- **ABI filter**: Only `arm64-v8a` is included (`android/app/build.gradle`). No 32-bit ARM or x86 native libs are shipped.
- **R8 shrink + minify** is enabled for release builds. ProGuard rules in `android/app/proguard-rules.pro` keep ONNX Runtime JNI bindings.
- **Play release notes**: Keep `release/V<version>/release_notes.txt` short, high-level, and user-facing. Cover the delta since the last Play Store release with clear bullets, avoid implementation details or changelog-style prose, and keep each locale block under Play's 500-character limit.
- **Test fixtures** (`assets/test_fixtures/`) are **not bundled** in the APK. For integration tests, push them to the device first:
  ```bash
  adb push assets/test_fixtures /data/local/tmp/test_fixtures
  flutter test integration_test/geo_soundscape_test.dart -d <device_id>
  ```
- **App Bundle**: Use `flutter build appbundle` for Play Store — `.onnx` files are shipped through the install-time `models_pack` asset pack so the base module stays under Play's size limit while the installed app remains offline-capable.
