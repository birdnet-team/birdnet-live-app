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
// - [PostProcessor] — sensitivity, top-K
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

import 'advanced_pooling_params.dart';
import 'classifier_model.dart';
import 'label_parser.dart';
import 'model_config.dart';
import 'models/detection.dart';
import 'models/species.dart';
import 'post_processor.dart';
import 'score_blacklist.dart';
import 'species_ignore_filter.dart';

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

  /// Rolling buffer of recent raw per-class probability vectors for temporal
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

  /// Log-Mean-Exp alpha. User override (via [applyAdvancedPoolingParams])
  /// wins; otherwise falls back to the active model config.
  double get poolingAlpha =>
      _alphaOverride ?? _config?.inference.temporalPooling.alpha ?? 5.0;
  double? _alphaOverride;

  /// Number of recent windows required to clear the temporal support gate.
  /// User override wins; otherwise the active model config. `1` disables the
  /// gate (see [PostProcessor.hasTemporalSupport]).
  int get minSupportWindows =>
      _minSupportWindowsOverride ??
      _config?.inference.temporalPooling.minSupportWindows ??
      2;
  int? _minSupportWindowsOverride;

  /// Fraction of the confidence threshold used as the per-window support
  /// threshold, before the floor. User override wins; otherwise model config.
  double get supportThresholdFraction =>
      _supportThresholdFractionOverride ??
      _config?.inference.temporalPooling.supportThresholdFraction ??
      0.6;
  double? _supportThresholdFractionOverride;

  /// Lower bound on the per-window support threshold. User override wins;
  /// otherwise model config.
  double get supportThresholdFloor =>
      _supportThresholdFloorOverride ??
      _config?.inference.temporalPooling.supportThresholdFloor ??
      0.25;
  double? _supportThresholdFloorOverride;

  /// Raw current-window score that bypasses multi-window support. User
  /// override wins; otherwise model config.
  double get veryHighImmediateThreshold =>
      _veryHighImmediateThresholdOverride ??
      _config?.inference.temporalPooling.veryHighImmediateThreshold ??
      0.98;
  double? _veryHighImmediateThresholdOverride;

  /// Per-window support threshold for [confidenceThreshold], applying the
  /// overridable fraction + floor. Mirrors
  /// [TemporalPoolingConfig.supportThresholdFor] but honours the runtime
  /// overrides above.
  double _supportThresholdFor(double confidenceThreshold) {
    final threshold = confidenceThreshold * supportThresholdFraction;
    final floor = supportThresholdFloor;
    if (threshold < floor) return floor;
    if (threshold > 1.0) return 1.0;
    return threshold;
  }

  /// Apply the advanced temporal-pooling overrides from a user setting. Each
  /// `null` field reverts that knob to the model-config default. Takes effect
  /// on the next inference cycle — the rolling score buffer is preserved
  /// because these knobs only change how stored windows are pooled/gated, not
  /// the stored values themselves.
  void applyAdvancedPoolingParams(AdvancedPoolingParams params) {
    _alphaOverride = params.alpha;
    _minSupportWindowsOverride = params.minSupportWindows;
    _supportThresholdFractionOverride = params.supportThresholdFraction;
    _supportThresholdFloorOverride = params.supportThresholdFloor;
    _veryHighImmediateThresholdOverride = params.veryHighImmediateThreshold;
  }

  /// Maximum real-time age, in seconds, for windows included in score pooling.
  double get maxPoolAgeSeconds =>
      _maxPoolAgeSecondsOverride ??
      _config?.inference.temporalPooling.maxAgeSeconds ??
      10.0;
  double? _maxPoolAgeSecondsOverride;

  /// Override the pooling time gate. Pass `null` to fall back to config.
  void setMaxPoolAgeSeconds(double? value) {
    if (value != null && value <= 0) {
      _maxPoolAgeSecondsOverride = 0.001;
    } else {
      _maxPoolAgeSecondsOverride = value;
    }
  }

  /// Score-pooling mode driven by the user setting. Recognized values:
  /// `'off'` (no pooling — single-window scores), `'average'`,
  /// `'max'`, `'lme'`, and `'adaptive_lme_peak'`. Adaptive mode currently uses
  /// LME at all inference rates (with the temporal support gate and time gate),
  /// plus recent-peak display confidence.
  /// Unknown values fall back to `'adaptive_lme_peak'`.
  String _poolingMode = 'adaptive_lme_peak';
  String get poolingMode => _poolingMode;

  /// Override the pooling mode at runtime from a user setting. Pass
  /// `null` or an empty string to revert to `'adaptive_lme_peak'`. The rolling
  /// score buffer is cleared so a switch (e.g. lme → max) doesn't
  /// cross-contaminate the new mode with stale scores.
  void setPoolingMode(String? mode) {
    final requested =
        (mode == null || mode.isEmpty) ? 'adaptive_lme_peak' : mode;
    final next =
        _isSupportedPoolingMode(requested) ? requested : 'adaptive_lme_peak';
    if (next == _poolingMode) return;
    _poolingMode = next;
    _recentScores.clear();
    _confirmedDetectionIndexes.clear();
  }

  Set<String> _ignoredSpeciesNames = const <String>{};

  /// Replace the binary species mask applied to every sigmoid-activated score
  /// vector before temporal pooling. The rolling buffer can stay intact: raw
  /// probabilities are stored there and the current mask is reapplied when
  /// each window participates in the next pooled result.
  void setIgnoredSpeciesNames(Set<String> scientificNames) {
    _ignoredSpeciesNames = Set<String>.unmodifiable(scientificNames);
    _confirmedDetectionIndexes.clear();
  }

  List<double> _applySpeciesIgnoreFilter(List<double> scores) {
    return SpeciesIgnoreFilter.applyToAudioScores(
      scores: scores,
      labels: _labels,
      ignoredScientificNames: _ignoredSpeciesNames,
    );
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
    int? intraOpNumThreads,
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
      intraOpNumThreads: intraOpNumThreads,
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
    _ignoredSpeciesNames = const <String>{};
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

    return _postProcessOutput(
      output,
      sensitivity: sens,
      confidenceThreshold: thresh,
      topK: k,
      useTemporalPooling: useTemporalPooling,
      timestamp: now,
    );
  }

  /// Run a group of audio windows in one native model call.
  ///
  /// Post-processing remains sequential so temporal pooling and support state
  /// have exactly the same ordering semantics as repeated [infer] calls.
  Future<List<List<Detection>>> inferBatch(
    List<Float32List> audioWindows, {
    int? windowSeconds,
    double? sensitivity,
    double? confidenceThreshold,
    int? topK,
    bool useTemporalPooling = true,
    List<DateTime>? timestamps,
  }) async {
    if (!isReady) {
      throw StateError(
        'InferenceService not initialized. Call initialize() first.',
      );
    }
    if (audioWindows.isEmpty) return const [];
    if (timestamps != null && timestamps.length != audioWindows.length) {
      throw ArgumentError.value(
        timestamps,
        'timestamps',
        'Must contain one timestamp per audio window',
      );
    }

    final cfg = _config!;
    final ws = windowSeconds ?? cfg.inference.defaultWindowSeconds;
    final sens = sensitivity ?? cfg.inference.defaultSensitivity;
    final thresh =
        confidenceThreshold ?? cfg.inference.defaultConfidenceThreshold;
    final k = topK ?? cfg.inference.defaultTopK;
    final outputs = await _model.predictBatch(
      audioWindows,
      windowSamples: sampleRate * ws,
    );

    return [
      for (var index = 0; index < outputs.length; index++)
        _postProcessOutput(
          outputs[index],
          sensitivity: sens,
          confidenceThreshold: thresh,
          topK: k,
          useTemporalPooling: useTemporalPooling,
          timestamp:
              timestamps?[index] ??
              DateTime.now().subtract(Duration(seconds: ws)),
        ),
    ];
  }

  List<Detection> _postProcessOutput(
    ModelOutput output, {
    required double sensitivity,
    required double confidenceThreshold,
    required int topK,
    required bool useTemporalPooling,
    required DateTime timestamp,
  }) {
    final sens = sensitivity;
    final thresh = confidenceThreshold;
    final k = topK;
    final now = timestamp;

    // The model output is already sigmoid-activated (probabilities in [0, 1]).
    // Do NOT apply sigmoid again — that would flatten all near-zero
    // probabilities to ~0.5, making every detection appear at 50 %.
    final rawProbs = output.predictions;

    // Sensitivity is an x-axis offset in logit space. Apply it to raw model
    // probabilities before any pooling or filtering so downstream stages
    // operate on the adjusted curve. The rolling buffer stores raw
    // probabilities so a sensitivity change hot-applies consistently to every
    // recent window used by the next pooled result.
    final currentScores = _applySpeciesIgnoreFilter(
      PostProcessor.applySensitivityAll(rawProbs, sens),
    );

    // Temporal pooling (optional).
    //
    // The user-selected [poolingMode] picks the algorithm; the legacy
    // [useTemporalPooling] flag still acts as a hard override (set to
    // `false` by callers that want raw single-window probs).
    List<double> finalScores;
    List<_TimestampedScores> poolingInput = [];
    List<List<double>> poolingInputScores = [];

    if (!useTemporalPooling || _poolingMode == 'off') {
      // Don't grow the rolling buffer when pooling is off — it would
      // re-pollute results if the user switches back to a pooled mode
      // mid-session.
      finalScores = currentScores;
    } else {
      _recentScores.add(_TimestampedScores(now, rawProbs));
      if (_recentScores.length > maxPoolWindows) {
        _recentScores.removeAt(0);
      }

      // Filter out chunks whose start timestamp is older than 10 seconds than "now"
      final validRecentTimestamped =
          _recentScores.where((ts) {
            final age = now.difference(ts.timestamp);
            return age.inMicroseconds >= 0 &&
                age.inMicroseconds <= maxPoolAgeSeconds * 1000000;
          }).toList();

      poolingInput =
          validRecentTimestamped
              .map(
                (ts) => _TimestampedScores(
                  ts.timestamp,
                  _applySpeciesIgnoreFilter(
                    PostProcessor.applySensitivityAll(ts.scores, sens),
                  ),
                ),
              )
              .toList();
      poolingInputScores = poolingInput.map((ts) => ts.scores).toList();

      switch (_poolingMode) {
        case 'adaptive_lme_peak':
          // Experiment: use LME at ALL inference rates. Previously this mode
          // switched to average pooling at high inference rates
          // (stepSeconds <= 1.25) and only used LME for low rates. The support
          // gate and time gate below still apply.
          finalScores = PostProcessor.logMeanExp(
            poolingInputScores,
            alpha: poolingAlpha,
          );
          break;
        case 'avg':
        case 'average':
          finalScores = PostProcessor.average(poolingInputScores);
          break;
        case 'max':
          finalScores = PostProcessor.max(poolingInputScores);
          break;
        case 'lme':
          finalScores = PostProcessor.logMeanExp(
            poolingInputScores,
            alpha: poolingAlpha,
          );
          break;
        default:
          finalScores = PostProcessor.logMeanExp(
            poolingInputScores,
            alpha: poolingAlpha,
          );
      }
    }

    // Score multipliers + top-K + threshold.
    final adjusted = ScoreBlacklist.applyMultipliers(
      scores: finalScores,
      multipliers: _scoreMultipliers,
    );

    final gated =
        (_poolingMode == 'lme' || _poolingMode == 'adaptive_lme_peak') &&
                useTemporalPooling &&
                poolingInputScores.isNotEmpty
            ? PostProcessor.applyTemporalSupportGate(
              scores: adjusted,
              windowScores: poolingInputScores,
              confirmedIndexes: _confirmedDetectionIndexes,
              confidenceThreshold: thresh,
              supportThreshold: _supportThresholdFor(thresh),
              minSupportWindows: minSupportWindows,
              veryHighImmediateThreshold: veryHighImmediateThreshold,
            )
            : adjusted;

    var detections = PostProcessor.topK(
      scores: gated,
      labels: _labels,
      k: k,
      threshold: thresh,
      timestamp: now,
    );

    if (useTemporalPooling && poolingInput.isNotEmpty) {
      detections = _withEarliestSupportTimestamps(
        detections,
        poolingInput,
        _supportThresholdFor(thresh),
      );
    }

    if (_poolingMode == 'adaptive_lme_peak' &&
        useTemporalPooling &&
        poolingInputScores.isNotEmpty) {
      detections = _withRecentPeakConfidence(detections, poolingInputScores);
    }

    _confirmedDetectionIndexes
      ..clear()
      ..addAll(detections.map((detection) => detection.species.index));

    return detections;
  }

  bool _isSupportedPoolingMode(String mode) {
    return mode == 'off' ||
        mode == 'avg' ||
        mode == 'average' ||
        mode == 'max' ||
        mode == 'lme' ||
        mode == 'adaptive_lme_peak';
  }

  List<Detection> _withRecentPeakConfidence(
    List<Detection> detections,
    List<List<double>> windowScores,
  ) {
    if (detections.isEmpty) return detections;

    final peaks = PostProcessor.recentPeakScores(
      windowScores,
      multipliers: _scoreMultipliers,
    );
    final adjusted = <Detection>[];
    for (final detection in detections) {
      final index = detection.species.index;
      var peak = detection.confidence;
      if (index >= 0 && index < peaks.length && peaks[index] > peak) {
        peak = peaks[index];
      }
      adjusted.add(
        Detection(
          species: detection.species,
          confidence: peak.clamp(0.0, 1.0).toDouble(),
          timestamp: detection.timestamp,
        ),
      );
    }

    adjusted.sort((a, b) => b.confidence.compareTo(a.confidence));
    return adjusted;
  }

  List<Detection> _withEarliestSupportTimestamps(
    List<Detection> detections,
    List<_TimestampedScores> windowScores,
    double supportThreshold,
  ) {
    if (detections.isEmpty || windowScores.isEmpty) return detections;

    final scores = windowScores.map((ts) => ts.scores).toList();
    final timestamps = windowScores.map((ts) => ts.timestamp).toList();

    return [
      for (final detection in detections)
        Detection(
          species: detection.species,
          confidence: detection.confidence,
          timestamp:
              PostProcessor.earliestSupportingTimestamp(
                windowScores: scores,
                timestamps: timestamps,
                index: detection.species.index,
                supportThreshold: supportThreshold,
              ) ??
              detection.timestamp,
        ),
    ];
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
