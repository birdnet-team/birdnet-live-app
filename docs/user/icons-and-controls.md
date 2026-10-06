# Icons & Controls

This page explains the recurring controls and symbols used throughout BirdNET Live. The labels below match the controls exactly as they appear in the app.

## Mode Icons

These are the same icon shapes used in the app. Icons here inherit the text color; app colors vary with the theme, dynamic color, and high contrast.

- :app-micRounded: **Live**
- :app-locationOnRounded: **Point Count**
- :app-routeRounded: **Survey**
- :app-timerRounded: **ARU Mode**
- :app-audioFileRounded: **File Analysis**
- :app-sdStorage: **Batch Analysis** (Coming Soon)

## Shared Navigation Controls

| Control | Where you see it | What it does |
|---|---|---|
| :app-tuneRounded: **Settings** | Home footer, Live, Point Count, Survey, File Analysis, Session Review | Opens Settings. In mode screens, it opens the settings most relevant to that workflow. |
| :app-searchRounded: **Explore** | Home footer | Opens Explore. |
| :app-libraryMusic: **Library** | Home footer | Opens Session Library. |
| :app-helpOutlineRounded: **Help** | Home footer, Explore header, Survey dashboard, Session Review toolbar | Opens Help or a screen-specific help sheet. |
| :app-infoOutline: **Info / About** | Home footer, info bars, help sheets | Shows general information or summary context. |
| :app-arrowBackRounded: **Back** | Live Mode | Returns to the previous screen. |
| :app-openInNew: **Open external** | About screen, documentation links | Opens an external page such as the online User Guide. |
| :app-arrowUpwardRounded: **Back to top** | Help screen | Returns to the introduction and section shortcuts. Appears after scrolling down. |
| :app-volunteerActivism: **Donate** | About screen | Opens the BirdNET donation page. |

## Weather Symbols

| Control | Meaning |
|---|---|
| :app-wbSunny: **Clear** | Clear sky. |
| :app-partlyCloudyDay: **Partly cloudy** | Sun and cloud for mainly clear or partly cloudy weather. |
| :app-cloudy: **Overcast** | Full cloud cover. |
| :app-foggy: **Fog** | Fog or depositing rime fog. |
| :app-rainyLight: **Drizzle** | Light precipitation. |
| :app-rainy: **Rain** | Rain or rain showers. |
| :app-weatherSnowy: **Snow** | Snow or snow showers. |
| :app-thunderstorm: **Thunderstorm** | Thunderstorm conditions. |

## Start, Stop, and Session Controls

| Control | Meaning |
|---|---|
| :app-micRounded: **Mic** | Start live listening. |
| :app-stopRounded: **Stop** | Stop an active recording, point count, or survey. |
| :app-playArrowRounded: **Play** | Start a configured setup flow or resume from a paused-ready state. |
| :app-close: **Close** / :app-stop: **Cancel** | Cancel an active file analysis from the header or the progress screen. |
| :app-timerOutlined: **Timer** | Duration or time remaining. |
| :app-errorOutline: **Error** | Model or processing error. |

## Location and Time Controls

| Control | Meaning |
|---|---|
| :app-myLocation: **Current location** | Use the device's current GPS position. |
| :app-editLocationAlt: **Manual coordinates** | Enter coordinates manually. |
| :app-locationOff: **No location** | Skip location or show that location is unavailable. |
| :app-locationOn: **Has location** | Confirm a location, show coordinates, or label a mapped session. |
| :app-refresh: **Refresh** | Re-read the current location or refresh a prediction list. |
| :app-mapSheet: **Map picker** | Pick coordinates from the map picker. |
| :app-calendarToday: **Date** | Set or display a date. |
| :app-clear: **Clear** | Remove a selected date. |

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
| :app-checkCircleOutline: **Confirm** | One-tap checkmark that flags a detection as visually or acoustically verified. Confirmed detections gain a small green check on cluster rows and map markers. |
| :app-moreVert: **More** | Opens the per-detection overflow with **Share detection**, **Replace species**, **Delete detection**, and **Delete species**. |
| :app-share: **Share detection** | Shares one detection through the platform share sheet, attaching the audio clip whenever one is available — including a slice of the in-progress recording during a live survey. |
| :app-swapHoriz: **Replace species** | Pick a different species for this detection. Also opens by swiping a review row to the left. |
| :app-deleteOutline: **Delete detection** | Removes the row immediately. An undo SnackBar appears for a few seconds. Also triggered by swiping a review row to the right. |
| :app-deleteSweep: **Delete species** | Removes every detection of that species from the session in one shot, with the same SnackBar undo. |
| :app-hearing: **Heard** | On a manually added detection: you heard the bird. Set from the checkbox on the confirmation sheet shown after picking a species. |
| :app-visibility: **Seen** | On a manually added detection: you saw the bird. Both glyphs together mean heard *and* seen. |

## Session Review Toolbar

These controls are used on the Session Review screen.

| Control | Meaning |
|---|---|
| :app-addCircleOutline: **Add** | Add content, such as a species or annotation. |
| :app-undo: **Undo** / :app-redo: **Redo** | Step backward or forward through review edits. |
| :app-contentCut: **Trim** | Enter trim mode or show that trim mode is active. |
| :app-save: **Save** | Save review changes. |
| :app-share: **Share** | Export or share the session. |
| :app-deleteOutline: **Delete** | Discard the session. |
| :app-playArrowRounded: **Continue** | Continue an unfinished survey from Session Review when that action is available. |

## Screen-Specific Status Bars

### Live Mode

The Live info bar uses :app-infoOutline: followed by compact labels such as:

- `now` — detections currently visible in the live list
- `spp` — unique species count
- `det` — total detections
- duration and estimated recording size when recording is active

### Point Count

The point-count timer bar combines :app-stopRounded: **Stop**, :app-timerOutlined: **Timer**, and a progress bar to show the remaining timed session.

### Survey

The survey dashboard uses:

- :app-map: **Map** — live map tab
- :app-graphicEq: **Spectrogram** — spectrogram tab
- :app-summaryChart: **Summary** — summary tab
- :app-summaryChart: stats labels in the survey summary view

## When in Doubt

If you are unsure what a control does, open the nearest Help sheet in the app, or check the workflow page for that screen in this user guide.