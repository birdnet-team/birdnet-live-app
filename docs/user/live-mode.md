# Live Mode

Live Mode is the fastest way to listen through the phone microphone and review detections as they appear in real time.

## How to Open It

From the Home screen, tap the **Live Mode** card with the :app-micRounded: icon.

## Quick Listen

Quick Listen starts listening in a single tap, without opening the app and navigating in first — useful when you hear something you want identified before it stops calling. Every entry point below opens Live Mode and begins listening straight away, whatever the **Auto-start recording** setting is set to, and none of them changes that setting.

### Android: home-screen widget

Add it the way you add any widget: press and hold an empty spot on the home screen, tap **Widgets**, find **BirdNET Live**, and drag out one of the two tiles.

- **Quick Listen** (2×1) — icon with a **Start Listening** label
- **Quick Listen (compact)** (1×1) — icon only

Both do the same thing.

### iOS: Shortcuts, Siri, Action Button, and app icon

BirdNET Live offers a **Start Listening** action to the system, so there is nothing to build by hand:

- **Action Button** (iPhone 15 Pro and later) — open **Settings → Action Button**, choose **Shortcut**, and pick **Start Listening** under BirdNET Live. Pressing and holding the button then starts listening.
- **Siri** — say "Start listening with BirdNET Live", "Listen for birds with BirdNET Live", or "Identify a bird with BirdNET Live".
- **Shortcuts app** — the **Start Listening** action is listed under BirdNET Live. Use it in a shortcut of your own, add that shortcut to the home screen, or run it from Back Tap, a Focus, or an NFC tag.
- **App icon** — press and hold the BirdNET Live icon on the home screen and tap **Start Listening**.
- **URL** — automations that open a URL can use `birdnetlive://listen`.

Siri phrases and the Action Button listing need iOS 17. The Shortcuts action, the app-icon menu, and the URL also work on iOS 16.

### What happens next

If Live Mode is already open, Quick Listen returns to that same screen instead of rebuilding it. A running or paused Session continues unchanged; if it is stopped, listening starts on the existing screen.

Quick Listen never replaces another running mode. If a Point Count, Survey, File Analysis, or [ARU Mode](aru-mode.md) Session is running or starting, the app comes to the foreground and asks you to stop that Session first. Its screen and work remain accessible and are not interrupted.

## Top Bar

The top bar contains three elements:

- :app-arrowBackRounded: — leave Live Mode
- center status text — `Initializing`, `Loading model`, `Ready`, `Identifying species`, `Paused`, or `Error`
- :app-tuneRounded: — open the Live-specific Settings view

## Main Action Button

The large circular button at the bottom center changes state:

- :app-mic: — start listening
- :app-stopRounded: — stop the active session
- :app-playArrowRounded: — resume from a paused-ready state

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

When automatic Session saving is enabled, Live Mode also saves a partial Session at the start, every 30 seconds, and when the app goes into the background. After a crash or power loss, the latest saved snapshot is available in Session Library. Changes since that snapshot can be lost. Turning automatic saving off also turns off these checkpoints.

## Screen-off listening

Live Mode normally pauses when you lock the screen or leave the app and resumes the same Session when you return. The first time this happens, a dialog offers limited background listening. In [Recording settings](settings.md), turn on **Continue with screen off** and choose a 15, 30, 60, or 120 minute maximum (30 minutes by default). The time limit applies to each period away from the app; reaching it ends the Session. On Android, a persistent notification shows that listening is active and offers Open and Stop actions. On Windows, Live Mode keeps listening while its window is minimized.
