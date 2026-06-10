// =============================================================================
// Alert Throttler — Smooths out the firehose of survey species alerts
// =============================================================================
//
// The [SurveyAlertEngine] decides which detections deserve an alert. The
// throttler decides whether and when to actually deliver a notification
// for that decision. Three layers, applied in order:
//
//   1. Startup grace period — for the first N seconds after survey start,
//      notifications are suppressed (the alert IS recorded for the engine's
//      bookkeeping; it just doesn't fire a heads-up). Bypassed for the
//      "rare" and "watchlist" reasons since those are rarer and more
//      important — if a target bird shows up immediately, the user wants
//      to know.
//
//   2. Minimum interval — a hard cooldown between any two delivered
//      notifications, regardless of total volume.
//
//   3. Sliding 60 s rate cap — at most N alerts delivered per minute.
//      Excess alerts are *coalesced* (queued for a summary) rather than
//      dropped, so the user never silently misses a new species.
//
// Coalesced alerts are flushed as a single summary notification by [tick],
// which the controller invokes on a periodic timer (~5 s). [tick] also
// returns a final summary on `force: true` (used in `finalize()`).
//
// All decisions are pure: the clock is injected via [now] so unit tests
// can drive the throttler deterministically.
// =============================================================================

import 'survey_alert_engine.dart';

/// Outcome of [AlertThrottler.admit].
sealed class ThrottleDecision {
  const ThrottleDecision();
}

/// Deliver this alert as a heads-up notification immediately.
class DeliverNow extends ThrottleDecision {
  const DeliverNow(this.alert);
  final AlertCandidate alert;
}

/// Drop this alert from notifications entirely (still recorded by the
/// engine for first-in-session tracking). Used for the startup grace
/// period when the alert is not bypass-eligible.
class Suppress extends ThrottleDecision {
  const Suppress();
}

/// Queue this alert for a future summary notification. The throttler will
/// emit a [SummaryAlert] from a subsequent [AlertThrottler.tick] call.
class Coalesce extends ThrottleDecision {
  const Coalesce();
}

/// One coalesced summary notification covering several species at once.
class SummaryAlert {
  SummaryAlert({required this.alerts}) : assert(alerts.isNotEmpty);
  final List<AlertCandidate> alerts;
  int get count => alerts.length;

  /// Reason used to color/icon the summary. Picks the most "important"
  /// reason represented in the queue, with rare > watchlist > firstEver
  /// > firstInSession.
  AlertReason get primaryReason {
    const order = {
      AlertReason.rare: 3,
      AlertReason.watchlist: 2,
      AlertReason.firstEver: 1,
      AlertReason.firstInSession: 0,
    };
    return alerts
        .map((a) => a.reason)
        .reduce((a, b) => (order[a]! >= order[b]!) ? a : b);
  }
}

/// Smooths alert delivery so users aren't bombarded.
///
/// Construct one per survey at start time. Snapshots all settings at
/// construction so mid-survey config changes don't disrupt behavior.
class AlertThrottler {
  AlertThrottler({
    required this.surveyStart,
    required this.startupGrace,
    required this.minInterval,
    required this.maxPerMinute,
    required this.coalesce,
    required this.bypassReasons,
    required this.now,
    this.maxQueueAge = const Duration(seconds: 30),
    this.maxQueueSize = 5,
  });

  /// When the survey began. Used to evaluate the startup grace window.
  final DateTime surveyStart;

  /// How long after [surveyStart] to suppress non-bypassed alerts.
  final Duration startupGrace;

  /// Hard cooldown between any two delivered notifications.
  final Duration minInterval;

  /// Maximum delivered notifications per 60 s sliding window.
  /// `0` (or negative) means unlimited.
  final int maxPerMinute;

  /// When `true`, alerts that fail rate / interval limits are queued for
  /// a summary. When `false`, they are silently suppressed.
  final bool coalesce;

  /// Reasons that bypass the startup grace period (typically rare and
  /// watchlist). Reasons in this set still respect the rate cap and
  /// minimum interval.
  final Set<AlertReason> bypassReasons;

