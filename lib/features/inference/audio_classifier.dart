// =============================================================================
// Audio Classifier — common interface of the ONNX and LiteRT model wrappers
// =============================================================================

import 'dart:typed_data';

import 'classifier_model.dart';

/// A loaded audio classification model.
///
/// Implemented by [ClassifierModel] (ONNX Runtime) and
/// `LiteRtClassifierModel` (experimental LiteRT backend).
abstract interface class AudioClassifier {
  /// Whether a model is loaded and ready for inference.
  bool get isLoaded;

  /// Classify one window of 32 kHz mono audio in [-1, 1].
  Future<ModelOutput> predict(
    Float32List audioSamples, {
    required int windowSamples,
  });

  /// Classify several independent windows of equal length.
  Future<List<ModelOutput>> predictBatch(
    List<Float32List> audioWindows, {
    required int windowSamples,
  });

  /// Release native resources.
  Future<void> dispose();
}
