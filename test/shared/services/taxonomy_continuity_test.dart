// =============================================================================
// Taxonomy Continuity Tests
// =============================================================================
//
// A model or taxonomy update must not orphan what users already have. Sessions
// store the scientific name a species had when it was detected, so:
//
//   - an older name has to resolve to the current entry (aliases),
//   - a species the current model no longer detects has to keep its entry
//     (legacy rows), and
//   - neither kind may leak into counts, pickers, or the species the model is
//     said to cover.
//
// The first group pins that behavior on a small synthetic CSV. The second
// group reads the files the app ships and checks the promise end to end:
// every scientific name any release has ever stored still resolves.
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/features/inference/label_parser.dart';
import 'package:birdnet_live/features/inference/model_config.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _csv =
    '''birdnet_id,scientific_name,canonical_scientific_name,scientific_name_aliases,in_model,record_type,common_name,taxon_group,common_name_de
BN09096,Schoeniclus schoeniclus,Schoeniclus schoeniclus,Emberiza schoeniclus,1,species,Common Reed Bunting,Aves,Rohrammer
BN00008,Acanthis flammea,Acanthis flammea,Acanthis cabaret|Carduelis flammea|Acanthis hornemanni,1,species,Redpoll,Aves,Birkenzeisig
BN07148,Parus major,Parus major,Turdus merula,1,species,Great Tit,Aves,Kohlmeise
BN10218,Turdus merula,Turdus merula,,1,species,Eurasian Blackbird,Aves,Amsel
BN20810,Bombus terrestris,Bombus terrestris,,0,species,Buff-tailed Bumble Bee,Insecta,Dunkle Erdhummel
BN90002,Aircraft,Aircraft,Airplane,1,sound_class,Aircraft,Anthropogenic,Flugzeug
BN00001,Strix aluco,Strix aluco,,1,species,"Tawny ""Brown"" Owl, Eurasian",Aves,Waldkauz''';

