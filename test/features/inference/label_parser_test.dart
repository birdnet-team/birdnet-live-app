// =============================================================================
// Label Parser Tests
// =============================================================================
//
// Verifies the configurable delimited-text parsing logic for species labels.
// Tests cover:
//   - Default (BirdNET) format with semicolons and full column set
//   - Custom configs with different delimiters and column mappings
//   - No-header mode with positional column indices
//   - Error conditions (empty input, missing scientificName)
//   - Real labels file integration test
// =============================================================================

import 'dart:io';

import 'package:birdnet_live/features/inference/label_parser.dart';
import 'package:birdnet_live/features/inference/model_config.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LabelParser — default BirdNET format', () {
    // ── Valid CSV data ──────────────────────────────────────────────────────

    const validCsv = '''idx;id;sci_name;com_name;class;order
0;3;Abeillia abeillei;Emerald-chinned Hummingbird;Aves;Apodiformes
1;5;Abroscopus albogularis;Rufous-faced Warbler;Aves;Passeriformes
2;6;Abroscopus schisticeps;Black-faced Warbler;Aves;Passeriformes''';

    test('parses valid CSV into Species list', () {
      final species = LabelParser.parse(validCsv);

      expect(species.length, 3);
      expect(species[0], isA<Species>());
    });

    test('first species has correct fields', () {
      final species = LabelParser.parse(validCsv);

      expect(species[0].index, 0);
      expect(species[0].id, 3);
      expect(species[0].scientificName, 'Abeillia abeillei');
      expect(species[0].commonName, 'Emerald-chinned Hummingbird');
      expect(species[0].className, 'Aves');
      expect(species[0].order, 'Apodiformes');
    });

    test('last species has correct index', () {
      final species = LabelParser.parse(validCsv);

      expect(species[2].index, 2);
      expect(species[2].commonName, 'Black-faced Warbler');
    });

    test('result is sorted by index', () {
      const unsorted = '''idx;id;sci_name;com_name;class;order
2;6;Sp C;Common C;Aves;Order
0;3;Sp A;Common A;Aves;Order
1;5;Sp B;Common B;Aves;Order''';

      final species = LabelParser.parse(unsorted);

      expect(species[0].index, 0);
      expect(species[1].index, 1);
      expect(species[2].index, 2);
    });

    test('handles trailing newlines', () {
      const withTrailing = '''idx;id;sci_name;com_name;class;order
0;1;Sp A;Name A;Aves;Order

''';
      final species = LabelParser.parse(withTrailing);
      expect(species.length, 1);
    });

    test('handles Windows-style line endings (CRLF)', () {
      const crlf = 'idx;id;sci_name;com_name;class;order\r\n'
          '0;1;Sp A;Name A;Aves;Order\r\n'
          '1;2;Sp B;Name B;Aves;Order\r\n';

      final species = LabelParser.parse(crlf);
      expect(species.length, 2);
    });

    // ── Error conditions ─────────────────────────────────────────────────

    test('throws FormatException on empty string', () {
      expect(() => LabelParser.parse(''), throwsA(isA<FormatException>()));
    });

    test('throws FormatException on whitespace-only string', () {
      expect(
        () => LabelParser.parse('   \n  \n  '),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on empty scientific name', () {
      const bad = '''idx;id;sci_name;com_name;class;order
0;3;;Hummingbird;Aves;Order''';
      expect(() => LabelParser.parse(bad), throwsA(isA<FormatException>()));
    });

    // ── Species data class ───────────────────────────────────────────────

    test('Species equality is by index', () {
      const a = Species(
        index: 0,
        id: 3,
        scientificName: 'A',
        commonName: 'A',
        className: 'Aves',
        order: 'X',
      );
      const b = Species(
        index: 0,
        id: 999,
        scientificName: 'B',
        commonName: 'B',
        className: 'Insecta',
        order: 'Y',
      );
      expect(a, equals(b)); // Same index → equal.
    });

    test('Species toString contains common and scientific name', () {
      const sp = Species(
        index: 42,
        id: 7,
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        className: 'Aves',
        order: 'Passeriformes',
      );
      expect(sp.toString(), contains('Great Tit'));
      expect(sp.toString(), contains('Parus major'));
    });

    // ── Real labels file (integration-level) ────────────────────────────

    test('parses real labels file from disk', () {
      final content = _readLabelsFile();
      if (content == null) return; // Skip in CI.

      final species = LabelParser.parse(content);

      expect(species.length, 11560);
      expect(species.first.index, 0);
      expect(species.last.index, 11559);
      expect(species.first.scientificName, 'Abeillia abeillei');
      expect(species.last.scientificName, 'Zosterornis whiteheadi');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Custom config tests
  // ══════════════════════════════════════════════════════════════════════════

  group('LabelParser — custom config', () {
    test('parses comma-delimited CSV with custom column names', () {
      const config = LabelsConfig(
        file: 'labels.csv',
        delimiter: ',',
        hasHeader: true,
        columns: {
          'scientificName': 'species',
          'commonName': 'common',
        },
      );
      const csv = '''species,common
Parus major,Great Tit
Turdus merula,Eurasian Blackbird''';

      final species = LabelParser.parse(csv, config: config);

      expect(species.length, 2);
      expect(species[0].index, 0); // auto-generated
      expect(species[0].id, 0); // defaults to index
      expect(species[0].scientificName, 'Parus major');
      expect(species[0].commonName, 'Great Tit');
      expect(species[0].className, ''); // not in CSV
      expect(species[0].order, ''); // not in CSV
    });

    test('parses tab-delimited file', () {
      const config = LabelsConfig(
        file: 'labels.tsv',
        delimiter: '\t',
        hasHeader: true,
        columns: {
          'index': 'idx',
          'scientificName': 'name',
        },
      );
      const tsv = 'idx\tname\n0\tParus major\n1\tTurdus merula';

      final species = LabelParser.parse(tsv, config: config);

      expect(species.length, 2);
      expect(species[0].index, 0);
      expect(species[0].scientificName, 'Parus major');
      // commonName defaults to scientificName when not mapped.
      expect(species[0].commonName, 'Parus major');
    });

    test('auto-generates index from row order when no index column', () {
      const config = LabelsConfig(
        file: 'labels.csv',
        delimiter: ',',
        hasHeader: true,
        columns: {
          'scientificName': 'name',
          'commonName': 'common',
        },
      );
      const csv = '''name,common
Species A,Common A
Species B,Common B
Species C,Common C''';

      final species = LabelParser.parse(csv, config: config);

      expect(species[0].index, 0);
      expect(species[1].index, 1);
      expect(species[2].index, 2);
    });

    test('parses headerless CSV with positional columns', () {
      const config = LabelsConfig(
        file: 'labels.csv',
        delimiter: ',',
        hasHeader: false,
        columns: {
          'scientificName': '0', // positional mapping
          'commonName': '1',
        },
      );
      const csv = '''Parus major,Great Tit
Turdus merula,Eurasian Blackbird''';

      final species = LabelParser.parse(csv, config: config);

      expect(species.length, 2);
      expect(species[0].index, 0);
      expect(species[0].scientificName, 'Parus major');
      expect(species[0].commonName, 'Great Tit');
    });

    test('handles missing optional columns gracefully', () {
      const config = LabelsConfig(
        file: 'labels.csv',
        delimiter: ';',
        hasHeader: true,
        columns: {
          'scientificName': 'sci',
        },
      );
      const csv = '''sci
Parus major''';

      final species = LabelParser.parse(csv, config: config);

      expect(species.length, 1);
      expect(species[0].scientificName, 'Parus major');
      expect(species[0].commonName, 'Parus major'); // falls back
      expect(species[0].className, '');
      expect(species[0].order, '');
    });

    test('case-insensitive header matching', () {
      const config = LabelsConfig(
        file: 'labels.csv',
        delimiter: ',',
        hasHeader: true,
        columns: {
          'scientificName': 'Species_Name',
          'commonName': 'Common_Name',
        },
      );
      const csv = '''SPECIES_NAME,COMMON_NAME
Parus major,Great Tit''';

      final species = LabelParser.parse(csv, config: config);

      expect(species[0].scientificName, 'Parus major');
      expect(species[0].commonName, 'Great Tit');
    });
  });
}

/// Try to read the real labels CSV from the dev/models folder.
String? _readLabelsFile() {
  try {
    final file = File(
      'dev/models/BirdNET+_V3.0-preview3_Global_11K_Labels.csv',
    );
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  } catch (_) {
    return null;
  }
}
