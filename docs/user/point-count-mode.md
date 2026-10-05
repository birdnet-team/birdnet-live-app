# Point Count Mode

Point Count Mode is the timed stationary workflow in BirdNET Live.

## How to Open It

From Home, tap the **Point Count Mode** card with the :material-map-marker: icon.

## Setup Flow

Point Count setup uses four steps.

### 1. Duration and location

Choose:

- one of the available duration chips: 3, 5, 10, 15, 20, 25, or 30 minutes
- whether the count continues with the screen off (on by default)
- current GPS with :material-crosshairs-gps:
- manual coordinates with :material-map-marker-plus:
- no location with :material-map-marker-off:
- map picker with :material-map:

The setup screen refreshes GPS when you return from the system permission
dialog or app settings, so a newly granted location permission should update
the coordinates without restarting the wizard. The same section also includes
a weather card. If weather access is off, the card asks for **Allow weather
lookup** consent; once enabled, it previews the site with a weather icon,
temperature, and wind only. The same cached Open-Meteo snapshot is reused when
the point count is saved.

### 2. Analysis settings

Choose per-session analysis settings such as inference rate,
confidence threshold, and species-filter mode. These start from your global
settings but can be adjusted for this count without changing your defaults.

| Setup control | Icon |
|---|---|
| Microphone | :material-microphone: |
| Recording mode | :material-record-circle: |
| Clip context | :material-timer: |
| Inference rate | :material-speedometer: |
| Confidence threshold | :material-check-decagram: |
| Sensitivity | :material-ear-hearing: |
| Species filter | :material-filter-outline: |

The :material-help: button beside each control explains its effect. The
:material-timer: duration control and location selector have the same help
button on the first step.

Choose **Full** to save continuous audio (the default), **Clips** to save a
clip for every detected vocalization, or **Off** to save no audio. This choice
is separate from Live Mode's recording setting and is remembered for the next
Point Count. Clips use the same peak-window selection and clip context as Live
Mode, with no location-based thinning. When Clips is selected, the Clip Context
slider controls how many seconds are kept before and after each analyzed window;
it also updates the Live Mode clip context setting.

### 3. Field tips

This screen presents a short in-app checklist to run through before starting.

### 4. Ready

The ready screen summarizes the selected duration, recording choice, and
screen-off behavior, then lets you start with :material-play:.

## Live Point Count Screen

The live point-count screen focuses on a timed dashboard.

### Top bar

- :material-stop: — end the point count early
- :material-timer: — show time remaining
- :material-help-circle-outline: — open Point Count help
- :material-tune: — open Point Count settings

### Main indicators

- countdown progress bar
- compact info bar with current detections, unique species count, and total detections
- spectrogram view
- detection list

## After the Count

With **Continue with screen off** on in Point Count setup, the count continues when you lock the screen or switch to another app while the screen stays on. It stops at its selected duration; the countdown uses elapsed clock time, so a suspended screen cannot lengthen the count. Android shows a persistent notification with Open and Stop actions. Turn the switch off in setup to end the count early when you lock the screen or switch to another app. Point Counts do not pause and resume because that would interrupt a timed count. If you leave the app while the count is still starting, it is canceled with a message; set it up again to start a new count. On Windows, minimizing the window does not end a count.

When the point count ends, BirdNET Live opens [Session Review](session-review.md).
It saves the Session automatically when that setting is enabled; otherwise,
save it from review if you want to keep it.
With automatic saving enabled, an unfinished count is also saved at the start,
every 30 seconds, and when the app leaves the foreground. After a crash or
power loss, the latest partial count is available in Session Library.
