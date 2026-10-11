# Architecture

Application architecture and design patterns.

## Feature-Based Architecture

The codebase is organized by feature rather than by layer. Each feature module contains its own screen, providers, widgets, and services:

```
lib/features/
  live/              # Real-time identification pipeline + UI
  point_count/       # Timed point-count survey mode
  survey/            # Long-running transect survey mode (GPS, sampling, map)
  file_analysis/     # Offline file analysis wizard
  explore/           # Species exploration by location (geo-model)
  audio/             # Audio capture, ring buffer
  inference/         # ONNX model wrappers (classifier, geo-model)
  history/           # Session persistence, library, review, export
  settings/          # Settings screen (context-aware filtering)
  home/              # Home screen / main menu + help screen
  about/             # Credits, links, legal
  onboarding/        # Intro carousel + acceptable-use gate
  recording/         # WAV/FLAC writing (full + detection clips)
  spectrogram/       # FFT, color maps, CustomPainter
```

Shared utilities live under `lib/shared/` (models, providers, services) and `lib/core/` (constants, theme). Reusable widgets such as `ContentWidthConstraint` (600 dp max-width for tablet layouts) are in `lib/shared/widgets/`.

## Key Design Decisions

### On-Device Inference

All classification runs locally using ONNX Runtime, so no audio data ever leaves the device. The audio classifier (~152 MB) and geo-model (~6 MB) are resolved through `AssetPackService`: Play Store App Bundles read them from the install-time `models_pack` asset pack, while sideload APKs, iOS, Windows, and tests fall back to Flutter assets. The models are then extracted to an on-device file path so ONNX Runtime can memory-map them.

### Native Background Queue for Inference

`flutter_onnxruntime` runs native inference on a platform background queue. The historical `InferenceIsolate` class name is kept to avoid churn, but it now delegates to `InferenceService` on the root isolate and serializes calls into the native session.

### Android Foreground Services

Background operation on Android runs under one shared `ForegroundService`
(declared in `AndroidManifest.xml` with `microphone|location`), driven through
`flutter_foreground_task`. Only one mode owns it at a time, enforced by
`ForegroundServiceGuard`:

| Mode | Wrapper | Service ID | Declared types |
|------|---------|------------|----------------|
| Live Mode, Point Count | `AudioBackgroundNotificationService` | 384 | `microphone` |
| Survey | `SurveyNotificationService` | 256 | `microphone`, plus `location` only while the Survey tracks GPS and the location permission is granted |
| ARU | `AruNotificationService` | 512 | `microphone` |

Every wrapper passes its types explicitly. Android 14+ refuses to start a
service that declares `location` without a granted location permission, so
inheriting both manifest types would leave a Survey or ARU deployment without
its service whenever GPS is off or denied.

### Ring Buffer Audio Pipeline

Audio flows through a shared `RingBuffer`:

```
Microphone → PCM16 → Float32 → RingBuffer → { Spectrogram, Inference, Recording }
```

Multiple consumers read from the same buffer without copying the data.

### JSON-Driven Model Config

All model parameters (tensor names, sample rate, inference defaults, label format) come from `assets/models/model_config.json`. No model-specific values are hardcoded.

### Riverpod State Management

Providers bridge services to the widget tree. Settings use generic `StateNotifierProvider` types (`DoubleSettingNotifier`, `IntSettingNotifier`) backed by `SharedPreferences`.

## State Machine

The live identification pipeline follows a strict state machine:

```
idle → loading → ready → active ↔ paused → ready
                      ↘ error
```
