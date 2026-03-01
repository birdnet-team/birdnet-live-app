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
// idx;id;sci_name;com_name;class;order
// 0;3;Abeillia abeillei;Emerald-chinned Hummingbird;Aves;Apodiformes
// ```
//
// The [id] field is a sparse internal identifier (not contiguous) and is kept
// for cross-referencing with external databases.
// =============================================================================

/// An individual species that the classifier model can identify.
///
/// Constructed by [LabelParser] from the bundled labels CSV.
class Species {
  /// Creates a species entry.
  const Species({
    required this.index,
    required this.id,
    required this.scientificName,
    required this.commonName,
    required this.className,
    required this.order,
  });

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// Zero-based position in the model output tensor.
  final int index;

  /// Sparse internal species ID.
  final int id;

  /// Binomial scientific name (e.g. "Parus major").
  final String scientificName;

  /// English common name (e.g. "Great Tit").
  final String commonName;

  /// Taxonomic class (e.g. "Aves", "Insecta").
  final String className;

  /// Taxonomic order (e.g. "Passeriformes").
  final String order;

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
