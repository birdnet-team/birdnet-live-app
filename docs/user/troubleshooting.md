# Troubleshooting

Common issues and solutions.

## No Detections Showing

1. **Check microphone permission** — the app needs microphone access to capture audio.
2. **Lower the confidence threshold** in Settings (default is 25%).
3. **Ensure the session is active** — the mic button should show a red stop icon.
4. **Wait for model loading** — the first launch extracts a ~259 MB model file, which takes time.

## Model Loading Failed

- **Insufficient storage**: The app needs ~300 MB of free space for the model file.
- **Corrupted extraction**: Clear app data and restart to re-extract the model.
- **Crash on startup**: Check that your device has enough RAM (at least 2 GB free).

## Spectrogram Not Scrolling

- Verify audio capture is active (green "Recording" status in the status bar).
- Check that no other app is holding the microphone (voice recorders, phone calls).
- On Android, ensure the app is not being battery-optimized (Settings → Battery → BirdNET Live → Unrestricted).

## GPS / Location Issues

- Grant location permission for geo-model species filtering.
- Enable high-accuracy mode in device location settings.
- The geo-model is optional — the app works without location, just without geographic filtering.

## Audio Playback Not Working

- Ensure the device volume is not muted.
- Check that the recording file exists in the session directory.
- WAV files are 32 kHz mono 16-bit PCM — ensure your media player supports this format.

## App Crash on Pixel / Samsung

- Update to the latest app version.
- Ensure your OS is up to date (Android 8.0+ required).
- Report crashes with device model and Android version via GitHub Issues.
