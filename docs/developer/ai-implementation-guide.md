# AI Implementation Guide

This document is an AI-facing map of the current BirdNET Live implementation. It is intended for coding agents that need to modify the app safely: where behavior lives, what data flows through the app, which invariants matter, and what to test after touching each subsystem.

The app is a Flutter/Dart application named `birdnet_live`. It identifies species from audio with on-device ONNX inference, supports live microphone sessions, point counts, long-running GPS surveys, offline file analysis, session review, exports, and species exploration. The implementation is feature-based: feature code lives under `lib/features/`, cross-cutting services live under `lib/core/`, and reusable app-level models/providers/widgets live under `lib/shared/`.

## Entry Point and App Gate

`lib/main.dart` is the process entry point. Startup does the following:

1. Calls `WidgetsFlutterBinding.ensureInitialized()`.
2. Initializes foreground-task communication with `FlutterForegroundTask.initCommunicationPort()`.
3. Initializes survey notifications through `SurveyNotificationService.init()`.
4. Enables edge-to-edge UI and transparent system bars.
5. Loads `SharedPreferences`.
6. Migrates the legacy `map_tile_consent` setting into `privacy_allow_map` and `privacy_allow_reverse_geocoding` when needed.
7. Runs `App` inside a Riverpod `ProviderScope`, overriding `sharedPreferencesProvider`.

`lib/app.dart` creates the `MaterialApp`, wires theme/localization, and uses `_AppGate` to decide whether to show `OnboardingScreen` or `HomeScreen`. The gate requires both `onboardingCompleteProvider` and `termsAcceptedProvider`; onboarding also captures terms acceptance.

AI caution: do not create new `SharedPreferences.getInstance()` entry points for normal settings unless there is a good reason. Most settings should flow through Riverpod providers in `shared/providers/`.

## Build and Runtime Shape

Primary configuration is in `pubspec.yaml`:

- Flutter SDK with Dart `^3.7.0`.
- Riverpod for state management.
- `record` for microphone capture.
- `flutter_onnxruntime` for ONNX inference.
- `just_audio` for playback.
- `flutter_foreground_task` and `flutter_local_notifications` for survey background/alert behavior.
- `geolocator`, `flutter_map`, `latlong2` for location/maps.
- `archive`, `crypto`, file/path packages for exports and persistence.

Large model assets are declared under `assets/models/`, together with taxonomy/species image data. `assets/models/model_config.json` is the source of truth for model file names, tensor names, label parsing, sample rate, window durations, thresholds, and geo-model metadata.

Android-specific runtime code lives in:

- `android/app/src/main/kotlin/com/birdnet/birdnet_live/MainActivity.kt`
- `android/app/src/main/kotlin/com/birdnet/birdnet_live/NativeAudioDecoder.kt`
- `android/app/src/main/AndroidManifest.xml`

`MainActivity.kt` exposes three method channels:

- `com.birdnet/wakelock`: toggles `FLAG_KEEP_SCREEN_ON`.
- `com.birdnet/audio_decoder`: decodes compressed audio via Android `MediaCodec`.
- `com.birdnet/asset_pack`: extracts large ONNX files from Android assets / Play Asset Delivery into real files.

Android release builds use `android/models_pack` as an install-time asset pack for AAB builds. APK builds keep ONNX files in Flutter assets. `AssetPackService.resolveModelPath()` abstracts both flows and should be the only path used by Dart model loaders.

## Top-Level Navigation

`HomeScreen` is the main menu after onboarding. It pushes screens directly through `MaterialPageRoute` rather than a named-route router:

- `LiveScreen`
- `PointCountSetupScreen`
- `SurveySetupScreen`
- `FileAnalysisScreen`
- `SessionLibraryScreen`
- `ExploreScreen`
- `SettingsScreen`
- `HelpScreen`
- `AboutScreen`

The app currently uses direct widget navigation. If adding major navigation behavior, stay consistent or introduce a router only as a deliberate refactor.

## Provider Model

Riverpod is used for dependency injection and UI state. The core provider files are:

- `lib/shared/providers/app_providers.dart`
- `lib/shared/providers/settings_providers.dart`
- `lib/features/audio/audio_providers.dart`
- `lib/features/live/live_providers.dart`
- `lib/features/survey/survey_providers.dart`
- `lib/features/file_analysis/file_analysis_providers.dart`
- `lib/features/explore/explore_providers.dart`

Settings are backed by `SharedPreferences` through generic notifiers:

