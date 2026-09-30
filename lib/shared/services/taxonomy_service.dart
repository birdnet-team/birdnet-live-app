// =============================================================================
// Taxonomy Service — Species metadata from bundled CSV
// =============================================================================
//
// Provides species information from the bundled taxonomy CSV, parsed once at
// startup.  Covers names, IDs, image metadata, and localized common names
// for all ~9,789 model species.
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

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/taxonomy_species.dart';

/// Parse the bundled taxonomy CSV into a lookup index keyed by scientific name.
///
/// Top-level and free of any [TaxonomyService] state so it can run inside a
/// `compute()` isolate — see [TaxonomyService.loadFromCsvBytes].
Map<String, TaxonomySpecies> parseTaxonomyCsv(String csvContent) {
  final index = <String, TaxonomySpecies>{};

  final lines = csvContent.split('\n');
  if (lines.isEmpty) return index;

  // Parse header.
  final header = _parseCsvLine(lines.first);
  if (header.isEmpty) return index;

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
      index[sciName] = TaxonomySpecies.fromCsvRow(row);
    }
  }

  return index;
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

/// UTF-8 decode *and* parse, so only the raw bytes have to cross the isolate
/// boundary rather than an 11 MB string on the way in as well.
Map<String, TaxonomySpecies> _decodeAndParseTaxonomyCsv(Uint8List bytes) =>
    parseTaxonomyCsv(utf8.decode(bytes));

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

  /// Count of species per taxon group (e.g. {"Aves": 4597, "Mammalia": 232}).
  Map<String, int> get taxonGroupCounts {
    final counts = <String, int>{};
    for (final species in _csvIndex.values) {
      final group = species.taxonGroup;
      if (group.isNotEmpty) counts[group] = (counts[group] ?? 0) + 1;
    }
    return counts;
  }

  // ---------------------------------------------------------------------------
  // CSV Loading
  // ---------------------------------------------------------------------------

  /// Parse the bundled taxonomy CSV and build the lookup index.
  ///
  /// The CSV is comma-delimited with a header row.
  ///
  /// Synchronous, and the bundled CSV is ~11 MB — at app scale prefer
  /// [loadFromCsvBytes], which does the same work off the main isolate.
  void loadFromCsv(String csvContent) {
    _csvIndex
      ..clear()
      ..addAll(parseTaxonomyCsv(csvContent));

    debugPrint('[TaxonomyService] loaded ${_csvIndex.length} species from CSV');
  }

  /// Decode and parse the taxonomy CSV on a background isolate.
  ///
  /// The bundled CSV is ~11 MB over ~9,800 rows, which takes the parser well
  /// past a second on a mid-range phone. Run on the main isolate that stalls
  /// every pending callback behind it — including the image decode for the
  /// main menu's logo — so the parse is handed to `compute()` instead. The
  /// result is transferred, not copied, so it lands here for free.
  Future<void> loadFromCsvBytes(Uint8List csvBytes) async {
    final index = await compute(
      _decodeAndParseTaxonomyCsv,
      csvBytes,
      debugLabel: 'taxonomy CSV parse',
    );

    _csvIndex
      ..clear()
      ..addAll(index);

    debugPrint('[TaxonomyService] loaded ${_csvIndex.length} species from CSV');
  }

  // ---------------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------------

  /// Look up a species by scientific name (CSV only, offline).
  TaxonomySpecies? lookup(String scientificName) {
    return _csvIndex[scientificName];
  }

  /// Canonical scientific name to display for a model-label [scientificName].
  ///
  /// Returns the taxonomy-canonical name when the species resolves, otherwise
  /// the input is returned unchanged.  Use this wherever a scientific name is
  /// shown to the user so that older model-label synonyms are normalized.
  String displayScientificName(String scientificName) =>
      lookup(scientificName)?.displayScientificName ?? scientificName;

  /// Look up multiple species by scientific name.
  List<TaxonomySpecies> lookupAll(Iterable<String> scientificNames) {
    return scientificNames
        .map((name) => lookup(name))
        .where((s) => s != null)
        .cast<TaxonomySpecies>()
        .toList();
  }

  /// Search by the user's localized common name or scientific name.
  ///
  /// Exact full-name matches sort alphabetically first. Every other match
  /// sorts by descending geo score, then alphabetically. Searching only the
  /// two names visible to the user avoids scanning every bundled locale on
  /// each edit.
  List<TaxonomySpecies> search(
    String query, {
    required String locale,
    Map<String, double>? geoScores,
    int limit = 50,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final normalizedQuery = trimmed.toLowerCase();
    final tokens =
        normalizedQuery
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toList();
    if (tokens.isEmpty) return const [];

    final matches = <({bool exact, String name, TaxonomySpecies species})>[];
    for (final species in _csvIndex.values) {
      final localizedName = species.commonNameForLocale(locale).toLowerCase();
      final names = <String>[
        species.scientificName.toLowerCase(),
        species.displayScientificName.toLowerCase(),
        localizedName,
      ];
      if (!tokens.every((token) => names.any((name) => name.contains(token)))) {
        continue;
      }
      matches.add((
        exact: names.any((name) => name == normalizedQuery),
        name: localizedName,
        species: species,
      ));
    }

    matches.sort((a, b) {
      if (a.exact != b.exact) return a.exact ? -1 : 1;
      if (!a.exact) {
        final geo = (geoScores?[b.species.scientificName] ?? 0).compareTo(
          geoScores?[a.species.scientificName] ?? 0,
        );
        if (geo != 0) return geo;
      }
      return a.name.compareTo(b.name);
    });

    if (matches.length > limit) matches.length = limit;
    return matches.map((match) => match.species).toList();
  }

  /// Splits ordered search [results] into species at or above [threshold] in
  /// [geoScores] and the rest, keeping their order.
  ///
  /// Returns null when no geo scores are available (no location yet), so
  /// callers can show one unsectioned list instead of a misleading split.
  static ({List<TaxonomySpecies> likely, List<TaxonomySpecies> other})?
  splitByGeoLikelihood(
    List<TaxonomySpecies> results, {
    required Map<String, double>? geoScores,
    required double threshold,
  }) {
    if (geoScores == null || geoScores.isEmpty) return null;
    final likely = <TaxonomySpecies>[];
    final other = <TaxonomySpecies>[];
    for (final species in results) {
      final score = geoScores[species.scientificName] ?? 0;
      (score >= threshold ? likely : other).add(species);
    }
    return (likely: likely, other: other);
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
