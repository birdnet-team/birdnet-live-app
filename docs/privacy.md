# Privacy Policy

**Last updated:** April 2026

BirdNET Live respects your privacy. This document explains how the app handles your data.

## On-Device Processing

All audio analysis and bird species identification happen **entirely on your device**. The app uses two neural network models that run locally:

- **BirdNET+ audio classifier** — analyzes microphone audio to identify bird species.
- **BirdNET geo-model** — predicts which species are likely at your location and time of year.

No audio data is ever transmitted to external servers.

## Data Collection

BirdNET Live does **not** collect, transmit, or share any personal data by default. There is no analytics, no tracking, and no telemetry.

### Data stored locally on your device:

| Data Type | Purpose | Storage |
|-----------|---------|---------|
| Audio recordings | Bird identification, playback | Local files |
| Detection results | Species, confidence, timestamp | JSON files |
| GPS coordinates | Geotagging detections, geo-model predictions | JSON files |
| App settings | User preferences | SharedPreferences |

## External Resources

The app may access the following external resources:

| Resource | Purpose | When |
|----------|---------|------|
| Species images & descriptions | Showing species details in Explore | When opening species info |
| Map tiles (OpenTopoMap) | GPS visualization | First map access (consent required) |

Species images and descriptions are fetched from the BirdNET taxonomy API (`birdnet.cornell.edu/taxonomy/api/`). No personally identifiable information is sent — only the scientific name of the species being viewed.

## Data Export & Deletion

- **Export**: Settings > Export to download all your data (CSV, JSON, Raven selection tables)
- **Delete**: Settings > Danger Zone > Clear All Data to permanently remove all stored data

## Contact

For privacy questions: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