- `DoubleSettingNotifier`
- `IntSettingNotifier`
- `StringSettingNotifier`
- `BoolSettingNotifier`

Preference keys are centralized in `PrefKeys` in `lib/core/constants/app_constants.dart`. Add new persisted settings there first, then add a provider in `settings_providers.dart`, then wire UI.

Important settings families:

- Audio: gain, high-pass cutoff, mic device.
- Inference: window duration, confidence threshold, inference rate, sensitivity, score pooling, geo/custom species filter mode.
- Spectrogram: FFT size, colormap, dB floor/ceiling, duration, max frequency, log amplitude, rendering quality.
- Recording/export: WAV/FLAC, full/detections/off, clip context, export formats, include audio, HTML report.
- Privacy: map tiles, reverse geocoding, weather.
- Location: GPS/manual coordinates, geo threshold.
- Survey: inference/GPS/max duration/battery/recording/sampling/alerts/watchlists.
- Display: species language, scientific names, timestamp style.

AI caution: a setting's persisted value is often a snapshot in `LiveSession.settings`. Mid-session UI changes may hot-apply to controllers, but the session snapshot remains the value selected at start for auditability.

## Audio Pipeline

The live audio pipeline is:

```text
Microphone -> PCM16 bytes -> Float32 [-1, 1] -> DSP -> RingBuffer
                                      -> inference windows
                                      -> spectrogram reads
                                      -> recording flushes/clips
                                      -> level meter
```

Key files:

- `features/audio/audio_capture_service.dart`
- `features/audio/audio_providers.dart`
- `features/audio/ring_buffer.dart`

`AudioCaptureService` wraps the `record` package. It records 32 kHz mono PCM16, converts to `Float32List`, applies gain and optional fourth-order Butterworth high-pass filtering, and writes into a shared `RingBuffer`.

The service emits:

- `levelStream`: RMS levels at about 15 Hz.
- `onDataAvailable`: chunk sizes when samples are written.
- `micContestedStream`: true/false when the watchdog believes another app is holding the microphone.

The watchdog runs every 2 seconds. After repeated stalls, it backs off for 30 seconds and marks the mic contested to avoid repeatedly stealing the mic from another app.

`RingBuffer` is a fixed-capacity circular `Float32List`, defaulting to 640,000 samples (20 seconds at 32 kHz). `readLast(count)` zero-pads at the beginning when there is not enough audio. This is important for model windows at session start.

AI caution: do not make the ring buffer dynamically grow. It is intentionally bounded to protect memory during long surveys.

## Inference Pipeline

Model configuration lives in `assets/models/model_config.json`. The audio model is BirdNET+ V3.0-preview3, 5,250 species, 32 kHz mono. The geo model is BirdNET+ Geomodel V3.0.1.

Key files:

- `features/inference/model_config.dart`
- `features/inference/classifier_model.dart`
- `features/inference/inference_service.dart`
- `features/inference/inference_isolate.dart`
- `features/inference/post_processor.dart`
- `features/inference/species_filter.dart`
- `features/inference/geo_model.dart`
- `features/inference/label_parser.dart`

Despite the name, `InferenceIsolate` no longer spawns a Dart isolate. `flutter_onnxruntime` runs native work off the UI thread, so the wrapper keeps the old API and serializes calls into one `InferenceService`. Do not assume it is an isolate boundary.

`InferenceService`:

1. Parses labels through `LabelParser`.
2. Loads ONNX with `ClassifierModel.loadModelFromFile()`.
3. Runs the model for fixed-size windows.
4. Treats model predictions as already sigmoid-activated probabilities.
5. Optionally pools recent score vectors.
6. Applies sensitivity and top-K thresholding.

Pooling modes:

- `off`: use only current window and do not grow the rolling buffer.
- `average`
- `max`
- `lme`: log-mean-exp, default/historical behavior.

Sensitivity is applied after pooling. The confidence threshold passed to inference is on a 0.0-1.0 scale, while UI settings store it as 0-100.

`SpeciesFilter.apply()` supports:

- `off`: no filtering.
- `geoExclude`: only keep species with geo score above threshold.
- `geoMerge`: multiply audio confidence by geo probability, then threshold and sort.
- `customList`: keep explicit species. Some current call sites pass no custom set, so this mode behaves as no-op unless a set is supplied.

Live/file/survey flows also restrict detections to species present in the geo-model label set when `geoModelSpeciesNames` is provided. This keeps live detections within the intersection of the audio and geo models.

## Live Mode

Key files:

