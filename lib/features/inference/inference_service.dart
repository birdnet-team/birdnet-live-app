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
//   modelBytes: bytes,
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
  ModelConfig? _config;

  /// Rolling buffer of recent per-class probability vectors for temporal
  /// pooling (newest last).
  final List<List<double>> _recentScores = [];

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

  /// Maximum pooling window count from the active config.
  int get maxPoolWindows => _config?.inference.temporalPooling.maxWindows ?? 5;

  /// Log-Mean-Exp alpha from the active config.
  double get poolingAlpha => _config?.inference.temporalPooling.alpha ?? 5.0;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Load the ONNX model and parse species labels.
  ///
  /// [modelBytes] — raw bytes of the `.onnx` model file.
  /// [labelsCsv] — full text content of the labels file.
  /// [config] — model configuration describing tensor names, label format,
  ///   and inference defaults.
  Future<void> initialize({
    required Uint8List modelBytes,
    required String labelsCsv,
    required ModelConfig config,
  }) async {
    _config = config;
    _labels = LabelParser.parse(labelsCsv, config: config.labels);
    await _model.loadModel(
      modelBytes,
      inputName: config.onnx.inputName,
      predictionsName: config.onnx.predictionsName,
      embeddingsName: config.onnx.embeddingsName,
    );
  }

  /// Release all resources (ONNX session, native memory).
  void dispose() {
    _model.dispose();
    _labels = const [];
    _config = null;
    _recentScores.clear();
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
    final now = DateTime.now();

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
    List<double> finalScores;
    if (useTemporalPooling) {
      _recentScores.add(probs);
      if (_recentScores.length > maxPoolWindows) {
        _recentScores.removeAt(0);
      }
      finalScores = PostProcessor.logMeanExp(
        _recentScores,
        alpha: poolingAlpha,
      );
    } else {
      finalScores = probs;
    }

    // Sensitivity + top-K + threshold.
    final adjusted = PostProcessor.applySensitivityAll(
      finalScores,
      sens,
    );

    return PostProcessor.topK(
      scores: adjusted,
      labels: _labels,
      k: k,
      threshold: thresh,
      timestamp: now,
    );
  }

  /// Clear the temporal pooling buffer.
  ///
  /// Call this when switching modes or resetting the analysis context.
  void resetPooling() {
    _recentScores.clear();
  }
}
