// =============================================================================
// Classifier Model — ONNX Runtime wrapper for species classification
// =============================================================================
//
// Encapsulates all ONNX-specific logic: model loading, session management,
// tensor creation, and inference execution.  The rest of the app interacts
// only through the high-level [ClassifierModel] interface.
//
// ### Model-agnostic design
//
// Tensor names and output structure are configured at load time via optional
// parameters (which default to BirdNET conventions).  To swap models, change
// the JSON config file — no code changes needed.
//
// ### Typical tensor layout
//
// ```
// Input:  <inputName>       — float32 [batch, samples]
// Output: <predictionsName> — float32 [batch, N]       (raw logits per class)
// Output: <embeddingsName>  — float32 [batch, M]       (feature vectors, optional)
// ```
//
// Audio must be mono float32 normalised to [-1.0, 1.0].  If the provided
// audio is shorter than the expected window it is zero-padded on the right.
//
// ### Threading
//
// The `onnxruntime` package uses FFI, so sessions can be created inside
// Dart [Isolate]s.  The [InferenceIsolate] class in this feature handles
// isolate lifecycle; this service is the low-level model wrapper.
//
// ### Lifecycle
//
// 1. Call [loadModel] or [loadModelFromFile] to load the `.onnx` model.
// 2. Call [predict] as many times as needed.
// 3. Call [dispose] when finished to free native resources.
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';

/// Low-level wrapper around an ONNX classification model.
///
/// Handles session creation, input tensor construction, inference, and
/// resource cleanup.  Not intended for direct UI consumption — use
/// [InferenceService] or [InferenceIsolate] instead.
class ClassifierModel {
  /// Creates a new model instance.  Call [loadModel] to initialise.
  ClassifierModel();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  OrtSession? _session;
  bool _envInitialised = false;

  /// Tensor name used for the audio input.
  String _inputName = 'input';

  /// Tensor name used for the predictions (logits) output.
  String _predictionsName = 'predictions';

  /// Tensor name for embeddings output, or `null` if the model doesn't
  /// produce embeddings.
  String? _embeddingsName = 'embeddings';

  /// Index of the predictions tensor in the session's output list.
  int _predictionsIndex = 0;

  /// Index of the embeddings tensor in the session's output list, or -1.
  int _embeddingsIndex = -1;

  /// Whether a model is currently loaded and ready for inference.
  bool get isLoaded => _session != null;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Load an ONNX model from raw [modelBytes].
  ///
  /// This is the primary loading method, suitable for models read from
  /// Flutter's `rootBundle` or from any byte source.
  ///
  /// Tensor names default to BirdNET conventions but can be overridden to
  /// support any ONNX model:
  /// - [inputName] — name of the audio input tensor (default `"input"`).
  /// - [predictionsName] — name of the logits output tensor (default
  ///   `"predictions"`).
  /// - [embeddingsName] — name of the embeddings output tensor, or `null` if
  ///   the model does not produce embeddings (default `"embeddings"`).
  ///
  /// Initialises the ORT environment on first call.  May throw if the model
  /// bytes are invalid.
  Future<void> loadModel(
    Uint8List modelBytes, {
    String inputName = 'input',
    String predictionsName = 'predictions',
    String? embeddingsName = 'embeddings',
  }) async {
    _inputName = inputName;
    _predictionsName = predictionsName;
    _embeddingsName = embeddingsName;
    if (!_envInitialised) {
      OrtEnv.instance.init();
      _envInitialised = true;
    }

    // Release previous session if reloading.
    _session?.release();

    final sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromBuffer(modelBytes, sessionOptions);

    // Resolve output tensor indices by name so we don't rely on graph order.
    _resolveOutputIndices();
  }

  /// Map configured output tensor names to their actual indices in the
  /// session's output list.
  ///
  /// The ONNX graph may order outputs differently than expected (e.g.
  /// embeddings before predictions).  Querying [OrtSession.outputNames]
  /// lets us handle any ordering.
  void _resolveOutputIndices() {
    final session = _session;
    if (session == null) return;

    final names = session.outputNames;
    debugPrint('[ClassifierModel] output tensor names: $names');

    _predictionsIndex = names.indexOf(_predictionsName);
    if (_predictionsIndex < 0) {
      // Fallback: pick whichever output is NOT the embeddings output.
      // If only one output exists, use index 0.
      final embName = _embeddingsName;
      if (embName != null && names.contains(embName)) {
        _predictionsIndex = names.indexOf(embName) == 0 ? 1 : 0;
      } else {
        _predictionsIndex = 0;
      }
      debugPrint('[ClassifierModel] predictions name "$_predictionsName" not '
          'found in outputs; falling back to index $_predictionsIndex');
    }

    final embName = _embeddingsName;
    if (embName != null) {
      _embeddingsIndex = names.indexOf(embName);
    } else {
      _embeddingsIndex = -1;
    }

    debugPrint('[ClassifierModel] resolved — predictions @ index '
        '$_predictionsIndex, embeddings @ index $_embeddingsIndex');
  }

