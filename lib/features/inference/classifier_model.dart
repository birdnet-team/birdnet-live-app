// =============================================================================
// Classifier Model — onnxruntime_v2 wrapper for species classification
// =============================================================================
//
// Encapsulates all ONNX-specific logic: model loading, session management,
// tensor creation, and inference execution.  The rest of the app interacts
// only through the high-level [InferenceService] interface.
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
// Audio must be mono float32 normalized to [-1.0, 1.0].  If the provided
// audio is shorter than the expected window it is zero-padded on the right.
//
// ### Execution Providers
//
// The [executionProvider] parameter controls hardware acceleration:
// - `'cpu'`         — always-available baseline.
// - `'accelerated'` — NNAPI on Android, CoreML on iOS; falls back to CPU.
//
// ### Threading
//
// onnxruntime_v2 runs native inference on a background thread via platform
// channels, so calls do not block the UI.
//
// ### Lifecycle
//
// 1. Call [loadModelFromFile] to load the `.onnx` model.
// 2. Call [predict] as many times as needed.
// 3. Call [dispose] when finished to free native resources.
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

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

  OrtSession? _session;

  /// Tensor name used for the audio input.
  String _inputName = 'input';

  /// Tensor name used for the predictions (logits) output.
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
  /// [executionProvider] controls hardware acceleration:
  /// - `'cpu'`         — CPU-only (default, always available).
  /// - `'accelerated'` — NNAPI (Android) or CoreML (iOS); CPU fallback.
  ///
  /// Tensor names default to BirdNET conventions but can be overridden to
  /// support any ONNX model.
  ///
  /// Throws [FileSystemException] if the file does not exist.
  Future<void> loadModelFromFile(
    String modelPath, {
    String inputName = 'input',
    String predictionsName = 'predictions',
    String? embeddingsName = 'embeddings',
    String executionProvider = 'cpu',
    int intraOpThreads = 0, // 0 = ONNX Runtime default (auto)
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
    old?.release();

    final sessionOptions = OrtSessionOptions();
    _applyExecutionProvider(sessionOptions, executionProvider);
    if (intraOpThreads > 0) {
      sessionOptions.setIntraOpNumThreads(intraOpThreads);
    }

    _session = OrtSession.fromFile(modelFile, sessionOptions);
    sessionOptions.release();

    debugPrint('[ClassifierModel] loaded'
        ' inputs:${_session!.inputNames}'
        ' outputs:${_session!.outputNames}'
        ' EP:$executionProvider');
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
      throw StateError('Model not loaded. Call loadModelFromFile() first.');
    }

    // Prepare input: pad or truncate to exactly [windowSamples].
    final input = Float32List(windowSamples);
    final copyLen = audioSamples.length < windowSamples
        ? audioSamples.length
        : windowSamples;
    for (var i = 0; i < copyLen; i++) {
      input[i] = audioSamples[i].clamp(-1.0, 1.0);
    }

    // Create input tensor: shape [1, windowSamples].
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      input,
      [1, windowSamples],
    );

    final runOptions = OrtRunOptions();
    List<OrtValue?> outputs = [];
    try {
      // runAsync offloads the blocking FFI call to a Dart isolate so the UI
      // thread stays responsive for progress updates between windows.
      outputs =
          await session.runAsync(runOptions, {_inputName: inputTensor}) ?? [];

      // Map output list back to names.
      final outputMap = <String, OrtValue?>{};
      for (var i = 0; i < session.outputNames.length; i++) {
        outputMap[session.outputNames[i]] = outputs[i];
      }

      // Extract predictions tensor by name.
      final predValue = outputMap[_predictionsName];
      if (predValue == null) {
        throw StateError(
          'Predictions output "$_predictionsName" not found in model outputs '
          '(${outputMap.keys.toList()})',
        );
      }
      final predictions = _toDoubleList(predValue.value);

      // Extract embeddings tensor if configured and available.
      List<double>? embeddings;
      final embName = _embeddingsName;
      if (embName != null && outputMap.containsKey(embName)) {
        final embValue = outputMap[embName];
        if (embValue != null) {
          embeddings = _toDoubleList(embValue.value);
        }
      }

      return ModelOutput(predictions: predictions, embeddings: embeddings);
    } finally {
      inputTensor.release();
      runOptions.release();
      for (final t in outputs) {
        t?.release();
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
    s?.release();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Configure the [OrtSessionOptions] based on [provider].
  static void _applyExecutionProvider(
    OrtSessionOptions options,
    String provider,
  ) {
    if (provider == 'accelerated') {
      if (Platform.isAndroid) {
        options.appendNnapiProvider(NnapiFlags.useNone);
      } else if (Platform.isIOS) {
        options.appendCoreMLProvider(CoreMLFlags.useNone);
      }
    } else if (provider == 'nnapi_npu_only') {
      // cpuDisabled: NNAPI must use a hardware accelerator — no CPU fallback.
      // Throws if no supported hardware accelerator is available for this model.
      if (Platform.isAndroid) {
        options.appendNnapiProvider(NnapiFlags.cpuDisabled);
      }
    } else if (provider == 'xnnpack') {
      options.appendXnnpackProvider();
    }
    // CPU is always the final fallback (except for nnapi_npu_only).
    if (provider != 'nnapi_npu_only') {
      options.appendCPUProvider(CPUFlags.useArena);
    }
  }

  /// Convert a tensor value to a flat `List<double>`.
  ///
  /// onnxruntime_v2 returns multi-dimensional tensors as nested lists
  /// (e.g. shape `[1, N]` becomes `List<List<double>>`). This flattens any nesting.
  static List<double> _toDoubleList(dynamic raw) {
    if (raw is Float32List) return raw.toList();
    if (raw is List<double>) return raw;
    if (raw is List) return _flatten(raw);
    throw StateError('Unexpected tensor value type: ${raw.runtimeType}');
  }

  static List<double> _flatten(List raw) {
    final result = <double>[];
    for (final e in raw) {
      if (e is double) {
        result.add(e);
      } else if (e is num) {
        result.add(e.toDouble());
      } else if (e is Float32List) {
        result.addAll(e.toList());
      } else if (e is List) {
        result.addAll(_flatten(e));
      } else {
        throw StateError('Unexpected element type in tensor: ${e.runtimeType}');
      }
    }
    return result;
  }
}

// =============================================================================
// Model Output — Container for raw inference results
// =============================================================================

/// Raw output from a single model inference run.
class ModelOutput {
  const ModelOutput({required this.predictions, this.embeddings});

  /// Model scores for each species class.
  ///
  /// The BirdNET model outputs sigmoid-activated probabilities in [0, 1].
  final List<double> predictions;

  /// Feature embeddings (length = 1 280) for similarity/clustering.
  ///
  /// Null if the model doesn't produce embeddings or [embeddingsName] was
  /// not configured.
  final List<double>? embeddings;
}
