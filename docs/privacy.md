# Privacy Policy

**Last updated:** 2025

BirdNET Live respects your privacy. This document explains how the app handles your data.

## On-Device Processing

All audio processing and bird species inference happen entirely on your device. No audio data is transmitted to external servers unless you explicitly configure API sync.

## Data Collection

BirdNET Live does **not** collect, transmit, or share any personal data by default.

### Data stored locally on your device:

| Data Type | Purpose | Storage |
|-----------|---------|---------|
| Audio recordings | Bird identification, playback | Local files |
| Detection results | Species, confidence, timestamp | Local database |
| GPS coordinates | Geotagging detections, survey tracks | Local database |
| App settings | User preferences | SharedPreferences |

## External Resources

The app requests explicit consent before accessing any external service:

| Resource | Purpose | When |
|----------|---------|------|
| Map tiles (OpenTopoMap) | GPS visualization | First map access |
| API sync | Survey data upload | User-configured |

You can revoke consent at any time in Settings.

## Data Export & Deletion

- **Export**: Settings > Export to download all your data (CSV, JSON, GPX)
- **Delete**: Settings > Clear All Data to permanently remove all stored data

## Contact

For privacy questions: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
