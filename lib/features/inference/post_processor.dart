// =============================================================================
// Post-Processor — Pure Dart post-processing for model output
// =============================================================================
//
// Transforms raw model logits into actionable detection results.  All methods
// are static, side-effect-free, and operate on plain Dart lists — fully
// testable without platform dependencies.
//
// ### Pipeline
//
// 1. **Sigmoid** — convert raw logits to probabilities [0, 1].
// 2. **Sensitivity scaling** — shift the sigmoid curve to boost or suppress
//    weak signals (reference: BirdNET PWA `applySensitivity`).
// 3. **Top-K extraction** — select the N highest-confidence species.
// 4. **Threshold filtering** — discard detections below a confidence floor.
//
// ### Reference
//
// The sensitivity formula comes from the official BirdNET PWA:
//
// ```js
// const bias = (sensitivity - 1.0) * 5.0;
// const logit = Math.log(p / (1 - p));
// return 1 / (1 + Math.exp(-(logit + bias)));
// ```
// =============================================================================

import 'dart:math' as math;

import 'models/detection.dart';
import 'models/species.dart';

/// Static helpers for post-processing model output.
///
/// All methods are pure functions with no side effects.
abstract final class PostProcessor {
  // ---------------------------------------------------------------------------
  // Sigmoid
  // ---------------------------------------------------------------------------

  /// Standard sigmoid: σ(x) = 1 / (1 + e^(−x)).
  ///
  /// Clamps extreme values to avoid NaN from overflow.
  static double sigmoid(double x) {
    if (x >= 20) return 1.0;
    if (x <= -20) return 0.0;
    return 1.0 / (1.0 + math.exp(-x));
  }

  /// Apply sigmoid to every element of [logits], returning probabilities.
  static List<double> sigmoidAll(List<double> logits) =>
      logits.map(sigmoid).toList();

  // ---------------------------------------------------------------------------
  // Sensitivity scaling
  // ---------------------------------------------------------------------------

  /// Apply sensitivity scaling to a probability [p].
  ///
  /// [sensitivity] is typically in [0.5, 1.5]:
  /// - `1.0` = no change.
  /// - `> 1.0` = boost weak signals (more detections, more false positives).
  /// - `< 1.0` = suppress weak signals (fewer detections, fewer false positives).
  ///
  /// The formula converts p → logit, adds a bias, then converts back:
  /// ```
  /// bias = (sensitivity - 1.0) * 5.0
  /// logit = ln(p / (1 - p))
  /// result = σ(logit + bias)
  /// ```
  static double applySensitivity(double p, double sensitivity) {
    if (sensitivity == 1.0) return p;

    // Clamp to avoid log(0) or log(∞).
    final pp = p.clamp(1e-7, 1.0 - 1e-7);
    final logit = math.log(pp / (1.0 - pp));
    final bias = (sensitivity - 1.0) * 5.0;
    return sigmoid(logit + bias);
  }

  /// Apply sensitivity scaling to all probabilities in [probs].
  static List<double> applySensitivityAll(
    List<double> probs,
    double sensitivity,
  ) {
    if (sensitivity == 1.0) return probs;
    return probs.map((p) => applySensitivity(p, sensitivity)).toList();
  }

  // ---------------------------------------------------------------------------
  // Top-K extraction
  // ---------------------------------------------------------------------------

