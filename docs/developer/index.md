# Developer Guide

Guide for contributing to BirdNET Live development.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| **Framework** | Flutter 3.6.2+ / Dart ^3.6.2 |
| **State Management** | flutter_riverpod 2.6.1 |
| **Inference** | onnxruntime 1.4.1 (on-device ONNX) |
| **Location** | geolocator 13.0.2 |
| **Audio** | just_audio (playback), record (capture) |
| **Persistence** | shared_preferences |
| **Images** | cached_network_image 3.4.1 |

## Project Structure

```
lib/
  core/          # App-wide constants, services, themes
  shared/        # Shared models, providers, services
  features/      # Feature modules (screen + providers + widgets)
    live/        # Live identification mode
    explore/     # Species exploration by location
    inference/   # ONNX model wrappers (classifier, geo-model)
    audio/       # Audio capture, ring buffer, spectrogram
    settings/    # Settings screen
    home/        # Home screen / main menu
    history/     # Session review and library
    recording/   # Audio recording (WAV writer)
    spectrogram/ # FFT + color maps + painter
  l10n/          # ARB localization files (EN, DE)
```

## Getting Started

See the [Developer Getting Started](getting-started.md) guide for environment setup.

## Key Topics

- [Architecture](architecture.md) — Feature-based architecture and patterns
- [State Management](state-management.md) — Riverpod providers and notifiers
- [Audio Pipeline](audio-pipeline.md) — Capture, ring buffer, and processing
- [Inference Engine](inference-engine.md) — ONNX model loading and classification
- [Spectrogram](spectrogram.md) — FFT processing and rendering
- [Testing](testing.md) — Test strategy and running tests
- [Code Style](code-style.md) — Conventions and standards
