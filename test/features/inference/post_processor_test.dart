// =============================================================================
// Post-Processor Tests
// =============================================================================
//
// Verifies the pure Dart post-processing pipeline: sigmoid, sensitivity
// scaling, top-K extraction, temporal pooling (Log-Mean-Exp).
//
// All tests use synthetic data — no model or platform dependencies.
// =============================================================================

import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/inference/post_processor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to build a list of dummy [Species] for testing.
List<Species> _dummyLabels(int count) => List.generate(
      count,
      (i) => Species(
        index: i,
        id: i,
        scientificName: 'Species $i',
        commonName: 'Bird $i',
        className: 'Aves',
        order: 'Order',
      ),
    );

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Sigmoid
  // ─────────────────────────────────────────────────────────────────────────

  group('PostProcessor.sigmoid', () {
    test('sigmoid(0) = 0.5', () {
      expect(PostProcessor.sigmoid(0), closeTo(0.5, 1e-10));
    });

    test('sigmoid of large positive ≈ 1.0', () {
      expect(PostProcessor.sigmoid(20), 1.0);
      expect(PostProcessor.sigmoid(100), 1.0);
    });

    test('sigmoid of large negative ≈ 0.0', () {
      expect(PostProcessor.sigmoid(-20), 0.0);
      expect(PostProcessor.sigmoid(-100), 0.0);
    });

    test('sigmoid is monotonically increasing', () {
      for (var x = -10.0; x < 10.0; x += 0.5) {
        expect(PostProcessor.sigmoid(x + 0.5),
            greaterThanOrEqualTo(PostProcessor.sigmoid(x)));
      }
    });

    test('sigmoid(-x) = 1 - sigmoid(x)', () {
      for (var x = -5.0; x <= 5.0; x += 0.5) {
        expect(PostProcessor.sigmoid(-x),
            closeTo(1.0 - PostProcessor.sigmoid(x), 1e-10));
      }
    });

    test('sigmoidAll applies sigmoid to every element', () {
      final logits = [-2.0, 0.0, 2.0];
      final probs = PostProcessor.sigmoidAll(logits);

      expect(probs.length, 3);
      for (var i = 0; i < logits.length; i++) {
        expect(probs[i], closeTo(PostProcessor.sigmoid(logits[i]), 1e-10));
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Sensitivity scaling
  // ─────────────────────────────────────────────────────────────────────────

  group('PostProcessor.applySensitivity', () {
    test('sensitivity 1.0 returns same value', () {
      expect(PostProcessor.applySensitivity(0.5, 1.0), closeTo(0.5, 1e-10));
      expect(PostProcessor.applySensitivity(0.9, 1.0), closeTo(0.9, 1e-10));
    });

    test('sensitivity > 1.0 boosts low confidence', () {
      final base = 0.2;
      final boosted = PostProcessor.applySensitivity(base, 1.5);
      expect(boosted, greaterThan(base));
    });

    test('sensitivity < 1.0 suppresses confidence', () {
      final base = 0.8;
      final suppressed = PostProcessor.applySensitivity(base, 0.5);
      expect(suppressed, lessThan(base));
    });

    test('sensitivity result stays in (0, 1)', () {
      for (var s = 0.5; s <= 1.5; s += 0.1) {
        for (var p = 0.01; p <= 0.99; p += 0.1) {
          final result = PostProcessor.applySensitivity(p, s);
          expect(result, greaterThan(0));
          expect(result, lessThan(1));
        }
      }
    });

    test('applySensitivityAll applies to all elements', () {
      final probs = [0.1, 0.5, 0.9];
      final adjusted = PostProcessor.applySensitivityAll(probs, 1.2);
      expect(adjusted.length, 3);
      for (var i = 0; i < probs.length; i++) {
        expect(adjusted[i],
            closeTo(PostProcessor.applySensitivity(probs[i], 1.2), 1e-10));
      }
    });

    test('sensitivity 1.0 fast path returns same list', () {
      final probs = [0.1, 0.5, 0.9];
      final result = PostProcessor.applySensitivityAll(probs, 1.0);
      expect(identical(result, probs), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Top-K extraction
  // ─────────────────────────────────────────────────────────────────────────

  group('PostProcessor.topK', () {
    test('returns top-K sorted by descending confidence', () {
      final labels = _dummyLabels(5);
      final scores = [0.1, 0.9, 0.3, 0.7, 0.5];

      final results = PostProcessor.topK(
        scores: scores,
        labels: labels,
        k: 3,
      );

      expect(results.length, 3);
      expect(results[0].species.index, 1); // 0.9
      expect(results[1].species.index, 3); // 0.7
      expect(results[2].species.index, 4); // 0.5
    });

    test('returns fewer than K when not enough scores', () {
      final labels = _dummyLabels(2);
      final scores = [0.8, 0.6];

      final results = PostProcessor.topK(
        scores: scores,
        labels: labels,
        k: 10,
      );

      expect(results.length, 2);
    });

    test('threshold filters low scores', () {
      final labels = _dummyLabels(5);
      final scores = [0.1, 0.9, 0.05, 0.7, 0.02];

      final results = PostProcessor.topK(
        scores: scores,
        labels: labels,
        k: 10,
        threshold: 0.15,
      );

      // Only 0.9 and 0.7 exceed 0.15.
      expect(results.length, 2);
      expect(results[0].confidence, 0.9);
      expect(results[1].confidence, 0.7);
    });

    test('threshold 0.0 includes all scores > 0', () {
      final labels = _dummyLabels(3);
      final scores = [0.0, 0.5, 0.001];

      final results = PostProcessor.topK(
        scores: scores,
        labels: labels,
        k: 10,
        threshold: 0.0,
      );

      // Only exactly 0.0 is filtered (>= 0.0 passes all).
      expect(results.length, 3);
    });

    test('attaches timestamp to detections', () {
      final labels = _dummyLabels(2);
      final scores = [0.5, 0.8];
      final now = DateTime(2026, 1, 1);

      final results = PostProcessor.topK(
        scores: scores,
        labels: labels,
        k: 2,
        timestamp: now,
      );

      expect(results[0].timestamp, now);
      expect(results[1].timestamp, now);
    });

    test('empty scores returns empty list', () {
      final results = PostProcessor.topK(
        scores: [],
        labels: [],
        k: 10,
      );
      expect(results, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Full pipeline
  // ─────────────────────────────────────────────────────────────────────────

  group('PostProcessor.process', () {
    test('full pipeline produces detections from probabilities', () {
      final labels = _dummyLabels(5);
      // Probabilities (model output is already sigmoid-activated).
      final scores = [0.01, 0.95, 0.01, 0.75, 0.01];

      final results = PostProcessor.process(
        scores: scores,
        labels: labels,
        topK: 2,
        threshold: 0.1,
      );

      expect(results.length, 2);
      expect(results[0].species.index, 1); // 0.95 → highest
      expect(results[0].confidence, greaterThan(0.9));
      expect(results[1].species.index, 3); // 0.75 → second
    });

    test(
        'all near-zero probabilities produce no detections at default threshold',
        () {
      final labels = _dummyLabels(5);
      final scores = [0.001, 0.001, 0.001, 0.001, 0.001];

      final results = PostProcessor.process(
        scores: scores,
        labels: labels,
        threshold: 0.15,
      );

      expect(results, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Temporal pooling (Log-Mean-Exp)
  // ─────────────────────────────────────────────────────────────────────────

  group('PostProcessor.logMeanExp', () {
    test('single window returns same values', () {
      final scores = [0.1, 0.5, 0.9];
      final pooled = PostProcessor.logMeanExp([scores]);

      for (var i = 0; i < scores.length; i++) {
        expect(pooled[i], closeTo(scores[i], 1e-10));
      }
    });

    test('empty input returns empty list', () {
      expect(PostProcessor.logMeanExp([]), isEmpty);
    });

    test('identical windows return same values', () {
      final scores = [0.3, 0.7, 0.5];
      final pooled = PostProcessor.logMeanExp([scores, scores, scores]);

      for (var i = 0; i < scores.length; i++) {
        expect(pooled[i], closeTo(scores[i], 1e-6));
      }
    });

    test('pooling emphasises peaks over troughs', () {
      // Window 1: class 0 has 0.9, Window 2: class 0 has 0.1.
      // Log-Mean-Exp with α=5 should produce a value biased toward 0.9.
      final w1 = [0.9, 0.1];
      final w2 = [0.1, 0.9];
      final pooled = PostProcessor.logMeanExp([w1, w2], alpha: 5.0);

      // Simple arithmetic mean would give 0.5 for both.
      // LME should give > 0.5 because it biases toward peaks.
      expect(pooled[0], greaterThan(0.5));
      expect(pooled[1], greaterThan(0.5));
    });

    test('alpha=0 degenerates to arithmetic mean', () {
      // With α close to 0, LME approaches arithmetic mean.
      final w1 = [0.8, 0.2];
      final w2 = [0.2, 0.8];
      final pooled = PostProcessor.logMeanExp([w1, w2], alpha: 0.001);

      // Should be very close to 0.5 for both classes.
      expect(pooled[0], closeTo(0.5, 0.01));
      expect(pooled[1], closeTo(0.5, 0.01));
    });

    test('higher alpha produces stronger peak emphasis', () {
      final w1 = [0.8, 0.2];
      final w2 = [0.2, 0.8];

      final low = PostProcessor.logMeanExp([w1, w2], alpha: 1.0);
      final high = PostProcessor.logMeanExp([w1, w2], alpha: 10.0);

      // Higher alpha → result closer to 0.8 (the peak).
      expect(high[0], greaterThan(low[0]));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Detection data class
  // ─────────────────────────────────────────────────────────────────────

  group('Detection', () {
    test('confidencePercent formats correctly', () {
      final labels = _dummyLabels(1);
      final det = PostProcessor.topK(
        scores: [0.873],
        labels: labels,
        k: 1,
      ).first;

      expect(det.confidencePercent, '87.3 %');
    });

    test('toString contains species name', () {
      final labels = _dummyLabels(1);
      final det = PostProcessor.topK(
        scores: [0.5],
        labels: labels,
        k: 1,
      ).first;

      expect(det.toString(), contains('Bird 0'));
    });

    test('equality checks species and confidence', () {
      final labels = _dummyLabels(2);
      final a = PostProcessor.topK(
        scores: [0.8, 0.2],
        labels: labels,
        k: 1,
      ).first;
      final b = PostProcessor.topK(
        scores: [0.8, 0.2],
        labels: labels,
        k: 1,
      ).first;

      expect(a, equals(b));
    });
  });
}
