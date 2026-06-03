// =============================================================================
// Inference Service — High-level coordinator for species classification
// =============================================================================
//
// Orchestrates the full inference pipeline:
//
//   1. **Load** — model bytes + labels CSV + config.
//   2. **Infer** — pre-process audio → ONNX model → post-process results.
//   3. **Pool** — temporal smoothing via Log-Mean-Exp across recent windows.
//
// The service is model-agnostic: all model-specific parameters (sample rate,
// tensor names, post-processing defaults) come from a [ModelConfig] supplied
// at initialization time.
//
// ### Dependencies
//
// - [ClassifierModel] — low-level ONNX session wrapper
// - [LabelParser] — configurable delimited-text parser for species labels
// - [PostProcessor] — sigmoid, sensitivity, top-K
//
// ### Lifecycle
//
// ```dart
// final svc = InferenceService();
// await svc.initialize(
//   modelFilePath: '/path/to/model.onnx',
//   labelsCsv: csvText,
//   config: modelConfig,
// );
// final detections = await svc.infer(audioSamples, windowSeconds: 3);
// svc.dispose();
// ```
// =============================================================================

import 'dart:typed_data';

import 'classifier_model.dart';
import 'label_parser.dart';
import 'model_config.dart';
import 'models/detection.dart';
import 'models/species.dart';
import 'post_processor.dart';
import 'score_blacklist.dart';

/// High-level inference coordinator.
///
/// Combines model loading, label parsing, inference execution, and post-
/// processing into a single, easy-to-use API.  All model-specific knobs
/// are driven by a [ModelConfig] — no values are hardcoded.
class InferenceService {
  /// Creates an uninitialized inference service.
  ///
  /// Call [initialize] before [infer].
  InferenceService();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final ClassifierModel _model = ClassifierModel();
  List<Species> _labels = const [];
  List<double> _scoreMultipliers = const [];
  ModelConfig? _config;

  /// Rolling buffer of recent per-class probability vectors for temporal
  /// pooling (newest last) with their start timestamps.
  final List<_TimestampedScores> _recentScores = [];

  /// Class indexes that were emitted on the previous cycle.
  final Set<int> _confirmedDetectionIndexes = {};

  /// Whether the service has been successfully initialized.
  bool get isReady => _model.isLoaded && _labels.isNotEmpty && _config != null;

  /// The full list of species labels, available after [initialize].
  List<Species> get labels => _labels;

  /// The active model configuration, available after [initialize].
  ModelConfig? get config => _config;

  /// Audio sample rate from the active config (Hz).
  ///
  /// Defaults to 32 000 if no config is loaded.
  int get sampleRate => _config?.audio.sampleRate ?? 32000;

  /// Maximum pooling window count.
  ///
  /// Defaults to the value from the active model config but can be overridden
  /// at runtime via [setMaxPoolWindows] (driven by the user setting). The
  /// effective value is clamped to ≥ 1 so the rolling buffer always contains
  /// at least the current window.
  int get maxPoolWindows =>
      _maxPoolWindowsOverride ??
      _config?.inference.temporalPooling.maxWindows ??
      5;
  int? _maxPoolWindowsOverride;

  /// Override the pooling-window count from a user setting. Pass `null` to
  /// fall back to the model-config default.
  void setMaxPoolWindows(int? value) {
    if (value != null && value < 1) {
      _maxPoolWindowsOverride = 1;
    } else {
      _maxPoolWindowsOverride = value;
    }
    // Trim the rolling buffer immediately so a smaller setting takes effect
    // without waiting for the next inference call to push fresh samples in.
    while (_recentScores.length > maxPoolWindows) {
      _recentScores.removeAt(0);
    }
  }

  /// Log-Mean-Exp alpha from the active config.
  double get poolingAlpha => _config?.inference.temporalPooling.alpha ?? 5.0;

  /// Score-pooling mode driven by the user setting. Recognized values:
  /// `'off'` (no pooling — single-window scores), `'average'`,
  /// `'max'`, and `'lme'` (log-mean-exp, default and historical
  /// behavior). Unknown values fall back to `'lme'`.
  String _poolingMode = 'lme';
  String get poolingMode => _poolingMode;

