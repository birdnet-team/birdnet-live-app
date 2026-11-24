// =============================================================================
// Survey GPS Tracker — Periodic GPS logging for survey transects
// =============================================================================
//
// Wraps [geolocator] to provide a stream of GPS positions during a survey.
//
//   - Appends [GpsPoint] entries to the session's GPS track.
//   - Computes cumulative distance walked (Haversine via [latlong2]).
//   - Operates in two modes:
//       * **Continuous** — a stream of fixes. On Android these come from the
//         platform `gps` provider (see gps_fix_stream.dart), with geolocator
//         as the fallback when precise satellite fixes are not available. On
//         iOS and Windows they come from geolocator at best accuracy.
//       * **Manual GPS** — single fixes on demand when the app is foregrounded.
//   - Every fix passes the same filter on every platform ([addFix]): an
//     accuracy gate that degrades instead of failing, the GPS interval, a
//     movement threshold that scales with the reported accuracy, and removal
//     of out-and-back spikes.
//   - Track simplification (Douglas-Peucker) runs at finalization time.
//
// All position handling is done in WGS84 (EPSG:4326).
// =============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/gps_fix_stream.dart';
import '../../core/services/location_service.dart';
import '../../shared/models/gps_point.dart';

/// Tracks GPS position during a survey and maintains the track + distance.
class SurveyGpsTracker {
  SurveyGpsTracker({this.intervalSeconds = 10});

  /// Minimum interval between position updates (seconds).
  ///
  /// Android applies it at the provider, so the receiver can sleep between
  /// fixes. iOS has no such request; [addFix] enforces it for every platform.
  ///
  /// No distance filter is requested from any provider: [addFix] applies the
  /// movement threshold itself, and it needs the fixes of a stationary
  /// observer to confirm a held point and to tell "standing still" from
  /// "no good fix anymore".
  final int intervalSeconds;

  /// Accumulated GPS track.
  final List<GpsPoint> track = [];

  /// Total distance walked in meters.
  double distanceMeters = 0;

  /// Latest accepted fix (for tagging detections).
  ///
  /// Includes fixes too close to [track]'s last point to be recorded, so a
  /// stationary observer still gets the freshest height, and fixes too coarse
  /// for a track when nothing better is available; speed outliers are
  /// excluded. Not age-gated: the exported fix time lets consumers judge
  /// staleness.
  GpsPoint? get lastPoint => _latestFix;

  GpsPoint? _latestFix;

  StreamSubscription<Object?>? _positionSub;

  /// Whether the tracker is actively listening to GPS.
  bool get isTracking => _positionSub != null;

  /// Called whenever a new GPS point is recorded.
  void Function(GpsPoint point)? onPoint;

  /// Pre-populate the track with points from an existing session (resume).
  ///
  /// Also recalculates total distance so the tracker continues seamlessly.
  void seedTrack(List<GpsPoint> existingTrack) {
    track
      ..clear()
      ..addAll(existingTrack);
    _latestFix = track.where((point) => point.measured).lastOrNull;
    _pending = null;
    _lastAcceptedTime = null;
    _lastTrackQualityTime = null;
    _speedOutliers = 0;
    distanceMeters = 0;
    for (var i = 1; i < track.length; i++) {
      distanceMeters += const Distance().as(
        LengthUnit.Meter,
        LatLng(track[i - 1].latitude, track[i - 1].longitude),
        LatLng(track[i].latitude, track[i].longitude),
      );
    }
    debugPrint(
      '[SurveyGpsTracker] seeded ${track.length} points, '
      '${distanceMeters.toStringAsFixed(0)} m',
    );
  }

  /// Start continuous GPS tracking.
  Future<void> startTracking() async {
    if (_positionSub != null) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      late final StreamSubscription<GpsPoint> sub;
      sub = androidGpsFixes(interval: Duration(seconds: intervalSeconds))
          .listen(
            addFix,
            onError: (Object error, StackTrace stackTrace) {
              // Precise location not granted, or the provider is missing or
              // off. Geolocator still delivers whatever the device can.
              debugPrint('[SurveyGpsTracker] gps provider unavailable: $error');
              if (!identical(_positionSub, sub)) return;
              _positionSub = null;
              _startGeolocatorStream();
            },
            cancelOnError: true,
          );
      _positionSub = sub;
    } else {
      _startGeolocatorStream();
    }

