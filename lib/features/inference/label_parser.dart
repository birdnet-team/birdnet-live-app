// =============================================================================
// Label Parser — Reads species labels from a delimited text file
// =============================================================================
//
// The labels file is a delimited text file shipped as a Flutter asset.
// The default format is semicolon-delimited CSV:
//
// ```
// idx;id;sci_name;com_name;class;order
// 0;3;Abeillia abeillei;Emerald-chinned Hummingbird;Aves;Apodiformes
// ```
//
// The delimiter, header presence, and column mapping are all configurable via
// [LabelsConfig] so the parser works with any model's label format.
//
// This parser is pure Dart with no platform dependencies, making it fully
// unit-testable without a Flutter host.
//
// ### Usage
//
// ```dart
// final labels = LabelParser.parse(csvString);          // default BirdNET format
// final labels = LabelParser.parse(csvString, config: myConfig);  // custom format
// ```
// =============================================================================

import 'model_config.dart';
import 'models/species.dart';

/// Parses a species labels file into a list of [Species].
///
/// The returned list is ordered by model output index (0 – N-1) so that
/// `labels[i]` corresponds to output tensor position `i`.
abstract final class LabelParser {
  // ---------------------------------------------------------------------------
  // Default column mapping (BirdNET format)
  // ---------------------------------------------------------------------------

  static const _defaultColumns = {
    'index': 'idx',
    'id': 'id',
    'scientificName': 'sci_name',
    'commonName': 'com_name',
    'className': 'class',
    'order': 'order',
  };

  /// Parse a delimited labels [content] string into species entries.
  ///
  /// When [config] is provided, the delimiter, header presence, and column
  /// mapping are taken from it.  When omitted, the BirdNET defaults apply
  /// (semicolon delimiter, header row, standard column names).
  ///
  /// Throws [FormatException] if a required column is missing or a data line
  /// cannot be parsed.
  static List<Species> parse(
    String content, {
    LabelsConfig? config,
  }) {
    final delimiter = config?.delimiter ?? ';';
    final hasHeader = config?.hasHeader ?? true;
    final columns = config?.columns ?? _defaultColumns;

    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      throw const FormatException('Labels file is empty');
    }

    // Resolve column indices from header or fall back to positional.
    Map<String, int> colIndex;
    int dataStart;

    if (hasHeader) {
      final headerParts =
          lines.first.split(delimiter).map((h) => h.trim()).toList();
      colIndex = _resolveColumnIndices(headerParts, columns);
      dataStart = 1;
    } else {
      // No header — use positional indices in column-map insertion order.
      colIndex = {};
      var pos = 0;
      for (final key in columns.keys) {
        colIndex[key] = pos++;
      }
      dataStart = 0;
    }

    // Ensure we have at least a scientificName mapping.
    if (!colIndex.containsKey('scientificName')) {
      throw const FormatException(
        'Labels config must map at least "scientificName" to a column.',
      );
    }

    final species = <Species>[];

    for (var i = dataStart; i < lines.length; i++) {
      final parts = lines[i].split(delimiter);

      // Row-relative index (0-based position in the data rows).
      final autoIndex = i - dataStart;

      final indexVal = _intAt(parts, colIndex['index']) ?? autoIndex;
      final idVal = _intAt(parts, colIndex['id']) ?? indexVal;
      final sciName = _stringAt(parts, colIndex['scientificName']) ?? '';
      final comName = _stringAt(parts, colIndex['commonName']) ?? sciName;
      final clsName = _stringAt(parts, colIndex['className']) ?? '';
      final ord = _stringAt(parts, colIndex['order']) ?? '';

      if (sciName.isEmpty) {
        throw FormatException(
          'Line ${i + 1}: scientific name is empty: "${lines[i]}"',
        );
      }

      species.add(Species(
        index: indexVal,
        id: idVal,
        scientificName: sciName,
        commonName: comName,
        className: clsName,
        order: ord,
      ));
    }

    // Sort by index to guarantee alignment with model output tensor.
    species.sort((a, b) => a.index.compareTo(b.index));

    return species;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Build a map from logical field name → column position by matching
  /// header names against the config's column mapping.
  static Map<String, int> _resolveColumnIndices(
    List<String> headerParts,
    Map<String, String> columns,
  ) {
    // Lower-case header lookup for case-insensitive matching.
    final lowerHeaders = headerParts.map((h) => h.toLowerCase()).toList();

    final result = <String, int>{};
    for (final entry in columns.entries) {
      final fieldName = entry.key; // e.g. 'scientificName'
      final csvHeader = entry.value.toLowerCase(); // e.g. 'sci_name'
      final pos = lowerHeaders.indexOf(csvHeader);
      if (pos >= 0) {
        result[fieldName] = pos;
      }
      // If the header isn't found, the field will get a default value.
    }
    return result;
  }

  /// Safely read a trimmed string at [colIdx] from [parts], or `null`.
  static String? _stringAt(List<String> parts, int? colIdx) {
    if (colIdx == null || colIdx >= parts.length) return null;
    final v = parts[colIdx].trim();
    return v.isEmpty ? null : v;
  }

  /// Safely parse an int at [colIdx] from [parts], or `null`.
  static int? _intAt(List<String> parts, int? colIdx) {
    if (colIdx == null || colIdx >= parts.length) return null;
    return int.tryParse(parts[colIdx].trim());
  }
}
