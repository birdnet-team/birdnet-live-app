# Database

Persistence and data storage.

## SharedPreferences

User settings are stored via `shared_preferences`. All keys are centralized in `PrefKeys` (`core/constants/app_constants.dart`).

## Session Storage

Sessions are serialized to JSON files in the app's documents directory:

```
<documents>/sessions/<session-id>.json
```

The `SessionRepository` handles saving, loading, listing, and deleting sessions.

## Recording Storage

Audio recordings are stored as WAV or FLAC files:

```
<documents>/recordings/<session-id>/full.wav
<documents>/recordings/<session-id>/<clip-name>.wav
```

## Model Cache

The ONNX model is extracted from Flutter assets to the documents directory on first launch:

```
<documents>/BirdNET+_V3.0-preview3_Global_11K_FP16.onnx
```

Subsequent launches load directly from disk.