void main() {
  group('older names and legacy species', () {
    late TaxonomyService taxonomy;

    setUp(() => taxonomy = TaxonomyService()..loadFromCsv(_csv));

    test('an older scientific name resolves to the current entry', () {
      final species = taxonomy.lookup('Emberiza schoeniclus');

      expect(species, isNotNull);
      expect(species!.scientificName, 'Schoeniclus schoeniclus');
      expect(species.birdnetId, 'BN09096');
      expect(species.commonNameForLocale('de'), 'Rohrammer');
      expect(
        taxonomy.assetImagePath('Emberiza schoeniclus'),
        'assets/species_images/BN09096.webp',
      );
    });

    test('several older names can share one current entry', () {
      for (final old in [
        'Acanthis cabaret',
        'Carduelis flammea',
        'Acanthis hornemanni',
      ]) {
        expect(
          taxonomy.lookup(old)?.scientificName,
          'Acanthis flammea',
          reason: old,
        );
      }
    });

    test('canonicalScientificName maps old and current names together', () {
      expect(
        taxonomy.canonicalScientificName('Emberiza schoeniclus'),
        'Schoeniclus schoeniclus',
      );
      expect(
        taxonomy.canonicalScientificName('Schoeniclus schoeniclus'),
        'Schoeniclus schoeniclus',
      );
      // Unknown names pass through unchanged so nothing is ever dropped.
      expect(taxonomy.canonicalScientificName('Unknown thing'), 'Unknown thing');
      expect(taxonomy.canonicalScientificName(''), '');
    });

    test('a current name beats an alias that points elsewhere', () {
      // "Turdus merula" is both its own row and (wrongly) an alias of
      // Parus major. The row must win.
      expect(taxonomy.lookup('Turdus merula')?.birdnetId, 'BN10218');
      expect(taxonomy.displayScientificName('Turdus merula'), 'Turdus merula');
    });

    test('displayScientificName shows the current name for an old one', () {
      expect(
        taxonomy.displayScientificName('Emberiza schoeniclus'),
        'Schoeniclus schoeniclus',
      );
    });

    test('a species the model no longer detects keeps its entry', () {
      final species = taxonomy.lookup('Bombus terrestris');

      expect(species, isNotNull);
      expect(species!.inModel, isFalse);
      expect(species.commonNameForLocale('de'), 'Dunkle Erdhummel');
      expect(species.assetImagePath, 'assets/species_images/BN20810.webp');
    });

    test('counts cover only species the current model detects', () {
      // 5 model species; the legacy bumble bee and the sound class are out.
      expect(taxonomy.speciesCount, 5);
      expect(taxonomy.soundClassCount, 1);
      expect(taxonomy.taxonGroupCounts, {'Aves': 5});
    });

    test('pickers do not offer legacy species or sound classes', () {
      expect(taxonomy.search('Bombus', locale: 'en'), isEmpty);
      expect(taxonomy.search('Aircraft', locale: 'en'), isEmpty);
      expect(
        taxonomy
            .search('Aircraft', locale: 'en', includeSoundClasses: true)
            .single
            .scientificName,
        'Aircraft',
      );
      expect(
        taxonomy.search('Redpoll', locale: 'en').single.scientificName,
        'Acanthis flammea',
      );
    });

    test('a sound class is flagged and resolves by its taxonomy name too', () {
      final aircraft = taxonomy.lookup('Aircraft')!;
      expect(aircraft.isSoundClass, isTrue);
      expect(taxonomy.lookup('Airplane')?.scientificName, 'Aircraft');
      expect(taxonomy.lookup('Parus major')!.isSoundClass, isFalse);
    });

    test('columns added later default to "species in the model"', () {
      final old = TaxonomyService()
        ..loadFromCsv(
          'birdnet_id,scientific_name,common_name\nBN1,Parus major,Great Tit',
        );
      final species = old.lookup('Parus major')!;
      expect(species.inModel, isTrue);
      expect(species.isSoundClass, isFalse);
      expect(species.aliases, isEmpty);
    });

    test('a doubled quote inside a quoted field is a literal quote', () {
      expect(
        taxonomy.lookup('Strix aluco')!.commonName,
        'Tawny "Brown" Owl, Eurasian',
      );
    });
  });

  group('bundled taxonomy', () {
    final taxonomy = TaxonomyService()
      ..loadFromCsv(File('assets/models/taxonomy.csv').readAsStringSync());
    final config =
        jsonDecode(File('assets/models/model_config.json').readAsStringSync())
            as Map<String, dynamic>;
    final audioConfig = config['audioModel'] as Map<String, dynamic>;
    final labelsConfig = LabelsConfig.fromJson(
      audioConfig['labels'] as Map<String, dynamic>,
    );
    final labels = LabelParser.parse(
      File('assets/models/${labelsConfig.file}').readAsStringSync(),
      config: labelsConfig,
    );

    test('every model class has its own row with the label\'s BirdNET ID', () {
      for (final label in labels) {
        final species = taxonomy.lookup(label.scientificName);
        expect(species, isNotNull, reason: label.scientificName);
        expect(
          species!.scientificName,
          label.scientificName,
          reason: 'a label must be a row, not an alias',
        );
        expect(species.birdnetId, label.birdnetId, reason: label.scientificName);
        expect(species.inModel, isTrue, reason: label.scientificName);
        expect(
          species.isSoundClass,
          label.isSoundClass,
          reason: label.scientificName,
        );
        expect(species.taxonGroup, label.className, reason: label.scientificName);
        expect(species.commonName, label.commonName, reason: label.scientificName);
      }
    });

    test('counts match the model config', () {
      expect(taxonomy.speciesCount, audioConfig['speciesCount']);
      expect(taxonomy.soundClassCount, audioConfig['soundClassCount']);
    });

    test('every name a release has ever stored still resolves', () {
      // test/fixtures/released_species_names.txt is written by the model
      // build from the label files of every tagged release. A name missing
      // here would show up in a user's old session without its translation,
      // picture, and links. A name the taxonomy has dropped altogether is
      // kept through tools/retired_species.json, not excused here.
      final names = File('test/fixtures/released_species_names.txt')
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .toList();
      expect(names.length, greaterThan(10000));

      final missing = [
        for (final name in names)
          if (taxonomy.lookup(name) == null) name,
      ];
      expect(missing, isEmpty);
    });

    test('resolved entries carry what a detection tile needs', () {
      final names = File(
        'test/fixtures/released_species_names.txt',
      ).readAsLinesSync().where((line) => line.trim().isNotEmpty);
      for (final name in names) {
        final species = taxonomy.lookup(name);
        if (species == null) continue;
        expect(species.birdnetId, matches(r'^BN\d{5}$'), reason: name);
        expect(species.commonName, isNotEmpty, reason: name);
      }
    });

    test('renamed species resolve to their current names', () {
      // A sample of names the previous model used, with today's names.
      const renamed = {
        'Emberiza schoeniclus': 'Schoeniclus schoeniclus',
        'Bison bison': 'Bos bison',
        'Apus nipalensis': 'Apus affinis',
        'Grus paradiseus': 'Grus paradisea',
      };
      for (final entry in renamed.entries) {
        expect(
          taxonomy.canonicalScientificName(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('species images exist for every row when the bundle is built', () {
      // assets/species_images is generated (tools/build_species_bundle.py)
      // and not in git; skip on a checkout that has not built it.
      final dir = Directory('assets/species_images');
      final built = dir.existsSync() && dir.listSync().length > 100;
      if (!built) return;

      final names = File(
        'test/fixtures/released_species_names.txt',
      ).readAsLinesSync().where((line) => line.trim().isNotEmpty);
      final missing = <String>[];
      for (final name in names) {
        final species = taxonomy.lookup(name);
        if (species == null) continue;
        if (!File(species.assetImagePath).existsSync()) missing.add(name);
      }
      expect(missing, isEmpty);
    });
  });
}
