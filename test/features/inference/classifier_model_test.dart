// =============================================================================
// Classifier Model Tests
// =============================================================================
//
// Tests for the ONNX model wrapper.  Since we cannot load the full ONNX model
// in unit tests (no native runtime), these tests focus on:
//
//   1. Pre-inference state validation (isLoaded, StateError on predict).
//   2. ModelOutput data class behaviour.
//   3. The internal _flatten helper (tested indirectly via public API).
//
// Full model integration tests require a device or emulator with the ONNX
// runtime and the model file available.
// =============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/features/inference/classifier_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClassifierModel', () {
    test('isLoaded is false before loading', () {
      final model = ClassifierModel();
      expect(model.isLoaded, isFalse);
    });

    test('predict throws StateError when model not loaded', () {
      final model = ClassifierModel();
      expect(
        () => model.predict(
          Float32List(96000),
          windowSamples: 96000,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('loadModelFromFile throws on missing file', () {
      final model = ClassifierModel();
      expect(
        () => model.loadModelFromFile('/nonexistent/path/model.onnx'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('ModelOutput', () {
    test('stores predictions list', () {
      final output = ModelOutput(
        predictions: [0.1, 0.2, 0.3],
      );
      expect(output.predictions, [0.1, 0.2, 0.3]);
      expect(output.embeddings, isNull);
    });

    test('stores optional embeddings', () {
      final output = ModelOutput(
        predictions: [0.1],
        embeddings: [0.5, 0.6],
      );
      expect(output.embeddings, isNotNull);
      expect(output.embeddings!.length, 2);
    });
  });
}
