# Export & Sync

Export detection data and recordings from the Session Review screen.

## Export Formats

| Format | Extension | Description |
|--------|-----------|-------------|
| **Raven Pro** | `.txt` | Tab-delimited selection table compatible with Cornell's Raven Pro/Lite software |
| **CSV** | `.csv` | Comma-separated values with timestamps, species, and confidence scores |
| **JSON** | `.json` | Full session data including settings, detections, and annotations |
| **ZIP Bundle** | `.zip` | Archives the audio recording + JSON metadata for sharing |

## How to Export

1. Open a session from the **Session Library** (home screen).
2. Tap the **export/share** button in the Session Review screen.
3. Choose the desired format.
4. Use the system share sheet to send via email, messaging, cloud storage, etc.

## Audio Files

Recordings are stored in the app's documents directory:

```
<documents>/recordings/<session-id>/full.wav   (or full.flac)
<documents>/recordings/<session-id>/clip_<ts>.wav
```

Full recordings use WAV (uncompressed) or FLAC format depending on the Recording Format setting. Detection clips are always WAV.

## Raven Pro Format

The Raven Pro selection table is the standard format used in ornithology research. Each row represents one detection:

| Column | Description |
|--------|-------------|
| Selection | Sequential detection number |
| View | Always "Spectrogram 1" |
| Channel | Always 1 (mono) |
| Begin Time (s) | Detection start time in seconds |
| End Time (s) | Detection end time in seconds |
| Low Freq (Hz) | Lower frequency bound |
| High Freq (Hz) | Upper frequency bound |
| Species | Common name of detected species |
| Scientific Name | Latin binomial |
| Confidence | Detection confidence (0-1) |

## Sync

!!! info "Coming Soon"
    API sync functionality will be added in a future update.
