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

ONNX Runtime needs the model as a real file. Where that file lives depends on the platform (`AssetPackService.resolveModelPath`):

- **iOS, Windows, macOS, Linux**: the bundled asset is used in place (`flutter_assets/assets/models/<modelFile>` inside the app bundle). Nothing is extracted.
- **Android**: assets live inside the APK or the install-time asset pack, so each model is copied once to the app's private `filesDir`. The copy is named after the model file and version in `assets/models/model_config.json`, so a model update extracts a fresh copy:

```
<filesDir>/<audioModel.onnx.modelFile>_v<audioModel.version>
<filesDir>/<geoModel.modelFile>_v<geoModel.version>
```

Subsequent launches load the extracted models directly from disk.

If neither source is available, the model is extracted to `<documents>/<modelFile>_v<version>` instead. Builds up to 1.2.0 always extracted there.

After each model is resolved, extracted copies (`BirdNET*.onnx_v*`, plus `.tmp` files of interrupted copies) that do not belong to a model in `model_config.json` are deleted from `filesDir` and the documents directory, so an update does not leave the previous models behind. Copies in the documents directory are also deleted once the model is read from the bundle or from `filesDir`.
