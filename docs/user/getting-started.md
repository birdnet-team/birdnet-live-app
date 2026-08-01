# Getting Started

## Installation

BirdNET Live is available for Android, iOS, and Windows.

### Requirements

- **Android**: 8.0 (API 26) or later
- **iOS**: 15.0 or later
- **Windows**: 10 or later (experimental)
- ~300 MB storage for app + models

### Download

- **Android** — [Google Play Store](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live), or sideload the signed APK from the [GitHub Releases page](https://github.com/birdnet-team/birdnet-live-app/releases/latest).
- **iOS** — [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).
- **Windows** — build from source; see the [Developer Guide](../developer/building.md).

## First-Time App Flow

When you open BirdNET Live for the first time, the app walks you through a short onboarding flow and permission setup.

1. Read the onboarding screens.
2. Review the Acceptable Use Policy and Privacy Policy.
3. Grant microphone permission so BirdNET Live can process audio.
4. Optionally allow location permission for geotagging, Explore, Point Count, and Survey.
5. Optionally allow notifications for long-running surveys.

## First Launch

1. **Onboarding** — Quick introduction to features and permissions
2. **Acceptable Use & Privacy** — Review the Acceptable Use Policy and Privacy Policy
3. **Permissions** — Grant microphone access (required for all modes)
4. **Ready** — Start identifying birds!

## Home Screen Overview

The Home screen is the main hub.

### Main mode cards

- :material-microphone: **Live Mode**
- :material-map-marker: **Point Count Mode**
- :material-routes: **Survey Mode**
- :material-file-music: **File Analysis**

### Footer buttons

- :material-tune: **Settings**
- :material-magnify: **Explore**
- :material-music-box-multiple-outline: **Session Library**
- :material-help-circle-outline: **Help**
- :material-information-outline: **About**

## What Gets Saved

BirdNET Live automatically saves each completed session and opens it in Session Review once processing stops.

- Live sessions save detections and, depending on your settings, recordings or clips.
- Point Count sessions save as timed point-count sessions.
- Survey sessions save the route, detections, and related metadata.
- File Analysis results are converted into a reviewable session.

## Recommended Next Pages

- Read [Icons & Controls](icons-and-controls.md) if you want a quick explanation of the recurring UI symbols.
- Read [Settings](settings.md) before changing thresholds, filters, recording behavior, or spectrogram display.
- Open the guide for the workflow you use most often: [Live Mode](live-mode.md), [Point Count Mode](point-count-mode.md), [Survey Mode](survey-mode.md), or [File Analysis](file-analysis.md).

## Permissions

| Permission | Required For | Optional? |
|------------|-------------|-----------|
| Microphone | All recording modes | Required |
| Location | GPS tagging, Survey/Point Count | Optional for Live |
| Storage | Saving recordings, exports | Required for recording |
| Notifications | Background survey alerts | Optional |
