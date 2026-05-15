import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/announcements/domain/announcement_buckets.dart';
import 'package:birdnet_live/features/announcements/domain/announcement_signals.dart';

void main() {
  group('confidenceBinFor', () {
    test('high at 0.80 and above', () {
      expect(confidenceBinFor(0.80), ConfidenceBin.high);
      expect(confidenceBinFor(0.95), ConfidenceBin.high);
    });

    test('medium between 0.55 and 0.80', () {
      expect(confidenceBinFor(0.55), ConfidenceBin.medium);
      expect(confidenceBinFor(0.7999), ConfidenceBin.medium);
    });

    test('low below 0.55', () {
      expect(confidenceBinFor(0.0), ConfidenceBin.low);
      expect(confidenceBinFor(0.5499), ConfidenceBin.low);
    });
  });

  group('selectBucket', () {
    AnnouncementSignals s({
      required ConfidenceBin c,
      bool recent = false,
      bool first = true,
      int streak = 1,
    }) => AnnouncementSignals(
      confidence: c,
      isRecent: recent,
      isFirstInSession: first,
      streakLength: streak,
    );

    test('high + fresh → A', () {
      expect(selectBucket(s(c: ConfidenceBin.high)), AnnouncementBucket.a);
    });

    test('high + recent → B', () {
      expect(
        selectBucket(s(c: ConfidenceBin.high, recent: true)),
        AnnouncementBucket.b,
      );
    });

    test('streak ≥ 2 → C regardless of confidence/recency', () {
      expect(
        selectBucket(s(c: ConfidenceBin.low, recent: true, streak: 4)),
        AnnouncementBucket.c,
      );
      expect(
        selectBucket(s(c: ConfidenceBin.high, streak: 2)),
        AnnouncementBucket.c,
      );
    });

    test('medium routing', () {
      expect(selectBucket(s(c: ConfidenceBin.medium)), AnnouncementBucket.d);
      expect(
        selectBucket(s(c: ConfidenceBin.medium, recent: true)),
        AnnouncementBucket.e,
      );
    });

    test('low routing', () {
      expect(selectBucket(s(c: ConfidenceBin.low)), AnnouncementBucket.f);
      expect(
        selectBucket(s(c: ConfidenceBin.low, recent: true)),
        AnnouncementBucket.g,
      );
    });
  });

  group('selectCoalesceBucket', () {
    test('two names → H_two', () {
      expect(selectCoalesceBucket(2), AnnouncementBucket.hTwo);
    });

    test('three names → H_three', () {
      expect(selectCoalesceBucket(3), AnnouncementBucket.hThree);
    });

    test('four or more → H_many', () {
      expect(selectCoalesceBucket(4), AnnouncementBucket.hMany);
      expect(selectCoalesceBucket(99), AnnouncementBucket.hMany);
    });
  });

  group('AnnouncementBucket.jsonKey', () {
    test('single-letter buckets uppercase', () {
      expect(AnnouncementBucket.a.jsonKey, 'A');
      expect(AnnouncementBucket.g.jsonKey, 'G');
    });

    test('multi-species buckets use H_two / H_three / H_many', () {
      expect(AnnouncementBucket.hTwo.jsonKey, 'H_two');
      expect(AnnouncementBucket.hThree.jsonKey, 'H_three');
      expect(AnnouncementBucket.hMany.jsonKey, 'H_many');
    });
  });
}
