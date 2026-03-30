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
// 1. **Local CSV** (`birdnet_taxonomy_0.1-Mar2026.csv`) — bundled with the
//    app, provides offline access to names, IDs, and image URLs.
// 2. **Taxonomy API** (`https://birdnet.cornell.edu/taxonomy/api/`) — live
//    endpoint for descriptions, Wikipedia excerpts, and fresh images.
//
// ### Image URLs
//
// The API provides WebP images at two sizes:
//   - `thumb`  — 150×100 px (4:3)
//   - `medium` — 480×320 px (4:3)
//
// URL pattern: `https://birdnet.cornell.edu/taxonomy/api/image/{sci_name}?size=thumb|medium`
// =============================================================================

/// Rich species metadata for display and information overlays.
class TaxonomySpecies {
  const TaxonomySpecies({
    required this.scientificName,
    required this.commonName,
    this.commonNameAlt,
    this.taxonGroup = '',
    this.birdnetId,
    this.ebirdCode,
    this.inatId,
    this.observationsCount,
    this.imageUrl,
    this.imageAuthor,
    this.imageLicense,
    this.imageSource,
    this.descriptionSource,
    this.descriptions,
    this.commonNames,
    this.wikipediaUrls,
  });

  /// Binomial scientific name (primary key for matching).
  final String scientificName;

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

  /// Observation count from data sources.
  final int? observationsCount;

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

  /// Thumbnail image URL (150×100 WebP).
  String get thumbUrl =>
      'https://birdnet.cornell.edu/taxonomy/api/image/${Uri.encodeComponent(scientificName)}?size=thumb';

  /// Medium image URL (480×320 WebP).
  String get mediumUrl =>
      imageUrl ??
      'https://birdnet.cornell.edu/taxonomy/api/image/${Uri.encodeComponent(scientificName)}?size=medium';

  /// eBird species page URL (if eBird code is available).
  String? get ebirdUrl =>
      ebirdCode != null ? 'https://ebird.org/species/$ebirdCode' : null;

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
    if (commonNames != null && commonNames!.containsKey(locale)) {
      return commonNames![locale]!;
    }
    return commonName;
  }

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// Parse from a row of the bundled taxonomy CSV.
  ///
  /// CSV header:
  /// ```
  /// birdnet_id,scientific_name,common_name,common_name_alt,taxon_group,
  /// inat_id,ebird_code,...,image_url,image_author,image_license,
  /// image_source,common_name_en,common_name_de,...
  /// ```
  factory TaxonomySpecies.fromCsvRow(
    Map<String, String> row,
  ) {
    // Extract localized common names from common_name_* columns.
    final commonNames = <String, String>{};
    for (final entry in row.entries) {
      if (entry.key.startsWith('common_name_') &&
          entry.key != 'common_name_alt' &&
          entry.value.isNotEmpty) {
        final locale = entry.key.substring('common_name_'.length);
        commonNames[locale] = entry.value;
      }
    }

    return TaxonomySpecies(
      scientificName: row['scientific_name'] ?? '',
      commonName: row['common_name'] ?? '',
      commonNameAlt: _nonEmpty(row['common_name_alt']),
      taxonGroup: row['taxon_group'] ?? '',
      birdnetId: _nonEmpty(row['birdnet_id']),
      ebirdCode: _nonEmpty(row['ebird_code']),
      inatId: int.tryParse(row['inat_id'] ?? ''),
      observationsCount: int.tryParse(row['observations_count'] ?? ''),
      imageUrl: _nonEmpty(row['image_url']),
      imageAuthor: _nonEmpty(row['image_author']),
      imageLicense: _nonEmpty(row['image_license']),
      imageSource: _nonEmpty(row['image_source']),
      descriptionSource: _nonEmpty(row['description_source']),
      commonNames: commonNames.isNotEmpty ? commonNames : null,
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
      observationsCount: json['observations_count'] as int?,
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
