import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/history/session_review_screen.dart';

void main() {
  group('compareSessionReviewConfidenceSortEntries', () {
    final base = DateTime.utc(2026, 5, 24, 8);

    test('prefers clip-backed detections before clipless detections', () {
      final result = compareSessionReviewConfidenceSortEntries(
        aHasAudioClip: true,
        aConfidence: 0.70,
        aTimestamp: base.add(const Duration(seconds: 20)),
        bHasAudioClip: false,
        bConfidence: 0.99,
        bTimestamp: base,
      );

      expect(result, isNegative);
    });

    test('sorts by descending confidence within the same clip state', () {
      final result = compareSessionReviewConfidenceSortEntries(
        aHasAudioClip: true,
        aConfidence: 0.82,
        aTimestamp: base,
        bHasAudioClip: true,
        bConfidence: 0.94,
        bTimestamp: base.add(const Duration(seconds: 20)),
      );

      expect(result, isPositive);
    });

    test('uses timestamp as a deterministic tie-breaker', () {
      final result = compareSessionReviewConfidenceSortEntries(
        aHasAudioClip: false,
        aConfidence: 0.82,
        aTimestamp: base,
        bHasAudioClip: false,
        bConfidence: 0.82,
        bTimestamp: base.add(const Duration(seconds: 20)),
      );

      expect(result, isNegative);
    });
  });
}
