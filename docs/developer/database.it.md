<!-- TRANSLATION TODO (it) -->

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

Audio recordings are stored as WAV or FLAC files depending on the user's settings. On iOS, voice memos fall back to WAV format to prevent CoreAudio AAC compression issues:

```
<documents>/recordings/<session-id>/full.wav       # or full.flac
<documents>/recordings/<session-id>/<clip-name>.wav # or <clip-name>.flac
<documents>/recordings/<session-id>/memos/memo_<timestamp>.m4a # or .wav on iOS
```

## Model Cache

ONNX model files are extracted from Flutter assets to the documents directory on first launch. To handle model updates, the extracted files are suffixed with `_v<version>` (configured in the code):

```
<documents>/BirdNET+_V3.0-preview3_Global_5K-pruned_FP16.onnx_v<version>
<documents>/BirdNET+_Geomodel_V3.0.1_Global_5K-pruned_FP16.onnx_v<version>
```

Subsequent launches load the cached models directly from disk.