- `features/live/live_screen.dart`
- `features/live/live_controller.dart`
- `features/live/live_providers.dart`
- `features/live/live_session.dart`
- `features/live/widgets/detection_list_widget.dart`

`LiveController` owns model loading, inference timing, session state, detection accumulation, recording, and clip playback. Its state machine is:

```text
idle -> loading -> ready -> active -> paused -> active
                         -> ready after finalizeSession()
                         -> error on load failure
```

Starting a session creates a `LiveSession` with:

- timestamp ID with colons replaced for filesystem safety,
- `SessionSettings` snapshot,
- optional recording path,
- empty detection lists,
- optional geo scores and geo model species set.

The inference loop runs via `Timer.periodic`, reading the latest `windowDuration * sampleRate` samples from the shared `RingBuffer`. Concurrent inference cycles are skipped with `_inferring`.

Detection counting is card-visibility-based:

1. Each inference cycle produces filtered detections.
2. `_currentLiveDetections` is replaced every cycle for UI cards.
3. `_activeCardSpecies` tracks species currently visible as cards.
4. A species that appears when not tracked creates a new `DetectionRecord`.
5. A species that remains visible updates the existing record only if confidence increases.
6. A species that disappears gets a closed `endTimestamp`.
7. Reappearance after disappearance creates a new record.

This means one continuously calling bird is one detection, while gaps create new detections.

Pause stops the inference timer but keeps recording running so audio and wall-clock timestamps stay aligned. Finalization stops recording, closes open detection windows, ends the session, resets controller state, and returns the completed `LiveSession` for saving.

AI caution: if you change detection timestamp logic, test session review offsets, clip playback, Raven exports, and file analysis merging. Timestamps currently represent the start of the analyzed window.

## Session Data Model

`features/live/live_session.dart` defines the persistence model used by every mode.

`LiveSession` fields include:

- identity: `id`, `sessionNumber`, `customName`, `type`.
- timing: `startTime`, `endTime`, `recordedDurationSeconds`.
- detections: list of `DetectionRecord`.
- recording: `recordingPath`.
- settings snapshot: `SessionSettings`.
- review metadata: `annotations`, `trimStartSec`, `trimEndSec`.
- location: `latitude`, `longitude`, `locationName`, `gpsTrack`, `distanceMeters`.
- survey metadata: `transectId`, `observerName`, `stopReason`, `stopReasonValue`.
- weather snapshot.

`DetectionRecord` fields include:

- `scientificName`, `commonName`, `confidence`.
- `timestamp`, optional `endTimestamp`.
- optional `audioClipPath`.
- `source`: `auto`, `manual`, `manualGlobal`, `userSpecified`.
- optional detection `latitude`/`longitude`.
- review fields: `confirmedAt`, `note`, `voiceMemoPath`.

`SessionSettings` snapshots inference and survey/alert settings so exports can explain how detections were produced. Many fields are nullable for legacy session compatibility.

Serialization is JSON with UTC ISO strings for timestamps. Deserializers provide defaults for legacy sessions; keep this pattern when adding fields.

AI caution: `DetectionRecord.audioClipPath`, `confirmedAt`, `note`, and `voiceMemoPath` are mutable by design. Some review and sampler code mutates existing record objects rather than replacing every reference.

## Recording

Key files:

- `features/recording/recording_service.dart`
- `features/recording/audio_file_writer.dart`
- `features/recording/wav_writer.dart`
- `features/recording/flac_encoder.dart`
- `features/recording/audio_decoder.dart`
- `features/recording/native_audio_decoder.dart`

Recording modes:

- `off`: no files.
- `full`: periodic flush from ring buffer to `full.wav` or `full.flac`.
- `detectionsOnly`: save clips around detection events.

File layout:

```text
<documents>/recordings/<sessionId>/
  full.flac or full.wav
  clip_<timestamp>.flac or .wav
  memos/...
```

Full recording flushes every second. `_flushing` prevents overlapping flushes, which is especially important for FLAC encoding and memory behavior. Detection clips wait for post-roll equal to `clipContextSeconds`, then read `windowSeconds + 2 * clipContextSeconds` from the ring buffer.

AI caution: `RecordingService` constructor has `windowSeconds = 3`, and the provider currently passes sample rate and clip context, not window duration. If supporting non-3-second clip windows in new modes, audit this wiring.

## Surveys

Key files:

