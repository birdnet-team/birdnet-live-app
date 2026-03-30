# Export & Sync

Export detection data and recordings.

## Session Export

After a live session, you can share the results from the Session Review screen:

- **Share button** — exports the session as a JSON file containing all detections, timestamps, confidence scores, and session settings.
- **Audio files** — full WAV recordings are stored in the app's documents directory and can be accessed via a file manager.

## Data Format

Session JSON includes:

```json
{
  "id": "2025-01-15T10-30-00.000",
  "startTime": "2025-01-15T10:30:00.000Z",
  "endTime": "2025-01-15T11:00:00.000Z",
  "detections": [
    {
      "scientificName": "Turdus merula",
      "commonName": "Eurasian Blackbird",
      "confidence": 0.87,
      "timestamp": "2025-01-15T10:32:15.000Z"
    }
  ],
  "settings": {
    "windowDuration": 3,
    "confidenceThreshold": 25,
    "inferenceRate": 1.0
  }
}
```