  /// Extract the top [k] detections from [scores] above [threshold].
  ///
  /// [scores] must have the same length as [labels].  Returns detections
  /// sorted by descending confidence.
  ///
  /// If [timestamp] is provided, it is attached to each [Detection].
  static List<Detection> topK({
    required List<double> scores,
    required List<Species> labels,
    int k = 10,
    double threshold = 0.0,
    DateTime? timestamp,
  }) {
    assert(
      scores.length == labels.length,
      'scores (${scores.length}) must match labels (${labels.length})',
    );

    // Build index-score pairs, filter by threshold, sort descending.
    final indexed = <_IndexedScore>[];
    for (var i = 0; i < scores.length; i++) {
      if (scores[i] >= threshold) {
        indexed.add(_IndexedScore(i, scores[i]));
      }
    }

    // Partial sort: only need top-k so a full sort is fine for ≤ 12K items.
    indexed.sort((a, b) => b.score.compareTo(a.score));

    final topCount = indexed.length < k ? indexed.length : k;
    return [
      for (var i = 0; i < topCount; i++)
        Detection(
          species: labels[indexed[i].index],
          confidence: indexed[i].score,
          timestamp: timestamp,
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Full pipeline
  // ---------------------------------------------------------------------------

  /// Run the complete post-processing pipeline on model [scores].
  ///
  /// Steps:
  /// 1. Sensitivity scaling (operates in logit space on probabilities).
  /// 2. Top-K with threshold filtering.
  ///
  /// [scores] are expected to be sigmoid-activated probabilities in [0, 1]
  /// (as output by the BirdNET model).  Sigmoid is **not** applied here.
  static List<Detection> process({
    required List<double> scores,
    required List<Species> labels,
    double sensitivity = 1.0,
    int topK = 10,
    double threshold = 0.15,
    DateTime? timestamp,
  }) {
    // 1. Sensitivity.
    final adjusted = applySensitivityAll(scores, sensitivity);

    // 2. Top-K + threshold.
    return PostProcessor.topK(
      scores: adjusted,
      labels: labels,
      k: topK,
      threshold: threshold,
      timestamp: timestamp,
    );
  }

  // ---------------------------------------------------------------------------
  // Temporal pooling (Log-Mean-Exp)
  // ---------------------------------------------------------------------------

  /// Pool multiple inference windows using Log-Mean-Exp for temporal stability.
  ///
  /// [windowScores] is a list of per-class probability vectors from recent
  /// inference cycles.  Returns a single pooled probability vector.
  ///
  /// The formula (per class):
  /// ```
  /// pooled = log( mean( exp(α · confidence_i) ) ) / α
  /// ```
  ///
  /// [alpha] controls smoothing: higher values emphasise peaks (default 5.0,
  /// matching the BirdNET PWA reference implementation). [peakRetention]
  /// optionally keeps the pooled score close to the strongest recent raw score;
  /// temporal support gating should be used with this so one-off spikes do not
  /// become first detections.
  static List<double> logMeanExp(
    List<List<double>> windowScores, {
    double alpha = 5.0,
    double peakRetention = 0.0,
  }) {
    if (windowScores.isEmpty) return [];
    if (windowScores.length == 1) return List.of(windowScores.first);

    final numClasses = windowScores.first.length;
    final pooled = List<double>.filled(numClasses, 0.0);
    final retention = peakRetention.clamp(0.0, 1.0);

    for (var c = 0; c < numClasses; c++) {
      // Collect scores for this class across all windows.
      var sumExp = 0.0;
      var peak = 0.0;
      for (final window in windowScores) {
        final score = window[c];
        sumExp += math.exp(alpha * score);
        if (score > peak) peak = score;
      }
      final meanExp = sumExp / windowScores.length;
      final lme = math.log(meanExp) / alpha;
      pooled[c] = math.max(lme, peak * retention);
    }

    return pooled;
  }

  /// Per-class arithmetic mean across [windowScores].
  ///
  /// Smooths flickering detections: noisy single-window peaks get pulled
  /// down by surrounding low-score windows, so only sustained calls stay
  /// above threshold.
  static List<double> average(List<List<double>> windowScores) {
    if (windowScores.isEmpty) return [];
    if (windowScores.length == 1) return List.of(windowScores.first);
    final numClasses = windowScores.first.length;
    final pooled = List<double>.filled(numClasses, 0.0);
    for (final window in windowScores) {
      for (var c = 0; c < numClasses; c++) {
        pooled[c] += window[c];
      }
    }
    final n = windowScores.length;
    for (var c = 0; c < numClasses; c++) {
      pooled[c] /= n;
    }
    return pooled;
  }

  /// Per-class maximum across [windowScores].
  ///
  /// Most reactive pooling: any single window above threshold wins.
  /// Good for very brief calls but lets transient noise through.
  static List<double> max(List<List<double>> windowScores) {
    if (windowScores.isEmpty) return [];
    if (windowScores.length == 1) return List.of(windowScores.first);
    final numClasses = windowScores.first.length;
    final pooled = List<double>.from(windowScores.first);
    for (var w = 1; w < windowScores.length; w++) {
      final window = windowScores[w];
      for (var c = 0; c < numClasses; c++) {
        if (window[c] > pooled[c]) pooled[c] = window[c];
      }
    }
    return pooled;
  }

  /// Whether class [index] has enough raw-window support to appear.
  ///
  /// This is separate from LME scoring: LME preserves high peaks, while this
  /// gate prevents a single unsupported peak from becoming a first detection.
  static bool hasTemporalSupport({
    required List<List<double>> windowScores,
    required int index,
    required double supportThreshold,
    required int minSupportWindows,
    required double veryHighImmediateThreshold,
  }) {
    if (windowScores.isEmpty) return true;
    if (minSupportWindows <= 1) return true;

    final latest = windowScores.last[index];
    if (latest >= veryHighImmediateThreshold) return true;

    var supportingWindows = 0;
    for (final window in windowScores) {
      if (window[index] >= supportThreshold) {
        supportingWindows++;
        if (supportingWindows >= minSupportWindows) return true;
      }
    }

    return false;
  }

  /// Suppress new pooled detections that lack raw-window support.
  ///
  /// [confirmedIndexes] are already visible detections from the previous
  /// inference cycle. They keep using pooled scores until they fall below the
  /// active confidence threshold, avoiding flicker after initial confirmation.
  static List<double> applyTemporalSupportGate({
    required List<double> scores,
    required List<List<double>> windowScores,
    required Set<int> confirmedIndexes,
    required double confidenceThreshold,
    required double supportThreshold,
    required int minSupportWindows,
    required double veryHighImmediateThreshold,
  }) {
    if (windowScores.isEmpty || minSupportWindows <= 1) return scores;

    final gated = List<double>.of(scores);
    for (var i = 0; i < scores.length; i++) {
      if (scores[i] < confidenceThreshold || confirmedIndexes.contains(i)) {
        continue;
      }

      final supported = hasTemporalSupport(
        windowScores: windowScores,
        index: i,
        supportThreshold: supportThreshold,
        minSupportWindows: minSupportWindows,
        veryHighImmediateThreshold: veryHighImmediateThreshold,
      );
      if (!supported) gated[i] = -1.0;
    }

    return gated;
  }
}

/// Internal helper for sorting indices by score.
class _IndexedScore {
  const _IndexedScore(this.index, this.score);
  final int index;
  final double score;
}
