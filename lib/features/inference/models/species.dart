// =============================================================================
// Species — Immutable data class for species label information
// =============================================================================
//
// Each instance represents one row from the classifier's labels CSV.  The
// model outputs a flat vector of confidence scores; [index] maps directly to
// the position in that output tensor.
//
// ### CSV format (semicolon-delimited)
//
// ```
// idx;birdnet_id;sci_name;com_name;class
// 0;BN00001;Abeillia abeillei;Emerald-chinned Hummingbird;Aves
// 10047;BN90067;Gun;Gun;Anthropogenic
// ```
//
// Most rows are animal species.  The model also has a few non-animal sound
// classes (engines, sirens, music, …); see [isSoundClass].
// =============================================================================

/// One class the classifier model can identify: an animal species or a
/// non-animal sound class.
///
/// Constructed by [LabelParser] from the bundled labels CSV.
class Species {
  /// Creates a species entry.
  const Species({
    required this.index,
    required this.scientificName,
    required this.commonName,
    required this.className,
    this.birdnetId = '',
  });

  /// Taxonomic classes of the animals the model detects.
  ///
  /// Every label whose [className] is not one of these is a sound class. The
  /// model build (`dev/models/november2026/build_november2026.py`) refuses to
  /// ship an animal outside these four classes, so the rule cannot misfile a
  /// species.
  static const Set<String> wildlifeClasses = {
    'Aves',
    'Mammalia',
    'Amphibia',
    'Insecta',
  };

  /// Whether [className] names a non-animal sound class.
  static bool isSoundClassName(String className) =>
      className.isNotEmpty && !wildlifeClasses.contains(className);

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// Zero-based position in the model output tensor.
  final int index;

  /// BirdNET taxonomy ID (e.g. "BN07148"), shared by the audio model's labels
  /// and the taxonomy.  Empty when the labels file has no such column.
  final String birdnetId;

  /// Scientific name (e.g. "Parus major"); the class name for sound classes.
  final String scientificName;

  /// English common name (e.g. "Great Tit").
  final String commonName;

  /// Taxonomic class (e.g. "Aves", "Insecta"), or the sound class group
  /// (e.g. "Anthropogenic").
  final String className;

  /// Whether this is a non-animal sound class rather than a species.
  ///
  /// Sound classes have no range, so the geo-model does not know them and
  /// location filters leave them alone.
  bool get isSoundClass => isSoundClassName(className);

  // ---------------------------------------------------------------------------
  // Overrides
  // ---------------------------------------------------------------------------

  @override
  String toString() => 'Species($index: $commonName [$scientificName])';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Species &&
          runtimeType == other.runtimeType &&
          index == other.index;

  @override
  int get hashCode => index.hashCode;
}
