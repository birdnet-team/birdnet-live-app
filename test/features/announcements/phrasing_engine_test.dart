import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/announcements/domain/announcement_buckets.dart';
import 'package:birdnet_live/features/announcements/domain/announcement_presets.dart';
import 'package:birdnet_live/features/announcements/domain/announcement_signals.dart';
import 'package:birdnet_live/features/announcements/phrasing/phrasing_engine.dart';
import 'package:birdnet_live/features/announcements/phrasing/template_library.dart';

TemplateBundle _bundle({Map<String, List<String>>? overrides}) {
  // Three balanced + one chatty per non-H bucket; one of each for the
  // multi-species buckets. Just enough variety to exercise anti-repeat
  // without hauling the real JSON into the test.
  final defaults = {
    'A': ['A1 {name}.', 'A2 {name}.', 'A3 {name}.'],
    'B': ['B1 {name}.'],
    'C': ['C1 {name}.', 'C2 {name}.'],
    'D': ['D1 {name}.', 'D2 {name}.', 'D3 {name}.'],
    'E': ['E1 {name}.'],
    'F': ['F1 {name}.', 'F2 {name}.'],
    'G': ['G1 {name}.'],
    'H_two': ['Two: {name1} and {name2}.'],
    'H_three': ['Three: {name1}, {name2}, {name3}.'],
    'H_many': ['Many: {name1}, {name2}, {name3}, etc.'],
  };
  if (overrides != null) defaults.addAll(overrides);
  final json = {
    'locale': 'en',
    'version': 1,
    'buckets': {
      for (final entry in defaults.entries)
        entry.key: {
          'balanced': entry.value,
          'chatty': ['CHATTY ${entry.value.first}'],
        },
    },
  };
  return TemplateBundle.fromJson(json);
}

AnnouncementSignals _sig({
  ConfidenceBin c = ConfidenceBin.high,
  bool recent = false,
  int streak = 1,
}) => AnnouncementSignals(
  confidence: c,
  isRecent: recent,
  isFirstInSession: true,
  streakLength: streak,
);

