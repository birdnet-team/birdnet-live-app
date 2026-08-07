// =============================================================================
// Live Controller — Orchestrates the real-time identification pipeline
// =============================================================================
//
// The central coordinator for Live Mode.  Manages the complete lifecycle:
//
//   1. **Model loading** — loads model config, ONNX bytes, and labels from
//      Flutter assets, then initializes the inference isolate.
//   2. **Inference loop** — timer-based, reads audio from the ring buffer
//      at the configured inference rate, runs classification, and
//      accumulates detections.
//   3. **Session management** — creates a [LiveSession] on start, records
//      detections, optionally triggers recording, finalizes on stop.
//   4. **Playback** — uses `just_audio` to play back detection audio clips.
//
// ### State machine
//
// ```
//   idle ──loadModel()──▶ loading ──(success)──▶ ready
//                                  ──(error)───▶ error
//   ready ──startSession()──▶ active
//   active ──pauseSession()──▶ paused
//   paused ──resumeSession()──▶ active
//   active|paused ──finalizeSession()──▶ ready
// ```
//
// ### Threading
//
// All ONNX inference runs in a background isolate via [InferenceIsolate].
// The controller itself lives on the main isolate and communicates with
// the inference isolate through typed messages.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/asset_pack_service.dart';
import '../../core/services/memory_monitor.dart';
import '../audio/ring_buffer.dart';
import '../announcements/announcements_controller.dart'
    show AnnouncementDetection;
import '../inference/advanced_pooling_params.dart';
import '../inference/detection_accumulator.dart';
import '../inference/detection_clip_writer.dart';
import '../inference/inference_isolate.dart';
import '../inference/inference_window_driver.dart';
import '../inference/model_config.dart';
import '../inference/models/detection.dart';
import '../inference/species_filter.dart';
import '../inference/species_ignore_filter.dart';
import '../recording/recording_service.dart';
import 'live_session.dart';

// =============================================================================
// State
// =============================================================================

/// Lifecycle state of the live identification pipeline.
enum LiveState {
  /// No model loaded.  Call [LiveController.loadModel].
  idle,

  /// Model is being loaded from assets.
  loading,

  /// Model loaded, ready to start a session.
  ready,

  /// Actively capturing + inferring.
  active,

  /// Session paused — capture stopped but session kept alive.
  paused,

  /// An error occurred.
  error,
}

// =============================================================================
// Controller
// =============================================================================

/// Orchestrates model loading, inference loop, recording, and session
/// management for Live Mode.
///
/// Designed to be held by a Riverpod [StateNotifier] that exposes
/// [LiveControllerState] to the widget tree.
class LiveController {
  LiveController({required this.ringBuffer, required this.recordingService});

  /// Shared ring buffer for audio samples.
  final RingBuffer ringBuffer;

  /// Recording service for saving audio.
  final RecordingService recordingService;

  // ── Internal state ────────────────────────────────────────────────────

  final InferenceIsolate _isolate = InferenceIsolate();
  final AudioPlayer _player = AudioPlayer();
  ModelConfig? _config;
  LiveSession? _session;
  late final InferenceWindowDriver _windowDriver = InferenceWindowDriver(
    ringBuffer: ringBuffer,
    debugLabel: 'LiveController',
  );
  LiveState _state = LiveState.idle;
  String? _errorMessage;

  /// The load currently in flight, or null when none is.  Shared by every
  /// concurrent [loadModel] caller so the main-menu warm-up and the Live
  /// screen can never start two loads of the same model.  See [loadModel].
  Future<void>? _loadFuture;

  /// When the current recording segment started.
  DateTime? _segmentStart;

  /// All detections from the current session (newest first for history).
  final List<DetectionRecord> _sessionDetections = [];

  /// Current live detections — replaced each inference cycle.
  ///
  /// One entry per species, sorted by descending confidence.
  /// This is the list shown in the UI (like the PWA's renderDetections).
  List<DetectionRecord> _currentLiveDetections = const [];

