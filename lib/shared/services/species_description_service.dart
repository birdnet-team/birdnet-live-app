// =============================================================================
// Species Description Service — Offline species descriptions from bundled data
// =============================================================================
//
// Loads gzip-compressed JSON description files bundled in the APK.  Each file
// covers one locale (e.g. `descriptions_en.json.gz`) and maps scientific
// names to description text.
//
// ### Usage
//
// ```dart
// final service = SpeciesDescriptionService();
// final desc = await service.getDescription('Parus major', 'de');
// ```
//
// ### Caching
//
// Parsed descriptions are cached in-memory per locale.  Only the locales
// actually requested are loaded (lazy).  English is pre-loaded as a fallback.
//
// ### Data source
//
// Built by `tools/build_species_bundle.py` from the taxonomy JSON.
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Provides offline species descriptions from bundled gzip JSON files.
class SpeciesDescriptionService {
  /// In-memory cache of parsed description maps, keyed by locale.
  final Map<String, Map<String, String>> _cache = {};

  /// Available description locales (matching the bundled files).
  static const List<String> availableLocales = [
    'en',
    'de',
    'fr',
    'es',
    'cs',
    'pt',
    'it',
  ];

  /// Get the description for [scientificName] in [locale].
  ///
  /// Falls back to English if the description is not available in the
  /// requested locale.  Returns null if no description exists at all.
  Future<String?> getDescription(String scientificName, String locale) async {
    // Ensure the requested locale is loaded.
    if (!_cache.containsKey(locale)) {
      await _loadLocale(locale);
    }
    // Ensure English fallback is loaded.
    if (!_cache.containsKey('en')) {
      await _loadLocale('en');
    }
    return _cache[locale]?[scientificName] ?? _cache['en']?[scientificName];
  }

  /// Load and decompress a single locale file.
  Future<void> _loadLocale(String locale) async {
    try {
      final bytes = await rootBundle.load(
        'assets/species_data/descriptions_$locale.json.gz',
      );
      final decompressed = gzip.decode(bytes.buffer.asUint8List());
      final json =
          jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;
      _cache[locale] = json.map((k, v) => MapEntry(k, v as String));
      debugPrint(
        '[SpeciesDescriptionService] loaded $locale: '
        '${_cache[locale]!.length} descriptions',
      );
    } catch (e) {
      debugPrint('[SpeciesDescriptionService] failed to load $locale: $e');
      _cache[locale] = {};
    }
  }
}
