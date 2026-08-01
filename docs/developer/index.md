# Developer Guide

A guide for contributing to BirdNET Live.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| **Framework** | Flutter 3.27+ / Dart 3.7+ |
| **State Management** | flutter_riverpod 3.4.2+ |
| **Inference** | flutter_onnxruntime 1.7.1, pinned (on-device ONNX) — see [ONNX Runtime Pin](onnxruntime-pin.md) |
| **Location** | geolocator 14.0.2 |
| **Audio** | record, just_audio, fftea, flutter_tts |
| **Persistence** | shared_preferences, JSON session files |
| **Maps & Context** | flutter_map, OpenStreetMap tiles, Nominatim, Open-Meteo |
| **Images & Species Data** | bundled species images/data, http, flutter_cache_manager |

## Project Structure

```
lib/
  core/          # App-wide constants, services, themes
  shared/        # Shared models, providers, services, widgets
  features/      # Feature modules (screen + providers + widgets)
    live/        # Live identification mode
    point_count/ # Timed point-count survey mode
    survey/      # Long-running transect survey mode
    file_analysis/ # Offline file analysis wizard
    aru/         # Scheduled acoustic recording unit deployments
    explore/     # Species exploration by location
    announcements/ # Spoken detection announcements (TTS)
    inference/   # ONNX model wrappers (classifier, geo-model)
    audio/       # Audio capture, ring buffer
    recording/   # WAV/FLAC writing (full + detection clips)
    spectrogram/ # FFT + color maps + painter
    history/     # Session review, library, export
    settings/    # Settings screen
    home/        # Home screen / main menu
    onboarding/  # Intro carousel + acceptable-use gate
    about/       # Credits, links, legal
  l10n/          # ARB localization files (en, de, cs, es, fr, it, pt, nl, pl, ru, zh)
```

## Getting Started

See the [Developer Getting Started](getting-started.md) guide for environment setup.

## Key Topics

- [Architecture](architecture.md) — Feature-based architecture and patterns
- [State Management](state-management.md) — Riverpod providers and notifiers
- [Audio Pipeline](audio-pipeline.md) — Capture, ring buffer, and processing
- [Inference Engine](inference-engine.md) — ONNX model loading and classification
- [ONNX Runtime Pin](onnxruntime-pin.md) — why `flutter_onnxruntime` is pinned, and when to re-check
- [Spectrogram](spectrogram.md) — FFT processing and rendering
- [Session Review](session-review.md) — Post-session editing, playback, and export
- [Localization](localization.md) — ARB files, adding strings, translation conventions
- [Database](database.md) — Session persistence (JSON files)
- [Testing](testing.md) — Test strategy and running tests
- [Code Style](code-style.md) — Conventions and standards
- [Species Bundle](species-bundle.md) — Rebuild bundled species images and metadata
- [Building](building.md) — Build commands and release notes
- [Releasing](releasing.md) — Version bumping and release process
