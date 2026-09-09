// =============================================================================
// Explore Tier - presentation helpers for the abundance tiers
// =============================================================================
//
// The tier model itself ([ExploreTier], [ExploreTierScale]) lives in
// `features/inference/geo_abundance.dart` because Explore, Announcements and
// the adaptive location filter all classify species the same way. It is
// re-exported here so existing `explore_tier.dart` imports keep working.
//
// What stays in this file: turning a tier into a color, a localized name and
// the compact card glyph — the parts that need Flutter and the l10n bundle.
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/theme/score_colors.dart';
import '../../l10n/app_localizations.dart';
import '../inference/geo_abundance.dart';

export '../inference/geo_abundance.dart'
    show ExploreTier, ExploreTierScale, kAbundanceInclusionThreshold;

/// Samples the app's five-stop [ScoreColors] ramp at [t] (0-1), interpolating
/// between adjacent stops so six tiers each get a distinct color drawn from the
/// same CVD-safe palette used everywhere else.
Color exploreTierColor(ScoreColors colors, ExploreTier tier) {
  final stops = [
    colors.veryLow,
    colors.low,
    colors.mid,
    colors.high,
    colors.veryHigh,
  ];
  final x = tier.rampPosition.clamp(0.0, 1.0).toDouble() * (stops.length - 1);
  final i = x.floor().clamp(0, stops.length - 2);
  final f = x - i;
  return Color.lerp(stops[i], stops[i + 1], f) ?? stops[i];
}

/// Full localized tier name (e.g. "Abundant"). Shown in the species overlay and
/// used as the screen-reader annotation for the compact card chip.
String exploreTierLabel(AppLocalizations l10n, ExploreTier tier) {
  switch (tier) {
    case ExploreTier.abundant:
      return l10n.speciesFrequencyAbundant;
    case ExploreTier.common:
      return l10n.speciesFrequencyCommon;
    case ExploreTier.frequent:
      return l10n.speciesFrequencyFrequent;
    case ExploreTier.uncommon:
      return l10n.speciesFrequencyUncommon;
    case ExploreTier.scarce:
      return l10n.speciesFrequencyScarce;
    case ExploreTier.rare:
      return l10n.speciesFrequencyRare;
  }
}

/// First letter of the localized tier name, uppercased - the compact glyph
/// shown next to the fill circle on Explore cards.
String exploreTierLetter(AppLocalizations l10n, ExploreTier tier) {
  final label = exploreTierLabel(l10n, tier).trim();
  if (label.isEmpty) return '';
  return label.substring(0, 1).toUpperCase();
}