  /// Override the pooling mode at runtime from a user setting. Pass
  /// `null` or an empty string to revert to `'lme'`. The rolling
  /// score buffer is cleared so a switch (e.g. lme → max) doesn't
  /// cross-contaminate the new mode with stale logits.
  void setPoolingMode(String? mode) {
    final next = (mode == null || mode.isEmpty) ? 'lme' : mode;
    if (next == _poolingMode) return;
    _poolingMode = next;
    _recentScores.clear();
    _confirmedDetectionIndexes.clear();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Load the ONNX model and parse species labels.
  ///
  /// [modelFilePath] — absolute path to the `.onnx` model file on disk.
  /// [labelsCsv] — full text content of the labels file.
  /// [config] — model configuration describing tensor names, label format,
  ///   and inference defaults.
  /// [scoreBlacklistJson] — optional JSON map from English common names to
  ///   confidence multipliers in [0, 1].
  Future<void> initialize({
    required String modelFilePath,
    required String labelsCsv,
    required ModelConfig config,
    String? scoreBlacklistJson,
  }) async {
    _config = config;
    _labels = LabelParser.parse(labelsCsv, config: config.labels);
    final blacklist =
        scoreBlacklistJson == null
            ? const <String, double>{}
            : ScoreBlacklist.parse(scoreBlacklistJson);
    _scoreMultipliers = ScoreBlacklist.buildMultiplierVector(
      labels: _labels,
      fractions: blacklist,
    );
    await _model.loadModelFromFile(
      modelFilePath,
      inputName: config.onnx.inputName,
      predictionsName: config.onnx.predictionsName,
      embeddingsName: config.onnx.embeddingsName,
    );
  }

  /// Release all resources (ONNX session, native memory).
  Future<void> dispose() async {
    await _model.dispose();
    _labels = const [];
    _scoreMultipliers = const [];
    _config = null;
    _recentScores.clear();
    _confirmedDetectionIndexes.clear();
  }

  // ---------------------------------------------------------------------------
  // Inference
  // ---------------------------------------------------------------------------

  /// Run inference on [audioSamples] and return post-processed detections.
  ///
  /// Parameters that are not supplied fall back to the values from the
  /// active [ModelConfig]:
  ///
  /// - [windowSeconds] — analysis window duration.
  /// - [sensitivity] — sensitivity scaling factor.
  /// - [confidenceThreshold] — minimum confidence to include (0.0–1.0).
  /// - [topK] — maximum number of detections to return.
  /// - [useTemporalPooling] — whether to smooth with recent windows.
  ///
  /// The returned list is sorted by descending confidence and filtered
  /// against [confidenceThreshold].
  Future<List<Detection>> infer(
    Float32List audioSamples, {
    int? windowSeconds,
    double? sensitivity,
    double? confidenceThreshold,
    int? topK,
    bool useTemporalPooling = true,
    DateTime? timestamp,
  }) async {
    if (!isReady) {
      throw StateError(
        'InferenceService not initialized. Call initialize() first.',
      );
    }

    final cfg = _config!;
    final ws = windowSeconds ?? cfg.inference.defaultWindowSeconds;
    final sens = sensitivity ?? cfg.inference.defaultSensitivity;
    final thresh =
        confidenceThreshold ?? cfg.inference.defaultConfidenceThreshold;
    final k = topK ?? cfg.inference.defaultTopK;

    final windowSamples = sampleRate * ws;
    // Stamp the detection at the START of the analyzed audio window
    // (not at the end of inference). The provided [audioSamples] cover
    // approximately the last [ws] seconds before now, so the earliest
    // sample corresponds to (now - ws). Using this start-of-window
    // timestamp keeps the session-review offsets and the audio playhead
    // aligned with where the call actually is in the recording.
    final now = timestamp ?? DateTime.now().subtract(Duration(seconds: ws));

    // Run model.
    final output = await _model.predict(
      audioSamples,
      windowSamples: windowSamples,
    );

    // The model output is already sigmoid-activated (probabilities in [0, 1]).
    // Do NOT apply sigmoid again — that would flatten all near-zero
    // probabilities to ~0.5, making every detection appear at 50 %.
    final probs = output.predictions;

    // Temporal pooling (optional).
    //
    // The user-selected [poolingMode] picks the algorithm; the legacy
    // [useTemporalPooling] flag still acts as a hard override (set to
    // `false` by callers that want raw single-window probs).
    List<double> finalScores;
    List<List<double>> poolingInputScores = [];

    if (!useTemporalPooling || _poolingMode == 'off') {
      // Don't grow the rolling buffer when pooling is off — it would
      // re-pollute results if the user switches back to a pooled mode
      // mid-session.
      finalScores = probs;
    } else {
      _recentScores.add(_TimestampedScores(now, probs));
      if (_recentScores.length > maxPoolWindows) {
        _recentScores.removeAt(0);
      }

      // Filter out chunks whose start timestamp is older than 10 seconds than "now"
      final validRecentTimestamped =
          _recentScores.where((ts) {
            final age = now.difference(ts.timestamp);
            return age.inMicroseconds >= 0 && age.inSeconds <= 10;
          }).toList();

      poolingInputScores =
          validRecentTimestamped.map((ts) => ts.scores).toList();

      switch (_poolingMode) {
        case 'average':
          finalScores = PostProcessor.average(poolingInputScores);
          break;
        case 'max':
          finalScores = PostProcessor.max(poolingInputScores);
          break;
        case 'lme':
        default:
          finalScores = PostProcessor.logMeanExp(
            poolingInputScores,
            alpha: poolingAlpha,
            peakRetention: cfg.inference.temporalPooling.peakRetention,
          );
      }
    }

    // Sensitivity + top-K + threshold.
    final sensitivityAdjusted = PostProcessor.applySensitivityAll(
      finalScores,
      sens,
    );
    final adjusted = ScoreBlacklist.applyMultipliers(
      scores: sensitivityAdjusted,
      multipliers: _scoreMultipliers,
    );

    final gated =
        _poolingMode == 'lme' &&
                useTemporalPooling &&
                poolingInputScores.isNotEmpty
            ? PostProcessor.applyTemporalSupportGate(
              scores: adjusted,
              windowScores: poolingInputScores,
              confirmedIndexes: _confirmedDetectionIndexes,
              confidenceThreshold: thresh,
              supportThreshold: cfg.inference.temporalPooling
                  .supportThresholdFor(thresh),
              minSupportWindows:
                  cfg.inference.temporalPooling.minSupportWindows,
              veryHighImmediateThreshold:
                  cfg.inference.temporalPooling.veryHighImmediateThreshold,
            )
            : adjusted;

    final detections = PostProcessor.topK(
      scores: gated,
      labels: _labels,
      k: k,
      threshold: thresh,
      timestamp: now,
    );

    _confirmedDetectionIndexes
      ..clear()
      ..addAll(detections.map((detection) => detection.species.index));

    return detections;
  }

  /// Clear the temporal pooling buffer.
  ///
  /// Call this when switching modes or resetting the analysis context.
  void resetPooling() {
    _recentScores.clear();
    _confirmedDetectionIndexes.clear();
  }
}

class _TimestampedScores {
  final DateTime timestamp;
  final List<double> scores;
  _TimestampedScores(this.timestamp, this.scores);
}
