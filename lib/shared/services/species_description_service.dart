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

/// Decompresses and parses one bundled description file.
///
/// Top-level so it can run through [compute]: a locale file is roughly a
/// megabyte of gzip that inflates to several megabytes of JSON, and parsing
/// that on the UI isolate — which is also the platform thread on Android and
/// iOS — is a visible hitch the first time a species card opens.
Map<String, String> parseSpeciesDescriptions(Uint8List gzipBytes) {
  final decompressed = gzip.decode(gzipBytes);
  final json = jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;
  return json.map((k, v) => MapEntry(k, v as String));
}

/// Provides offline species descriptions from bundled gzip JSON files.
class SpeciesDescriptionService {
  /// In-memory cache of parsed description maps, keyed by locale.
  final Map<String, Map<String, String>> _cache = {};

  /// Loads in flight, keyed by locale. A species list opening several cards
  /// at once asks for the same unloaded locale several times before the
  /// first parse lands; sharing the load keeps that at one isolate and one
  /// copy of the file instead of one per card.
  final Map<String, Future<void>> _loading = {};

  /// Available description locales (matching the bundled files).
  static const List<String> availableLocales = [
    'en',
    'de',
    'fr',
    'es',
    'cs',
    'pt',
    'it',
    'nl',
    'pl',
    'ru',
    'zh',
    'ko',
  ];

  /// Resolve a species-locale tag to a bundled description locale.
  ///
  /// Callers pass [effectiveSpeciesLocaleProvider], which carries a region
  /// for Chinese (`zh-CN` — the tag produced for every Chinese system locale
  /// and the only Chinese option in the species-language picker) and for the
  /// regional picker entries (`es_ES`, `pt_PT`, ...). The bundles are keyed by
  /// bare language code, so an exact-tag lookup misses the asset entirely and
  /// silently drops the user back to English. Try the exact tag, then the
  /// language subtag, then `en`.
  @visibleForTesting
  static String resolveBundleLocale(String locale) {
    final normalized = locale.trim().replaceAll('_', '-');
    if (normalized.isEmpty) return 'en';
    if (availableLocales.contains(normalized)) return normalized;
    final dash = normalized.indexOf('-');
    if (dash > 0) {
      final base = normalized.substring(0, dash);
      if (availableLocales.contains(base)) return base;
    }
    return 'en';
  }

  /// Get the description for [scientificName] in [locale].
  ///
  /// Falls back to English if the description is not available in the
  /// requested locale.  Returns null if no description exists at all.
  Future<String?> getDescription(String scientificName, String locale) async {
    final resolved = resolveBundleLocale(locale);
    // Ensure the requested locale is loaded.
    if (!_cache.containsKey(resolved)) {
      await _loadLocale(resolved);
    }
    // Ensure English fallback is loaded.
    if (!_cache.containsKey('en')) {
      await _loadLocale('en');
    }
    return _cache[resolved]?[scientificName] ?? _cache['en']?[scientificName];
  }

  /// Load and decompress a single locale file off the UI isolate, joining a
  /// load of the same locale that is already under way.
  Future<void> _loadLocale(String locale) =>
      _loading[locale] ??= _parseLocale(locale).whenComplete(() {
        // A block, not an arrow: returning the removed future from here
        // would make the shared future wait on itself.
        _loading.remove(locale);
      });

  Future<void> _parseLocale(String locale) async {
    try {
      final bytes = await rootBundle.load(
        'assets/species_data/descriptions_$locale.json.gz',
      );
      _cache[locale] = await compute(
        parseSpeciesDescriptions,
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        debugLabel: 'species-descriptions-$locale',
      );
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