  /// Latest batch of detections from the most recent inference cycle.
  List<Detection> _latestDetections = const [];

  /// Whether an inference cycle is currently in progress.
  bool _inferring = false;

  /// Monotonic generation used to discard stale inference results after
  /// session lifecycle transitions.
  int _sessionGeneration = 0;

  /// Inference cycle counter for periodic memory logging.
  int _inferenceCycleCount = 0;

  /// Geo-model scores for species filtering (set at session start).
  Map<String, double>? _geoScores;

  /// All scientific names in the geo-model's label file.
  ///
  /// When set, detections for species absent from the geo-model are always
  /// removed regardless of the active [_filterMode].  This ensures the live
  /// screen only shows species both models know about.
  Set<String>? _geoModelSpeciesNames;

  /// Active species filter mode for the current session.
  SpeciesFilterMode _filterMode = SpeciesFilterMode.off;

  /// Geo-model threshold for the current session.
  double _geoThreshold = 0.03;

  /// Whether per-detection audio clips should be saved.
  bool _saveDetectionClips = false;

  /// Live-tunable confidence threshold (0–100 scale). Captured at
  /// session start; updated by [setConfidenceThreshold] without
  /// restarting the inference timer so a mid-session settings change is
  /// picked up on the next cycle.
  int _confidenceThreshold = 50;

  /// Live-tunable sensitivity (typically 0.5–1.5). Shifts the sigmoid
  /// horizontally in logit space — see [PostProcessor.applySensitivity].
  /// Updated by [setSensitivity] mid-session without restart.
  double _sensitivity = 1.0;

  /// Species currently present in the active inference result.
  ///
  /// Maps scientific name → active [DetectionRecord] in [_sessionDetections].
  /// A species is added when it first appears in inference results and
  /// removed when it drops out.  Re-appearance after removal creates a
  /// brand-new detection record for session review.
  ///
  /// This intentionally stays tied to inference presence, not UI row
  /// visibility. The optional all-species display can keep old rows visible,
  /// but [endTimestamp] still marks when the species stopped being actively
  /// detected.
  DetectionAccumulator? _accumulator;

  /// Clip writes run outside the inference critical path.
  late final DetectionClipWriter _clipWriter = DetectionClipWriter(
    recordingService: recordingService,
    debugLabel: 'LiveController',
    accumulatorOf: () => _accumulator,
    isCurrentSession: () => _session != null,
    onRecordsChanged: () {
      _syncSessionDetections();
      _notifyListeners();
    },
  );

  /// Maximum number of in-memory detections (older entries are still
  /// persisted in the [LiveSession] object).
  static const int _maxInMemoryDetections = 1000;

  // ── Getters ───────────────────────────────────────────────────────────

  /// Current pipeline state.
  LiveState get state => _state;

  /// Error message (if state is [LiveState.error]).
  String? get errorMessage => _errorMessage;

  /// The active model configuration.
  ModelConfig? get config => _config;

  /// The active session (if any).
  LiveSession? get session => _session;

  /// All detection records from the current session (newest first).
  List<DetectionRecord> get sessionDetections =>
      List.unmodifiable(_sessionDetections);

  /// Current live detections for display — replaced each cycle.
  ///
  /// One entry per species, sorted by descending confidence.
  List<DetectionRecord> get currentLiveDetections =>
      List.unmodifiable(_currentLiveDetections);

  /// Latest detections from the most recent inference cycle.
  List<Detection> get latestDetections => _latestDetections;

  /// Whether inference is currently running (within an inference cycle).
  bool get isInferring => _inferring;

  // ── Callbacks (set by provider layer) ─────────────────────────────────

  /// Called whenever the controller state changes.
  void Function()? onStateChanged;

