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
import '../inference/inference_isolate.dart';
import '../inference/model_config.dart';
import '../inference/models/detection.dart';
import '../inference/species_filter.dart';
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
  Timer? _inferenceTimer;
  LiveState _state = LiveState.idle;
  String? _errorMessage;

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

  /// Species currently shown on the live screen (have visible cards).
  ///
  /// Maps scientific name → active [DetectionRecord] in [_sessionDetections].
  /// A species is added when it first appears in inference results and
  /// removed when it drops out.  Re-appearance after removal creates a
  /// brand-new detection record for session review.
  final Map<String, DetectionRecord> _activeCardSpecies = {};

  /// Maximum number of in-memory detections (older entries are still
  /// persisted in the [LiveSession] object).
  static const int _maxInMemoryDetections = 500;

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
  Future<void> loadModel() async {
    if (_state == LiveState.loading || _state == LiveState.ready) return;

    _state = LiveState.loading;
    _errorMessage = null;
    _notifyListeners();

    try {
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

      // Start isolate with file path (not bytes).
      await _isolate.start(
        modelFilePath: modelFilePath,
        labelsCsv: labelsCsv,
        config: _config!,
      );

      debugPrint('[LiveController] isolate ready');
      _state = LiveState.ready;
    } catch (e, st) {
      debugPrint('[LiveController] loadModel error: $e\n$st');
      _state = LiveState.error;
      _errorMessage = e.toString();
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
    String poolingMode = 'lme',
    double sensitivity = 1.0,
    double? gainLinear,
    double? highPassHz,
  }) async {
    if (_state != LiveState.ready) return;

    final sessionId = DateTime.now().toIso8601String().replaceAll(':', '-');

    _session = LiveSession(
      id: sessionId,
      startTime: DateTime.now(),
      settings: SessionSettings(
        windowDuration: windowDuration,
        confidenceThreshold: confidenceThreshold,
        inferenceRate: inferenceRate,
        speciesFilterMode: speciesFilterMode,
        sensitivity: sensitivity,
        poolingMode: poolingMode,
        poolingWindows: poolingWindows,
        gainLinear: gainLinear,
        highPassHz: highPassHz,
      ),
    );

    _sessionDetections.clear();
    _latestDetections = const [];
    _currentLiveDetections = const [];
    _activeCardSpecies.clear();
    _confidenceThreshold = confidenceThreshold;
    _sensitivity = sensitivity;
    _isolate.setMaxPoolWindows(poolingWindows);
    _isolate.setPoolingMode(poolingMode);
    _isolate.resetPooling();
    _inferenceCycleCount = 0;
    ringBuffer.clear();

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
    if (recordingMode != RecordingMode.off) {
      final dir = await recordingService.startRecording(
        sessionId: sessionId,
        mode: recordingMode,
        format: recordingFormat,
      );
      _session!.recordingPath = dir;
    }

    _state = LiveState.active;
    onSessionStarted?.call();
    _notifyListeners();

    debugPrint(
      '[LiveController] session started '
      '(window=${windowDuration}s, rate=${inferenceRate}Hz, '
      'threshold=$confidenceThreshold)',
    );

    // Start the inference timer.
    final intervalMs = (1000.0 / inferenceRate).round();
    debugPrint('[LiveController] inference timer interval: ${intervalMs}ms');
    _inferenceTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _runInference(windowDuration: windowDuration),
    );
  }

  /// Pause the current session.
  ///
  /// Stops the inference timer but keeps the recording running so the
  /// audio file stays continuous and detection timestamps (which use
  /// wall-clock) remain in sync with audio time across the pause.
  /// The detection list is preserved.
  Future<void> pauseSession() async {
    if (_state != LiveState.active || _session == null) return;

    _inferenceTimer?.cancel();
    _inferenceTimer = null;

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

    _state = LiveState.active;
    _notifyListeners();

    debugPrint('[LiveController] session resumed');

    // Restart the inference timer.
    final intervalMs = (1000.0 / settings.inferenceRate).round();
    _inferenceTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _runInference(windowDuration: settings.windowDuration),
    );
  }

  /// Finalize and stop the current session completely.
  ///
  /// Called when leaving the live screen.  Returns the completed
  /// [LiveSession] for persistence, or null if there is no session.
  Future<LiveSession?> finalizeSession() async {
    if (_session == null) return null;

    // If still active, stop timer first.
    _inferenceTimer?.cancel();
    _inferenceTimer = null;

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

    // Close any still-open detection windows so that long-running cards
    // visible at session end get a proper [endTimestamp].
    if (_activeCardSpecies.isNotEmpty) {
      final now = DateTime.now();
      for (final existing in _activeCardSpecies.values) {
        final closed = DetectionRecord(
          scientificName: existing.scientificName,
          commonName: existing.commonName,
          confidence: existing.confidence,
          timestamp: existing.timestamp,
          endTimestamp: now,
          audioClipPath: existing.audioClipPath,
          source: existing.source,
          latitude: existing.latitude,
          longitude: existing.longitude,
        );
        final sessionIdx = _sessionDetections.indexOf(existing);
        if (sessionIdx != -1) _sessionDetections[sessionIdx] = closed;
        final lsIdx = _session!.detections.indexOf(existing);
        if (lsIdx != -1) _session!.detections[lsIdx] = closed;
      }
    }

    _session!.end();
    final completedSession = _session!;

    // Reset session state.
    _session = null;
    _sessionDetections.clear();
    _latestDetections = const [];
    _currentLiveDetections = const [];
    _activeCardSpecies.clear();

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

  /// Update the score-pooling window count and forward to the inference
  /// isolate. Pass `null` to use the model-config default.
  void setPoolingWindows(int? value) {
    _isolate.setMaxPoolWindows(value);
  }

  /// Update the score-pooling mode and forward to the inference isolate.
  /// Recognized values: `'off' | 'average' | 'max' | 'lme'`.
  void setPoolingMode(String value) {
    _isolate.setPoolingMode(value);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  /// Dispose of all resources.
  Future<void> dispose() async {
    _inferenceTimer?.cancel();
    await _isolate.stop();
    await _player.dispose();
    recordingService.dispose();
  }

  // ── Private ───────────────────────────────────────────────────────────

  /// Run a single inference cycle.
  Future<void> _runInference({required int windowDuration}) async {
    if (_inferring || !_isolate.isRunning) {
      debugPrint(
        '[LiveController] _runInference skipped '
        '(inferring=$_inferring, running=${_isolate.isRunning})',
      );
      return;
    }

    _inferring = true;
    _inferenceCycleCount++;

    // Snapshot the live-tunable threshold for this cycle so a mid-cycle
    // setter call can't half-apply.
    final confidenceThreshold = _confidenceThreshold;
    final sensitivity = _sensitivity;

    try {
      final sampleRate = _config?.audio.sampleRate ?? AppConstants.sampleRate;
      final windowSamples = windowDuration * sampleRate;
      final audioSamples = ringBuffer.readLast(windowSamples);

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
      );

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

      // ── Detection counting: card-visibility based ─────────────────
      //
      // A species counts as ONE detection for as long as its card is
      // continuously visible on the live screen.  Only when the card
      // disappears (species drops out of inference results) and later
      // reappears does it become a SECOND detection for session review.
      if (_session != null) {
        // Determine which species are present this cycle.
        final currentNames = <String>{
          for (final d in filteredDetections) d.species.scientificName,
        };

        // Species that just appeared (not currently tracked) → new detection.
        final appeared = currentNames.difference(
          _activeCardSpecies.keys.toSet(),
        );

        // Species that disappeared → close the detection window and
        // stop tracking. Stamping `endTimestamp` lets the review screen
        // visualize the full duration during which the species was on
        // screen, instead of just the first inference window.
        final disappeared = _activeCardSpecies.keys.toSet().difference(
          currentNames,
        );
        final now = DateTime.now();
        for (final name in disappeared) {
          final existing = _activeCardSpecies.remove(name);
          if (existing == null) continue;
          final closed = DetectionRecord(
            scientificName: existing.scientificName,
            commonName: existing.commonName,
            confidence: existing.confidence,
            timestamp: existing.timestamp,
            endTimestamp: now,
            audioClipPath: existing.audioClipPath,
            source: existing.source,
            latitude: existing.latitude,
            longitude: existing.longitude,
          );
          final sessionIdx = _sessionDetections.indexOf(existing);
          if (sessionIdx != -1) _sessionDetections[sessionIdx] = closed;
          final lsIdx = _session!.detections.indexOf(existing);
          if (lsIdx != -1) _session!.detections[lsIdx] = closed;
        }

        // Save detection clip if user requested per-detection clips
        // and there are new species appearing.
        String? clipPath;
        if (_saveDetectionClips && appeared.isNotEmpty) {
          final clipName = 'clip_${DateTime.now().millisecondsSinceEpoch}';
          clipPath = await recordingService.saveDetectionClip(
            clipName: clipName,
          );
        }

        for (final detection in filteredDetections) {
          final name = detection.species.scientificName;

          if (appeared.contains(name)) {
            // New detection — species just appeared on screen.
            final record = DetectionRecord.fromDetection(
              detection,
              audioClipPath: clipPath,
            );
            _session!.addDetection(record);
            _sessionDetections.insert(0, record);
            _activeCardSpecies[name] = record;
          } else if (_activeCardSpecies.containsKey(name)) {
            // Ongoing — update confidence if higher (same detection).
            final existing = _activeCardSpecies[name]!;
            if (detection.confidence > existing.confidence) {
              final updated = DetectionRecord(
                scientificName: existing.scientificName,
                commonName: existing.commonName,
                confidence: detection.confidence,
                timestamp: existing.timestamp,
                audioClipPath: existing.audioClipPath ?? clipPath,
                source: existing.source,
                latitude: existing.latitude,
                longitude: existing.longitude,
              );
              final sessionIdx = _sessionDetections.indexOf(existing);
              if (sessionIdx != -1) _sessionDetections[sessionIdx] = updated;
              final lsIdx = _session!.detections.indexOf(existing);
              if (lsIdx != -1) _session!.detections[lsIdx] = updated;
              _activeCardSpecies[name] = updated;
            }
          }
        }

        // Cap in-memory list to avoid unbounded growth.
        if (_sessionDetections.length > _maxInMemoryDetections) {
          _sessionDetections.removeRange(
            _maxInMemoryDetections,
            _sessionDetections.length,
          );
        }

        // Hand the current cycle's detections to the Announcements
        // pipeline (no-op when the feature is disabled). We submit the
        // full per-cycle list, not just newly-appeared species: the
        // first sighting is often near the confidence floor, while the
        // peak score arrives a few cycles later when the card is still
        // on screen. The controller's per-species streak silence and
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
      // below threshold), so the UI clears stale cards.
      _notifyListeners();
    } catch (e, st) {
      // Inference errors are logged but don't stop the session.
      debugPrint('[LiveController] inference ERROR: $e\n$st');
      _errorMessage = e.toString();
    } finally {
      _inferring = false;
    }
  }

  /// Notify the provider layer of state changes.
  void _notifyListeners() {
    onStateChanged?.call();
  }
}