- `features/survey/survey_controller.dart`
- `features/survey/survey_setup_screen.dart`
- `features/survey/survey_live_screen.dart`
- `features/survey/survey_providers.dart`
- `features/survey/survey_gps_tracker.dart`
- `features/survey/detection_sampler.dart`
- `features/survey/survey_notification.dart`
- `features/survey/survey_alert_engine.dart`
- `features/survey/survey_alert_coordinator.dart`
- `features/survey/alert_throttler.dart`
- `features/survey/species_alert_notifier.dart`

`SurveyController` is a long-running variant of live mode. It composes the same ring buffer, inference wrapper, recording service, and model loading path, then adds GPS, foreground notification, incremental persistence, sampling, and auto-stop.

Survey state:

```text
idle -> loading -> starting -> active -> stopping -> finalized
                         \-> error
```

Survey behavior:

- No pause state; surveys are active or stopped.
- Starts/resumes an existing `LiveSession`.
- Uses `SurveyGpsTracker` to tag detections and store track points.
- Periodically persists session JSON every 30 seconds with a recovery-file write-ahead pattern.
- Updates foreground notification every second.
- Checks battery auto-stop on the persistence cadence.
- Auto-stops on max duration or low battery, storing `SessionStopReason`.
- Simplifies GPS track on finalization.
- Supports manual detections and session annotations while running.

Detection counting is the same card-visibility model as live mode. When records close, `DetectionSampler` may keep or delete the audio clip depending on sampling mode.

`DetectionSampler` modes:

- `all`: keep every clip.
- `topN`: keep the N highest-confidence clips per species.
- `smart`: top-N with spatial/time deduplication, while keeping a minimum number per species.

Sampler invariants:

- Detection records are always kept.
- Only files and `audioClipPath` are removed.
- The sampler mutates `DetectionRecord.audioClipPath` in place.

`SurveyGpsTracker` rejects fixes with poor accuracy, nearby jitter, or implausible speed. It records WGS84 GPS points, computes distance, supports manual one-shot fixes, can seed from existing tracks for resume, and simplifies tracks with Douglas-Peucker.

Survey alerts are split intentionally:

- `SurveyAlertEngine`: pure decision logic.
- `AlertThrottler`: rate limiting / coalescing.
- `SpeciesAlertNotifier`: local notification delivery.
- `SurveyAlertCoordinator`: wires engine, throttler, notifier, and global species history.

AI caution: alert settings are snapshotted at survey start. Do not casually hot-apply alert mode changes mid-survey unless you also update the design/test assumptions.

## Point Count Mode

Point count code lives in:

- `features/point_count/point_count_setup_screen.dart`
- `features/point_count/point_count_live_screen.dart`

Point count is a timed fixed-station workflow using much of the same live infrastructure. Settings include point-count duration and last observer. It produces `SessionType.pointCount` sessions and should be treated as a live-recording mode with fixed metadata and countdown behavior.

When modifying shared live/session behavior, verify point count still starts, records, times out correctly, and saves a session with the right `SessionType`.

## File Analysis

Key files:

- `features/file_analysis/file_analysis_controller.dart`
- `features/file_analysis/file_analysis_screen.dart`
- `features/file_analysis/file_analysis_providers.dart`

`FileAnalysisController` analyzes an existing audio file:

1. Loads the same audio model through `AssetPackService`.
2. Inspects/decodes the file.
3. Uses pure Dart decoders for WAV/FLAC where possible.
4. Uses Android native `MediaCodec` for compressed formats through `NativeAudioDecoder`.
5. Resamples to model sample rate if needed.
6. Slides fixed windows through the audio.
7. Runs inference with temporal pooling disabled.
8. Applies species filtering and geo-model intersection.
9. Merges consecutive windows of the same species into one `DetectionRecord`.
10. Creates a completed `LiveSession` of type `fileUpload`.

File analysis timestamps are based on the selected recording date or current time. `session.recordingPath` points to the source file for review playback. `inferenceRate` is set to 0 because it is not a live timer.

Cancellation sets `_cancelRequested`, stops the analysis loop, and returns to ready state.

AI caution: file analysis uses `endTimestamp` to represent merged continuous detections across windows. If changing merge logic, test overlapping windows and export offsets.

## Explore and Geo Context

Key files:

- `features/explore/explore_providers.dart`
- `features/explore/explore_screen.dart`
- `features/explore/widgets/species_card.dart`
- `features/explore/widgets/species_info_overlay.dart`
- `shared/services/taxonomy_service.dart`
- `shared/services/species_description_service.dart`
- `features/inference/geo_model.dart`

Explore combines:

- current or manual location,
- geo-model scores for all 48 weeks,
- taxonomy metadata,
- localized species names,
- audio-label intersection,
- bundled species descriptions and images.

`exploreSpeciesProvider` returns species expected at the user's current location/week, filtered to species also supported by the audio classifier and normalized so the top current-week score is 100. `geoScoresProvider` returns raw geo scores used by live/survey filters.

`TaxonomyService` parses `assets/models/taxonomy.csv` into an O(1) scientific-name map. Search matches scientific/common/localized/alternative names with token AND semantics and ranking.

`SpeciesDescriptionService` lazily loads gzip JSON descriptions per locale and falls back to English.

AI caution: Explore uses hard-coded probability category strings in `explore_providers.dart`; UI localization may happen elsewhere, but provider-level labels are English.

## History, Review, and Export

Key files:

- `features/history/session_repository.dart`
- `features/history/session_library_screen.dart`
- `features/history/session_review_screen.dart`
- `features/history/session_export.dart`
- `features/history/html_report.dart`
- `features/history/global_species_history.dart`
- `features/history/services/detection_sharing_service.dart`
- `features/history/widgets/*`

`SessionRepository` stores sessions as JSON files:

```text
<documents>/sessions/<sanitized-session-id>.json
```

It can save, load, list, delete one, delete all, count, and compute the next per-type session number. Deleting a session also attempts to delete its recording directory.

`sessionListProvider` lists sessions newest-first and opportunistically backfills `locationName` from the reverse-geocode cache without network calls.

Session Review supports:

- playback through full recordings or clips,
- detection confirmation,
- notes,
- voice memos,
- manual species additions,
- unknown/user-specified detections,
- annotations,
- metadata-only trimming,
- survey maps,
- export.

Exports include combinations of Raven Pro selection tables, CSV, JSON, GPX, annotations, memos, audio, and optional `report.html` ZIP content.

AI caution: trimming is metadata-oriented. The original recording is not destroyed. Exports and review views apply trim windows; session JSON retains trim fields.

## Privacy and Network Behavior

The app's core inference and taxonomy functions are offline. Network access is gated by settings:

- Map tiles: `privacyAllowMapProvider` gates OpenStreetMap tile fetching.
- Reverse geocoding: `privacyAllowReverseGeocodingProvider` gates Nominatim.
- Weather: `privacyAllowWeatherProvider` gates Open-Meteo.

Weather fetches are best-effort and must never block saving. `WeatherService` returns `null` when privacy is off, network fails, response is malformed, or timeout occurs. It caches by coarse 0.1 degree cell and hour in memory and persists a coarser cell cache for 6 hours.

Reverse geocoding caches coarse cell names in `SharedPreferences` using `PrefKeys.reverseGeocodeCachePrefix`.

AI caution: before adding any network request, add an explicit privacy gate and make failures non-fatal unless the user has explicitly initiated that request.

## Spectrogram

Key files:

- `features/spectrogram/fft_processor.dart`
- `features/spectrogram/color_maps.dart`
- `features/spectrogram/spectrogram_painter.dart`
- `features/spectrogram/spectrogram_widget.dart`
- `features/history/widgets/clip_player_sheet.dart`
- `features/history/widgets/session_review_widgets.dart`

Live spectrogram rendering reads from `RingBuffer`, performs FFT processing, maps magnitudes through selected color maps, and paints in the UI. Settings control FFT size, duration, visible max frequency, dB floor/ceiling, log amplitude, and rendering quality.

Session review and clip playback build spectrogram views from decoded files rather than live ring-buffer samples.

AI caution: spectrogram hot paths should avoid allocations. Prefer existing `readLastInto` and cached buffers when changing live rendering.

## Localization

Localization is generated from ARB files in `lib/l10n/` using `l10n.yaml`. The generated class is `AppLocalizations`.

Current locales include:

- `en`
- `de`
- `fr`
- `es`
- `cs`
- `pt`
- `it`

All user-facing UI strings should use ARB keys. Existing code has some provider-level English strings and comments; new visible text should go through ARB unless it is test-only or developer-only.

After changing ARB files, run:

```bash
flutter gen-l10n
```

## Tests

Tests mirror `lib/` under `test/`. Integration tests live in `integration_test/`.

Useful test targets by subsystem:

- Audio: `test/features/audio/*`
- Inference: `test/features/inference/*`
- File analysis: `test/features/file_analysis/*`
- Recording: `test/features/recording/*`
- Survey: `test/features/survey/*`
- History/export: `test/features/history/*`
- Shared providers/models/widgets: `test/shared/*`

