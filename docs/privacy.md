# Privacy Policy

**Last updated:** May 2026

BirdNET Live respects your privacy. This document explains how the app handles your data.

## On-Device Processing

All audio analysis and bird species identification happen **entirely on your device**. The app uses two neural network models that run locally:

- **BirdNET+ audio classifier** — analyzes microphone audio to identify bird species.
- **BirdNET geo-model** — predicts which species are likely at your location and time of year.

No audio data is ever transmitted to external servers.

## Data Collection

BirdNET Live does **not** collect, transmit, or share any personal data. There is no analytics, no tracking, and no telemetry.

### Data stored locally on your device:

| Data Type | Purpose | Storage |
|-----------|---------|---------|
| Audio recordings | Bird identification, playback, export | Local files |
| Detection results | Species, confidence, timestamps | Local JSON session files |
| GPS coordinates | Geotagging detections, survey tracks, geo-model predictions | Local JSON session files |
| Session metadata | Session history, review, export | Local JSON session files |
| Weather snapshot (optional) | One-shot temperature, precipitation, wind, cloud cover, weather code captured per session when **Allow weather lookup** is on | Local JSON session files |
| App settings | User preferences | SharedPreferences |

### Bundled offline data

Species images, descriptions, and taxonomy data are **bundled in the app** and loaded from local assets. No network requests are made for species information.

## External Resources

The app may access the following external resources. Each resource is gated by an independent toggle under **Settings → Privacy**, and **all three are off by default** on a fresh install. Nothing leaves your device until you opt in.

| Resource | Purpose | Gated by | Sent on each request |
|----------|---------|----------|----------------------|
| Map tiles (OpenStreetMap) | Base map for the location picker, the Survey live map, and the session map | **Settings → Privacy → Allow map tiles** | Tile coordinates `(z, x, y)` and the BirdNET Live user-agent string — no PII |
| Reverse geocoding (OpenStreetMap Nominatim) | Resolving GPS coordinates into a human-readable place name (e.g. "Berlin, Germany") for session display | **Settings → Privacy → Allow place name lookup** | The session's latitude / longitude, plus the BirdNET Live user-agent string |
| Weather snapshot (Open-Meteo) | One-shot capture of local conditions (temperature, precipitation, wind, cloud cover, WMO weather code) at the recording coordinates and end time | **Settings → Privacy → Allow weather lookup** | The session's latitude / longitude and end timestamp, plus the BirdNET Live user-agent string |

Map tile requests are standard HTTPS GET requests to `tile.openstreetmap.org` with a BirdNET Live user-agent string. Only tile coordinates are sent — no personally identifiable information.

Reverse-geocoding requests send the session's latitude and longitude to `nominatim.openstreetmap.org` over HTTPS, together with the BirdNET Live user-agent string as required by the [Nominatim Usage Policy](https://operations.osmfoundation.org/policies/nominatim/). The resolved place name is stored locally with the session so a session is only geocoded once. No request is made if the session has no GPS coordinates or the device is offline.

Weather requests send the session's latitude / longitude and end timestamp to `api.open-meteo.com` over HTTPS, together with the BirdNET Live user-agent string. [Open-Meteo](https://open-meteo.com/) is a free service and requires neither an account nor an API key. The returned weather snapshot is stored locally with the session and is also written into the JSON export, the per-session `metadata.json` block, and the HTML report.

**Retention:** none of the third-party services above is contacted to *upload* or *store* user data. Returned values (place name, weather snapshot) live only inside the local session record on your device, and travel only into export files you explicitly produce.

**Revocation:** you can disable any of the three services at any time under **Settings → Privacy**. Existing locally-stored place names and weather snapshots remain attached to the sessions where they were captured; delete those sessions from Session Library or use **Settings → Danger Zone → Clear All Data** to remove that historical data.

**No other network requests are made.** The app functions fully offline.

## GPS & Location

The app uses GPS location for:

- **Species filtering** — predicting which species are likely at your location.
- **Survey mode** — recording GPS tracks and geotagging detections along a transect.
- **Point count mode** — tagging the observation location.

GPS data is stored locally and included in exports only when you explicitly share or export a session. Location access requires your permission and can be revoked at any time via system settings.

## Data Export

You can export session data in multiple formats (Raven Selection Tables, CSV, JSON, GPX) and tick any combination of formats at once under **Settings → Export → Formats**; selected formats are bundled together inside a single ZIP next to any audio clips and the optional self-contained HTML report. Exports are generated locally and shared via the system share sheet. The app does not upload export data to any server.

## Data Deletion

Individual sessions and their recordings can be deleted from Session Library. To wipe BirdNET Live's local sessions, recordings, voice memos, custom species lists, preferences, and caches from inside the app, use **Settings → Danger Zone → Clear All Data**. You can also clear BirdNET Live's app storage in your operating system settings or uninstall the app.

## Contact

For privacy questions: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
