# Live Mode

Real-time bird identification with a scrolling spectrogram.

## Overview

Live Mode is the primary feature of BirdNET Live. It uses your device's microphone to capture audio, displays a real-time spectrogram, and identifies bird species using on-device ONNX inference — no internet connection required.

## How It Works

1. **Tap the microphone button** to start a session.
2. The app captures audio at 32 kHz mono and feeds it through an FFT processor to render a scrolling spectrogram.
3. At the configured inference rate (default 1 Hz), the app runs the BirdNET+ classifier model on the most recent audio window (default 3 seconds).
4. Detected species appear in the detection list below the spectrogram, sorted by confidence.

## Screen Layout

| Area | Description |
|------|-------------|
| **Status bar** | Back arrow, session status (idle / recording / paused), settings gear |
| **Spectrogram** | Scrolling FFT visualization (top ~40% of screen) |
| **Session info** | Detection count and elapsed time (visible during active session) |
| **Detection list** | Species detections sorted by confidence (bottom ~60%) |
| **Capture button** | Mic (start), pause, or stop button (bottom center) |

## Session Lifecycle

```
Ready → Start → Active → Pause → Resume → Active → Stop → Review
```

- **Start**: Begins audio capture, inference timer, and full audio recording.
- **Pause**: Stops the inference timer but keeps the session alive. Detections are preserved.
- **Resume**: Restarts inference from a paused session.
- **Stop**: Shows a confirmation dialog, then finalizes the session and navigates to the Session Review screen.

## Species Filtering

Live Mode supports geographic species filtering via the BirdNET+ geo-model:

| Filter Mode | Behavior |
|-------------|----------|
| **Off** | No filtering — all 11,000+ species are eligible |
| **Geo Exclude** | Keep only species the geo-model predicts at your location (above threshold) |
| **Geo Merge** | Multiply audio confidence by geo-model probability |
| **Custom List** | Keep only species you have manually selected |

## Tips

- **Hold the device steady** — movement noise can trigger false detections.
- **Point toward the sound** — directional microphones work best facing the bird.
- **Lower the confidence threshold** in settings if you're missing detections.
- **Use the spectrogram** to visually confirm bird calls — look for characteristic patterns.
