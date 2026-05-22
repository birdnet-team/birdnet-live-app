<!-- TRANSLATION TODO (cs) -->

# BirdNET Live

**Profesionální bioakustika ve vaší kapse.**

BirdNET Live is a Flutter app built for field researchers, conservationists, and birders who need dependable acoustic evidence in the field. It runs the BirdNET+ audio classifier and geo-model directly on your device, so species identification works offline after installation.

<p align="center">
  <img src="https://img.shields.io/badge/latest-v0.15.3-orange.svg" alt="Latest release: v0.15.3">
  <img src="https://img.shields.io/badge/species-5%2C250-brightgreen.svg" alt="Species: 5,250">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
</p>

## Features

- **Live Mode** - Real-time scrolling spectrogram with species identification
- **Point Count Mode** - Timed survey sessions with countdown timer and station metadata
- **Survey Mode** - Long-running transect surveys with GPS tracking, background monitoring, and detection sampling
- **File Analysis Mode** - Offline analysis of existing recordings (WAV, FLAC, MP3, OGG, and more)
- **Explore** - Browse species expected at your location using the BirdNET geo-model
- **Session Library** - Review, edit, and export past sessions with audio playback
- **Export** - Raven Pro, CSV, JSON, GPX, and ZIP bundle formats with provenance metadata
- **On-device inference** - BirdNET+ model coverage for 5,250 species, no internet required
- **FLAC recording** - Compressed audio capture with smaller files for long surveys
- **Accessibility** - Screen-reader labels, tooltips, and optional spoken detection announcements
- **Responsive layouts** - Adaptive phone, tablet, portrait, and landscape interfaces

<p align="center">
  <img src="assets/screenshots/live-mode.png" alt="Live Mode" width="150">
  <img src="assets/screenshots/survey.png" alt="Survey Mode" width="150">
  <img src="assets/screenshots/session-review.png" alt="Session Review" width="150">
  <img src="assets/screenshots/explore.png" alt="Explore" width="150">
  <img src="assets/screenshots/file-analysis.png" alt="File Analysis" width="150">
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live"><b>Google Play</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases/latest"><b>Download APK</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app"><b>GitHub</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases"><b>All Releases</b></a>
</p>

## Quick Start

See the [User Guide](user/index.md) for an overview, then open [Getting Started](user/getting-started.md) to install and run BirdNET Live.

## Install on Android

BirdNET Live is available as a signed APK for sideloading. Download the latest release from the [GitHub Releases page](https://github.com/birdnet-team/birdnet-live-app/releases/latest), transfer the `.apk` file to your phone, and open it to install. You may need to allow installation from unknown sources in your device settings.

> **Note:** The APK is ~253 MB because it includes the BirdNET+ model assets for offline inference.

## For Developers

Check the [Developer Guide](developer/index.md) for architecture, building, and contributing.

## License

BirdNET Live is open source under the [MIT License](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE).
