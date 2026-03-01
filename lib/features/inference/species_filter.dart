// =============================================================================
// Species Filter — Filters detections by geo-model or custom species list
// =============================================================================
//
// After the audio classifier produces raw detections, this module applies an
// optional geographic or user-defined filter to narrow results to species
// that are plausible at the current location/time or that the user has
// explicitly selected.
//
// ### Filter modes
//
// | Mode           | Behaviour                                              |
// |----------------|--------------------------------------------------------|
// | `off`          | No filtering — all species eligible.                   |
// | `geoExclude`   | Keep only species the geo-model predicted (≥ threshold).|
// | `geoMerge`     | Multiply audio score by geo-model probability.         |
// | `customList`   | Keep only species whose scientific name is in the list.|
//
// ### Score merging (geoMerge)
//
// When merging, the final confidence is:
//
//   `merged = audioScore * geoScore`
//
// This naturally down-weights species the geo-model considers unlikely while
// preserving the audio model's relative ranking.
// =============================================================================

import 'models/detection.dart';

/// How audio classifier detections are filtered by geographic or user data.
enum SpeciesFilterMode {
  /// No filtering — all species from the audio model are eligible.
  off,

  /// Exclude species not predicted by the geo-model above [threshold].
  geoExclude,

  /// Multiply audio confidence by geo-model probability (soft weighting).
  geoMerge,

  /// Keep only species whose scientific name appears in a custom list.
  customList,
}

/// Static helpers for filtering [Detection] lists.
///
/// All methods are pure functions with no side effects.
abstract final class SpeciesFilter {
  /// Apply a species filter to [detections].
  ///
  /// [mode] — the active filter strategy.
  /// [geoScores] — geo-model predictions keyed by scientific name (required
  ///   for [SpeciesFilterMode.geoExclude] and [SpeciesFilterMode.geoMerge]).
  /// [geoThreshold] — minimum geo-model score to include a species in
  ///   exclude mode (default 0.03).
  /// [customSpecies] — set of scientific names for custom list mode.
  /// [confidenceThreshold] — re-applied after merging to drop weak results.
  ///
  /// Returns a new list; the input is not modified.
  static List<Detection> apply({
    required List<Detection> detections,
    required SpeciesFilterMode mode,
    Map<String, double>? geoScores,
    double geoThreshold = 0.03,
    Set<String>? customSpecies,
    double confidenceThreshold = 0.0,
  }) {
    switch (mode) {
      case SpeciesFilterMode.off:
        return detections;

      case SpeciesFilterMode.geoExclude:
        if (geoScores == null) return detections;
        return _excludeByGeo(detections, geoScores, geoThreshold);

      case SpeciesFilterMode.geoMerge:
        if (geoScores == null) return detections;
        return _mergeWithGeo(
          detections,
          geoScores,
          confidenceThreshold,
        );

      case SpeciesFilterMode.customList:
        if (customSpecies == null || customSpecies.isEmpty) return detections;
        return _filterByCustomList(detections, customSpecies);
    }
  }

  // ---------------------------------------------------------------------------
  // Private strategies
  // ---------------------------------------------------------------------------

  /// Keep only detections whose species appears in [geoScores] with a score
  /// at or above [threshold].
  static List<Detection> _excludeByGeo(
    List<Detection> detections,
    Map<String, double> geoScores,
    double threshold,
  ) {
    return detections.where((d) {
      final geoScore = geoScores[d.species.scientificName];
      return geoScore != null && geoScore >= threshold;
    }).toList();
  }

  /// Multiply audio confidence by geo-model probability, then re-sort and
  /// re-filter.
  static List<Detection> _mergeWithGeo(
    List<Detection> detections,
    Map<String, double> geoScores,
    double confidenceThreshold,
  ) {
    final merged = <Detection>[];

    for (final d in detections) {
      final geoScore = geoScores[d.species.scientificName] ?? 0.0;
      final mergedConfidence = d.confidence * geoScore;

      if (mergedConfidence >= confidenceThreshold) {
        merged.add(Detection(
          species: d.species,
          confidence: mergedConfidence,
          timestamp: d.timestamp,
        ));
      }
    }

    // Re-sort by descending merged confidence.
    merged.sort((a, b) => b.confidence.compareTo(a.confidence));
    return merged;
  }

  /// Keep only detections whose scientific name is in [allowedSpecies].
  static List<Detection> _filterByCustomList(
    List<Detection> detections,
    Set<String> allowedSpecies,
  ) {
    return detections
        .where((d) => allowedSpecies.contains(d.species.scientificName))
        .toList();
  }
}
