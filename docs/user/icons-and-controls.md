# Icons & Controls

This page explains the recurring controls and symbols used throughout BirdNET Live. The labels below match the controls exactly as they appear in the app.

## Shared Navigation Controls

| Control | Where you see it | What it does |
|---|---|---|
| :material-tune: **Settings** | Home footer, Live, Point Count, Survey, File Analysis, Session Review | Opens Settings. In mode screens, it opens the settings most relevant to that workflow. |
| :material-magnify: **Explore** | Home footer | Opens Explore. |
| :material-music-box-multiple-outline: **Library** | Home footer | Opens Session Library. |
| :material-help-circle-outline: **Help** | Home footer, Explore header, Survey dashboard, Session Review toolbar | Opens Help or a screen-specific help sheet. |
| :material-information-outline: **Info / About** | Home footer, info bars, help sheets | Shows general information or summary context. |
| :material-arrow-left: **Back** | Live Mode | Returns to the previous screen. |
| :material-open-in-new: **Open external** | About screen, documentation links | Opens an external page such as the online User Guide. |
| :material-hand-heart: **Donate** | About screen | Opens the BirdNET donation page. |

## Weather Symbols

| Control | Meaning |
|---|---|
| :material-weather-sunny: **Clear** | Clear sky. |
| :material-weather-partly-cloudy: **Partly cloudy** | Sun and cloud for mainly clear or partly cloudy weather. |
| :material-weather-cloudy: **Overcast** | Full cloud cover. |
| :material-weather-fog: **Fog** | Fog or depositing rime fog. |
| :material-weather-partly-rainy: **Drizzle** | Light precipitation. |
| :material-weather-rainy: **Rain** | Rain or rain showers. |
| :material-weather-snowy: **Snow** | Snow or snow showers. |
| :material-weather-lightning-rainy: **Thunderstorm** | Thunderstorm conditions. |

## Start, Stop, and Session Controls

| Control | Meaning |
|---|---|
| :material-microphone: **Mic** | Start live listening. |
| :material-stop: **Stop** | Stop an active recording, point count, or survey. |
| :material-play: **Play** | Start a configured setup flow or resume from a paused-ready state. |
| :material-close: **Close / Cancel** | Cancel an active file analysis. |
| :material-timer: **Timer** | Duration or time remaining. |
| :material-alert-circle-outline: **Error** | Model or processing error. |

## Location and Time Controls

| Control | Meaning |
|---|---|
| :material-crosshairs-gps: **Current location** | Use the device's current GPS position. |
| :material-map-marker-plus: **Manual coordinates** | Enter coordinates manually. |
| :material-map-marker-off: **No location** | Skip location or show that location is unavailable. |
| :material-map-marker: **Has location** | Confirm a location, show coordinates, or label a mapped session. |
| :material-refresh: **Refresh** | Re-read the current location or refresh a prediction list. |
| :material-map: **Map picker** | Pick coordinates from the map picker. |
| :material-calendar: **Date** | Set or display a date. |
| :material-close: **Clear** | Remove a selected date. |

## Explore and Species Symbols

| Control | Meaning |
|---|---|
| Species thumbnail | Bundled image for the species when available. |
| Confidence or geo-model percentage badge | A quick numeric summary of model output. Higher numbers indicate stronger support within that screen's context. |
| Monthly labels (`Jan`, `Apr`, `Jul`, `Oct`, `Dec`) | Reference points on the weekly expected-frequency chart in the species overlay. |

## Per-Detection Actions

These controls appear on every detection row across the app — Session Review species list, the clip player sheet, the live survey detection list, and survey map markers. See [Session Review → Per-detection actions](session-review.md#per-detection-actions) for the full behavior.

| Control | Meaning |
|---|---|
| :material-check: **Confirm** | One-tap checkmark that flags a detection as visually or acoustically verified. Confirmed detections gain a small green check on cluster rows and map markers. |
| :material-dots-vertical: **More** | Opens the per-detection overflow with **Share detection**, **Replace species**, **Delete detection**, and **Delete species**. |
| :material-share-variant: **Share detection** | Shares one detection through the platform share sheet, attaching the audio clip whenever one is available — including a slice of the in-progress recording during a live survey. |
| :material-swap-horizontal: **Replace species** | Pick a different species for this detection. Also opens by swiping a review row to the left. |
| :material-delete-outline: **Delete detection** | Removes the row immediately. An undo SnackBar appears for a few seconds. Also triggered by swiping a review row to the right. |
| :material-delete-sweep-outline: **Delete species** | Removes every detection of that species from the session in one shot, with the same SnackBar undo. |
| :material-ear-hearing: **Heard** | On a manually added detection: you heard the bird. Set from the checkbox on the confirmation sheet shown after picking a species. |
| :material-eye: **Seen** | On a manually added detection: you saw the bird. Both glyphs together mean heard *and* seen. |

## Session Review Toolbar

These controls are used on the Session Review screen.

| Control | Meaning |
|---|---|
| :material-plus-circle-outline: **Add** | Add content, such as a species or annotation. |
| :material-undo-variant: **Undo** / :material-redo-variant: **Redo** | Step backward or forward through review edits. |
| :material-content-cut: **Trim** | Enter trim mode or show that trim mode is active. |
| :material-content-save: **Save** | Save review changes. |
| :material-share-variant: **Share** | Export or share the session. |
| :material-delete-outline: **Delete** | Discard the session. |
| :material-play: **Continue** | Continue an unfinished survey from Session Review when that action is available. |

## Screen-Specific Status Bars

### Live Mode

The Live info bar uses :material-information-outline: followed by compact labels such as:

- `now` — detections currently visible in the live list
- `spp` — unique species count
- `det` — total detections
- duration and estimated recording size when recording is active

### Point Count

The point-count timer bar combines :material-stop: **Stop**, :material-timer: **Timer**, and a progress bar to show the remaining timed session.

### Survey

The survey dashboard uses:

- :material-map-outline: **Map** — live map tab
- :material-equalizer: **Spectrogram** — spectrogram tab
- :material-chart-bar: **Summary** — summary tab
- :material-chart-bar: stats labels in the survey summary view

## When in Doubt

If you are unsure what a control does, open the nearest Help sheet in the app, or check the workflow page for that screen in this user guide.