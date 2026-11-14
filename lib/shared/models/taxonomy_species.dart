// =============================================================================
// Taxonomy Species — Rich species metadata model
// =============================================================================
//
// Represents detailed species information sourced from either the bundled
// taxonomy CSV or the BirdNET Taxonomy API.  Used by:
//
//   - **Explore screen** — species list with images and descriptions
//   - **Species info overlay** — detailed species card
//   - **Detection tiles** — thumbnails and common names
//
// ### Data sources
//
// 1. **Local CSV** (`assets/models/taxonomy.csv`, written by
//    `tools/build_species_bundle.py`) — bundled with the app, provides
//    offline access to names, IDs, and image URLs. It holds one row per class
//    of the audio model plus one row per species an earlier release could
//    detect, so sessions recorded with an older model keep resolving.
// 2. **Taxonomy API** (`https://birdnet.cornell.edu/taxonomy/api/`) — live
//    endpoint for descriptions, Wikipedia excerpts, and fresh images.
//
// ### Image URLs
//
// The API provides WebP images at two sizes:
//   - `thumb`  — 150×100 px (3:2)
//   - `medium` — 480×320 px (3:2)
//
// URL pattern: `https://birdnet.cornell.edu/taxonomy/api/image/{sci_name}?size=thumb|medium`
// =============================================================================

/// Rich species metadata for display and information overlays.
class TaxonomySpecies {
  const TaxonomySpecies({
    required this.scientificName,
    required this.commonName,
    this.canonicalScientificName,
    this.aliases = const [],
    this.inModel = true,
    this.recordType = speciesRecordType,
    this.commonNameAlt,
    this.taxonGroup = '',
    this.birdnetId,
    this.ebirdCode,
    this.inatId,
    this.imageUrl,
    this.imageAuthor,
    this.imageLicense,
    this.imageSource,
    this.descriptionSource,
    this.descriptions,
    this.commonNames,
    this.wikipediaUrls,
  });

  /// `record_type` of an animal species.
  static const speciesRecordType = 'species';

  /// `record_type` of a non-animal sound class (engine, siren, music, …).
  static const soundClassRecordType = 'sound_class';

  /// Scientific name (primary key for matching).
  ///
  /// This is the current model label name for species the model detects and
  /// the taxonomy name for species only earlier models detected. Sound
  /// classes carry their class name here (e.g. `Aircraft`).
  final String scientificName;

  /// Scientific name to show in the UI; see [displayScientificName].
  final String? canonicalScientificName;

  /// Other scientific names that resolve to this entry.
  ///
  /// These are synonyms and older names: a session recorded before a taxonomy
  /// revision stores the name of its day (e.g. `Emberiza schoeniclus`), and
  /// `TaxonomyService.lookup` follows the alias to the current entry.
  final List<String> aliases;

  /// Whether the current audio model has a class for this entry.
  ///
  /// False for species that only earlier models could detect; they stay in
  /// the taxonomy so existing sessions keep their names and images.
  final bool inModel;

  /// Taxonomy record type: [speciesRecordType] or [soundClassRecordType].
  final String recordType;

  /// English common name.
  final String commonName;

  /// Alternative common name (e.g. Clements/eBird).
  final String? commonNameAlt;

  /// Taxonomic group (e.g. "Aves", "Insecta", "Amphibia").
  final String taxonGroup;

  /// BirdNET internal ID (e.g. "BN00498").
  final String? birdnetId;

  /// eBird species code (e.g. "mallar3").
  final String? ebirdCode;

  /// iNaturalist taxon ID.
  final int? inatId;

  /// Medium image URL from the taxonomy API.
  final String? imageUrl;

  /// Image attribution author.
  final String? imageAuthor;

  /// Image license (e.g. "cc-by-nc").
  final String? imageLicense;

  /// Image source (e.g. "iNaturalist", "Macaulay Library").
  final String? imageSource;

  /// Description source (e.g. "wikipedia", "ebird").
  final String? descriptionSource;

  /// Localized descriptions keyed by locale code (e.g. {"en": "...", "de": "..."}).
  final Map<String, String>? descriptions;

  /// Localized common names keyed by locale code.
  final Map<String, String>? commonNames;

  /// Wikipedia URLs keyed by locale code.
  final Map<String, String>? wikipediaUrls;

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  /// Whether this entry is a non-animal sound class rather than a species.
  bool get isSoundClass => recordType == soundClassRecordType;

  /// Scientific name to show in the UI.
  ///
  /// Falls back to [scientificName] when no canonical name is available.
  String get displayScientificName =>
      (canonicalScientificName != null && canonicalScientificName!.isNotEmpty)
      ? canonicalScientificName!
      : scientificName;

  /// Bundled asset image path (480x320 WebP).
  ///
  /// Falls back to the placeholder image if [birdnetId] is null.
  String get assetImagePath => birdnetId != null
      ? 'assets/species_images/$birdnetId.webp'
      : 'assets/images/dummy_species.png';

  /// eBird species page URL (if eBird code is available).
  String? get ebirdUrl =>
      ebirdCode != null ? 'https://ebird.org/species/$ebirdCode' : null;

  /// eBird / Macaulay Library audio catalog for this species, sorted with the
  /// best-quality recording first (if an eBird code is available).
  ///
  /// The species page's own "Listen" player is a click-only JavaScript overlay
  /// with no deep-link, so we point at the public media catalog instead: it
  /// opens in the browser with one-tap playable recordings and needs no login.
  String? get ebirdListenUrl => ebirdCode != null
      ? 'https://media.ebird.org/catalog?taxonCode=$ebirdCode'
            '&mediaType=audio&sort=rating_rank_desc'
      : null;

  /// iNaturalist species page URL (if iNat ID is available).
  String? get inatUrl =>
      inatId != null ? 'https://www.inaturalist.org/taxa/$inatId' : null;

