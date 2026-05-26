// =============================================================================
// Inference Isolate — Thin in-process wrapper around InferenceService
// =============================================================================
//
// Originally this class spawned a Dart [Isolate] to run ONNX inference off
// the UI thread, because the `onnxruntime` package used dart:ffi (which is
// isolate-friendly).
//
// `flutter_onnxruntime` (the runtime we now ship) talks to the native ORT
// session via platform channels and runs inference on a native background
// thread queue, so the heavy work already happens off the UI thread.  The
// remaining Dart-side post-processing (sigmoid, sort, top-K) takes
// sub-millisecond on the 5,250-class label space and is safe to run on the
// root isolate.
//
// To minimize churn at the call sites this class now keeps the same public
// API but delegates synchronously to a single [InferenceService] instance.
// If post-processing latency becomes visible, we can wrap individual
// operations in `compute()` later.
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'inference_service.dart';
import 'model_config.dart';
import 'models/detection.dart';

/// Runs ONNX inference for the audio classifier on the root isolate.
///
/// The class keeps the historical "isolate" name to avoid a wide rename;
/// see the file header for the rationale.
class InferenceIsolate {
  InferenceService? _service;
  Future<void>? _pendingInfer; // serialize calls into the native session.

  /// Whether the underlying inference service is initialized and ready.
  bool get isRunning => _service != null;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Load the model from a file path and parse labels.
  ///
  /// [modelFilePath] — absolute path to the `.onnx` model file on disk.
  /// [labelsCsv] — full content of the labels file.
  /// [config] — model configuration (tensor names, label format, defaults).
  /// [scoreBlacklistJson] — optional JSON score multiplier map.
  Future<void> start({
    required String modelFilePath,
    required String labelsCsv,
    required ModelConfig config,
    String? scoreBlacklistJson,
  }) async {
    if (isRunning) return;

    debugPrint('[InferenceIsolate] loading model from file: $modelFilePath');
    if (!File(modelFilePath).existsSync()) {
      throw FileSystemException('Model file not found', modelFilePath);
    }

    final svc = InferenceService();
    await svc.initialize(
      modelFilePath: modelFilePath,
      labelsCsv: labelsCsv,
      config: config,
      scoreBlacklistJson: scoreBlacklistJson,
    );
    _service = svc;
    debugPrint('[InferenceIsolate] model ready');
  }

  /// Release the inference service and free native resources.
  Future<void> stop() async {
    final svc = _service;
    _service = null;
    if (svc != null) {
      // Wait for any in-flight inference to settle before closing the session.
      try {
        await _pendingInfer;
      } catch (_) {}
      await svc.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Inference
  // ---------------------------------------------------------------------------

  /// Run inference on [audioSamples].
  ///
  /// Calls are serialized so that overlapping requests never enter the
  /// native session simultaneously (which would race on output tensor
  /// disposal).
  Future<List<Detection>> infer(
    Float32List audioSamples, {
    int? windowSeconds,
    double? sensitivity,
    double? confidenceThreshold,
    int? topK,
    bool useTemporalPooling = true,
  }) async {
    final svc = _service;
    if (svc == null) {
      throw StateError('Inference service not started. Call start() first.');
    }

    // Serialize concurrent inference calls.
    final previous = _pendingInfer;
    final completer = Completer<void>();
    _pendingInfer = completer.future;
    try {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      return await svc.infer(
        audioSamples,
        windowSeconds: windowSeconds,
        sensitivity: sensitivity,
        confidenceThreshold: confidenceThreshold,
        topK: topK,
        useTemporalPooling: useTemporalPooling,
      );
    } finally {
      completer.complete();
    }
  }

  /// Clear the temporal pooling buffer.
  void resetPooling() {
    _service?.resetPooling();
  }

  /// Override the temporal-pooling window count. Pass `null` to revert to
  /// the model-config default. Safe to call before [start] has completed —
  /// the call is dropped if the service is not yet ready.
  void setMaxPoolWindows(int? value) {
    _service?.setMaxPoolWindows(value);
  }

  /// Override the pooling mode (`'off' | 'average' | 'max' | 'lme'`).
  /// Safe to call before [start] — silently dropped if not ready.
  void setPoolingMode(String? mode) {
    _service?.setPoolingMode(mode);
  }
}