  /// Load an ONNX model from a file at [modelPath] on disk.
  ///
  /// Convenience wrapper that reads the file and delegates to [loadModel].
  /// Tensor name parameters are forwarded — see [loadModel] for details.
  /// Throws [FileSystemException] if the file does not exist.
  Future<void> loadModelFromFile(
    String modelPath, {
    String inputName = 'input',
    String predictionsName = 'predictions',
    String? embeddingsName = 'embeddings',
  }) async {
    final modelFile = File(modelPath);
    if (!modelFile.existsSync()) {
      throw FileSystemException('Model file not found', modelPath);
    }
    final bytes = await modelFile.readAsBytes();
    await loadModel(
      bytes,
      inputName: inputName,
      predictionsName: predictionsName,
      embeddingsName: embeddingsName,
    );
  }

  // ---------------------------------------------------------------------------
  // Inference
  // ---------------------------------------------------------------------------

  /// Run inference on [audioSamples] (32 kHz mono float32, [-1, 1]).
  ///
  /// [windowSamples] is the expected number of samples for the configured
  /// window duration (e.g. 96 000 for 3 s at 32 kHz).  If [audioSamples] is
  /// shorter it is zero-padded; if longer it is truncated.
  ///
  /// Returns a [ModelOutput] with the raw logits and embeddings.
  Future<ModelOutput> predict(
    Float32List audioSamples, {
    required int windowSamples,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    // Prepare input: pad or truncate to exactly [windowSamples].
    final input = Float32List(windowSamples);
    final copyLen = audioSamples.length < windowSamples
        ? audioSamples.length
        : windowSamples;
    for (var i = 0; i < copyLen; i++) {
      input[i] = audioSamples[i].clamp(-1.0, 1.0);
    }
    // Remaining elements are already 0.0 (zero-padding).

    // Create input tensor: shape [1, windowSamples].
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      input,
      [1, windowSamples],
    );

    final runOptions = OrtRunOptions();

    try {
      // Run inference.
      final outputs =
          await session.runAsync(runOptions, {_inputName: inputTensor});

      // Extract predictions tensor using resolved index.
      final predictionsRaw = outputs?[_predictionsIndex]?.value;
      final predictions = _flatten(predictionsRaw);

      // Extract embeddings tensor if configured and available.
      List<double>? embeddings;
      if (_embeddingsIndex >= 0 &&
          outputs != null &&
          _embeddingsIndex < outputs.length &&
          outputs[_embeddingsIndex] != null) {
        embeddings = _flatten(outputs[_embeddingsIndex]!.value);
      }

      // Release output tensors.
      outputs?.forEach((e) => e?.release());

      return ModelOutput(
        predictions: predictions,
        embeddings: embeddings,
      );
    } finally {
      // Release native resources.
      inputTensor.release();
      runOptions.release();
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Release all native resources held by the ONNX session.
  void dispose() {
    _session?.release();
    _session = null;
    if (_envInitialised) {
      OrtEnv.instance.release();
      _envInitialised = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Flatten a nested list from ORT output into a single [List<double>].
  ///
  /// ORT may return `List<List<double>>` for batched outputs or `List<double>`
  /// for single outputs.
  static List<double> _flatten(dynamic value) {
    if (value is List<List<double>>) {
      // Batched output — take first batch.
      return value.first;
    }
    if (value is List<double>) {
      return value;
    }
    if (value is List) {
      // Try to cast inner elements.
      return value
          .expand((e) => e is List ? e : [e])
          .map((e) => (e as num).toDouble())
          .toList();
    }
    throw ArgumentError('Unexpected ORT output type: ${value.runtimeType}');
  }
}

// =============================================================================
// Model Output — Container for raw inference results
// =============================================================================

/// Raw output from a single model inference run.
///
/// Contains the logit scores for all species classes plus optional feature
/// embeddings.
class ModelOutput {
  /// Creates a model output container.
  const ModelOutput({
    required this.predictions,
    this.embeddings,
  });

  /// Model scores for each species class.
  ///
  /// The BirdNET model outputs sigmoid-activated probabilities in [0, 1].
  /// Do **not** apply sigmoid again — pass these directly to sensitivity
  /// scaling and top-K extraction.
  final List<double> predictions;

  /// Feature embeddings (length = 1 280) for similarity/clustering.
  ///
  /// May be `null` if the model output did not include embeddings.
  final List<double>? embeddings;
}
