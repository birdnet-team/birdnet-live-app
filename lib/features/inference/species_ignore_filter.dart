// =============================================================================
// Species Ignore Filter — Binary score mask applied before temporal pooling
// =============================================================================

import 'models/species.dart';

/// Persisted user choices that determine which species are ignored.
class SpeciesIgnoreSettings {
  const SpeciesIgnoreSettings({
    this.ignoreBirds = false,
    this.ignoreMammals = false,
    this.ignoreAmphibians = false,
    this.ignoreInsects = false,
    this.commonGeoScoreCutoff = 1.0,
  });

  final bool ignoreBirds;
  final bool ignoreMammals;
  final bool ignoreAmphibians;
  final bool ignoreInsects;

  /// Geo-model probability above which a species is considered common.
  final double commonGeoScoreCutoff;

  bool ignoresClass(String className) => switch (className) {
    'Aves' => ignoreBirds,
    'Mammalia' => ignoreMammals,
    'Amphibia' => ignoreAmphibians,
    'Insecta' => ignoreInsects,
    _ => false,
  };
}

/// Pure helpers for building and applying the inference-time binary mask.
abstract final class SpeciesIgnoreFilter {
  /// Build the complete set of scientific names to suppress.
  ///
  /// Taxonomic groups come from the audio model labels. Common species come
  /// from the current geo-model prediction, using an inclusive cutoff.
  static Set<String> ignoredScientificNames({
    required Map<String, String> classByScientificName,
    required SpeciesIgnoreSettings settings,
    Map<String, double>? geoScores,
  }) {
    final ignored = <String>{};

    for (final entry in classByScientificName.entries) {
      if (settings.ignoresClass(entry.value)) ignored.add(entry.key);
    }

    if (geoScores != null) {
      final cutoff = settings.commonGeoScoreCutoff.clamp(0.0, 1.0);
      for (final entry in geoScores.entries) {
        if (entry.value > cutoff) ignored.add(entry.key);
      }
    }

    return ignored;
  }

  /// Return a geo-model score map with ignored species set to exactly zero.
  static Map<String, double> applyToGeoScores(
    Map<String, double> scores,
    Set<String> ignoredScientificNames,
  ) {
    if (ignoredScientificNames.isEmpty) return scores;
    return scores.map(
      (name, score) =>
          MapEntry(name, ignoredScientificNames.contains(name) ? 0.0 : score),
    );
  }

  /// Return an audio-model score vector with ignored species set to zero.
  static List<double> applyToAudioScores({
    required List<double> scores,
    required List<Species> labels,
    required Set<String> ignoredScientificNames,
  }) {
    if (ignoredScientificNames.isEmpty) return scores;

    final filtered = List<double>.of(scores);
    final count =
        filtered.length < labels.length ? filtered.length : labels.length;
    for (var i = 0; i < count; i++) {
      if (ignoredScientificNames.contains(labels[i].scientificName)) {
        filtered[i] = 0.0;
      }
    }
    return filtered;
  }
}
