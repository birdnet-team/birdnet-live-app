// =============================================================================
// Score Blacklist — Per-model confidence multipliers for noisy labels
// =============================================================================
//
// Some model labels are known to produce common false positives in the field.
// This helper parses a model-specific JSON asset that maps English common names
// from the classifier labels to score fractions, then builds a dense multiplier
// vector aligned with the model output tensor. App-level species-name
// localization happens later in UI/export layers, so user language settings do
// not affect these model-label matches.
//
// Example JSON:
//
// ```json
// {
//   "Red Fox": 0.5
// }
// ```
//
// The feature is intentionally internal: users do not see or edit it from the
// app UI, but the plain JSON asset remains easy to tune for each model.
// =============================================================================

import 'dart:convert';

import 'models/species.dart';

/// Parses and applies per-label score multipliers.
abstract final class ScoreBlacklist {
  /// Parse a JSON object mapping English common names to fractions in [0, 1].
  static Map<String, double> parse(String content) {
    if (content.trim().isEmpty) return const <String, double>{};

    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('Score blacklist must be a JSON object.');
    }

    final fractions = <String, double>{};
    for (final entry in decoded.entries) {
      final name = entry.key.toString().trim();
      if (name.isEmpty) {
        throw const FormatException(
          'Score blacklist contains an empty label name.',
        );
      }

      final rawFraction = entry.value;
      if (rawFraction is! num) {
        throw FormatException(
          'Score blacklist fraction for "$name" must be numeric.',
        );
      }

      final fraction = rawFraction.toDouble();
      if (fraction.isNaN ||
          fraction.isInfinite ||
          fraction < 0.0 ||
          fraction > 1.0) {
        throw FormatException(
          'Score blacklist fraction for "$name" must be between 0 and 1.',
        );
      }

      fractions[name] = fraction;
    }

    return Map.unmodifiable(fractions);
  }

  /// Build a dense multiplier vector aligned with [labels].
  ///
  /// Unknown label names throw so model-tuning mistakes are caught on load.
  /// An empty blacklist returns an empty vector, which callers can treat as a
  /// fast no-op.
  static List<double> buildMultiplierVector({
    required List<Species> labels,
    required Map<String, double> fractions,
  }) {
    if (fractions.isEmpty) return const <double>[];

    final multipliers = List<double>.filled(labels.length, 1.0);
    final unmatched = fractions.keys.toSet();

    for (var i = 0; i < labels.length; i++) {
      final fraction = fractions[labels[i].commonName];
      if (fraction == null) continue;
      multipliers[i] = fraction;
      unmatched.remove(labels[i].commonName);
    }

    if (unmatched.isNotEmpty) {
      final names = unmatched.toList()..sort();
      throw FormatException(
        'Score blacklist contains unknown model label names: ${names.join(', ')}',
      );
    }

    return multipliers;
  }

  /// Multiply scores by a dense vector from [buildMultiplierVector].
  static List<double> applyMultipliers({
    required List<double> scores,
    required List<double> multipliers,
  }) {
    if (multipliers.isEmpty) return scores;

    assert(
      scores.length == multipliers.length,
      'scores (${scores.length}) must match multipliers (${multipliers.length})',
    );

    final adjusted = List<double>.filled(scores.length, 0.0);
    for (var i = 0; i < scores.length; i++) {
      adjusted[i] = scores[i] * multipliers[i];
    }
    return adjusted;
  }
}
