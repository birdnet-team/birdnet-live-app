# Settings

Configure audio, inference, recording, and display preferences. Access settings from the gear icon on the live screen or from the home screen.

## General

| Setting | Default | Description |
|---------|---------|-------------|
| **Theme** | System | Light, Dark, or System (follows device setting) |
| **Language** | System | English or German |
| **Species Language** | Common name language for display |

## Audio Settings

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| **Input Device** | Default mic | — | Select microphone (bottom-sheet picker) |
| **Audio Gain** | 1.0 | 0.5–4.0 | Amplification applied to captured audio |
| **High-Pass Filter** | 0 Hz | 0–500 Hz | Cutoff frequency to reduce wind/handling noise |

## Inference Settings

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| **Window Duration** | 3 s | 3 / 5 / 10 s | Length of the audio analysis window |
| **Inference Rate** | 1.0 Hz | 0.5–4.0 Hz | How often inference runs per second |
| **Confidence Threshold** | 25% | 1–99% | Minimum confidence to show a detection |
| **Sensitivity** | 1.0 | 0.5–1.5 | Model sensitivity bias (higher = more detections, lower precision) |
| **Score Pooling** | LME | Off / Average / Max / LME | Temporal pooling across recent inference windows |
| **Species Filter** | Off | Off / Geo Exclude / Geo Merge / Custom | Geographic species filtering mode |

## Spectrogram Settings

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| **FFT Size** | 1024 | 512–4096 | Frequency resolution (larger = finer, slower) |
| **Color Map** | Viridis | Viridis / Magma / Inferno / Grayscale / BirdNET | Spectrogram palette |
| **dB Floor** | −90 dB | −120–−30 | Minimum amplitude shown |
| **dB Ceiling** | −10 dB | −50–0 | Maximum amplitude shown |
| **Duration** | 20 s | 5–60 s | Width of spectrogram time window |
| **Max Frequency** | 12,000 Hz | 4,000–16,000 | Upper frequency cutoff |
| **Log Amplitude** | On | On / Off | Compress dynamic range for better visibility of quiet sounds |

## Recording Settings

| Setting | Default | Description |
|---------|---------|-------------|
| **Recording Mode** | Full | `Off` / `Full` (continuous) / `Detections Only` (clips around detections) |
| **Recording Format** | FLAC | WAV (uncompressed) or FLAC (50–60% smaller) |
| **Pre-Buffer** | 3 s | Seconds before detection to include in clips |
| **Post-Buffer** | 3 s | Seconds after detection to include in clips |

## Location Settings

| Setting | Default | Description |
|---------|---------|-------------|
| **Use GPS** | On | Enable GPS for geo-model species filtering |
| **Manual Latitude** | 0.0 | Override latitude when GPS is off |
| **Manual Longitude** | 0.0 | Override longitude when GPS is off |
| **Geo Threshold** | 0.03 | Minimum geo-model score for species filtering |

## Danger Zone

| Action | Description |
|--------|-------------|
| **Reset Onboarding** | Show onboarding screens again on next launch (confirmation dialog) |
| **Clear All Data** | Delete all sessions, recordings, and settings. Requires typing "DELETE" to confirm. |
| **dB Floor** | -80 dB | Lower bound of the spectrogram dynamic range |
| **dB Ceiling** | 0 dB | Upper bound of the spectrogram dynamic range |
| **Max Frequency** | 15,000 Hz | Maximum frequency displayed (0 = full Nyquist) |
| **Log Amplitude** | Off | Apply logarithmic amplitude scaling for quieter sounds |

## Language Settings

| Setting | Default | Description |
|---------|---------|-------------|
| **UI Language** | System | App interface language (English, German) |
| **Species Language** | System | Language for common species names |