    debugPrint(
      '[SurveyGpsTracker] tracking started (interval=${intervalSeconds}s)',
    );
  }

  void _startGeolocatorStream() {
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: buildLocationSettings(
            // `high` is only "nearest ten meters" on iOS, which lets Core
            // Location answer from Wi-Fi and cell positions.
            accuracy: LocationAccuracy.best,
            intervalDuration: Duration(seconds: intervalSeconds),
            background: true,
          ),
        ).listen(
          (position) => addFix(_positionToGpsPoint(position, measured: true)),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('[SurveyGpsTracker] position stream error: $error');
            _positionSub = null;
          },
          onDone: () {
            debugPrint('[SurveyGpsTracker] position stream ended');
            _positionSub = null;
          },
          cancelOnError: true,
        );
  }

  /// Record a single GPS fix (for manual GPS mode).
  Future<GpsPoint?> captureOnce() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: buildLocationSettings(
          timeLimit: const Duration(seconds: 10),
        ),
      );
      final point = _positionToGpsPoint(position, measured: true);
      _addSingleFix(point);
      return point;
    } catch (e) {
      debugPrint('[SurveyGpsTracker] captureOnce failed: $e');
      return null;
    }
  }

  /// Stop GPS tracking.
  Future<void> stopTracking() async {
    final positionSub = _positionSub;
    _positionSub = null;
    if (positionSub != null) {
      try {
        await positionSub.cancel().timeout(const Duration(seconds: 2));
      } on TimeoutException {
        debugPrint('[SurveyGpsTracker] position stream stop timed out');
      } catch (error) {
        debugPrint('[SurveyGpsTracker] position stream stop failed: $error');
      }
    }
    // No later fix will confirm the held point; keep it.
    _commitPending();
    debugPrint(
      '[SurveyGpsTracker] tracking stopped '
      '(${track.length} points, ${distanceMeters.toStringAsFixed(0)} m)',
    );
  }

  /// Simplify the track using Douglas-Peucker algorithm.
  ///
  /// Call after survey finalization to reduce JSON size.
  /// [toleranceMeters] controls simplification aggressiveness.
  void simplifyTrack({double toleranceMeters = 10}) {
    if (track.length < 3) return;
    final simplified = _douglasPeucker(track, toleranceMeters);
    track
      ..clear()
      ..addAll(simplified);
    debugPrint(
      '[SurveyGpsTracker] track simplified: '
      '${simplified.length} points',
    );
  }

  /// Position at [timestamp], linearly interpolated between the nearest
  /// measured fixes before and after it.
  ///
  /// Outside the track, the first or last measured fix is returned as-is.
  /// An interpolated result has `measured: false`; its height is only set
  /// when both neighbors report one against the same reference surface.
  static GpsPoint? positionAt(List<GpsPoint> track, DateTime timestamp) {
    GpsPoint? before;
    GpsPoint? after;
    for (final p in track) {
      if (!p.measured) continue;
      if (!p.timestamp.isAfter(timestamp)) {
        before = p;
      } else {
        after ??= p;
      }
    }
    if (before == null || after == null) return before ?? after;

    final totalMs = after.timestamp.difference(before.timestamp).inMilliseconds;
    if (totalMs <= 0 || before.timestamp == timestamp) return before;
    final fraction =
        timestamp.difference(before.timestamp).inMilliseconds / totalMs;
    double lerp(double a, double b) => a + (b - a) * fraction;

    final hasHeight =
        before.altitude != null &&
        after.altitude != null &&
        before.altitudeReference == after.altitudeReference;
    final beforeAccuracy = before.altitudeAccuracy;
    final afterAccuracy = after.altitudeAccuracy;
    return GpsPoint(
      latitude: lerp(before.latitude, after.latitude),
      longitude: lerp(before.longitude, after.longitude),
      timestamp: timestamp,
      altitude: hasHeight ? lerp(before.altitude!, after.altitude!) : null,
      // Report the looser of the two uncertainties.
      altitudeAccuracy:
          hasHeight && beforeAccuracy != null && afterAccuracy != null
          ? math.max(beforeAccuracy, afterAccuracy)
          : null,
      altitudeReference: hasHeight ? before.altitudeReference : null,
      measured: false,
    );
  }

  // ── Private ─────────────────────────────────────────────────────────────

  /// Fixes at least this accurate make a track on their own.
  static const double _trackAccuracyMeters = 20.0;

  /// Fixes worse than this never enter the track (approximate location,
  /// cell-only positions); they only tag detections.
  static const double _coarseAccuracyMeters = 100.0;

  /// How long a track-quality fix keeps worse ones out. After that the
  /// track continues with what the device still delivers, so a walk under
  /// dense canopy or with imprecise location is sparse instead of empty.
  static const Duration _degradeAfter = Duration(seconds: 60);

  /// Minimum distance (meters) a new point must be from the last one to be
  /// added to the track. A fix's own accuracy raises it, so standing still
  /// with a noisy signal does not draw a scribble.
  static const double _minMoveMeters = 5.0;

  /// Maximum plausible speed in meters per second.
  /// Points implying faster movement are treated as GPS jumps and discarded.
  /// 30 km/h ≈ 8.3 m/s — generous for walking/birding surveys.
  static const double _maxSpeedMps = 8.3;

  /// This many speed outliers in a row mean the point they are measured
  /// from is the wrong one, not the fixes.
  static const int _maxSpeedOutliers = 3;

  /// A fix that moved, held until the next one shows it was not a spike.
  GpsPoint? _pending;

  DateTime? _lastAcceptedTime;

  /// Time of the last track-quality fix, or of the first fix of any quality
  /// while none has arrived yet, so a receiver that is still acquiring gets
  /// the same wait before a worse fix may start the track.
  DateTime? _lastTrackQualityTime;

  int _speedOutliers = 0;

  /// Run one fix of the continuous stream through the track filter.
  ///
  /// A fix that moved is held back until the next fix arrives, so [track]
  /// trails the stream by one fix; [lastPoint] does not.
  @visibleForTesting
  void addFix(GpsPoint fix) {
    // Accuracy gate. A fix without a reported accuracy is taken as is.
    final accuracy = fix.accuracy;
    if (accuracy != null && accuracy > _trackAccuracyMeters) {
      final since = fix.timestamp.difference(
        _lastTrackQualityTime ??= fix.timestamp,
      );
      if (since.isNegative) {
        // The earlier fix carried a time from the future (receiver date
        // glitch); start the wait over rather than block until then.
        _lastTrackQualityTime = fix.timestamp;
      }
      if (since < _degradeAfter) {
        // Better than no position at all for tagging detections.
        _latestFix ??= fix;
        return;
      }
      if (accuracy > _coarseAccuracyMeters) {
        if (_coarseFixReplaces(_latestFix, fix)) _latestFix = fix;
        return;
      }
    } else {
      _lastTrackQualityTime = fix.timestamp;
    }

    // GPS interval. Providers deliver slightly early, hence the tolerance.
    // A fix older than the last accepted one means that one was stamped in
    // the future; it must not hold back everything after it.
    final lastAccepted = _lastAcceptedTime;
    if (lastAccepted != null) {
      final elapsedMs = fix.timestamp.difference(lastAccepted).inMilliseconds;
      final toleranceMs = math.min(1500, intervalSeconds * 200);
      if (elapsedMs >= 0 && elapsedMs < intervalSeconds * 1000 - toleranceMs) {
        return;
      }
    }
    _lastAcceptedTime = fix.timestamp;

    _consider(fix);
  }

  void _consider(GpsPoint fix) {
    final anchor = _pending ?? track.lastOrNull;
    if (anchor == null) {
      // Nothing to compare the first fix against; show it right away.
      _latestFix = fix;
      _commit(fix);
      return;
    }

    final d = _distance(anchor, fix);
    if (d < math.max(_minMoveMeters, fix.accuracy ?? 0)) {
      // A second fix in the same place confirms a held point.
      _latestFix = fix;
      _speedOutliers = 0;
      _commitPending();
      return;
    }
    if (_isSpeedOutlier(anchor, fix, d)) {
      // A lone jump is skipped. A run of them is where the device really is.
      if (++_speedOutliers < _maxSpeedOutliers) return;
    }
    _speedOutliers = 0;

    final pending = _pending;
    if (pending != null) {
      if (_isSpike(track.last, pending, fix)) {
        debugPrint(
          '[SurveyGpsTracker] dropping spike '
          '(${_distance(track.last, pending).toStringAsFixed(0)} m out and back)',
        );
        _pending = null;
        _consider(fix);
        return;
      }
      _commitPending();
    }
    _latestFix = fix;
    _pending = fix;
  }

  /// A manual fix has no following fix to confirm it; record it directly.
  void _addSingleFix(GpsPoint fix) {
    _commitPending();
    final last = track.lastOrNull;
    if (last != null) {
      final d = _distance(last, fix);
      if (d < math.max(_minMoveMeters, fix.accuracy ?? 0)) {
        _latestFix = fix;
        return;
      }
      if (_isSpeedOutlier(last, fix, d)) return;
    }
    _latestFix = fix;
    if ((fix.accuracy ?? 0) > _coarseAccuracyMeters) return;
    _commit(fix);
  }

  /// Whether a fix too coarse for the track should still become the
  /// position detections are tagged with. It replaces a more accurate one
  /// only when that one lies outside the coarse fix's own uncertainty, which
  /// is evidence of having moved rather than of a worse signal.
  static bool _coarseFixReplaces(GpsPoint? current, GpsPoint coarse) {
    if (current == null) return true;
    final currentAccuracy = current.accuracy;
    final coarseAccuracy = coarse.accuracy ?? 0;
    if (currentAccuracy != null && currentAccuracy >= coarseAccuracy) {
      return true;
    }
    return _distance(current, coarse) > coarseAccuracy;
  }

  /// Whether [b] left the path only to come straight back: [c] ends up much
  /// closer to [a] than [b] ever was to either. A real about-turn within one
  /// GPS interval looks the same and loses its tip, which costs less than
  /// keeping every position jump.
  static bool _isSpike(GpsPoint a, GpsPoint b, GpsPoint c) {
    final out = _distance(a, b);
    final back = _distance(b, c);
    return _distance(a, c) < 0.5 * math.min(out, back);
  }

  bool _isSpeedOutlier(GpsPoint from, GpsPoint to, double meters) {
    final seconds =
        to.timestamp.difference(from.timestamp).inMilliseconds / 1000.0;
    if (seconds <= 0 || meters / seconds <= _maxSpeedMps) return false;
    debugPrint(
      '[SurveyGpsTracker] skipping speed outlier '
      '(${(meters / seconds).toStringAsFixed(1)} m/s over '
      '${meters.toStringAsFixed(0)} m)',
    );
    return true;
  }

  void _commitPending() {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    _commit(pending);
  }

  void _commit(GpsPoint point) {
    if (track.isNotEmpty) distanceMeters += _distance(track.last, point);
    track.add(point);
    onPoint?.call(point);
  }

  static double _distance(GpsPoint a, GpsPoint b) => const Distance().as(
    LengthUnit.Meter,
    LatLng(a.latitude, a.longitude),
    LatLng(b.latitude, b.longitude),
  );

  GpsPoint _positionToGpsPoint(Position position, {required bool measured}) {
    final location = AppLocation.fromPosition(position);
    return GpsPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: location.altitude,
      altitudeAccuracy: location.altitudeAccuracy,
      altitudeReference: location.altitudeReference,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      measured: measured,
    );
  }

  /// Douglas-Peucker polyline simplification.
  static List<GpsPoint> _douglasPeucker(
    List<GpsPoint> points,
    double toleranceMeters,
  ) {
    if (points.length < 3) return List.of(points);

    // Find the point with the maximum perpendicular distance.
    double maxDist = 0;
    int maxIndex = 0;
    final first = points.first;
    final last = points.last;

    for (var i = 1; i < points.length - 1; i++) {
      final d = math.max(
        _perpendicularDistance(points[i], first, last),
        _verticalDeviation(points[i], first, last),
      );
      if (d > maxDist) {
        maxDist = d;
        maxIndex = i;
      }
    }

    if (maxDist > toleranceMeters) {
      final left = _douglasPeucker(
        points.sublist(0, maxIndex + 1),
        toleranceMeters,
      );
      final right = _douglasPeucker(points.sublist(maxIndex), toleranceMeters);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [first, last];
    }
  }

  /// Preserve significant changes in height even on an almost straight path.
  static double _verticalDeviation(
    GpsPoint point,
    GpsPoint start,
    GpsPoint end,
  ) {
    if (point.altitude == null ||
        start.altitude == null ||
        end.altitude == null ||
        point.altitudeReference != start.altitudeReference ||
        point.altitudeReference != end.altitudeReference) {
      return 0;
    }
    final duration = end.timestamp.difference(start.timestamp).inMilliseconds;
    if (duration <= 0) return 0;
    final fraction =
        point.timestamp.difference(start.timestamp).inMilliseconds / duration;
    final expected =
        start.altitude! + (end.altitude! - start.altitude!) * fraction;
    final uncertainty = point.altitudeAccuracy ?? 0;
    return math.max(0, (point.altitude! - expected).abs() - uncertainty);
  }

  /// Approximate perpendicular distance from a point to a line segment
  /// (using flat-Earth approximation, acceptable at GPS scales).
  static double _perpendicularDistance(
    GpsPoint point,
    GpsPoint lineStart,
    GpsPoint lineEnd,
  ) {
    // Convert to meters using rough latitude scaling.
    const metersPerDeg = 111320.0;
    final cosLat = math.cos(point.latitude * math.pi / 180);

    final x = (point.longitude - lineStart.longitude) * metersPerDeg * cosLat;
    final y = (point.latitude - lineStart.latitude) * metersPerDeg;
    final x1 =
        (lineEnd.longitude - lineStart.longitude) * metersPerDeg * cosLat;
    final y1 = (lineEnd.latitude - lineStart.latitude) * metersPerDeg;

    final lineLen = math.sqrt(x1 * x1 + y1 * y1);
    if (lineLen == 0) return math.sqrt(x * x + y * y);

    return (x * y1 - y * x1).abs() / lineLen;
  }
}
