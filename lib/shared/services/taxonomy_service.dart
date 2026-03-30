// =============================================================================
// Taxonomy Service — Species metadata from CSV and API
// =============================================================================
//
// Provides species information from two sources:
//
// 1. **Bundled CSV** — offline-first, parsed once at startup, provides names,
//    IDs, image URLs, and basic metadata for all ~14K species.
// 2. **Taxonomy API** — on-demand enrichment with descriptions, Wikipedia
//    excerpts, localized names, and external links.
//
// ### Usage
//
// ```dart
// final service = TaxonomyService();
// await service.loadFromCsv(csvContent);
// final species = service.lookup('Parus major');
// final detailed = await service.fetchDetail('Parus major');
// ```
//
// ### Caching
//
// API responses are cached in-memory for the session lifetime.  The CSV
// lookup is O(1) via a HashMap keyed by scientific name.
//
// ### Reusability
//
// This service has no UI or feature dependencies.  It can be used by any
// screen that needs species metadata (explore, live, survey, info overlays).
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/taxonomy_species.dart';

/// Species metadata service — CSV + API hybrid.
class TaxonomyService {
  TaxonomyService();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// CSV-sourced species indexed by scientific name.
  final Map<String, TaxonomySpecies> _csvIndex = {};

  /// API-enriched species cached by scientific name.
  final Map<String, TaxonomySpecies> _apiCache = {};

  /// Whether the CSV has been loaded.
  bool get isLoaded => _csvIndex.isNotEmpty;

  /// Number of species in the CSV index.
  int get speciesCount => _csvIndex.length;

  /// Base URL for the taxonomy API.
  static const String _apiBase = 'https://birdnet.cornell.edu/taxonomy/api';

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
    return _apiCache[scientificName] ?? _csvIndex[scientificName];
  }

  /// Look up multiple species by scientific name.
  List<TaxonomySpecies> lookupAll(Iterable<String> scientificNames) {
    return scientificNames
        .map((name) => lookup(name))
        .where((s) => s != null)
        .cast<TaxonomySpecies>()
        .toList();
  }

  /// Search species by common name or scientific name (prefix match).
  List<TaxonomySpecies> search(String query, {int limit = 50}) {
    if (query.isEmpty) return const [];

    final lower = query.toLowerCase();
    final results = <TaxonomySpecies>[];

    for (final species in _csvIndex.values) {
      if (species.commonName.toLowerCase().contains(lower) ||
          species.scientificName.toLowerCase().contains(lower)) {
        results.add(species);
        if (results.length >= limit) break;
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // API Enrichment
  // ---------------------------------------------------------------------------

  /// Fetch detailed species info from the Taxonomy API.
  ///
  /// Returns the enriched [TaxonomySpecies] or the CSV entry if the API
  /// call fails.  Results are cached in-memory.
  ///
  /// [locale] — optional locale code for localized descriptions (e.g. "de").
  Future<TaxonomySpecies?> fetchDetail(
    String scientificName, {
    String? locale,
  }) async {
    // Check cache first.
    if (_apiCache.containsKey(scientificName)) {
      return _apiCache[scientificName];
    }

    try {
      final uri = Uri.parse(
        '$_apiBase/species/${Uri.encodeComponent(scientificName)}'
        '${locale != null ? '?locale=$locale' : ''}',
      );
      final response = await http.get(uri).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final species = TaxonomySpecies.fromApiJson(json);
        _apiCache[scientificName] = species;
        return species;
      }

      debugPrint('[TaxonomyService] API returned ${response.statusCode} '
          'for $scientificName');
    } catch (e) {
      debugPrint('[TaxonomyService] API error for $scientificName: $e');
    }

    // Fallback to CSV data.
    return _csvIndex[scientificName];
  }

  /// Generate the thumbnail URL for a species.
  ///
  /// Uses the taxonomy API image proxy (150×100 WebP).
  static String thumbUrl(String scientificName) =>
      '$_apiBase/image/${Uri.encodeComponent(scientificName)}?size=thumb';

  /// Generate the medium image URL for a species.
  ///
  /// Uses the taxonomy API image proxy (480×320 WebP).
  static String mediumUrl(String scientificName) =>
      '$_apiBase/image/${Uri.encodeComponent(scientificName)}?size=medium';
}
