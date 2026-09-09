# Privacy Policy for BirdNET Live

**Last updated:** August 6, 2026

This Privacy Policy applies to **BirdNET Live** (the **app**). The app is developed and offered by **BirdNET-Team** (the **developer**, **we**, or **us**).

## App and Developer Identity

| | |
|---|---|
| **App name** | BirdNET Live |
| **Developer name** | BirdNET-Team |
| **Privacy contact** | [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu) |

This policy is provided by BirdNET-Team in its own name and explains how BirdNET Live protects and handles personal information.

## On-Device Processing

All audio analysis and bird species identification happen **entirely on your device**. The app uses two neural network models that run locally:

- **BirdNET+ audio classifier** — analyzes microphone audio to identify bird species.
- **BirdNET geo-model** — predicts which species are likely at your location and time of year.

No audio data is ever transmitted to external servers.

## Personal Information Handling

BirdNET-Team does **not** operate an app backend and does not receive your recordings, location, Session data, or other personal information through BirdNET Live. The app has no user accounts, advertising, analytics, tracking, or telemetry. The app does process audio and location on your device and, only when you enable an optional network feature, sends the information described under **External Resources** directly to the named third-party provider.

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
| Map tiles (OpenStreetMap Foundation) | Base map for the location picker, the Survey live map, and the Session map | **Settings → Privacy → Allow map tiles** | Tile coordinates `(z, x, y)`, your IP address as part of the network connection, and the BirdNET Live user-agent string |
| Reverse geocoding (OpenStreetMap Foundation Nominatim) | Resolving GPS coordinates into a human-readable place name (e.g. "Berlin, Germany") for Session display | **Settings → Privacy → Allow place name lookup** | The Session's latitude / longitude, your IP address as part of the network connection, and the BirdNET Live user-agent string |
| Weather snapshot (OpenMeteo GmbH) | One-shot capture of local conditions (temperature, precipitation, wind, cloud cover, WMO weather code) at the recording coordinates and end time | **Settings → Privacy → Allow weather lookup** | The Session's latitude / longitude and end timestamp, your IP address as part of the network connection, and the BirdNET Live user-agent string |

Map tile requests are HTTPS GET requests to `tile.openstreetmap.org`. The tile coordinates identify the area of the map being viewed. Like any direct Internet request, the request also exposes your IP address to the service provider.

Reverse-geocoding requests send the session's latitude and longitude to `nominatim.openstreetmap.org` over HTTPS, together with the BirdNET Live user-agent string as required by the [Nominatim Usage Policy](https://operations.osmfoundation.org/policies/nominatim/). The resolved place name is stored locally with the session so a session is only geocoded once. No request is made if the session has no GPS coordinates or the device is offline.

Weather requests send the session's latitude / longitude and end timestamp to `api.open-meteo.com` over HTTPS, together with the BirdNET Live user-agent string. [Open-Meteo](https://open-meteo.com/) is a free service and requires neither an account nor an API key. The returned weather snapshot is stored locally with the session and is also written into the JSON export, the per-session `metadata.json` block, and the HTML report.

**Third-party processing and retention:** BirdNET-Team does not operate these services and does not receive their request data. The OpenStreetMap Foundation may process network access data and request details under its [Privacy Policy](https://osmfoundation.org/wiki/Privacy_Policy). Open-Meteo states that its free API web-server logs may contain IP addresses and geographic coordinates and are deleted after 90 days; see its [Terms & Privacy](https://open-meteo.com/en/terms). These providers may process data in countries other than yours. Returned values (place name and weather snapshot) are stored in the local Session record on your device and enter an export only when you create one.

**Revocation:** you can disable any of the three services at any time under **Settings → Privacy**. Existing locally-stored place names and weather snapshots remain attached to the sessions where they were captured; delete those sessions from Session Library or use **Settings → Danger Zone → Clear All Data** to remove that historical data.

**No other network requests are initiated by the app itself.** The app functions fully offline. Separately, content you deliberately open in your browser, including external links and exported HTML reports, may make browser requests as described below.

## External Links

BirdNET Live includes links to third-party websites that you can choose to open — for example, a species' **eBird**, **iNaturalist**, and **Wikipedia** pages and the *"Listen to this species on eBird"* audio link in the species view, plus links to the BirdNET project website, source code, user guide, and donation page from the **About** screen. Links that leave the app are marked with an external-link icon (↗) so you can recognize them before tapping.

Nothing is sent while a link is merely displayed, and no external link is ever opened automatically — a browser opens only when you tap one. When you do, the link opens in your device's default web browser and you leave BirdNET Live. The destination is operated by a third party and governed by **its own** privacy policy and terms, not this one. Such sites may independently collect information about your visit — for example your IP address, device or browser details, and how you interact with their pages — and may set their own cookies. We do not control and are not responsible for the content or data practices of external websites; please review each site's own privacy policy.

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
