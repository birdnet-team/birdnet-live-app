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

All classification runs locally using ONNX Runtime, so no audio data ever leaves the device. The audio classifier (~152 MB) and geo-model (~6 MB) are resolved through `AssetPackService` to a file path ONNX Runtime can memory-map, without ever loading the model into the Dart heap: on Android the native `extractAsset` call streams the file out of the `AssetManager` namespace (the install-time `models_pack` asset pack on Play Store builds, `flutter_assets/` on sideload APKs) into `filesDir`; on iOS, macOS, Windows, and Linux the bundled `flutter_assets` file is used where it is. Only tests and an unexpected bundle layout fall back to `rootBundle.load()`, which copies through a temporary file so a crash mid-extraction can never leave a truncated model behind.

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

The service is `stopWithTask` and `START_NOT_STICKY`: when Android kills the
process (memory pressure, a crash, the user swiping the task away), nothing
restarts a Survey or an ARU deployment. Both checkpoint their session every
30 s (`SessionCheckpointWriter`, `AruController.checkpoint`), so the Session
Library shows the last snapshot as an ended Session; a Survey can be continued
from its review with **Continue Survey**, an ARU deployment cannot be resumed.
`AruNotificationRoute` decides from in-memory state only, so a notification tap
that arrives after process death lands on the library rather than on a
deployment that no longer exists. This is deliberate: restarting microphone
capture from the background is not permitted on Android 14+, and silently
resuming a deployment the user believes has stopped would be worse than
stopping it.

### Ring Buffer Audio Pipeline

Audio flows through a shared `RingBuffer`:

```
Microphone → PCM16 → Float32 → RingBuffer → { Spectrogram, Inference, Recording }
```

Multiple consumers read from the same buffer without copying the data.

### JSON-Driven Model Config

All model parameters (tensor names, sample rate, inference defaults, label format) come from `assets/models/model_config.json`. No model-specific values are hardcoded.

### Error Log

`ErrorLog` (`lib/core/services/error_log.dart`) hooks `FlutterError.onError`
and `PlatformDispatcher.instance.onError` at startup and appends every
uncaught error to `<app support>/logs/errors.log`, chaining to the previous
handlers so console output is unchanged. The file is capped at 256 KB (the
oldest entries are dropped), holds only timestamps, messages, and stack
traces, and never leaves the device. In release builds uncaught Dart errors
do not crash the app, so without this file a field report has nothing to go
on.

### Riverpod State Management

Providers bridge services to the widget tree. Settings use generic `StateNotifierProvider` types (`DoubleSettingNotifier`, `IntSettingNotifier`) backed by `SharedPreferences`.

## State Machine

The live identification pipeline follows a strict state machine:

```
idle → loading → ready → active ↔ paused → ready
                      ↘ error
```
