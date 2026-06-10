// =============================================================================
// Survey GPS Tracker — Periodic GPS logging for survey transects
// =============================================================================
//
// Wraps [geolocator] to provide a stream of GPS positions during a survey.
//
//   - Appends [GpsPoint] entries to the session's GPS track.
//   - Computes cumulative distance walked (Haversine via [latlong2]).
//   - Operates in two modes:
//       * **Background GPS** — continuous stream via getPositionStream().
//       * **Manual GPS** — single fixes on demand when the app is foregrounded.
//   - Track simplification (Douglas-Peucker) runs at finalization time.
//
// All position handling is done in WGS84 (EPSG:4326).
// =============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../shared/models/gps_point.dart';

/// Tracks GPS position during a survey and maintains the track + distance.
class SurveyGpsTracker {
  SurveyGpsTracker({this.intervalSeconds = 10, this.distanceFilterMeters = 5});

  /// Minimum interval between position updates (seconds).
  final int intervalSeconds;

  /// Minimum distance change to register a new point (meters).
  final int distanceFilterMeters;

  /// Accumulated GPS track.
  final List<GpsPoint> track = [];

  /// Total distance walked in meters.
  double distanceMeters = 0;

  /// Latest position (for tagging detections).
  GpsPoint? get lastPoint => track.isEmpty ? null : track.last;

  StreamSubscription<Position>? _positionSub;

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

    late final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        intervalDuration: Duration(seconds: intervalSeconds),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      );
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPosition,
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

    debugPrint(
      '[SurveyGpsTracker] tracking started '
      '(interval=${intervalSeconds}s, filter=${distanceFilterMeters}m)',
    );
  }

  /// Record a single GPS fix (for manual GPS mode).
  Future<GpsPoint?> captureOnce() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final point = _positionToGpsPoint(position, measured: true);
      _addPoint(point);
      return point;
    } catch (e) {
      debugPrint('[SurveyGpsTracker] captureOnce failed: $e');
      return null;
    }
  }

  /// Stop GPS tracking.
  Future<void> stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
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

  /// Interpolate detection locations between measured GPS points.
  ///
  /// For detections that have no GPS fix, linearly interpolate between
  /// the nearest preceding and following measured points.
  static void interpolateDetectionLocations({
    required List<GpsPoint> measuredTrack,
    required List<({DateTime timestamp, double? lat, double? lon})> detections,
    required void Function(int index, double lat, double lon) onInterpolated,
  }) {
    if (measuredTrack.isEmpty) return;

    for (var i = 0; i < detections.length; i++) {
      final det = detections[i];
      if (det.lat != null && det.lon != null) continue;

      // Find bracketing measured points.
      GpsPoint? before;
      GpsPoint? after;
      for (final p in measuredTrack) {
        if (!p.measured) continue;
        if (!p.timestamp.isAfter(det.timestamp)) {
          before = p;
        } else {
          after ??= p;
        }
      }

      if (before != null && after != null) {
        final totalMs =
            after.timestamp.difference(before.timestamp).inMilliseconds;
        if (totalMs > 0) {
          final fraction =
              det.timestamp.difference(before.timestamp).inMilliseconds /
              totalMs;
          final lat =
              before.latitude + (after.latitude - before.latitude) * fraction;
          final lon =
              before.longitude +
              (after.longitude - before.longitude) * fraction;
          onInterpolated(i, lat, lon);
        }
      } else if (before != null) {
        // After the last known point — use last position.
        onInterpolated(i, before.latitude, before.longitude);
      } else if (after != null) {
        // Before the first known point — use first position.
        onInterpolated(i, after.latitude, after.longitude);
      }
    }
  }

  // ── Private ─────────────────────────────────────────────────────────────

  void _onPosition(Position position) {
    // Reject fixes with very poor horizontal accuracy — these are typically
    // indoor or heavily obstructed readings that introduce large jitter.
    if (position.accuracy > _maxAccuracyMeters) {
      debugPrint(
        '[SurveyGpsTracker] skipping low-accuracy fix '
        '(${position.accuracy.toStringAsFixed(0)} m)',
      );
      return;
    }
    final point = _positionToGpsPoint(position, measured: true);
    _addPoint(point);
  }

  /// Reject GPS fixes with horizontal accuracy worse than this (meters).
  static const double _maxAccuracyMeters = 30.0;

  /// Minimum distance (meters) a new point must be from the last recorded
  /// point to be added to the track.  Eliminates GPS jitter when standing.
  static const double _jitterThresholdMeters = 5.0;

  /// Maximum plausible speed in meters per second.
  /// Points implying faster movement are treated as GPS jumps and discarded.
  /// 30 km/h ≈ 8.3 m/s — generous for walking/birding surveys.
  static const double _maxSpeedMps = 8.3;

  void _addPoint(GpsPoint point) {
    if (track.isNotEmpty) {
      final prev = track.last;
      final d = const Distance().as(
        LengthUnit.Meter,
        LatLng(prev.latitude, prev.longitude),
        LatLng(point.latitude, point.longitude),
      );
      // Skip points that are within jitter distance.
      if (d < _jitterThresholdMeters) return;

      // Speed gate: reject implausible jumps.
      final dtSeconds =
          point.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
      if (dtSeconds > 0 && d / dtSeconds > _maxSpeedMps) {
        debugPrint(
          '[SurveyGpsTracker] skipping speed outlier '
          '(${(d / dtSeconds).toStringAsFixed(1)} m/s over '
          '${d.toStringAsFixed(0)} m)',
        );
        return;
      }

      distanceMeters += d;
    }
    track.add(point);
    onPoint?.call(point);
  }

  GpsPoint _positionToGpsPoint(Position position, {required bool measured}) {
    return GpsPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
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
      final d = _perpendicularDistance(points[i], first, last);
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
