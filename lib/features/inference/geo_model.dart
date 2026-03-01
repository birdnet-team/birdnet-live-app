// =============================================================================
// Geo-Model — Location-based species prediction
// =============================================================================
//
// A secondary ONNX model that predicts which species are likely to be present
// at a given geographic location and time of year.  Its output is used to
// filter or weight the audio classifier's results.
//
// ### Model interface
//
// ```
// Input:  lat (float), lon (float), week (int 1–48, 4 weeks per month)
// Output: per-species probability vector
// ```
//
// The geo-model has its own labels file which overlaps significantly — but
// not 100% — with the audio classifier's labels.  Species are matched
// between models by scientific name.
//
// ### Current status
//
// The actual ONNX model is not yet available.  This class provides the full
// public interface with a **dummy implementation** that returns plausible
// placeholder scores.  When the real model is delivered, only the internal
// `predict` body needs to change.
//
// ### Week numbering
//
// Weeks 1–48 map to 4 weeks per calendar month:
//   - January  → weeks 1–4
//   - February → weeks 5–8
//   - …
//   - December → weeks 45–48
// =============================================================================

import 'dart:math' as math;

import 'label_parser.dart';
import 'models/species.dart';

/// Location-based species predictor.
///
/// Predicts which species are expected at a given lat/lon/week and returns
/// a scored list used to filter audio classifier results.
class GeoModel {
  /// Creates an uninitialised geo-model.  Call [loadLabels] before [predict].
  GeoModel();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  List<Species> _labels = const [];
  bool _modelLoaded = false;

  /// Whether the geo-model is initialised and ready for predictions.
  bool get isReady => _labels.isNotEmpty && _modelLoaded;

  /// The geo-model's own species labels.
  List<Species> get labels => _labels;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Load the geo-model's own labels CSV.
  ///
  /// The labels file uses the same semicolon-delimited format as the audio
  /// model but may contain a different (overlapping) set of species.
  void loadLabels(String labelsCsv) {
    _labels = LabelParser.parse(labelsCsv);
  }

  /// Load the geo-model ONNX file from [modelBytes].
  ///
  /// **Dummy implementation** — marks the model as loaded without actually
  /// initialising an ONNX session.  Replace with real ONNX loading when the
  /// model becomes available.
  Future<void> loadModel(/* Uint8List modelBytes */) async {
    // TODO: Replace with OrtSession.fromBuffer(modelBytes, opts) when the
    // real geo-model ONNX file is available.
    _modelLoaded = true;
  }

  /// Release all resources.
  void dispose() {
    _labels = const [];
    _modelLoaded = false;
  }

  // ---------------------------------------------------------------------------
  // Prediction
  // ---------------------------------------------------------------------------

  /// Predict species probabilities for a geographic location and week.
  ///
  /// Returns a map of **scientific name → probability** for every species in
  /// the geo-model's label set.  Only species with probability ≥ 0 are
  /// included (typically all of them).
  ///
  /// [latitude]  in degrees (−90 to +90).
  /// [longitude] in degrees (−180 to +180).
  /// [week]      week of the year (1–48, 4 per month).
  ///
  /// **Dummy implementation** — returns deterministic scores seeded from the
  /// location hash so that results are reproducible but vary by position.
  Map<String, double> predict({
    required double latitude,
    required double longitude,
    required int week,
  }) {
    if (!isReady) {
      throw StateError('GeoModel not ready. Call loadLabels() + loadModel().');
    }

    assert(week >= 1 && week <= 48, 'week must be 1–48, got $week');

    // ----- Dummy implementation -----
    // Generate plausible per-species scores that vary by location/week.
    // This allows the full filtering pipeline to be tested end-to-end.
    final rng = math.Random(
      latitude.hashCode ^ longitude.hashCode ^ week.hashCode,
    );

    final scores = <String, double>{};
    for (final sp in _labels) {
      // ~60 % of species get a nonzero score (simulates regional filtering).
      final score = rng.nextDouble();
      scores[sp.scientificName] = score;
    }
    return scores;
  }

  /// Return the subset of species whose geo-model score meets [threshold].
  ///
  /// Convenience wrapper around [predict] for simple include/exclude
  /// filtering.
  Set<String> expectedSpecies({
    required double latitude,
    required double longitude,
    required int week,
    double threshold = 0.03,
  }) {
    final scores = predict(
      latitude: latitude,
      longitude: longitude,
      week: week,
    );
    return {
      for (final entry in scores.entries)
        if (entry.value >= threshold) entry.key,
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Convert a [DateTime] to the 1–48 week number used by the geo-model.
  ///
  /// 4 weeks per month, so January 1–7 → week 1, January 8–14 → week 2, etc.
  static int dateTimeToWeek(DateTime dt) {
    final monthBase = (dt.month - 1) * 4; // 0, 4, 8, …, 44
    final weekInMonth = ((dt.day - 1) / 7).floor().clamp(0, 3); // 0–3
    return monthBase + weekInMonth + 1; // 1–48
  }
}
