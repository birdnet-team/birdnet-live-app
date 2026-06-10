// =============================================================================
// Taxonomy Service — Species metadata from bundled CSV
// =============================================================================
//
// Provides species information from the bundled taxonomy CSV, parsed once at
// startup.  Covers names, IDs, image metadata, and localized common names
// for all ~5,250 model species.
//
// ### Usage
//
// ```dart
// final service = TaxonomyService();
// service.loadFromCsv(csvContent);
// final species = service.lookup('Parus major');
// final imagePath = service.assetImagePath('Parus major');
// ```
//
// ### Caching
//
// The CSV lookup is O(1) via a HashMap keyed by scientific name.
//
// ### Reusability
//
// This service has no UI or feature dependencies.  It can be used by any
// screen that needs species metadata (explore, live, survey, info overlays).
// =============================================================================

import 'package:flutter/foundation.dart';

import '../models/taxonomy_species.dart';

/// Species metadata service — CSV-backed, fully offline.
class TaxonomyService {
  TaxonomyService();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// CSV-sourced species indexed by scientific name.
  final Map<String, TaxonomySpecies> _csvIndex = {};

  /// Whether the CSV has been loaded.
  bool get isLoaded => _csvIndex.isNotEmpty;

  /// Number of species in the CSV index.
  int get speciesCount => _csvIndex.length;

  // ---------------------------------------------------------------------------
  // CSV Loading
  // ---------------------------------------------------------------------------

  /// Parse the bundled taxonomy CSV and build the lookup index.
  ///
  /// The CSV is comma-delimited with a header row.
  void loadFromCsv(String csvContent) {
    _csvIndex.clear();

    final lines = csvContent.split('\n');
    if (lines.isEmpty) return;

    // Parse header.
    final header = _parseCsvLine(lines.first);
    if (header.isEmpty) return;

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final values = _parseCsvLine(line);
      if (values.length < header.length) continue;

      final row = <String, String>{};
      for (var j = 0; j < header.length && j < values.length; j++) {
        row[header[j]] = values[j];
      }

      final sciName = row['scientific_name'];
      if (sciName != null && sciName.isNotEmpty) {
        _csvIndex[sciName] = TaxonomySpecies.fromCsvRow(row);
      }
    }

    debugPrint('[TaxonomyService] loaded ${_csvIndex.length} species from CSV');
  }

  /// Simple CSV line parser handling commas within quotes.
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  // ---------------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------------

  /// Look up a species by scientific name (CSV only, offline).
  TaxonomySpecies? lookup(String scientificName) {
    return _csvIndex[scientificName];
  }

  /// Look up multiple species by scientific name.
  List<TaxonomySpecies> lookupAll(Iterable<String> scientificNames) {
    return scientificNames
        .map((name) => lookup(name))
        .where((s) => s != null)
        .cast<TaxonomySpecies>()
        .toList();
  }

  /// Search species by common name (any locale), alt name, or scientific name.
  ///
  /// Matches all whitespace-separated tokens (AND semantics) and ranks results
  /// so that exact prefix matches come before word-prefix matches, which come
  /// before substring matches. Ties are broken by observation count (more
  /// commonly observed species first), then alphabetical common name.
  List<TaxonomySpecies> search(String query, {int limit = 50}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final tokens =
        trimmed
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toList();
    if (tokens.isEmpty) return const [];

    // Score: 0 = full string starts with query, 1 = any word starts with a
    // token, 2 = substring only. Lower is better. Returns null if any token
    // fails to match anywhere.
    int? scoreSpecies(TaxonomySpecies species) {
      // Build the searchable haystacks: scientific name, English common
      // name, alt name, and every localized common name.
      final haystacks = <String>[
        species.scientificName.toLowerCase(),
        species.commonName.toLowerCase(),
        if (species.commonNameAlt != null) species.commonNameAlt!.toLowerCase(),
        if (species.commonNames != null)
          ...species.commonNames!.values.map((n) => n.toLowerCase()),
      ];

      var bestScore = 3;
      // Full-query prefix bonus: any haystack that starts with the full
      // (untokenized) query is the strongest signal.
      final fullLower = trimmed.toLowerCase();
      for (final h in haystacks) {
        if (h.startsWith(fullLower)) {
          bestScore = 0;
          break;
        }
      }

      // All tokens must match somewhere; track the worst per-token score.
      var worstTokenScore = 0;
      for (final token in tokens) {
        var tokenScore = 3;
        for (final h in haystacks) {
          if (h.startsWith(token)) {
            tokenScore = 1;
            break;
          }
          // Word-boundary prefix match (e.g. "owl" in "barn owl").
          for (final word in h.split(RegExp(r'\s+'))) {
            if (word.startsWith(token)) {
              tokenScore = 1;
              break;
            }
          }
          if (tokenScore == 1) break;
          if (h.contains(token)) tokenScore = 2;
        }
        if (tokenScore == 3) return null; // token unmatched: reject
        if (tokenScore > worstTokenScore) worstTokenScore = tokenScore;
      }

      if (bestScore == 3) bestScore = worstTokenScore;
      return bestScore;
    }

    final scored = <(int score, TaxonomySpecies species)>[];
    for (final species in _csvIndex.values) {
      final score = scoreSpecies(species);
      if (score != null) scored.add((score, species));
    }

    scored.sort((a, b) {
      if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
      final obsA = a.$2.observationsCount ?? 0;
      final obsB = b.$2.observationsCount ?? 0;
      if (obsA != obsB) return obsB.compareTo(obsA);
      return a.$2.commonName.compareTo(b.$2.commonName);
    });

    if (scored.length > limit) scored.length = limit;
    return scored.map((e) => e.$2).toList();
  }

  // ---------------------------------------------------------------------------
  // Image helpers
  // ---------------------------------------------------------------------------

  /// Bundled asset image path for a species.
  ///
  /// Looks up the BirdNET ID from the CSV index.  Returns the placeholder
  /// image path when the species is not found.
  String assetImagePath(String scientificName) {
    final species = _csvIndex[scientificName];
    return species?.assetImagePath ?? 'assets/images/dummy_species.png';
  }
}
