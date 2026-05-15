import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/announcements/domain/announcement_presets.dart';

void main() {
  group('parseVerbosity', () {
    test('round-trip for every value', () {
      for (final v in AnnouncementVerbosity.values) {
        expect(parseVerbosity(v.name), v);
      }
    });

    test('null / unknown falls back to balanced', () {
      expect(parseVerbosity(null), AnnouncementVerbosity.balanced);
      expect(parseVerbosity(''), AnnouncementVerbosity.balanced);
      expect(parseVerbosity('garbage'), AnnouncementVerbosity.balanced);
    });
  });

  group('parseFrequency', () {
    test('round-trip for every value', () {
      for (final f in AnnouncementFrequency.values) {
        expect(parseFrequency(f.name), f);
      }
    });

    test('null / unknown falls back to normal', () {
      expect(parseFrequency(null), AnnouncementFrequency.normal);
      expect(parseFrequency('garbage'), AnnouncementFrequency.normal);
    });
  });

  group('frequencyProfileFor', () {
    test('every named preset has a profile', () {
      expect(frequencyProfileFor(AnnouncementFrequency.sparse), isNotNull);
      expect(frequencyProfileFor(AnnouncementFrequency.normal), isNotNull);
      expect(frequencyProfileFor(AnnouncementFrequency.frequent), isNotNull);
    });

    test('custom returns null so the controller leaves prefs alone', () {
      expect(frequencyProfileFor(AnnouncementFrequency.custom), isNull);
    });

    test('cadence ordering: sparse < normal < frequent', () {
      final sparse = frequencyProfileFor(AnnouncementFrequency.sparse)!;
      final normal = frequencyProfileFor(AnnouncementFrequency.normal)!;
      final frequent = frequencyProfileFor(AnnouncementFrequency.frequent)!;
      expect(sparse.minIntervalSeconds, greaterThan(normal.minIntervalSeconds));
      expect(
        normal.minIntervalSeconds,
        greaterThan(frequent.minIntervalSeconds),
      );
      expect(sparse.maxPerMinute, lessThan(normal.maxPerMinute));
      expect(normal.maxPerMinute, lessThan(frequent.maxPerMinute));
      expect(
        sparse.streakSilenceSeconds,
        greaterThan(normal.streakSilenceSeconds),
      );
      expect(
        normal.streakSilenceSeconds,
        greaterThan(frequent.streakSilenceSeconds),
      );
    });

    test('speaker mode is always at least as throttled as headphone mode', () {
      for (final f in [
        AnnouncementFrequency.sparse,
        AnnouncementFrequency.normal,
        AnnouncementFrequency.frequent,
      ]) {
        final p = frequencyProfileFor(f)!;
        expect(
          p.minIntervalSecondsSpeaker,
          greaterThanOrEqualTo(p.minIntervalSeconds),
        );
        expect(p.maxPerMinuteSpeaker, lessThanOrEqualTo(p.maxPerMinute));
      }
    });
  });
}