  /// Called once per inference cycle with the current cycle's full set
  /// of filtered detections (one record per species, with that cycle's
  /// score). Used by the Announcements feature to feed the spoken-
  /// detection pipeline. Submitting every cycle (rather than only
  /// newly-appeared species) lets the controller pick the peak score
  /// for each species; its per-species streak silence and global
  /// min-interval gates prevent over-announcing. Errors thrown by the
  /// callback are caught and ignored — TTS hiccups must never affect
  /// inference.
  void Function(List<AnnouncementDetection> batch)? onFreshDetections;

  /// Called when a fresh session starts (at the bottom of
  /// [startSession] after the session is wired up). Used by the
  /// Announcements feature to reset its per-session bookkeeping
  /// (startup grace, anti-repeat, etc.).
  void Function()? onSessionStarted;

  // ── Model loading ─────────────────────────────────────────────────────

  /// Load the model from Flutter assets.
  ///
  /// On first launch the ONNX model bytes are extracted from the APK asset
  /// bundle and written to the app's documents directory.  Subsequent
  /// launches skip this step and read directly from disk.
  ///
  /// Only the file *path* is passed to the inference isolate — this avoids
  /// serializing ~259 MB through the isolate port, which would
  /// triple peak memory usage.
  ///
  /// Safe to call concurrently and repeatedly.  The main menu warms the model
  /// up in the background, so by the time the Live screen opens a load may
  /// already be in flight, already done, or already failed — and the retry
  /// button can land on top of any of those.  All of them are handled here so
  /// that callers never have to inspect [state] first:
  ///
  ///   * a load already running  → join it; never start a second one
  ///   * already `ready`         → return immediately
  ///   * `active` / `paused`     → return immediately; reloading the model out
  ///                               from under a running session would tear
  ///                               down the isolate it is inferring on
  ///   * `idle` / `error`        → load (or retry) now
  ///
  /// The returned future always completes *after* the model has settled into
  /// [LiveState.ready] or [LiveState.error] — awaiting it is enough to know
  /// the load is over, so callers can `await loadModel()` and then check
  /// [state] rather than racing it.
  Future<void> loadModel() {
    // A load is already running — hand every caller the *same* future so they
    // all resume together when it settles.
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;

    // Nothing to do: the model is loaded, or a session is using it.
    if (_state == LiveState.ready ||
        _state == LiveState.active ||
        _state == LiveState.paused) {
      return Future.value();
    }

    // Publish the future *before* running any of the load body, so a listener
    // woken by the `loading` notification below re-enters into the branch
    // above instead of kicking off a duplicate load.
    final completer = Completer<void>();
    _loadFuture = completer.future;
    unawaited(_runLoadModel(completer));
    return completer.future;
  }

  /// The actual load.  Always completes [completer] — never leaves an awaiter
  /// of [loadModel] stranded, even if a listener throws.
  Future<void> _runLoadModel(Completer<void> completer) async {
    try {
      _state = LiveState.loading;
      _errorMessage = null;
      _notifyListeners();

      // Load config JSON.
      debugPrint('[LiveController] loading model config …');
      final configJson = await rootBundle.loadString(
        AppConstants.modelConfigAssetPath,
      );
      final fullConfig = json.decode(configJson) as Map<String, dynamic>;
      _config = ModelConfig.fromJson(
        fullConfig['audioModel'] as Map<String, dynamic>,
      );
      debugPrint('[LiveController] config loaded: ${_config!.onnx.modelFile}');

      // Resolve the model path: install-time asset pack (Play Store AAB)
      // or fallback to extracting from rootBundle (sideload APK).
      final modelFilePath = await AssetPackService.resolveModelPath(
        fileName: _config!.onnx.modelFile,
        version: _config!.version,
      );
      debugPrint('[LiveController] model on disk: $modelFilePath');

      // Load labels CSV.
      final labelsAssetPath =
          '${AppConstants.modelAssetsDir}/${_config!.labels.file}';
      final labelsCsv = await rootBundle.loadString(labelsAssetPath);
      debugPrint('[LiveController] labels loaded (${labelsCsv.length} chars)');

      final blacklistFile = _config!.scoreBlacklistFile;
      final scoreBlacklistJson =
          blacklistFile == null
              ? null
              : await rootBundle.loadString(
                '${AppConstants.modelAssetsDir}/$blacklistFile',
              );

      // Start isolate with file path (not bytes).
      await _isolate.start(
        modelFilePath: modelFilePath,
        labelsCsv: labelsCsv,
        config: _config!,
        scoreBlacklistJson: scoreBlacklistJson,
      );

      debugPrint('[LiveController] isolate ready');
      _state = LiveState.ready;
    } catch (e, st) {
      debugPrint('[LiveController] loadModel error: $e\n$st');
      _state = LiveState.error;
      _errorMessage = e.toString();
    } finally {
      // Settle in a `finally` so the controller can never wedge: if anything
      // escaped the block above — a listener throwing out of the `loading`
      // notification, say — an uncompleted completer would leave every future
      // loadModel() caller joining a future that never resolves.
      if (_state == LiveState.loading) {
        _state = LiveState.error;
        _errorMessage ??= 'Model load interrupted';
      }
      // Clear before notifying: a listener that reacts to `error` by calling
      // loadModel() again must be able to start a fresh attempt, and complete
      // before notifying so an awaiter is never stranded by a throwing
      // listener.
      _loadFuture = null;
      if (!completer.isCompleted) completer.complete();
    }

    _notifyListeners();
  }

