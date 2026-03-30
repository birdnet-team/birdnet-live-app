# Settings

Configure audio, inference, recording, and display preferences.

## Audio Settings

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| **Window Duration** | 3 s | 1–5 s | Length of the audio analysis window |
| **Inference Rate** | 1.0 Hz | 0.5–4.0 Hz | How often inference runs per second |
| **Sample Rate** | 32,000 Hz | — | Fixed by the model (not configurable) |

## Inference Settings

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| **Confidence Threshold** | 25% | 1–99% | Minimum confidence to show a detection |
| **Species Filter** | Off | Off / Geo Exclude / Geo Merge / Custom | Geographic species filtering mode |
| **Geo Threshold** | 0.03 | 0.01–0.99 | Minimum geo-model score for Geo Exclude mode |

## Recording Settings

| Setting | Default | Description |
|---------|---------|-------------|
| **Recording Mode** | Full | `Off` / `Full` (continuous WAV) / `Detections Only` (clips around detections) |

## Display Settings

| Setting | Default | Description |
|---------|---------|-------------|
| **Color Map** | Viridis | Spectrogram palette: Viridis, Magma, Inferno, Grayscale, BirdNET |
| **dB Floor** | -80 dB | Lower bound of the spectrogram dynamic range |
| **dB Ceiling** | 0 dB | Upper bound of the spectrogram dynamic range |
| **Max Frequency** | 15,000 Hz | Maximum frequency displayed (0 = full Nyquist) |
| **Log Amplitude** | Off | Apply logarithmic amplitude scaling for quieter sounds |

## Language Settings

| Setting | Default | Description |
|---------|---------|-------------|
| **UI Language** | System | App interface language (English, German) |
| **Species Language** | System | Language for common species names |
