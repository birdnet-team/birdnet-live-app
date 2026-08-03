// =============================================================================
// Classifier Model — flutter_onnxruntime wrapper for species classification
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
// Output: <predictionsName> — float32 [batch, N]       (probabilities per class)
// Output: <embeddingsName>  — float32 [batch, M]       (feature vectors, optional)
// ```
//
// Audio must be mono float32 normalized to [-1.0, 1.0].  If the provided
// audio is shorter than the expected window it is zero-padded on the right.
//
// ### Threading
//
// `flutter_onnxruntime` uses platform channels and runs native inference on
// a background thread (BackgroundTaskQueue), so calls do not block the UI.
// All Dart-side calls must happen on the root isolate.
//
// ### Lifecycle
//
// 1. Call [loadModelFromFile] to load the `.onnx` model.
// 2. Call [predict] as many times as needed.
// 3. Call [dispose] when finished to free native resources.
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Low-level wrapper around an ONNX classification model.
///
/// Handles session creation, input tensor construction, inference, and
/// resource cleanup.  Not intended for direct UI consumption — use
/// [InferenceService] instead.
class ClassifierModel {
  /// Creates a new model instance.  Call [loadModelFromFile] to initialize.
  ClassifierModel();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final OnnxRuntime _ort = OnnxRuntime();
  OrtSession? _session;

  /// Tensor name used for the audio input.
  String _inputName = 'input';

  /// Tensor name used for the predictions output.
  String _predictionsName = 'predictions';

  /// Tensor name for embeddings output, or `null` if the model doesn't
  /// produce embeddings.
  String? _embeddingsName = 'embeddings';