  // ── Session lifecycle ─────────────────────────────────────────────────

  /// Start a new live identification session.
  ///
  /// [windowDuration] — analysis window in seconds.
  /// [inferenceRate] — how often to run inference (Hz).
  /// [confidenceThreshold] — minimum confidence (0–100 scale).
  /// [speciesFilterMode] — species filter setting.
  /// [recordingMode] — recording behavior.
  /// [recordingFormat] — audio file format ('wav' or 'flac').
  /// [geoScores] — optional geo-model predictions for species filtering.
  /// [geoThreshold] — minimum geo score for the geoExclude filter.
  /// [geoModelSpeciesNames] — all scientific names in the geo-model labels;
  ///   when provided, detections for species absent from the geo-model are
  ///   always removed regardless of the active filter mode.
  /// [poolingWindows] — number of consecutive inference windows to pool
  ///   over; pass `null` to use the model-config default.
  Future<void> startSession({
    required int windowDuration,
    required double inferenceRate,
    required int confidenceThreshold,
    required String speciesFilterMode,
    required RecordingMode recordingMode,
    String recordingFormat = 'flac',
    Map<String, double>? geoScores,
    double geoThreshold = 0.03,
    Set<String>? geoModelSpeciesNames,
    int? poolingWindows,
    String poolingMode = 'adaptive_lme_peak',
    double? poolingMaxAgeSeconds,
    AdvancedPoolingParams advancedPooling = AdvancedPoolingParams.none,
    double sensitivity = 1.0,
    SpeciesIgnoreSettings ignoreSettings = const SpeciesIgnoreSettings(),
    Set<String> ignoredSpeciesNames = const <String>{},
    double? gainLinear,
    double? highPassHz,
    int? targetDurationSeconds,
    double? latitude,
    double? longitude,
    bool clearRingBuffer = true,
  }) async {
    if (_state != LiveState.ready) return;

    final sessionId = DateTime.now().toIso8601String().replaceAll(':', '-');

    _session = LiveSession(
      id: sessionId,
      startTime: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      settings: SessionSettings(
        windowDuration: windowDuration,
        confidenceThreshold: confidenceThreshold,
        inferenceRate: inferenceRate,
        speciesFilterMode: speciesFilterMode,
        sensitivity: sensitivity,
        ignoreBirds: ignoreSettings.ignoreBirds,
        ignoreMammals: ignoreSettings.ignoreMammals,
        ignoreAmphibians: ignoreSettings.ignoreAmphibians,
        ignoreInsects: ignoreSettings.ignoreInsects,
        ignoreCommonGeoScoreCutoff: ignoreSettings.commonGeoScoreCutoff,
        poolingMode: poolingMode,
        poolingWindows: poolingWindows,
        poolingMaxAgeSeconds: poolingMaxAgeSeconds,
        poolingAlpha: advancedPooling.alpha,
        poolingMinSupportWindows: advancedPooling.minSupportWindows,
        poolingSupportThresholdFraction:
            advancedPooling.supportThresholdFraction,
        poolingSupportThresholdFloor: advancedPooling.supportThresholdFloor,
        poolingVeryHighImmediateThreshold:
            advancedPooling.veryHighImmediateThreshold,
        gainLinear: gainLinear,
        highPassHz: highPassHz,
        recordingMode: recordingMode.name,
        recordingFormat: recordingFormat,
        targetDurationSeconds: targetDurationSeconds,
      ),
    );
    final startingSession = _session!;

    _sessionDetections.clear();
    _latestDetections = const [];
    _currentLiveDetections = const [];
    _accumulator = DetectionAccumulator(
      sessionStart: startingSession.startTime,
      records: startingSession.detections,
    );
    _clipWriter.reset();
    _sessionGeneration++;
    _confidenceThreshold = confidenceThreshold;
    _sensitivity = sensitivity;
    _isolate.setMaxPoolWindows(poolingWindows);
    _isolate.setMaxPoolAgeSeconds(poolingMaxAgeSeconds);
    _isolate.setPoolingMode(poolingMode);
    _isolate.applyAdvancedPoolingParams(advancedPooling);
    _isolate.setIgnoredSpeciesNames(ignoredSpeciesNames);
    _isolate.resetPooling();
    _inferenceCycleCount = 0;
    if (clearRingBuffer) {
      ringBuffer.clear();
    }
    _windowDriver.start(
      sampleRate: _config?.audio.sampleRate ?? AppConstants.sampleRate,
      windowDurationSeconds: windowDuration,
      inferenceRateHz: inferenceRate,
      // A caller that kept the buffer (ARU, which starts capture itself and
      // then loads the model) has been recording this session all along, so
      // that audio is analyzed rather than skipped.
      useBufferedAudio: !clearRingBuffer,
    );

    _notifyListeners();

    // Start memory monitoring for this session (debug builds only).
    if (kDebugMode) {
      MemoryMonitor.startPeriodic(intervalSeconds: 10);
      MemoryMonitor.logOnce(tag: 'session-start');
    }

    // Store geo-filter state for this session.
    _geoScores = geoScores;
    _geoThreshold = geoThreshold;
    _geoModelSpeciesNames = geoModelSpeciesNames;
    _filterMode = switch (speciesFilterMode) {
      'geoExclude' => SpeciesFilterMode.geoExclude,
      'geoMerge' => SpeciesFilterMode.geoMerge,
      'customList' => SpeciesFilterMode.customList,
      _ => SpeciesFilterMode.off,
    };

    // Recording: respect the user’s choice (full / clips / off).
    _saveDetectionClips = recordingMode == RecordingMode.detectionsOnly;
    // Clips cover the window the model scored, whichever length this session
    // analyzes with.
    recordingService.setWindowSeconds(windowDuration);
    if (recordingMode != RecordingMode.off) {
      final dir = await recordingService.startRecording(
        sessionId: sessionId,
        mode: recordingMode,
        format: recordingFormat,
      );
      if (_session != startingSession) {
        await recordingService.stopRecording();
        return;
      }
      startingSession.recordingPath = dir;
    }

    if (_session != startingSession) return;

    _state = LiveState.active;
    onSessionStarted?.call();
    _notifyListeners();

    startingSession.startSegment();
    _segmentStart = DateTime.now();

    debugPrint(
      '[LiveController] session started '
      '(window=${windowDuration}s, rate=${inferenceRate}Hz, '
      'threshold=$confidenceThreshold)',
    );

    _armNextInference();
  }

