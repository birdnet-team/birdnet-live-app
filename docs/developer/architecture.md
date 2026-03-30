# Architecture

Application architecture and design patterns.

## Feature-Based Architecture

The codebase is organized by feature rather than by layer. Each feature module contains its own screen, providers, widgets, and services:

```
lib/features/live/
  live_controller.dart       # Business logic + state machine
  live_screen.dart           # UI (Scaffold, spectrogram, detection list)
  live_session.dart          # Data models (LiveSession, DetectionRecord)
  live_providers.dart        # Riverpod providers
  widgets/
    detection_list_widget.dart
```

## Key Design Decisions

### On-Device Inference

All classification runs locally using ONNX Runtime. No audio data leaves the device. The model file (~259 MB) is extracted from the APK asset bundle to disk on first launch, and the inference isolate loads it by file path to avoid serializing large byte arrays.

### Background Isolate for Inference

ONNX inference runs in a dedicated Dart isolate (`InferenceIsolate`) to keep the UI responsive. Communication uses typed messages via `SendPort` / `ReceivePort`.

### Ring Buffer Audio Pipeline

Audio flows through a shared `RingBuffer`:

```
Microphone → PCM16 → Float32 → RingBuffer → { Spectrogram, Inference, Recording }
```

Multiple consumers read from the same buffer without copies.

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
