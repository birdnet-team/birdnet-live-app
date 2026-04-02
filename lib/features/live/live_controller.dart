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
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../audio/ring_buffer.dart';
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
  LiveController({
    required this.ringBuffer,
    required this.recordingService,
  });

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

  /// Geo-model scores for species filtering (set at session start).
  Map<String, double>? _geoScores;

  /// Active species filter mode for the current session.
  SpeciesFilterMode _filterMode = SpeciesFilterMode.off;

  /// Geo-model threshold for the current session.
  double _geoThreshold = 0.03;

  /// Whether per-detection audio clips should be saved.
  bool _saveDetectionClips = false;

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

  // ── Model loading ─────────────────────────────────────────────────────

  /// Load the model from Flutter assets.
  ///
  /// On first launch the ONNX model bytes are extracted from the APK asset
  /// bundle and written to the app's documents directory.  Subsequent
  /// launches skip this step and read directly from disk.
  ///
  /// Only the file *path* is passed to the inference isolate — this avoids
  /// serialising ~259 MB through the isolate port, which would
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

      // Ensure model file exists on the filesystem.
      final modelFilePath = await _ensureModelOnDisk(
        _config!.onnx.modelFile,
        _config!.version,
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

  /// Copy the model asset to the app's documents directory if it doesn't
  /// already exist on disk, and return the absolute file path.
  Future<String> _ensureModelOnDisk(String fileName, String version) async {
    final appDir = await getApplicationDocumentsDirectory();
    final versionedName = '${fileName}_v$version';
    final modelFile = File('${appDir.path}/$versionedName');

    if (!modelFile.existsSync()) {
      debugPrint('[LiveController] extracting model to ${modelFile.path} …');
      final assetPath = '${AppConstants.modelAssetsDir}/$fileName';
      final data = await rootBundle.load(assetPath);
      await modelFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      debugPrint('[LiveController] extraction complete '
          '(${modelFile.lengthSync()} bytes)');
    } else {
      debugPrint('[LiveController] model already on disk '
          '(${modelFile.lengthSync()} bytes)');
    }

    return modelFile.path;
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
  Future<void> startSession({
    required int windowDuration,
    required double inferenceRate,
    required int confidenceThreshold,
    required String speciesFilterMode,
    required RecordingMode recordingMode,
    String recordingFormat = 'flac',
    Map<String, double>? geoScores,
    double geoThreshold = 0.03,
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
      ),
    );

    _sessionDetections.clear();
    _latestDetections = const [];
    _currentLiveDetections = const [];
    _isolate.resetPooling();

    // Store geo-filter state for this session.
    _geoScores = geoScores;
    _geoThreshold = geoThreshold;
    _filterMode = switch (speciesFilterMode) {
      'geoExclude' => SpeciesFilterMode.geoExclude,
      'geoMerge' => SpeciesFilterMode.geoMerge,
      'customList' => SpeciesFilterMode.customList,
      _ => SpeciesFilterMode.off,
    };

    // Always record full audio so sessions can be reviewed.
    final dir = await recordingService.startRecording(
      sessionId: sessionId,
      mode: RecordingMode.full,
      format: recordingFormat,
    );
    _session!.recordingPath = dir;

    // Also save per-detection clips if the user configured it.
    _saveDetectionClips = recordingMode == RecordingMode.detectionsOnly;

    _state = LiveState.active;
    _notifyListeners();

    debugPrint('[LiveController] session started '
        '(window=${windowDuration}s, rate=${inferenceRate}Hz, '
        'threshold=$confidenceThreshold)');

    // Start the inference timer.
    final intervalMs = (1000.0 / inferenceRate).round();
    debugPrint('[LiveController] inference timer interval: ${intervalMs}ms');
    _inferenceTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _runInference(
        windowDuration: windowDuration,
        confidenceThreshold: confidenceThreshold,
      ),
    );
  }

  /// Pause the current session.
  ///
  /// Stops the inference timer and recording but keeps the session alive
  /// so it can be resumed.  The detection list is preserved.
  Future<void> pauseSession() async {
    if (_state != LiveState.active || _session == null) return;

    _inferenceTimer?.cancel();
    _inferenceTimer = null;

    // Pause recording (don't finalize).
    await recordingService.stopRecording();

    _state = LiveState.paused;
    _notifyListeners();

    debugPrint('[LiveController] session paused');
  }

  /// Resume a previously paused session.
  ///
  /// Re-starts the inference timer with the same settings.
  Future<void> resumeSession() async {
    if (_state != LiveState.paused || _session == null) return;

    final settings = _session!.settings;

    // Restart full recording.
    await recordingService.startRecording(
      sessionId: _session!.id,
      mode: RecordingMode.full,
      format: recordingService.format,
    );

    _state = LiveState.active;
    _notifyListeners();

    debugPrint('[LiveController] session resumed');

    // Restart the inference timer.
    final intervalMs = (1000.0 / settings.inferenceRate).round();
    _inferenceTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _runInference(
        windowDuration: settings.windowDuration,
        confidenceThreshold: settings.confidenceThreshold,
      ),
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

    _session!.end();
    final completedSession = _session!;

    // Reset session state.
    _session = null;
    _sessionDetections.clear();
    _latestDetections = const [];
    _currentLiveDetections = const [];

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
  Future<void> _runInference({
    required int windowDuration,
    required int confidenceThreshold,
  }) async {
    if (_inferring || !_isolate.isRunning) {
      debugPrint('[LiveController] _runInference skipped '
          '(inferring=$_inferring, running=${_isolate.isRunning})');
      return;
    }

    _inferring = true;

    try {
      final sampleRate = _config?.audio.sampleRate ?? AppConstants.sampleRate;
      final windowSamples = windowDuration * sampleRate;
      final totalWritten = ringBuffer.totalWritten;
      final audioSamples = ringBuffer.readLast(windowSamples);

      debugPrint('[LiveController] inference: totalWritten=$totalWritten, '
          'windowSamples=$windowSamples, sampleRate=$sampleRate');

      // Temporary: log max absolute value of audio window to guarantee it's not silent
      if (audioSamples.isNotEmpty) {
        final maxAbsValue = audioSamples.fold<double>(
          0.0,
          (max, sample) => sample.abs() > max ? sample.abs() : max,
        );
        debugPrint('[LiveController] audio window max abs value: $maxAbsValue');
      }

      debugPrint('[LiveController] running inference …');
      final detections = await _isolate.infer(
        audioSamples,
        windowSeconds: windowDuration,
        confidenceThreshold: confidenceThreshold / 100.0,
      );

      debugPrint('[LiveController] inference done — '
          '${detections.length} detections '
          '(threshold=${confidenceThreshold / 100.0})');

      _latestDetections = detections;

      // Apply species filter (geo-model or custom list).
      final filteredDetections = SpeciesFilter.apply(
        detections: detections,
        mode: _filterMode,
        geoScores: _geoScores,
        geoThreshold: _geoThreshold,
        confidenceThreshold: confidenceThreshold / 100.0,
      );

      // Update the live detection list (replaced each cycle, like the PWA).
      // Each species appears at most once with its current score.
      _currentLiveDetections = [
        for (final d in filteredDetections) DetectionRecord.fromDetection(d),
      ];

      // Accumulate to session history (for session saving / stats).
      if (_session != null && filteredDetections.isNotEmpty) {
        // Save detection clip if user requested per-detection clips.
        String? clipPath;
        if (_saveDetectionClips) {
          final clipName = 'clip_${DateTime.now().millisecondsSinceEpoch}';
          clipPath = await recordingService.saveDetectionClip(
            clipName: clipName,
          );
        }

        for (final detection in filteredDetections) {
          final record = DetectionRecord.fromDetection(
            detection,
            audioClipPath: clipPath,
          );

          // Check if we should merge with a recent detection of the same species
          final recentMatchIdx = _sessionDetections.indexWhere((r) =>
              r.scientificName == record.scientificName &&
              record.timestamp.difference(r.timestamp).inMilliseconds.abs() <=
                  3000);

          if (recentMatchIdx != -1) {
            // Update the existing record if the new one has higher confidence
            final existing = _sessionDetections[recentMatchIdx];
            if (record.confidence > existing.confidence) {
              final updated = DetectionRecord(
                scientificName: existing.scientificName,
                commonName: existing.commonName,
                confidence:
                    record.confidence, // Update to new higher confidence
                timestamp: existing.timestamp, // Keep original timestamp
                audioClipPath: existing.audioClipPath ?? record.audioClipPath,
              );
              _sessionDetections[recentMatchIdx] = updated;

              // Also update in session
              final sessionIdx = _session!.detections.indexOf(existing);
              if (sessionIdx != -1) {
                _session!.detections[sessionIdx] = updated;
              }
            }
          } else {
            _session!.addDetection(record);
            _sessionDetections.insert(0, record); // newest first
          }
        }

        // Cap in-memory list to avoid unbounded growth.
        if (_sessionDetections.length > _maxInMemoryDetections) {
          _sessionDetections.removeRange(
            _maxInMemoryDetections,
            _sessionDetections.length,
          );
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