  /// Pause the current session.
  ///
  /// Stops the inference timer but keeps the recording running so the
  /// audio file stays continuous and detection timestamps (which use
  /// wall-clock) remain in sync with audio time across the pause.
  /// The detection list is preserved.
  Future<void> pauseSession() async {
    if (_state != LiveState.active || _session == null) return;

    _windowDriver.cancelPendingWakeup();

    _sessionGeneration++;
    for (final closed in _accumulator?.closeAll() ?? const <DetectionRecord>[]) {
      _clipWriter.forget(closed);
    }
    _syncSessionDetections();
    _closeRecordingSegment();

    _state = LiveState.paused;
    _notifyListeners();

    debugPrint('[LiveController] session paused');
  }

  /// Resume a previously paused session.
  ///
  /// Re-starts the inference timer with the same settings. Recording was
  /// not stopped on pause, so it keeps writing the same file.
  Future<void> resumeSession() async {
    if (_state != LiveState.paused || _session == null) return;

    final settings = _session!.settings;

    _sessionGeneration++;
    _state = LiveState.active;
    _notifyListeners();

    _session?.startSegment();
    _segmentStart = DateTime.now();

    debugPrint('[LiveController] session resumed');

    // Audio is discontinuous across a pause, so the pooling buffer must not
    // carry pre-pause windows into post-resume decisions: they would smooth
    // scores across the gap and date a resumed detection inside it.
    _isolate.resetPooling();

    // Start a fresh audio schedule so paused audio is not drained as a
    // backlog after resuming.
    _windowDriver.start(
      sampleRate: _config?.audio.sampleRate ?? AppConstants.sampleRate,
      windowDurationSeconds: settings.windowDuration,
      inferenceRateHz: settings.inferenceRate,
    );
    _armNextInference();
  }