  /// Clock — injectable for testability.
  final DateTime Function() now;

  /// Flush the queue early once it grows older than this since the oldest
  /// queued alert was added. Prevents users from waiting for a full
  /// minute window to elapse just to learn about a queued species.
  final Duration maxQueueAge;

  /// Hard cap on the queue length. Prevents runaway growth in the
  /// (unlikely) event of sustained high activity. When exceeded, the
  /// queue is flushed via [tick] regardless of timing.
  final int maxQueueSize;

  // ── Internal state ────────────────────────────────────────────────────
  final List<DateTime> _deliveredTimestamps = [];
  final List<AlertCandidate> _queue = [];
  DateTime? _lastDeliveredAt;
  DateTime? _oldestQueuedAt;

  // ── Public API ────────────────────────────────────────────────────────

  /// Decide what to do with [alert]. Always called exactly once per
  /// engine-positive evaluation.
  ThrottleDecision admit(AlertCandidate alert) {
    final t = now();

    // Layer 1: startup grace.
    final inGrace = t.difference(surveyStart) < startupGrace;
    final bypassGrace = bypassReasons.contains(alert.reason);
    if (inGrace && !bypassGrace) {
      // Don't even queue these — within the first N seconds the user is
      // typically still placing the phone, and a delayed summary 30 s
      // later for "Robin, Wren, Dunnock" is just noise. We have a clean
      // semantic: grace = silent.
      return const Suppress();
    }

    // Layer 2: min interval.
    final interval =
        _lastDeliveredAt == null ? null : t.difference(_lastDeliveredAt!);
    final intervalOk = interval == null || interval >= minInterval;

    // Layer 3: rate cap.
    _evictOldDeliveries(t);
    final rateOk =
        maxPerMinute <= 0 || _deliveredTimestamps.length < maxPerMinute;

    if (intervalOk && rateOk) {
      _deliveredTimestamps.add(t);
      _lastDeliveredAt = t;
      return DeliverNow(alert);
    }

    if (!coalesce) return const Suppress();

    _queue.add(alert);
    _oldestQueuedAt ??= t;
    return const Coalesce();
  }

  /// Periodically called (e.g. every 5 s) by the controller.
  ///
  /// Returns a [SummaryAlert] when the queue should be flushed *and*
  /// the rate / interval allow delivery right now. Returns `null` when
  /// the queue is empty, or when the throttler is still waiting.
  ///
  /// On [force] = `true` (e.g. survey end), the queue is always flushed
  /// regardless of timing — there's no point making the user wait for
  /// notifications about a survey that just ended.
  SummaryAlert? tick({bool force = false}) {
    if (_queue.isEmpty) return null;

    final t = now();
    final shouldFlush =
        force ||
        _queue.length >= maxQueueSize ||
        (_oldestQueuedAt != null &&
            t.difference(_oldestQueuedAt!) >= maxQueueAge) ||
        _canDeliverNow(t);

    if (!shouldFlush) return null;

    final summary = SummaryAlert(alerts: List.unmodifiable(_queue));
    _queue.clear();
    _oldestQueuedAt = null;

    // The summary itself counts toward the rate / interval budget.
    _deliveredTimestamps.add(t);
    _lastDeliveredAt = t;

    return summary;
  }

  // ── Internals ─────────────────────────────────────────────────────────

  void _evictOldDeliveries(DateTime t) {
    final cutoff = t.subtract(const Duration(seconds: 60));
    _deliveredTimestamps.removeWhere((d) => d.isBefore(cutoff));
  }

  bool _canDeliverNow(DateTime t) {
    final intervalOk =
        _lastDeliveredAt == null ||
        t.difference(_lastDeliveredAt!) >= minInterval;
    _evictOldDeliveries(t);
    final rateOk =
        maxPerMinute <= 0 || _deliveredTimestamps.length < maxPerMinute;
    return intervalOk && rateOk;
  }
}
