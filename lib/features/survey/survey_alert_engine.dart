// =============================================================================
// Survey Alert Engine — Decides which detections deserve a push notification
// =============================================================================
//
// Pure, side-effect-free decision logic for the Survey species-alert system.
// Given a [DetectionRecord] and the user's chosen [AlertMode], the engine
// returns an [AlertCandidate] describing *why* the alert should fire — or
// `null` to suppress.
//
// Throttling, coalescing, and actual notification delivery happen
// downstream in [AlertThrottler] and `SpeciesAlertNotifier`. Keeping the
// engine pure means the entire decision tree is unit-testable without
// any plugin dependencies, async state, or platform channels.
//
// ### Modes
//
// - `off` — never fires.
// - `firstInSession` — fires the first time a species is seen this session.
// - `firstEver` — first-in-session AND species not in the global history.
// - `rare` — first-in-session AND geo-model score below the user threshold
//   (treats absent species as score = 0, i.e. always rare here).
// - `watchlist` — first-in-session AND species on the user's selected list.
//
// All non-off modes require [firstInSession] (the caller tracks this in a
// per-session `Set<String>`). The minConfidence floor applies to every mode.
// =============================================================================

import '../live/live_session.dart';
import '../history/global_species_history.dart';

/// User-chosen alert criterion. Persisted as the integer index in
/// `PrefKeys.surveyAlertMode`.
enum AlertMode {
  off,
  firstInSession,
  firstEver,
  rare,
  watchlist;

  /// Stable enum index used for persistence. Adding a new mode must append
  /// to the end so existing prefs continue to point at the right entry.
  int get prefValue => index;

  static AlertMode fromPrefValue(int? value) {
    if (value == null || value < 0 || value >= AlertMode.values.length) {
      return AlertMode.off;
    }
    return AlertMode.values[value];
  }
}

/// Why an alert was raised. Drives the notification body string and icon.
enum AlertReason { firstInSession, firstEver, rare, watchlist }

/// One species-alert candidate produced by [SurveyAlertEngine.evaluate].
class AlertCandidate {
  const AlertCandidate({
    required this.scientificName,
    required this.commonName,
    required this.confidence,
    required this.timestamp,
    required this.reason,
    this.geoScore,
  });

  final String scientificName;
  final String commonName;
  final double confidence;
  final DateTime timestamp;
  final AlertReason reason;

  /// Geo-model score at the survey's location/week, when known. Always
  /// populated for [AlertReason.rare]; may be null for other reasons.
  final double? geoScore;

  AlertCandidate copyWith({String? commonName}) {
    return AlertCandidate(
      scientificName: scientificName,
      commonName: commonName ?? this.commonName,
      confidence: confidence,
      timestamp: timestamp,
      reason: reason,
      geoScore: geoScore,
    );
  }
}

/// Pure decision logic for species alerts.
///
/// Construct one engine per survey at start time, snapshotting the user's
/// settings. Mid-survey settings changes are intentionally ignored — see
/// the implementation plan for rationale.
class SurveyAlertEngine {
  SurveyAlertEngine({
    required this.mode,
    required this.minConfidence,
    required this.globalHistory,
    this.rareThreshold = 0.05,
    this.watchlist = const <String>{},
    this.geoScores = const <String, double>{},
  });

  final AlertMode mode;

  /// Detections below this confidence are never alerted on, regardless of
  /// mode. Caller should clamp this to at least the session's main
  /// confidence threshold so alert sensitivity never exceeds detection
  /// sensitivity.
  final double minConfidence;

  /// `0.0` – `1.0`. A species' [geoScores] entry strictly below this value
  /// is considered "rare here" for [AlertMode.rare]. Absent entries are
  /// treated as score 0 — a species the geo-model has never seen at this
  /// location is, by definition, rare.
  final double rareThreshold;

  /// Set of scientific names on the user's selected watchlist. Empty when
  /// no list is selected (in which case [AlertMode.watchlist] never fires).
  final Set<String> watchlist;

  /// Geo-model probability map snapshot for the current location/week.
  /// Maps scientific name → score in `[0, 1]`.
  final Map<String, double> geoScores;

  /// Lifetime species history. Used by [AlertMode.firstEver].
  final GlobalSpeciesHistory globalHistory;

  /// Returns an [AlertCandidate] when [d] should fire an alert, else null.
  ///
  /// [firstInSession] tells the engine whether this is the first time
  /// the species has appeared in the *current* survey. The caller is
  /// responsible for the bookkeeping (typically a `Set<String>` updated
  /// alongside the existing `_activeCardSpecies` map in `SurveyController`).
  AlertCandidate? evaluate(DetectionRecord d, {required bool firstInSession}) {
    if (mode == AlertMode.off) return null;
    if (d.confidence < minConfidence) return null;
    if (!firstInSession) return null;

    final name = d.scientificName;
    if (name.isEmpty) return null;

    switch (mode) {
      case AlertMode.off:
        return null; // unreachable
      case AlertMode.firstInSession:
        return _build(d, AlertReason.firstInSession);
      case AlertMode.firstEver:
        if (globalHistory.contains(name)) return null;
        return _build(d, AlertReason.firstEver);
      case AlertMode.rare:
        final score = geoScores[name] ?? 0.0;
        if (score >= rareThreshold) return null;
        return _build(d, AlertReason.rare, geoScore: score);
      case AlertMode.watchlist:
        if (!watchlist.contains(name)) return null;
        return _build(d, AlertReason.watchlist);
    }
  }

  AlertCandidate _build(
    DetectionRecord d,
    AlertReason reason, {
    double? geoScore,
  }) {
    return AlertCandidate(
      scientificName: d.scientificName,
      commonName: d.commonName,
      confidence: d.confidence,
      timestamp: d.timestamp,
      reason: reason,
      geoScore: geoScore,
    );
  }
}