  /// Finalize and stop the current session completely.
  ///
  /// Called when leaving the live screen.  Returns the completed
  /// [LiveSession] for persistence, or null if there is no session.
  Future<LiveSession?> finalizeSession() async {
    if (_session == null) return null;

    // If still active, stop the schedule first.
    _windowDriver.cancelPendingWakeup();

    _sessionGeneration++;
    _closeRecordingSegment();

    // Finish already-requested post-roll clips while capture and recording
    // are still available. These tasks never block inference or UI updates.
    await _clipWriter.drain();

    // Stop recording.
    final recordingPath = await recordingService.stopRecording();
    if (recordingPath != null) {
      _session!.recordingPath = recordingPath;
    }

    // Stop memory monitoring (debug builds only).
    if (kDebugMode) {
      MemoryMonitor.logOnce(tag: 'session-end');
      MemoryMonitor.printSummary();
      MemoryMonitor.stop();
    }

    // The shared accumulator closes at the last supporting audio-window end,
    // matching File Analysis rather than extending to wall-clock stop time.
    _accumulator?.closeAll();
    _syncSessionDetections();

    _session!.end();
    final completedSession = _session!;

    // Reset session state.
    _session = null;
    _sessionDetections.clear();
    _latestDetections = const [];
    _currentLiveDetections = const [];
    _accumulator = null;
    _windowDriver.stop();
    _clipWriter.reset();

    _state = LiveState.ready;
    _notifyListeners();

    debugPrint('[LiveController] session finalized');
    return completedSession;
  }

  // ── Playback ──────────────────────────────────────────────────────────

  /// Play back the audio clip for a detection.
  ///
  /// [clipPath] is the file path to the WAV clip.
  Future<void> playClip(String clipPath) async {
    try {
      await _player.setFilePath(clipPath);
      await _player.play();
    } catch (_) {
      // Playback failure is non-fatal.
    }
  }

  /// Stop any ongoing playback.
  Future<void> stopPlayback() async {
    await _player.stop();
  }

  // ── Live setting hot-apply ────────────────────────────────────────────

  /// Update the confidence threshold (0–100 scale) used by the inference
  /// loop. Takes effect on the next cycle so a mid-session settings
  /// change is picked up without restarting the timer.
  ///
  /// The original `SessionSettings.confidenceThreshold` recorded at
  /// session start is intentionally left untouched — it remains a
  /// snapshot of what the user chose when they hit start, so that
  /// detections later in the session can still be compared against the
  /// initial threshold for context.
  void setConfidenceThreshold(int value) {
    _confidenceThreshold = value;
  }

