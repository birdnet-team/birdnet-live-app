// =============================================================================
// Label Parser Tests
// =============================================================================
//
// Verifies the configurable delimited-text parsing logic for species labels.
// Tests cover:
//   - Default (BirdNET) format with semicolons and full column set
//   - Custom configs with different delimiters and column mappings
//   - No-header mode with positional column indices
//   - Error conditions (empty input, missing scientificName, broken indices)
//   - The bundled labels file and its agreement with the geo-model labels
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/features/inference/geo_model.dart';
import 'package:birdnet_live/features/inference/label_parser.dart';
import 'package:birdnet_live/features/inference/model_config.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LabelParser — default BirdNET format', () {
    // ── Valid CSV data ──────────────────────────────────────────────────────

    const validCsv = '''idx;birdnet_id;sci_name;com_name;class
0;BN00001;Abeillia abeillei;Emerald-chinned Hummingbird;Aves
1;BN00002;Abroscopus albogularis;Rufous-faced Warbler;Aves
2;BN90067;Gun;Gun;Anthropogenic''';

    test('parses valid CSV into Species list', () {
      final species = LabelParser.parse(validCsv);

      expect(species.length, 3);
      expect(species[0], isA<Species>());
    });

    test('first species has correct fields', () {
      final species = LabelParser.parse(validCsv);

      expect(species[0].index, 0);
      expect(species[0].birdnetId, 'BN00001');
      expect(species[0].scientificName, 'Abeillia abeillei');
      expect(species[0].commonName, 'Emerald-chinned Hummingbird');
      expect(species[0].className, 'Aves');
      expect(species[0].isSoundClass, isFalse);
    });

    test('a non-animal class is a sound class', () {
      final species = LabelParser.parse(validCsv);

      expect(species[2].index, 2);
      expect(species[2].birdnetId, 'BN90067');
      expect(species[2].scientificName, 'Gun');
      expect(species[2].className, 'Anthropogenic');
      expect(species[2].isSoundClass, isTrue);
    });

    test('result is sorted by index', () {
      const unsorted = '''idx;birdnet_id;sci_name;com_name;class
2;BN3;Sp C;Common C;Aves
0;BN1;Sp A;Common A;Aves
1;BN2;Sp B;Common B;Aves''';

      final species = LabelParser.parse(unsorted);

      expect(species.map((s) => s.scientificName), ['Sp A', 'Sp B', 'Sp C']);
    });

    test('handles trailing newlines', () {
      const withTrailing = '''idx;birdnet_id;sci_name;com_name;class
0;BN1;Sp A;Name A;Aves

''';
      final species = LabelParser.parse(withTrailing);
      expect(species.length, 1);
    });

    test('handles Windows-style line endings (CRLF)', () {
      const crlf =
          'idx;birdnet_id;sci_name;com_name;class\r\n'
          '0;BN1;Sp A;Name A;Aves\r\n'
          '1;BN2;Sp B;Name B;Aves\r\n';

      final species = LabelParser.parse(crlf);
      expect(species.length, 2);
      expect(species[1].className, 'Aves');
    });

    test('handles a UTF-8 byte order mark before the header', () {
      const bom =
          '﻿idx;birdnet_id;sci_name;com_name;class\n'
          '0;BN1;Sp A;Name A;Aves\n';

      final species = LabelParser.parse(bom);
      expect(species.single.index, 0);
      expect(species.single.scientificName, 'Sp A');
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
      const bad = '''idx;birdnet_id;sci_name;com_name;class
0;BN1;;Hummingbird;Aves''';
      expect(() => LabelParser.parse(bad), throwsA(isA<FormatException>()));
    });

    test('throws when the scientific-name column is not in the header', () {
      // The file is comma-delimited but the config says semicolon, so the
      // whole header is one unknown column.
      const wrongDelimiter = '''idx,birdnet_id,sci_name,com_name,class
0,BN1,Sp A,Name A,Aves''';
      expect(
        () => LabelParser.parse(wrongDelimiter),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when an index is missing from the sequence', () {
      const gap = '''idx;birdnet_id;sci_name;com_name;class
0;BN1;Sp A;Name A;Aves
2;BN3;Sp C;Name C;Aves''';
      expect(() => LabelParser.parse(gap), throwsA(isA<FormatException>()));
    });

    test('throws when an index is repeated', () {
      const repeated = '''idx;birdnet_id;sci_name;com_name;class
0;BN1;Sp A;Name A;Aves
0;BN2;Sp B;Name B;Aves''';
      expect(
        () => LabelParser.parse(repeated),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when a scientific name is repeated', () {
      const repeated = '''idx;birdnet_id;sci_name;com_name;class
0;BN1;Sp A;Name A;Aves
1;BN2;Sp A;Name B;Aves''';
      expect(
        () => LabelParser.parse(repeated),
        throwsA(isA<FormatException>()),
      );
    });

    // ── Species data class ───────────────────────────────────────────────

    test('Species equality is by index', () {
      const a = Species(
        index: 0,
        scientificName: 'A',
        commonName: 'A',
        className: 'Aves',
      );
      const b = Species(
        index: 0,
        scientificName: 'B',
        commonName: 'B',
        className: 'Insecta',
      );
      expect(a, equals(b)); // Same index → equal.
    });

    test('Species toString contains common and scientific name', () {
      const sp = Species(
        index: 42,
        scientificName: 'Parus major',
        commonName: 'Great Tit',
        className: 'Aves',
      );
      expect(sp.toString(), contains('Great Tit'));
      expect(sp.toString(), contains('Parus major'));
    });

    test('only classes outside the four animal classes are sound classes', () {
      for (final animal in ['Aves', 'Mammalia', 'Amphibia', 'Insecta']) {
        expect(Species.isSoundClassName(animal), isFalse, reason: animal);
      }
      for (final sound in ['Anthropogenic', 'Geophony', 'Music']) {
        expect(Species.isSoundClassName(sound), isTrue, reason: sound);
      }
      // A labels file without a class column must not turn every species
      // into a sound class.
      expect(Species.isSoundClassName(''), isFalse);
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
        columns: {'scientificName': 'species', 'commonName': 'common'},
      );
      const csv = '''species,common
Parus major,Great Tit
Turdus merula,Eurasian Blackbird''';

      final species = LabelParser.parse(csv, config: config);

      expect(species.length, 2);
      expect(species[0].index, 0); // auto-generated
      expect(species[0].birdnetId, ''); // not in CSV
      expect(species[0].scientificName, 'Parus major');
      expect(species[0].commonName, 'Great Tit');
      expect(species[0].className, ''); // not in CSV
    });

    test('parses tab-delimited file', () {
      const config = LabelsConfig(
        file: 'labels.tsv',
        delimiter: '\t',
        hasHeader: true,
        columns: {'index': 'idx', 'scientificName': 'name'},
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
        columns: {'scientificName': 'name', 'commonName': 'common'},
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
        columns: {'scientificName': 'sci'},
      );
      const csv = '''sci
Parus major''';

      final species = LabelParser.parse(csv, config: config);

      expect(species.length, 1);
      expect(species[0].scientificName, 'Parus major');
      expect(species[0].commonName, 'Parus major'); // falls back
      expect(species[0].className, '');
      expect(species[0].isSoundClass, isFalse);
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

  // ══════════════════════════════════════════════════════════════════════════
  // Bundled label files
  // ══════════════════════════════════════════════════════════════════════════
  //
  // These read the files the app ships. They guard the contract between the
  // model build (dev/models/…/build_*.py) and the app: counts from the model
  // config, a BirdNET ID on every class, only known classes, and the same
  // species in the audio and geo label files.

  group('bundled model labels', () {
    final config =
        jsonDecode(File('assets/models/model_config.json').readAsStringSync())
            as Map<String, dynamic>;
    final audioConfig = config['audioModel'] as Map<String, dynamic>;
    final geoConfig = config['geoModel'] as Map<String, dynamic>;
    final labelsConfig = LabelsConfig.fromJson(
      audioConfig['labels'] as Map<String, dynamic>,
    );
    final labels = LabelParser.parse(
      File('assets/models/${labelsConfig.file}').readAsStringSync(),
      config: labelsConfig,
    );
    final species = labels.where((l) => !l.isSoundClass).toList();
    final soundClasses = labels.where((l) => l.isSoundClass).toList();

    test('counts match the model config', () {
      expect(species.length, audioConfig['speciesCount']);
      expect(soundClasses.length, audioConfig['soundClassCount']);
      expect(labels.length, audioConfig['classCount']);
    });

    test('every class has a unique BirdNET ID', () {
      final ids = labels.map((l) => l.birdnetId).toSet();
      expect(ids.length, labels.length);
      expect(ids.every(RegExp(r'^BN\d{5}$').hasMatch), isTrue);
    });

    test('species are in the four animal classes, the rest are sounds', () {
      expect(species.map((l) => l.className).toSet(), Species.wildlifeClasses);
      expect(soundClasses, isNotEmpty);
      expect(soundClasses.map((l) => l.className).toSet(), {
        'Anthropogenic',
        'Geophony',
        'Music',
      });
    });

    test('the geo-model labels are exactly the audio species', () {
      final geoModel = GeoModel()
        ..loadLabels(
          File(
            'assets/models/${geoConfig['labelsFile']}',
          ).readAsStringSync(),
        );

      expect(geoModel.labels.length, geoConfig['speciesCount']);
      expect(
        geoModel.labels.map((l) => l.scientificName).toSet(),
        species.map((l) => l.scientificName).toSet(),
      );
      // Same BirdNET ID and English name on both sides.
      final audioByName = {for (final l in species) l.scientificName: l};
      for (final geo in geoModel.labels) {
        final audio = audioByName[geo.scientificName]!;
        expect(geo.id, audio.birdnetId, reason: geo.scientificName);
        expect(geo.commonName, audio.commonName, reason: geo.scientificName);
      }
    });
  });
}
