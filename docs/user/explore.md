# Explore

Browse bird species expected at your location.

## Overview

Explore mode uses the BirdNET geo-model to predict which species are likely in your area based on your GPS coordinates and the current time of year. Each species shows a thumbnail image, common and scientific names, and a geo-probability score.

## How It Works

1. Navigate to **Explore** from the home screen.
2. The app determines your location via GPS (or uses manual coordinates from Settings).
3. The geo-model predicts species probabilities for your location and the current week.
4. Species are listed in order of geo-probability (most likely first).

## Screen Layout

| Area | Description |
|------|-------------|
| **Location header** | Reverse-geocoded place name with latitude/longitude below |
| **Help icon** | Tap for an explanation of how the geo-model works |
| **Species list** | Scrollable cards with thumbnail, names, and geo-score indicator |

## Species Info

Tap any species card to open the **Species Info Overlay**:

- **Image** — Medium-resolution photo from the BirdNET taxonomy API
- **Image credit** — Attribution shown below the photo
- **Names** — Common name and scientific name
- **Description** — Wikipedia excerpt about the species
- **Weekly probability chart** — 48-week bar chart showing seasonal occurrence
- **External links** — eBird, iNaturalist, and Wikipedia (opens in browser)

## Location

Explore uses the same location settings as Live Mode:

- **GPS enabled** (default): Uses your device's GPS to determine location.
- **GPS disabled**: Uses the manual latitude/longitude from Settings > Location.

The geo-model divides the year into 48 weeks (4 per month) for seasonal predictions.