  /// Update the sigmoid-shift sensitivity used by inference. Takes
  /// effect on the next cycle. The original session-start value is
  /// preserved in `SessionSettings` for context.
  void setSensitivity(double value) {
    _sensitivity = value;
  }

  /// Hot-apply the inference-time species mask to the next audio window and
  /// every raw window already waiting in the temporal pooling buffer.
  void setSpeciesIgnoreFilter({
    required Set<String> scientificNames,
    required Map<String, double>? geoScores,
  }) {
    _isolate.setIgnoredSpeciesNames(scientificNames);
    _geoScores = geoScores;
  }

  /// Update the score-pooling window count and forward to the inference
  /// isolate. Pass `null` to use the model-config default.
  void setPoolingWindows(int? value) {
    _isolate.setMaxPoolWindows(value);
  }

  /// Update the score-pooling real-time age gate and forward to the inference
  /// isolate. Pass `null` to use the model-config default.
  void setPoolingMaxAgeSeconds(double? value) {
    _isolate.setMaxPoolAgeSeconds(value);
  }

  /// Update the score-pooling mode and forward to the inference isolate.
  /// Recognized values: `'off' | 'average' | 'max' | 'lme'`.
  void setPoolingMode(String value) {
    _isolate.setPoolingMode(value);
  }