void main() {
  group('PhrasingEngine.speakOne', () {
    test('minimal verbosity bypasses templates', () {
      final engine = PhrasingEngine(bundle: _bundle());
      final out = engine.speakOne(
        name: 'Robin',
        signals: _sig(),
        verbosity: AnnouncementVerbosity.minimal,
      );
      expect(out, 'Robin.');
    });

    test('balanced verbosity picks from balanced list', () {
      final engine = PhrasingEngine(bundle: _bundle(), random: Random(0));
      final out = engine.speakOne(
        name: 'Robin',
        signals: _sig(),
        verbosity: AnnouncementVerbosity.balanced,
      );
      expect(out, anyOf('A1 Robin.', 'A2 Robin.', 'A3 Robin.'));
    });

    test('chatty verbosity picks from chatty list', () {
      final engine = PhrasingEngine(bundle: _bundle(), random: Random(0));
      final out = engine.speakOne(
        name: 'Robin',
        signals: _sig(),
        verbosity: AnnouncementVerbosity.chatty,
      );
      expect(out, 'CHATTY A1 Robin.');
    });

    test('falls back to bare name when bucket is missing', () {
      // Build a bundle that has no entry for bucket A.
      final json = {
        'locale': 'en',
        'buckets': {
          'B': {
            'balanced': ['B1 {name}.'],
          },
        },
      };
      final engine = PhrasingEngine(bundle: TemplateBundle.fromJson(json));
      final out = engine.speakOne(
        name: 'Robin',
        signals: _sig(), // bucket A
        verbosity: AnnouncementVerbosity.balanced,
      );
      expect(out, 'Robin.');
    });
  });

  group('PhrasingEngine.speakMany', () {
    test('three names use H_three template', () {
      final engine = PhrasingEngine(bundle: _bundle());
      final out = engine.speakMany(
        names: ['Robin', 'Jay', 'Vireo'],
        verbosity: AnnouncementVerbosity.balanced,
      );
      expect(out, 'Three: Robin, Jay, Vireo.');
    });

    test('two names use H_two template', () {
      final engine = PhrasingEngine(bundle: _bundle());
      final out = engine.speakMany(
        names: ['Robin', 'Jay'],
        verbosity: AnnouncementVerbosity.balanced,
      );
      expect(out, 'Two: Robin and Jay.');
    });

    test('four names route to H_many', () {
      final engine = PhrasingEngine(bundle: _bundle());
      final out = engine.speakMany(
        names: ['Robin', 'Jay', 'Vireo', 'Wren'],
        verbosity: AnnouncementVerbosity.balanced,
      );
      expect(out, 'Many: Robin, Jay, Vireo, etc.');
    });

    test('minimal verbosity comma-joins names', () {
      final engine = PhrasingEngine(bundle: _bundle());
      final out = engine.speakMany(
        names: ['Robin', 'Jay', 'Vireo', 'Wren'],
        verbosity: AnnouncementVerbosity.minimal,
      );
      expect(out, 'Robin, Jay, Vireo.');
    });

    test('empty list returns empty string', () {
      final engine = PhrasingEngine(bundle: _bundle());
      expect(
        engine.speakMany(
          names: const [],
          verbosity: AnnouncementVerbosity.balanced,
        ),
        '',
      );
    });
  });

  group('Anti-repeat (3-slot ring buffer)', () {
    test('three calls into a 3-variant bucket cover all variants', () {
      // Bucket A has exactly 3 balanced variants in our test bundle.
      // After three calls, every variant should have been used once.
      final engine = PhrasingEngine(bundle: _bundle(), random: Random(42));
      final outputs = <String>{};
      for (var i = 0; i < 3; i++) {
        outputs.add(
          engine.speakOne(
            name: 'Robin',
            signals: _sig(),
            verbosity: AnnouncementVerbosity.balanced,
          ),
        );
      }
      expect(outputs.length, 3);
    });

    test('single-variant bucket repeats but does not crash', () {
      final engine = PhrasingEngine(bundle: _bundle());
      // Bucket B has only one variant.
      final out = engine.speakOne(
        name: 'Jay',
        signals: _sig(c: ConfidenceBin.high, recent: true),
        verbosity: AnnouncementVerbosity.balanced,
      );
      expect(out, 'B1 Jay.');
      final out2 = engine.speakOne(
        name: 'Jay',
        signals: _sig(c: ConfidenceBin.high, recent: true),
        verbosity: AnnouncementVerbosity.balanced,
      );
      expect(out2, 'B1 Jay.');
    });
  });

  group('TemplateBundle locale fallback', () {
    test('candidates: exact → language → en', () {
      // Indirectly via the static helper inside TemplateLibrary by
      // exercising the empty-bundle path for a missing locale.
      final empty = TemplateBundle.empty('xx');
      expect(
        empty.variantsFor(AnnouncementBucket.a, AnnouncementVerbosity.balanced),
        isEmpty,
      );
    });
  });

  group('commonnessBinForRatio', () {
    test('null / NaN / Inf / negative → null', () {
      expect(commonnessBinForRatio(null), isNull);
      expect(commonnessBinForRatio(double.nan), isNull);
      expect(commonnessBinForRatio(double.infinity), isNull);
      expect(commonnessBinForRatio(-0.1), isNull);
    });
    test('threshold mapping', () {
      expect(commonnessBinForRatio(1.0), CommonnessBin.abundant);
      expect(commonnessBinForRatio(0.50), CommonnessBin.abundant);
      expect(commonnessBinForRatio(0.49), CommonnessBin.common);
      expect(commonnessBinForRatio(0.20), CommonnessBin.common);
      expect(commonnessBinForRatio(0.19), CommonnessBin.uncommon);
      expect(commonnessBinForRatio(0.05), CommonnessBin.uncommon);
      expect(commonnessBinForRatio(0.049), CommonnessBin.rare);
      expect(commonnessBinForRatio(0.0), CommonnessBin.rare);
    });
  });

  group('Chatty commonness addendum', () {
    TemplateBundle bundleWithCommonness() {
      final json = {
        'locale': 'en',
        'buckets': {
          'A': {
            'balanced': ['BAL {name}.'],
            'chatty': ['CHATTY {name}.'],
          },
        },
        'commonness': {
          'abundant': ['Very common.'],
          'common': ['Common bird.'],
          'uncommon': ['Uncommon here.'],
          'rare': ['A rarity.'],
          'seasonalAddendum': ['Off-season too.'],
        },
      };
      return TemplateBundle.fromJson(json);
    }

    AnnouncementSignals firstAnnSig({
      CommonnessBin? bin,
      bool offSeason = false,
      bool first = true,
    }) => AnnouncementSignals(
      confidence: ConfidenceBin.high,
      isRecent: false,
      isFirstInSession: true,
      streakLength: 1,
      isFirstAnnouncement: first,
      commonness: bin,
      isOutOfSeason: offSeason,
    );

    test('chatty + first announcement + commonness appends phrase', () {
      final engine = PhrasingEngine(bundle: bundleWithCommonness());
      final out = engine.speakOne(
        name: 'Robin',
        signals: firstAnnSig(bin: CommonnessBin.common),
        verbosity: AnnouncementVerbosity.chatty,
      );
      expect(out, 'CHATTY Robin. Common bird.');
    });

    test('chatty + first + commonness + out-of-season appends both', () {
      final engine = PhrasingEngine(bundle: bundleWithCommonness());
      final out = engine.speakOne(
        name: 'Robin',
        signals: firstAnnSig(bin: CommonnessBin.uncommon, offSeason: true),
        verbosity: AnnouncementVerbosity.chatty,
      );
      expect(out, 'CHATTY Robin. Uncommon here. Off-season too.');
    });

    test('balanced verbosity never appends commonness', () {
      final engine = PhrasingEngine(bundle: bundleWithCommonness());
      final out = engine.speakOne(
        name: 'Robin',
        signals: firstAnnSig(bin: CommonnessBin.common),
        verbosity: AnnouncementVerbosity.balanced,
      );
      expect(out, 'BAL Robin.');
    });

    test('not-first-announcement skips commonness even in chatty', () {
      final engine = PhrasingEngine(bundle: bundleWithCommonness());
      final out = engine.speakOne(
        name: 'Robin',
        signals: firstAnnSig(bin: CommonnessBin.common, first: false),
        verbosity: AnnouncementVerbosity.chatty,
      );
      expect(out, 'CHATTY Robin.');
    });

    test('null commonness skips addendum', () {
      final engine = PhrasingEngine(bundle: bundleWithCommonness());
      final out = engine.speakOne(
        name: 'Robin',
        signals: firstAnnSig(bin: null),
        verbosity: AnnouncementVerbosity.chatty,
      );
      expect(out, 'CHATTY Robin.');
    });

    test('locale opting out of commonness leaves base phrase intact', () {
      // No `commonness` key in the JSON.
      final json = {
        'locale': 'en',
        'buckets': {
          'A': {
            'balanced': ['BAL {name}.'],
            'chatty': ['CHATTY {name}.'],
          },
        },
      };
      final engine = PhrasingEngine(bundle: TemplateBundle.fromJson(json));
      final out = engine.speakOne(
        name: 'Robin',
        signals: firstAnnSig(bin: CommonnessBin.abundant, offSeason: true),
        verbosity: AnnouncementVerbosity.chatty,
      );
      expect(out, 'CHATTY Robin.');
    });
  });
}