  /// English description (fallback to first available locale).
  String? get descriptionEn {
    if (descriptions == null || descriptions!.isEmpty) return null;
    return descriptions!['en'] ?? descriptions!.values.first;
  }

  /// Get description for a specific locale with fallback to English.
  String? descriptionForLocale(String locale) {
    if (descriptions == null || descriptions!.isEmpty) return null;
    return descriptions![locale] ?? descriptions!['en'];
  }

  /// Get common name for a specific locale with fallback to English.
  String commonNameForLocale(String locale) {
    final names = commonNames;
    if (names != null) {
      for (final candidate in _localeCandidates(locale)) {
        final name = names[candidate];
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return commonName;
  }

  static Iterable<String> _localeCandidates(String locale) sync* {
    final normalized = locale.trim().replaceAll('_', '-');
    if (normalized.isEmpty) return;

    yield normalized;

    final parts = normalized.split('-');
    if (parts.length > 1) {
      final country = parts[1].toUpperCase();
      yield '${parts.first}_$country';
      if (parts.first == 'zh' && country == 'CN') yield 'zh-CN';
      yield parts.first;
    }

    // The bundle carries Chinese common names under `zh-CN` only, so every
    // Chinese variant has to land there — a bare `zh` (what the Simplified
    // Chinese app locale produces) or a Traditional tag would otherwise miss
    // every column and fall back to the English common name.
    if (parts.first == 'zh') yield 'zh-CN';

    // Norwegian names live in `no`, but Bokmål is registered as `nb`
    // and Nynorsk `nn`.
    if (parts.first == 'nb' || parts.first == 'nn') yield 'no';
  }

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// Parse from a row of the bundled taxonomy CSV.
  ///
  /// CSV header:
  /// ```
  /// birdnet_id,scientific_name,canonical_scientific_name,
  /// scientific_name_aliases,in_model,record_type,common_name,
  /// common_name_alt,taxon_group,inat_id,ebird_code,...,image_url,
  /// image_author,image_license,image_source,common_name_en,...
  /// ```
  ///
  /// `scientific_name_aliases` is a `|`-separated list. A missing `in_model`
  /// or `record_type` column means "in the model" and "species".
  factory TaxonomySpecies.fromCsvRow(Map<String, String> row) {
    // Extract localized common names from common_name_* columns and
    // Wikipedia URLs from wikipedia_url_* columns.
    final commonNames = <String, String>{};
    final wikipediaUrls = <String, String>{};
    for (final entry in row.entries) {
      if (entry.key.startsWith('common_name_') &&
          entry.key != 'common_name_alt' &&
          entry.value.isNotEmpty) {
        final locale = entry.key.substring('common_name_'.length);
        commonNames[locale] = entry.value;
      } else if (entry.key.startsWith('wikipedia_url_') &&
          entry.value.isNotEmpty) {
        final locale = entry.key.substring('wikipedia_url_'.length);
        wikipediaUrls[locale] = entry.value;
      }
    }

    return TaxonomySpecies(
      scientificName: row['scientific_name'] ?? '',
      commonName: row['common_name'] ?? '',
      canonicalScientificName: _nonEmpty(row['canonical_scientific_name']),
      aliases: [
        for (final alias in (row['scientific_name_aliases'] ?? '').split('|'))
          if (alias.trim().isNotEmpty) alias.trim(),
      ],
      inModel: row['in_model'] != '0',
      recordType: _nonEmpty(row['record_type']) ?? speciesRecordType,
      commonNameAlt: _nonEmpty(row['common_name_alt']),
      taxonGroup: row['taxon_group'] ?? '',
      birdnetId: _nonEmpty(row['birdnet_id']),
      ebirdCode: _nonEmpty(row['ebird_code']),
      inatId: int.tryParse(row['inat_id'] ?? ''),
      imageUrl: _nonEmpty(row['image_url']),
      imageAuthor: _nonEmpty(row['image_author']),
      imageLicense: _nonEmpty(row['image_license']),
      imageSource: _nonEmpty(row['image_source']),
      descriptionSource: _nonEmpty(row['description_source']),
      commonNames: commonNames.isNotEmpty ? commonNames : null,
      wikipediaUrls: wikipediaUrls.isNotEmpty ? wikipediaUrls : null,
    );
  }

  /// Parse from a JSON response from the Taxonomy API.
  factory TaxonomySpecies.fromApiJson(Map<String, dynamic> json) {
    final image = json['image'] as Map<String, dynamic>?;

    return TaxonomySpecies(
      scientificName: json['scientific_name'] as String? ?? '',
      commonName: json['common_name'] as String? ?? '',
      commonNameAlt: json['common_name_alt'] as String?,
      taxonGroup: json['taxon_group'] as String? ?? '',
      birdnetId: json['birdnet_id'] as String?,
      ebirdCode: json['ebird_code'] as String?,
      inatId: json['inat_id'] as int?,
      imageUrl: image?['medium'] as String?,
      imageAuthor: image?['author'] as String?,
      imageLicense: image?['license'] as String?,
      imageSource: image?['source'] as String?,
      descriptionSource: json['description_source'] as String?,
      descriptions: _castStringMap(json['descriptions']),
      commonNames: _castStringMap(json['common_names']),
      wikipediaUrls: _castStringMap(json['wikipedia_urls']),
    );
  }

  static String? _nonEmpty(String? s) =>
      (s != null && s.trim().isNotEmpty) ? s.trim() : null;

  static Map<String, String>? _castStringMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return null;
  }

  @override
  String toString() => 'TaxonomySpecies($commonName [$scientificName])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxonomySpecies && scientificName == other.scientificName;

  @override
  int get hashCode => scientificName.hashCode;
}