  /// Update the advanced temporal-pooling overrides (LME alpha + support gate)
  /// and forward to the inference isolate. Takes effect on the next cycle.
  void setAdvancedPoolingParams(AdvancedPoolingParams params) {
    _isolate.applyAdvancedPoolingParams(params);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  /// Dispose of all resources.
  Future<void> dispose() async {
    _windowDriver.stop();
    await _isolate.stop();
    await _player.dispose();
    recordingService.dispose();
  }

  // ── Private ───────────────────────────────────────────────────────────

  /// Run a single inference cycle.
  Future<void> _runInference() async {
    if (_inferring || !_isolate.isRunning) {
      debugPrint(
        '[LiveController] _runInference skipped '
        '(inferring=$_inferring, running=${_isolate.isRunning})',
      );
      return;
    }

    final window = _windowDriver.takeReadyWindow();
    if (window == null) return;

    _inferring = true;
    _inferenceCycleCount++;
    final generation = _sessionGeneration;

    // Snapshot the live-tunable threshold for this cycle so a mid-cycle
    // setter call can't half-apply.
    final confidenceThreshold = _confidenceThreshold;
    final sensitivity = _sensitivity;

    try {
      final windowDuration = window.windowDurationSeconds;
      final audioReadAt = window.endTimestamp;
      final windowTimestamp = window.startTimestamp;
      final audioSamples = window.samples;

      // Log memory every 10 cycles (~10s at 1Hz) to track growth.
      if (kDebugMode && _inferenceCycleCount % 10 == 0) {
        MemoryMonitor.logOnce(tag: 'cycle-$_inferenceCycleCount');
      }

      debugPrint('[LiveController] running inference …');
      final detections = await _isolate.infer(
        audioSamples,
        windowSeconds: windowDuration,
        sensitivity: sensitivity,
        confidenceThreshold: confidenceThreshold / 100.0,
        timestamp: windowTimestamp,
      );

      if (generation != _sessionGeneration) {
        return;
      }

      debugPrint(
        '[LiveController] inference done — '
        '${detections.length} detections '
        '(threshold=${confidenceThreshold / 100.0})',
      );

      _latestDetections = detections;

      // Apply species filter (geo-model or custom list).
      final speciesFiltered = SpeciesFilter.apply(
        detections: detections,
        mode: _filterMode,
        geoScores: _geoScores,
        geoThreshold: _geoThreshold,
        confidenceThreshold: confidenceThreshold / 100.0,
      );

      // Restrict to the intersection of both models: only keep detections
      // for species the geo-model also knows, regardless of filter mode.
      final geoNames = _geoModelSpeciesNames;
      final filteredDetections =
          geoNames == null
              ? speciesFiltered
              : speciesFiltered
                  .where((d) => geoNames.contains(d.species.scientificName))
                  .toList();

      // Update the live detection list (replaced each cycle, like the PWA).
      // Each species appears at most once with its current score.
      _currentLiveDetections = [
        for (final d in filteredDetections) DetectionRecord.fromDetection(d),
      ];

      if (_session != null && _accumulator != null) {
        final cycle = _accumulator!.processCycle(
          detections: filteredDetections,
          windowEnd: audioReadAt,
        );
        for (final closed in cycle.closedRecords) {
          _clipWriter.forget(closed);
        }
        _syncSessionDetections();

        // Detection existence, score, and timestamps are now published before
        // post-roll capture or file encoding begins. Recording can enrich the
        // canonical record later but cannot alter inference cadence. The clip
        // is cut from this window's samples, so a late write still stores the
        // audio `clipTimestamp` claims it holds.
        if (_saveDetectionClips) {
          _clipWriter.requestClips(
            changes: cycle.changes,
            clipTimestamp: windowTimestamp,
            windowEndSample: window.windowEndSample,
          );
        }

        // Hand the current cycle's detections to the Announcements
        // pipeline (no-op when the feature is disabled). We submit the
        // full per-cycle list, not just newly-appeared species: the
        // first sighting is often near the confidence floor, while the
        // peak score arrives a few cycles later while the detection window is
        // still active. The controller's per-species streak silence and
        // global min-interval gates dedup re-submissions, and it picks
        // the highest score per species inside the batch, so this
        // surfaces the strongest call rather than the marginal one.
        final cb = onFreshDetections;
        if (cb != null && filteredDetections.isNotEmpty) {
          final batch = <AnnouncementDetection>[
            for (final d in filteredDetections)
              AnnouncementDetection(
                speciesId: d.species.scientificName,
                displayName: d.species.commonName,
                score: d.confidence,
                at: d.timestamp ?? DateTime.now(),
              ),
          ];
          try {
            cb(batch);
          } catch (_) {
            /* Announcements errors must never escape. */
          }
        }
      }

      // Always notify — even when the list becomes empty (species dropped
      // below threshold), so the current-vocalizing UI clears stale rows.
      _notifyListeners();
    } catch (e, st) {
      // Inference errors are logged but don't stop the session.
      debugPrint('[LiveController] inference ERROR: $e\n$st');
      _errorMessage = e.toString();
    } finally {
      _inferring = false;
    }
  }

  void _closeRecordingSegment() {
    final start = _segmentStart;
    final session = _session;
    if (start == null || session == null) return;
    final secs = DateTime.now().difference(start).inSeconds;
    if (secs > 0) session.accumulateRecordedSeconds(secs);
    session.closeSegment();
    _segmentStart = null;
  }

  /// Arm a one-shot wakeup for the next complete sample-anchored window.
  void _armNextInference() {
    _windowDriver.arm(
      isActive: () => _state == LiveState.active,
      runCycle: _runInference,
    );
  }

  void _syncSessionDetections() {
    final records = _session?.detections ?? const <DetectionRecord>[];
    _sessionDetections
      ..clear()
      ..addAll(records.reversed.take(_maxInMemoryDetections));
  }

  /// Clear the session state to prepare for a fresh run.
  void clearSessionState() {
    _sessionGeneration++;
    _session = null;
    _segmentStart = null;
    _errorMessage = null;
    _sessionDetections.clear();
    _latestDetections = const [];
    _currentLiveDetections = const [];
    _accumulator = null;
    _windowDriver.stop();
    _clipWriter.reset();
    _notifyListeners();
  }

  /// Notify the provider layer of state changes.
  void _notifyListeners() {
    onStateChanged?.call();
  }
}