  /// Whether a model is currently loaded and ready for inference.
  bool get isLoaded => _session != null;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Load an ONNX model from a file at [modelPath] on disk.
  ///
  /// `flutter_onnxruntime` only loads sessions from a file path (not raw
  /// bytes); the audio model lives on disk via the asset pack service, so
  /// this is the natural entry point.
  ///
  /// Tensor names default to BirdNET conventions but can be overridden to
  /// support any ONNX model:
  /// - [inputName] — name of the audio input tensor (default `"input"`).
  /// - [predictionsName] — name of the predictions output tensor (default
  ///   `"predictions"`).
  /// - [embeddingsName] — name of the embeddings output tensor, or `null` if
  ///   the model does not produce embeddings (default `"embeddings"`).
  ///
  /// Throws [FileSystemException] if the file does not exist.
  Future<void> loadModelFromFile(
    String modelPath, {
    String inputName = 'input',
    String predictionsName = 'predictions',
    String? embeddingsName = 'embeddings',
    int? intraOpNumThreads,
  }) async {
    final modelFile = File(modelPath);
    if (!modelFile.existsSync()) {
      throw FileSystemException('Model file not found', modelPath);
    }

    _inputName = inputName;
    _predictionsName = predictionsName;
    _embeddingsName = embeddingsName;

    // Release previous session if reloading.
    final old = _session;
    _session = null;
    if (old != null) {
      await old.close();
    }

    _session = await _ort.createSession(
      modelPath,
      options:
          intraOpNumThreads == null
              ? null
              : OrtSessionOptions(
                intraOpNumThreads: intraOpNumThreads,
                interOpNumThreads: 1,
                useArena: true,
              ),
    );

    debugPrint(
      '[ClassifierModel] loaded — inputs: ${_session!.inputNames} '
      'outputs: ${_session!.outputNames} '
      'intra-op threads: ${intraOpNumThreads ?? 'auto'}',
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
  /// Returns a [ModelOutput] with model predictions and embeddings.
  Future<ModelOutput> predict(
    Float32List audioSamples, {
    required int windowSamples,
  }) async {
    final outputs = await _predictBatchInput(
      _prepareInput(audioSamples, windowSamples),
      batchSize: 1,
      windowSamples: windowSamples,
    );
    return outputs.single;
  }

  /// Run one native inference call for multiple equally sized audio windows.
  ///
  /// Windows remain independent along the model's batch dimension. Short
  /// inputs are padded and long inputs are truncated exactly like [predict].
  Future<List<ModelOutput>> predictBatch(
    List<Float32List> audioWindows, {
    required int windowSamples,
  }) async {
    if (audioWindows.isEmpty) {
      throw ArgumentError.value(
        audioWindows,
        'audioWindows',
        'At least one audio window is required',
      );
    }

    if (audioWindows.length == 1) {
      return [await predict(audioWindows.single, windowSamples: windowSamples)];
    }

    final batchInput = Float32List(audioWindows.length * windowSamples);
    for (var batchIndex = 0; batchIndex < audioWindows.length; batchIndex++) {
      final window = _prepareInput(audioWindows[batchIndex], windowSamples);
      batchInput.setRange(
        batchIndex * windowSamples,
        (batchIndex + 1) * windowSamples,
        window,
      );
    }

    return _predictBatchInput(
      batchInput,
      batchSize: audioWindows.length,
      windowSamples: windowSamples,
    );
  }

  Future<List<ModelOutput>> _predictBatchInput(
    Float32List input, {
    required int batchSize,
    required int windowSamples,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError('Model not loaded. Call loadModelFromFile() first.');
    }

    final inputTensor = await OrtValue.fromList(input, [
      batchSize,
      windowSamples,
    ]);

    Map<String, OrtValue>? outputs;
    try {
      // Run inference.
      outputs = await session.run({_inputName: inputTensor});

      // Extract predictions tensor by name.
      final predTensor = outputs[_predictionsName];
      if (predTensor == null) {
        throw StateError(
          'Predictions output "$_predictionsName" not found in model outputs '
          '(${outputs.keys.toList()})',
        );
      }
      final predictions = await _toDoubleList(predTensor);

      // Extract embeddings tensor if configured and available.
      List<double>? embeddings;
      final embName = _embeddingsName;
      if (embName != null && outputs.containsKey(embName)) {
        embeddings = await _toDoubleList(outputs[embName]!);
      }

      return ModelOutput.splitBatch(
        predictions: predictions,
        embeddings: embeddings,
        batchSize: batchSize,
      );
    } finally {
      // Release native resources.
      await inputTensor.dispose();
      if (outputs != null) {
        for (final t in outputs.values) {
          await t.dispose();
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Release all native resources held by the ONNX session.
  Future<void> dispose() async {
    final s = _session;
    _session = null;
    if (s != null) {
      await s.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Read a tensor's data as a flat `List<double>`. Handles whatever numeric
  /// list type `flutter_onnxruntime` returns (`Float32List`, `List<num>`,
  /// etc.).
  static Future<List<double>> _toDoubleList(OrtValue tensor) async {
    final raw = await tensor.asFlattenedList();
    if (raw is List<double>) return raw;
    if (raw is Float32List) return raw;
    return raw.map((e) => (e as num).toDouble()).toList(growable: false);
  }

  static Float32List _prepareInput(
    Float32List audioSamples,
    int windowSamples,
  ) {
    if (audioSamples.length == windowSamples) {
      return audioSamples;
    }

    final input = Float32List(windowSamples);
    final copyLen =
        audioSamples.length < windowSamples
            ? audioSamples.length
            : windowSamples;
    for (var i = 0; i < copyLen; i++) {
      input[i] = audioSamples[i].clamp(-1.0, 1.0);
    }
    return input;
  }
}

// =============================================================================
// Model Output — Container for raw inference results
// =============================================================================

/// Raw output from a single model inference run.
///
/// Contains the probability scores for all species classes plus optional feature
/// embeddings.
class ModelOutput {
  /// Creates a model output container.
  const ModelOutput({required this.predictions, this.embeddings});

  /// Split flattened batched outputs into one result per input window.
  static List<ModelOutput> splitBatch({
    required List<double> predictions,
    required int batchSize,
    List<double>? embeddings,
  }) {
    if (batchSize < 1 || predictions.length % batchSize != 0) {
      throw StateError(
        'Prediction output length ${predictions.length} cannot be split into '
        '$batchSize batches',
      );
    }
    if (embeddings != null && embeddings.length % batchSize != 0) {
      throw StateError(
        'Embedding output length ${embeddings.length} cannot be split into '
        '$batchSize batches',
      );
    }

    final predictionsPerBatch = predictions.length ~/ batchSize;
    final embeddingsPerBatch =
        embeddings == null ? 0 : embeddings.length ~/ batchSize;
    return [
      for (var index = 0; index < batchSize; index++)
        ModelOutput(
          predictions: predictions.sublist(
            index * predictionsPerBatch,
            (index + 1) * predictionsPerBatch,
          ),
          embeddings: embeddings?.sublist(
            index * embeddingsPerBatch,
            (index + 1) * embeddingsPerBatch,
          ),
        ),
    ];
  }

  /// Model scores for each species class.
  ///
  /// The BirdNET model outputs sigmoid-activated probabilities in [0, 1].
  /// Do **not** apply sigmoid again — pass these directly to sensitivity
  /// scaling before pooling and thresholding.
  final List<double> predictions;

  /// Feature embeddings (length = 1 280) for similarity/clustering.
  ///
  /// Null if the model doesn't produce embeddings or [embeddingsName] was
  /// not configured.
  final List<double>? embeddings;
}
