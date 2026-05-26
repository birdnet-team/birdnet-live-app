// =============================================================================
// Score Blacklist Tests
// =============================================================================
//
// Verifies the internal model-tuning JSON that maps English common names to
// confidence-score fractions for known false-positive labels.
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/features/inference/label_parser.dart';
import 'package:birdnet_live/features/inference/model_config.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/inference/score_blacklist.dart';
import 'package:flutter_test/flutter_test.dart';

List<Species> _labels() => const [
  Species(
    index: 0,
    id: 0,
    scientificName: 'Turdus merula',
    commonName: 'Common Blackbird',
    className: 'Aves',
    order: 'Passeriformes',
  ),
  Species(
    index: 1,
    id: 1,
    scientificName: 'Vulpes vulpes',
    commonName: 'Red Fox',
    className: 'Mammalia',
    order: 'Carnivora',
  ),
  Species(
    index: 2,
    id: 2,
    scientificName: 'Parus major',
    commonName: 'Great Tit',
    className: 'Aves',
    order: 'Passeriformes',
  ),
];

void main() {
  group('ScoreBlacklist.parse', () {
    test('parses common-name fractions', () {
      final fractions = ScoreBlacklist.parse('{"Red Fox": 0.5}');

      expect(fractions, {'Red Fox': 0.5});
    });

    test('empty content is a no-op', () {
      expect(ScoreBlacklist.parse('  '), isEmpty);
    });

    test('rejects non-object JSON', () {
      expect(
        () => ScoreBlacklist.parse('["Red Fox", 0.5]'),
        throwsFormatException,
      );
    });

    test('rejects non-numeric fractions', () {
      expect(
        () => ScoreBlacklist.parse('{"Red Fox": "0.5"}'),
        throwsFormatException,
      );
    });

    test('rejects fractions outside the blacklist range', () {
      expect(
        () => ScoreBlacklist.parse('{"Red Fox": 1.2}'),
        throwsFormatException,
      );
      expect(
        () => ScoreBlacklist.parse('{"Red Fox": -0.1}'),
        throwsFormatException,
      );
    });
  });

  group('ScoreBlacklist.buildMultiplierVector', () {
    test('builds a dense vector aligned with labels', () {
      final multipliers = ScoreBlacklist.buildMultiplierVector(
        labels: _labels(),
        fractions: {'Red Fox': 0.5},
      );

      expect(multipliers, [1.0, 0.5, 1.0]);
    });

    test(
      'matches model-label English names before localized display names',
      () {
        const labels = [
          Species(
            index: 0,
            id: 0,
            scientificName: 'Cygnus olor',
            commonName: 'Mute Swan',
            className: 'Aves',
            order: 'Anseriformes',
          ),
        ];
        const localizedDisplayNames = {'Cygnus olor': 'Hoeckerschwan'};

        final multipliers = ScoreBlacklist.buildMultiplierVector(
          labels: labels,
          fractions: {'Mute Swan': 0.5},
        );
        final adjusted = ScoreBlacklist.applyMultipliers(
          scores: [0.8],
          multipliers: multipliers,
        );

        expect(
          localizedDisplayNames[labels.single.scientificName],
          isNot('Mute Swan'),
        );
        expect(adjusted.single, 0.4);
      },
    );

    test('empty blacklist returns an empty no-op vector', () {
      final multipliers = ScoreBlacklist.buildMultiplierVector(
        labels: _labels(),
        fractions: const {},
      );

      expect(multipliers, isEmpty);
    });

    test('rejects unknown label names', () {
      expect(
        () => ScoreBlacklist.buildMultiplierVector(
          labels: _labels(),
          fractions: {'Not In This Model': 0.5},
        ),
        throwsFormatException,
      );
    });
  });

  group('ScoreBlacklist.applyMultipliers', () {
    test('multiplies only listed species scores', () {
      final adjusted = ScoreBlacklist.applyMultipliers(
        scores: [0.7, 0.8, 0.9],
        multipliers: [1.0, 0.5, 1.0],
      );

      expect(adjusted, [0.7, 0.4, 0.9]);
    });

    test('empty multiplier vector returns the original score list', () {
      final scores = [0.7, 0.8, 0.9];
      final adjusted = ScoreBlacklist.applyMultipliers(
        scores: scores,
        multipliers: const [],
      );

      expect(identical(adjusted, scores), isTrue);
    });
  });

  group('Bundled score blacklist', () {
    test('matches the bundled model labels', () {
      final configFile = File('assets/models/model_config.json');
      if (!configFile.existsSync()) return;

      final configJson =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      final config = ModelConfig.fromJson(
        configJson['audioModel'] as Map<String, dynamic>,
      );

      final blacklistFileName = config.scoreBlacklistFile;
      expect(blacklistFileName, isNotNull);

      final blacklistFile = File('assets/models/$blacklistFileName');
      final labelsFile = File('assets/models/${config.labels.file}');
      if (!blacklistFile.existsSync() || !labelsFile.existsSync()) return;

      final fractions = ScoreBlacklist.parse(blacklistFile.readAsStringSync());
      final labels = LabelParser.parse(
        labelsFile.readAsStringSync(),
        config: config.labels,
      );
      final multipliers = ScoreBlacklist.buildMultiplierVector(
        labels: labels,
        fractions: fractions,
      );

      const expectedEntries = {
        'Eurasian Hoopoe': 0.5,
        'Eurasian Golden Oriole': 0.5,
        'Great Cormorant': 0.5,
        'Mute Swan': 0.5,
        'Red Fox': 0.5,
      };
      for (final entry in expectedEntries.entries) {
        expect(fractions[entry.key], entry.value);
      }
      expect(
        multipliers.where((value) => value != 1.0),
        hasLength(fractions.values.where((value) => value != 1.0).length),
      );
    });
  });
}
