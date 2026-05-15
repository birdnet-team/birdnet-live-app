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
  shared/        # Shared models, providers, services, widgets
  features/      # Feature modules (screen + providers + widgets)
    live/        # Live identification mode
    point_count/ # Timed point-count survey mode
    survey/      # Long-running transect survey mode
    file_analysis/ # Offline file analysis wizard
    explore/     # Species exploration by location
    inference/   # ONNX model wrappers (classifier, geo-model)
    audio/       # Audio capture, ring buffer
    recording/   # WAV/FLAC writing (full + detection clips)
    spectrogram/ # FFT + color maps + painter
    history/     # Session review, library, export
    settings/    # Settings screen
    home/        # Home screen / main menu
    onboarding/  # Intro carousel + terms gate
    about/       # Credits, links, legal
  l10n/          # ARB localization files (EN, DE)
```

## Getting Started

See the [Developer Getting Started](getting-started.md) guide for environment setup.

## Key Topics

- [AI Implementation Guide](ai-implementation-guide.md) — Current implementation map for AI coding agents
- [Architecture](architecture.md) — Feature-based architecture and patterns
- [State Management](state-management.md) — Riverpod providers and notifiers
- [Audio Pipeline](audio-pipeline.md) — Capture, ring buffer, and processing
- [Inference Engine](inference-engine.md) — ONNX model loading and classification
- [Spectrogram](spectrogram.md) — FFT processing and rendering
- [Session Review](session-review.md) — Post-session editing, playback, and export
- [Localization](localization.md) — ARB files, adding strings, translation conventions
- [Database](database.md) — Session persistence (JSON files)
- [Testing](testing.md) — Test strategy and running tests
- [Code Style](code-style.md) — Conventions and standards
- [Species Bundle](species-bundle.md) — Rebuild bundled species images and metadata
- [Building](building.md) — Build commands and release notes
- [Releasing](releasing.md) — Version bumping and release process
