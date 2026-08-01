# Live Mode

Live Mode is the fastest way to listen through the phone microphone and review detections as they appear in real time.

## How to Open It

From the Home screen, tap the **Live Mode** card with the :material-microphone: icon.

## Quick Listen Widget

**Android only.** A home-screen widget starts listening in a single tap, without opening the app and navigating in first — useful when you hear something you want identified before it stops calling.

Add it the way you add any widget: press and hold an empty spot on the home screen, tap **Widgets**, find **BirdNET Live**, and drag out one of the two tiles.

- **Quick Listen** (2×1) — icon with a **Start Listening** label
- **Quick Listen (compact)** (1×1) — icon only

Both do the same thing. Tapping either one opens Live Mode and begins listening straight away, whatever the **Auto-start recording** setting is set to. The widget does not change that setting.

If Live Mode is already open, the widget returns to that same screen instead of rebuilding it. A running or paused Session continues unchanged; if it is stopped, listening starts on the existing screen.

Quick Listen never replaces another running mode. If a Point Count, Survey, File Analysis, or [ARU Mode](aru-mode.md) Session is running or starting, the app comes to the foreground and asks you to stop that Session first. Its screen and work remain accessible and are not interrupted.

## Top Bar

The top bar contains three elements:

- :material-arrow-left: — leave Live Mode
- center status text — `Initializing`, `Loading model`, `Ready`, `Identifying species`, `Paused`, or `Error`
- :material-tune: — open the Live-specific Settings view

## Main Action Button

The large circular button at the bottom center changes state:

- :material-microphone: — start listening
- :material-stop: — stop the active session
- :material-play: — resume from a paused-ready state

## What You See While Listening

### Spectrogram

The spectrogram scrolls continuously while capture is active. It shows frequency content over time, using the color map, FFT size, frequency range, and duration configured in Settings.

### Detection list

Recent detections appear below the spectrogram. Each row can show:

- species image
- common name
- optional scientific name
- confidence value

Tap a species row to open the species details overlay.

### Session info bar

The compact info line under the spectrogram summarizes the current session, for example:

- current detections shown now
- unique species count (`spp`)
- total detections (`det`)
- elapsed duration
- estimated recording size when recording is enabled

## Recording Behavior

Recording is controlled in [Settings](settings.md).

- **Full** records the whole session.
- **Detections only** records clips around detections.
- **Off** disables recording.

When you stop Live Mode, BirdNET Live saves the session and opens [Session Review](session-review.md).
