// =============================================================================
// Geo Abundance - distribution-adaptive abundance tiers from geo-model scores
// =============================================================================
//
// Buckets species into six abundance tiers whose boundaries adapt to the
// *distribution* of geo-model scores for the current area, rather than to a
// fixed set of absolute thresholds.
//
// The intuition: in a confident area such as Ithaca many species score very
// high, so "Abundant" should demand a high bar (only the genuine top species
// qualify); in an area with weaker predictions the same tier is reached at a
// lower absolute score. We therefore derive the tier cut points from rank
// percentiles of the raw scores, then clamp them with a few gentle absolute
// floors so an objectively sparse area cannot mint an "Abundant" species out
// of a weak best guess.
//
// ### Who uses this
//
// | Consumer            | Use                                               |
// |---------------------|---------------------------------------------------|
// | Explore             | tier chip + color on each species card            |
// | Announcements       | spoken "a common bird around here" hint           |
// | `SpeciesFilter`     | neutral occurrence for the adaptive location filter|
//
// All three build the scale from the same population — species scoring at or
// above [kAbundanceInclusionThreshold] — so a bird shown as *Abundant* in
// Explore is the same bird the filter treats as abundant.
//
// Lives in the inference layer rather than in `explore/` because it is
// geo-model domain logic that Explore merely happens to display; the UI
// helpers (colors, localized labels) stay in `explore/explore_tier.dart`.
//
// Pure Dart apart from `@immutable`, so the classification logic can be
// unit-tested without a widget tree.
// =============================================================================

import 'package:flutter/foundation.dart';

/// Minimum raw geo score for a species to count as part of the local
/// population at all. Species below this are not on the area's list and are
/// excluded from the tier calibration.
const double kAbundanceInclusionThreshold = 0.03;

/// Six abundance tiers, ordered from least to most abundant so that
/// [ExploreTier.index] doubles as an ordinal rank (0 = rare ... 5 = abundant).
enum ExploreTier {
  rare,
  scarce,
  uncommon,
  frequent,
  common,
  abundant;

  /// Fraction of the circle glyph that is filled for this tier
  /// (1/6 for rare ... 6/6 for abundant).
  double get fillFraction => (index + 1) / ExploreTier.values.length;

  /// Position of this tier on the 0-1 score ramp used to pick its color.
  double get rampPosition => index / (ExploreTier.values.length - 1);
}

/// Distribution-adaptive thresholds that map a raw geo score to an
/// [ExploreTier]. Build one per location/week via [ExploreTierScale.fromScores]
/// and reuse it for every species so they all share the same calibration.
@immutable
class ExploreTierScale {
  const ExploreTierScale._(this._minRawForTier);

  /// Minimum raw score required to reach each tier, indexed by
  /// [ExploreTier.index]. Monotonically non-decreasing from rare to abundant.
  final List<double> _minRawForTier;

  // Tuning constants.
  //
  // Target share of species in each tier, most to least abundant. These are
  // rank percentiles: they answer "how many species are high-scoring?" and
  // drive the primary adaptivity. They sum to 1.0.
  static const double _shareAbundant = 0.08;
  static const double _shareCommon = 0.12;
  static const double _shareFrequent = 0.25;
  static const double _shareUncommon = 0.28;
  static const double _shareScarce = 0.17;
  // Rare gets the remainder (0.10).

  // Gentle absolute floors (raw geo score) so a genuinely weak area cannot
  // promote its best guess past what the score justifies. Kept low so the
  // distribution stays the dominant signal.
  static const double _floorAbundant = 0.20;
  static const double _floorCommon = 0.10;

  /// Builds a scale from the raw current-week geo scores of every species in
  /// the list. Scores may be in any range; only their relative order and the
  /// absolute floors matter.
  factory ExploreTierScale.fromScores(Iterable<double> rawScores) {
    final sorted = rawScores.toList()..sort((a, b) => b.compareTo(a));
    final n = sorted.length;

    // Fallback for an empty or tiny list: fixed thresholds so the mapping is
    // still well-defined (mostly relevant to tests and empty locations).
    if (n == 0) {
      return const ExploreTierScale._([0.0, 0.12, 0.25, 0.4, 0.55, 0.7]);
    }

    // Cumulative rank boundaries (fraction of species at or above each tier).
    final cumAbundant = _shareAbundant;
    final cumCommon = cumAbundant + _shareCommon;
    final cumFrequent = cumCommon + _shareFrequent;
    final cumUncommon = cumFrequent + _shareUncommon;
    final cumScarce = cumUncommon + _shareScarce;

    // Raw score at each boundary rank. The species at rank `ceil(frac*n)-1`
    // (clamped) is the faintest member still inside the tier, so its score is
    // that tier's inclusive lower edge.
    double edgeAt(double cumulativeFraction) {
      final rank = (cumulativeFraction * n).ceil().clamp(1, n) - 1;
      return sorted[rank];
    }

    var minAbundant = edgeAt(cumAbundant);
    var minCommon = edgeAt(cumCommon);
    var minFrequent = edgeAt(cumFrequent);
    var minUncommon = edgeAt(cumUncommon);
    var minScarce = edgeAt(cumScarce);
    // Rare is anything above the inclusion threshold, so its floor is 0.
    const minRare = 0.0;

    // Apply absolute floors for the top two tiers.
    if (minAbundant < _floorAbundant) minAbundant = _floorAbundant;
    if (minCommon < _floorCommon) minCommon = _floorCommon;

    // Enforce monotonic ordering (abundant >= common >= ... >= rare) after the
    // percentile picks and floor clamps, so no lower tier out-thresholds a
    // higher one.
    minCommon = minCommon.clamp(0.0, minAbundant).toDouble();
    minFrequent = minFrequent.clamp(0.0, minCommon).toDouble();
    minUncommon = minUncommon.clamp(0.0, minFrequent).toDouble();
    minScarce = minScarce.clamp(0.0, minUncommon).toDouble();

    return ExploreTierScale._([
      minRare, // ExploreTier.rare
      minScarce, // ExploreTier.scarce
      minUncommon, // ExploreTier.uncommon
      minFrequent, // ExploreTier.frequent
      minCommon, // ExploreTier.common
      minAbundant, // ExploreTier.abundant
    ]);
  }

  /// Builds a scale from every score in [geoScores] that clears
  /// [kAbundanceInclusionThreshold] — the same population Explore calibrates
  /// against, so tiers agree between the two.
  factory ExploreTierScale.fromGeoScores(Map<String, double> geoScores) {
    final included = <double>[
      for (final v in geoScores.values)
        if (v >= kAbundanceInclusionThreshold) v,
    ];
    return ExploreTierScale.fromScores(included);
  }

  /// Classifies a raw geo score into an [ExploreTier].
  ExploreTier tierFor(double rawScore) {
    for (var i = ExploreTier.values.length - 1; i >= 0; i--) {
      if (rawScore >= _minRawForTier[i]) return ExploreTier.values[i];
    }
    return ExploreTier.rare;
  }

  /// Minimum raw score to reach [tier].
  double minRawFor(ExploreTier tier) => _minRawForTier[tier.index];
}
