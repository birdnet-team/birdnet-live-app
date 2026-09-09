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
// | Mode           | Behavior                                               |
// |----------------|--------------------------------------------------------|
// | `off`          | No filtering — all species eligible.                   |
// | `geoExclude`   | Keep only species the geo-model predicted (≥ threshold).|
// | `geoAdaptive`  | Required geo-model score scales with audio confidence. |
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
//
// ### Adaptive filtering (geoAdaptive)
//
// The two scores are combined as evidence in log-odds space, with the
// geo-model's vote damped as audio confidence rises:
//
//   `z = logit(p) + w(p) * (logit(g) - logit(g0))`
//
// where `p` is the audio confidence, `g` the geo-model score, `g0` the
// *neutral occurrence*, and `w(p)` a damping weight that is `1` at the user's
// confidence threshold and falls to `0` at [_adaptiveImmunity].  A detection
// is kept when `z` still clears the confidence threshold.  Unlike `geoMerge`
// the reported confidence is never altered — the geo-model only votes on
// keep/drop, so no blended score reaches history or exports.
//
// `g0` is **the floor of the abundant tier** at this location, taken from the
// same [ExploreTierScale] the Explore screen and the spoken commonness hints
// use.  That makes the behaviour rank-relative rather than absolute, so it
// travels between a species-rich tropical site and an Arctic one unchanged,
// and it means the tier a user sees on an Explore card predicts how the filter
// will treat that bird:
//
// | Tier at this location | Roughly needs |
// |-----------------------|---------------|
// | abundant              | any score     |
// | common                | ~0.55–0.70    |
// | frequent              | ~0.70–0.82    |
// | uncommon              | ~0.78–0.89    |
// | scarce / rare         | ~0.83–0.92    |
// | not on the local list | ~0.92–0.97    |
//
// The mode is therefore stricter than `geoExclude` for weak detections and far
// more permissive for confident ones — the point being to cut false positives
// from uncommon species without losing a genuinely clear recording of one.
//
// Calibrated against the shipped geo-model across 20 locations worldwide × 4
// seasons; see `dev/adaptive_location_filter.md`.
// =============================================================================

import 'dart:math' as math;

import 'geo_abundance.dart';
import 'models/detection.dart';

/// How audio classifier detections are filtered by geographic or user data.
enum SpeciesFilterMode {
  /// No filtering — all species from the audio model are eligible.
  off,

  /// Exclude species not predicted by the geo-model above [threshold].
  geoExclude,

  /// Exclude species the geo-model considers implausible, with the required
  /// geo-model score falling as audio confidence rises.  Reported confidence
  /// is left untouched.
  geoAdaptive,

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
  ///   for [SpeciesFilterMode.geoExclude], [SpeciesFilterMode.geoAdaptive] and
  ///   [SpeciesFilterMode.geoMerge]).
  /// [geoThreshold] — minimum geo-model score to include a species in
  ///   exclude mode (default 0.03).  Adaptive mode ignores it and derives its
  ///   own bar from the local score distribution.
  /// [customSpecies] — set of scientific names for custom list mode.
  /// [confidenceThreshold] — re-applied after merging to drop weak results,
  ///   and used as the decision threshold in adaptive mode.
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

      case SpeciesFilterMode.geoAdaptive:
        if (geoScores == null) return detections;
        return _adaptiveGeoFilter(detections, geoScores, confidenceThreshold);

      case SpeciesFilterMode.geoMerge:
        if (geoScores == null) return detections;
        return _mergeWithGeo(detections, geoScores, confidenceThreshold);

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

  /// Audio confidence at or above which the geo-model gets no vote at all.
  static const double _adaptiveImmunity = 0.99;

  /// Exponent shaping the damping ramp.  Raising it makes confidence buy its
  /// way past the geo-model faster (looser); lowering it holds the geo-model's
  /// vote further up the confidence range (stricter).  The single tuning knob.
  static const double _adaptiveShape = 1.1;

  /// Clamp floor for logit inputs.  About 60% of geo-model outputs are exactly
  /// zero and the smallest non-zero value is ~7e-9 (fp16 subnormal floor), so
  /// this keeps exact zeros just below any real score instead of `-infinity`.
  static const double _adaptiveEpsilon = 1e-9;

  /// Log-odds of [x], clamped away from 0 and 1.
  static double _logit(double x) {
    final c = x.clamp(_adaptiveEpsilon, 1.0 - _adaptiveEpsilon);
    return math.log(c / (1.0 - c));
  }

  /// Keep detections whose combined audio + geo evidence still clears
  /// [confidenceThreshold], leaving the reported confidence untouched.
  ///
  /// The neutral occurrence — the geo score that neither helps nor hurts — is
  /// the abundant-tier floor for this location, so species above it are
  /// boosted, species below it are penalised, and the penalty shrinks to
  /// nothing as confidence approaches [_adaptiveImmunity].
  static List<Detection> _adaptiveGeoFilter(
    List<Detection> detections,
    Map<String, double> geoScores,
    double confidenceThreshold,
  ) {
    // Rank-relative rather than absolute: the bar is set by how this species
    // ranks among the ones actually expected here, using the same scale the
    // Explore screen shows.  Only ~300 of ~9800 scores clear the inclusion
    // threshold, so this is cheap enough to redo each inference cycle.
    final neutralOccurrence = ExploreTierScale.fromGeoScores(
      geoScores,
    ).minRawFor(ExploreTier.abundant);

    // The threshold is the pivot: at p == threshold a species needs exactly
    // `neutralOccurrence` to survive.  Clamping keeps it below the immunity
    // point so the damping ramp always spans a positive range.
    final threshold = confidenceThreshold.clamp(0.01, 0.9);
    final logitThreshold = _logit(threshold);
    final logitImmunity = _logit(_adaptiveImmunity);
    final logitNeutral = _logit(neutralOccurrence);
    final span = logitImmunity - logitThreshold;

    return detections.where((d) {
      // Near-certain detections are never filtered.
      if (d.confidence >= _adaptiveImmunity) return true;

      // Species the geo-model has no opinion on are treated as neutral.
      final geoScore =
          geoScores[d.species.scientificName] ?? neutralOccurrence;

      final logitConfidence = _logit(d.confidence);
      final ramp = ((logitImmunity - logitConfidence) / span).clamp(0.0, 1.0);
      final weight = math.pow(ramp, _adaptiveShape).toDouble();

      final evidence =
          logitConfidence + weight * (_logit(geoScore) - logitNeutral);
      return evidence >= logitThreshold;
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
        merged.add(
          Detection(
            species: d.species,
            confidence: mergedConfidence,
            timestamp: d.timestamp,
          ),
        );
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
