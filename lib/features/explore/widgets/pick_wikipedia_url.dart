// =============================================================================
// pickWikipediaUrl — locale-aware Wikipedia URL resolver
// =============================================================================
//
// Pure helper extracted from `species_info_overlay.dart` so it can be
// unit-tested without spinning up Riverpod or a widget tree.
//
// Resolution order:
//   1. Bundled URL for the user's effective species locale.
//   2. Bundled URL for that locale's bare language subtag. Species locale
//      tags carry a region for Chinese (`zh-CN`) and the regional picker
//      entries (`es_ES`, `pt_PT`), but `wikipedia_url_*` columns are keyed
//      by bare language code, so the exact tag alone would never match.
//   3. Bundled English URL.
//   4. Constructed English Wikipedia URL from the scientific name
//      (`https://en.wikipedia.org/wiki/<Genus_species>`). Wikipedia
//      reliably resolves scientific-name slugs (and redirects most
//      aliases), so this guarantees the Wikipedia chip is never missing
//      even when `taxonomy.csv` has no link for the species.
// =============================================================================

library;

/// Returns the best Wikipedia URL for [scientificName] given the
/// (optional) per-locale [bundledUrls] map and the user's [locale].
///
/// Always returns a non-empty URL; falls back to a constructed English
/// Wikipedia link if no bundled URL is available.
String pickWikipediaUrl({
  required String scientificName,
  required Map<String, String>? bundledUrls,
  required String locale,
}) {
  if (bundledUrls != null && bundledUrls.isNotEmpty) {
    for (final tag in _localeCandidates(locale)) {
      final localized = bundledUrls[tag];
      if (localized != null && localized.isNotEmpty) {
        return localized;
      }
    }
    final english = bundledUrls['en'];
    if (english != null && english.isNotEmpty) {
      return english;
    }
  }
  // Fallback: construct an English Wikipedia URL from the scientific
  // name. Wikipedia URL-encodes spaces as underscores.
  final slug = scientificName.trim().replaceAll(' ', '_');
  return 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(slug)}';
}

/// The exact locale tag followed by its bare language subtag.
List<String> _localeCandidates(String locale) {
  final normalized = locale.trim().replaceAll('_', '-');
  if (normalized.isEmpty) return const [];
  final dash = normalized.indexOf('-');
  if (dash <= 0) return [normalized];
  return [normalized, normalized.substring(0, dash)];
}
