// =============================================================================
// Detection — Result of a single species inference
// =============================================================================
//
// Produced by post-processing the model's raw output tensor.  Each detection
// pairs a [Species] with a confidence score and optional metadata such as
// the timestamp within the audio stream that triggered the detection.
//
// Detections are typically collected into a list, sorted by descending
// confidence, and filtered against a user-configurable threshold before
// being shown in the UI.
// =============================================================================

import 'species.dart';

/// A single species detection with its confidence score.
///
/// Created by the post-processing pipeline after running inference.
class Detection {
  /// Creates a detection result.
  const Detection({
    required this.species,
    required this.confidence,
    this.timestamp,
  });

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// The detected species.
  final Species species;

  /// Model confidence in [0.0, 1.0] after sigmoid and optional sensitivity
  /// scaling.
  final double confidence;

  /// Wall-clock [DateTime] when this detection was produced (optional).
  ///
  /// Set by the inference pipeline when processing live audio; may be `null`
  /// for offline / test scenarios.
  final DateTime? timestamp;

  // ---------------------------------------------------------------------------
  // Convenience
  // ---------------------------------------------------------------------------

  /// Confidence expressed as a percentage string, e.g. "87.3 %".
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)} %';

  // ---------------------------------------------------------------------------
  // Overrides
  // ---------------------------------------------------------------------------

  @override
  String toString() => 'Detection(${species.commonName}, $confidencePercent)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Detection &&
          runtimeType == other.runtimeType &&
          species == other.species &&
          confidence == other.confidence;

  @override
  int get hashCode => Object.hash(species, confidence);
}