Run broad validation with:

```bash
flutter test
flutter analyze
```

Integration tests require a device and real model assets:

```bash
flutter test integration_test/
```

AI caution: some tests/docs appear to mention older dependency names or counts. Trust `pubspec.yaml` and the current test tree over prose when they disagree.

## Common Change Recipes

### Add a Persisted Setting

1. Add key to `PrefKeys`.
2. Add provider to `settings_providers.dart` using the correct notifier.
3. Wire controls in `settings_screen.dart` or the relevant setup screen.
4. Snapshot the value in `SessionSettings` if it affects produced detections or exports.
5. Hot-apply to active controllers only if existing behavior supports mid-session changes.
6. Add/update provider tests.

### Add a Field to Session JSON

1. Add field to `LiveSession`, `DetectionRecord`, `SessionAnnotation`, or `SessionSettings`.
2. Add `fromJson` default for legacy data.
3. Add `toJson` only when non-null/non-default if the pattern in that model does so.
4. Update exports if the field is scientifically or review-relevant.
5. Update `session_repository_test.dart` or model tests.

### Change Detection Logic

Audit all of these:

- `LiveController._runInference`
- `SurveyController._runInference`
- `FileAnalysisController.analyze`
- `SessionReviewScreen` grouping/timeline behavior
- `session_export.dart`
- alert engine/coordinator if first-in-session semantics change
- tests for live sessions, survey sessions, file analysis, exports

### Add a New Session Type

1. Add to `SessionType`.
2. Add icon/color/name helpers in `shared/utils/session_type_visuals.dart`.
3. Update home/session-library navigation.
4. Ensure `SessionRepository.nextSessionNumber()` works automatically.
5. Add display/export handling.
6. Add tests for JSON round-trip and library display.

### Add Network-Backed Feature

1. Add privacy setting and UI copy.
2. Default it to false for new installs unless policy explicitly allows otherwise.
3. Short-circuit when disabled.
4. Add timeout.
5. Cache when reasonable.
6. Treat failure as non-fatal.
7. Add tests with injectable HTTP client where possible.

## Architectural Invariants

- ONNX model parameters come from `model_config.json`; avoid hardcoding tensor names or label file formats.
- Load model files through `AssetPackService.resolveModelPath()`.
- Do not pass large ONNX byte arrays between isolates or providers.
- Keep audio data bounded in `RingBuffer`; do not accumulate raw audio in memory for long sessions.
- Inference confidence thresholds in settings are 0-100; model/post-processing thresholds are 0.0-1.0.
- Detection timestamps represent the start of the analyzed window.
- Continuous live/survey detections are merged by card visibility until disappearance.
- Survey persistence must remain crash-resistant and non-blocking.
- Network calls must honor privacy gates.
- Session deserialization must remain backward-compatible.
- User-created review metadata must survive round-trip JSON and exports.
- Deleting a session should delete associated recordings when possible.
- UI text should be localized through ARB.

## Files Most Likely to Matter

```text
lib/main.dart
lib/app.dart
lib/core/constants/app_constants.dart
lib/core/services/asset_pack_service.dart
lib/core/services/location_service.dart
lib/shared/providers/app_providers.dart
lib/shared/providers/settings_providers.dart
lib/features/audio/audio_capture_service.dart
lib/features/audio/ring_buffer.dart
lib/features/inference/inference_service.dart
lib/features/inference/inference_isolate.dart
lib/features/inference/species_filter.dart
lib/features/live/live_controller.dart
lib/features/live/live_session.dart
lib/features/live/live_providers.dart
lib/features/survey/survey_controller.dart
lib/features/survey/detection_sampler.dart
lib/features/survey/survey_gps_tracker.dart
lib/features/survey/survey_alert_engine.dart
lib/features/file_analysis/file_analysis_controller.dart
lib/features/explore/explore_providers.dart
lib/shared/services/taxonomy_service.dart
lib/features/history/session_repository.dart
lib/features/history/session_review_screen.dart
lib/features/history/session_export.dart
android/app/src/main/kotlin/com/birdnet/birdnet_live/MainActivity.kt
android/app/build.gradle
assets/models/model_config.json
```

## Known Local Tooling Notes

In this workspace, `rg` and `git status` may fail because of Windows permissions or Git LFS clean-filter access errors around large model assets. Use PowerShell-native `Get-ChildItem`, `Get-Content`, and `Select-String` as fallbacks when necessary.
