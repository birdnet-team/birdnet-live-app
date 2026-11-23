// =============================================================================
// Survey GPS Tracker Tests — track filter and Android gps-provider fixes
// =============================================================================

import 'dart:math' as math;

import 'package:birdnet_live/core/services/gps_fix_stream.dart';
import 'package:birdnet_live/features/survey/survey_gps_tracker.dart';
import 'package:birdnet_live/shared/models/altitude_reference.dart';
import 'package:birdnet_live/shared/models/gps_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2025, 7, 1, 8);
  const baseLat = 52.52;
  const baseLon = 13.405;
  const metersPerDegree = 111320.0;

  /// A fix [north]/[east] meters from the base, [seconds] after the start.
  GpsPoint fix(
    int seconds, {
    double north = 0,
    double east = 0,
    double? accuracy = 4,
  }) {
    return GpsPoint(
      latitude: baseLat + north / metersPerDegree,
      longitude:
          baseLon +
          east / (metersPerDegree * math.cos(baseLat * math.pi / 180)),
      accuracy: accuracy,
      timestamp: start.add(Duration(seconds: seconds)),
    );
  }

  test('the first fix is recorded right away', () {
    final tracker = SurveyGpsTracker();
    final recorded = <GpsPoint>[];
    tracker.onPoint = recorded.add;

    tracker.addFix(fix(0));

    expect(tracker.track, hasLength(1));
    expect(recorded, hasLength(1));
    expect(tracker.lastPoint, same(tracker.track.single));
  });

  test('a steady walk is kept, one fix behind until tracking stops', () async {
    final tracker = SurveyGpsTracker();
    for (var i = 0; i <= 5; i++) {
      tracker.addFix(fix(i * 10, north: i * 13.0));
    }

    expect(tracker.track, hasLength(5));
    // The newest fix still tags detections while it waits for confirmation.
    expect(
      tracker.lastPoint!.timestamp,
      start.add(const Duration(seconds: 50)),
    );

    await tracker.stopTracking();
    expect(tracker.track, hasLength(6));
    expect(tracker.distanceMeters, closeTo(65, 1));
  });

  test('an out-and-back position jump is dropped', () async {
    final tracker = SurveyGpsTracker();
    tracker.addFix(fix(0));
    tracker.addFix(fix(10, north: 13));
    tracker.addFix(fix(20, north: 26, east: 70)); // the jump
    tracker.addFix(fix(30, north: 39));
    tracker.addFix(fix(40, north: 52));
    await tracker.stopTracking();

    expect(tracker.track, hasLength(4));
    expect(tracker.distanceMeters, closeTo(52, 1));
  });

  test('a right-angle turn is not mistaken for a jump', () async {
    final tracker = SurveyGpsTracker();
    tracker.addFix(fix(0));
    tracker.addFix(fix(10, north: 13));
    tracker.addFix(fix(20, north: 13, east: 13));
    tracker.addFix(fix(30, north: 13, east: 26));
    await tracker.stopTracking();

    expect(tracker.track, hasLength(4));
  });

  test('standing still with a noisy signal adds no points', () async {
    final tracker = SurveyGpsTracker();
    const wander = [
      [0.0, 0.0],
      [9.0, -6.0],
      [-8.0, 7.0],
      [11.0, 4.0],
      [-5.0, -10.0],
    ];
    for (var i = 0; i < wander.length; i++) {
      tracker.addFix(
        fix(i * 10, north: wander[i][0], east: wander[i][1], accuracy: 15),
      );
    }
    await tracker.stopTracking();

    expect(tracker.track, hasLength(1));
    expect(tracker.distanceMeters, 0);
    expect(
      tracker.lastPoint!.timestamp,
      start.add(const Duration(seconds: 40)),
    );
  });

  test('a fix that implies an impossible speed is skipped', () async {
    final tracker = SurveyGpsTracker();
    tracker.addFix(fix(0));
    tracker.addFix(fix(10, north: 300));
    await tracker.stopTracking();

    expect(tracker.track, hasLength(1));
    expect(tracker.lastPoint!.timestamp, start);
  });

  test('a run of speed outliers moves the track to where they are', () async {
    final tracker = SurveyGpsTracker();
    tracker.addFix(fix(0));
    for (var i = 1; i <= 4; i++) {
      tracker.addFix(fix(i * 10, north: 3000, east: i * 13.0));
    }
    await tracker.stopTracking();

    expect(tracker.track.length, greaterThan(1));
    expect(
      tracker.lastPoint!.timestamp,
      start.add(const Duration(seconds: 40)),
    );
  });

  test('a fix in the same place records the held point', () {
    final tracker = SurveyGpsTracker();
    final recorded = <GpsPoint>[];
    tracker.onPoint = recorded.add;
    tracker.addFix(fix(0));
    tracker.addFix(fix(10, north: 13));
    expect(recorded, hasLength(1));

    tracker.addFix(fix(20, north: 14));

    expect(recorded, hasLength(2));
    expect(tracker.distanceMeters, closeTo(13, 0.5));
  });

  test('a fix stamped in the future does not stall the track', () async {
    final tracker = SurveyGpsTracker();
    tracker.addFix(fix(0));
    tracker.addFix(fix(10, north: 13));
    tracker.addFix(fix(86400, north: 26));
    for (var i = 3; i <= 8; i++) {
      tracker.addFix(fix(i * 10, north: i * 13.0));
    }
    await tracker.stopTracking();

    expect(tracker.track.length, greaterThanOrEqualTo(7));
    expect(
      tracker.lastPoint!.timestamp,
      start.add(const Duration(seconds: 80)),
    );
  });

  test('fixes arriving faster than the GPS interval are thinned', () async {
    final tracker = SurveyGpsTracker(intervalSeconds: 10);
    for (var s = 0; s <= 40; s += 2) {
      tracker.addFix(fix(s, north: s * 1.3));
    }
    await tracker.stopTracking();

    expect(tracker.track, hasLength(5));
  });

  group('accuracy', () {
    test('a worse fix is ignored while a good one is recent', () async {
      final tracker = SurveyGpsTracker();
      tracker.addFix(fix(0));
      tracker.addFix(fix(10, north: 60, accuracy: 45));
      await tracker.stopTracking();

      expect(tracker.track, hasLength(1));
      expect(tracker.lastPoint!.timestamp, start);
    });

    test('the track continues with worse fixes once good ones stop', () async {
      final tracker = SurveyGpsTracker();
      tracker.addFix(fix(0));
      tracker.addFix(fix(70, north: 90, accuracy: 45));
      tracker.addFix(fix(140, north: 180, accuracy: 45));
      await tracker.stopTracking();

      expect(tracker.track, hasLength(3));
    });

    test('imprecise fixes alone still make a sparse track', () async {
      final tracker = SurveyGpsTracker();
      // The first minute is left for a better fix to arrive. After that,
      // under 30 m of movement stays inside the reported 30 m uncertainty.
      for (var i = 0; i <= 9; i++) {
        tracker.addFix(fix(i * 10, north: i * 13.0, accuracy: 30));
      }
      await tracker.stopTracking();

      expect(tracker.track, hasLength(2));
      expect(
        tracker.track.first.timestamp,
        start.add(const Duration(seconds: 60)),
      );
    });

    test('a coarse first fix does not become the track start', () async {
      final tracker = SurveyGpsTracker();
      tracker.addFix(fix(0, east: 60, accuracy: 60));
      // Still tags detections until something better arrives.
      expect(tracker.track, isEmpty);
      expect(tracker.lastPoint!.timestamp, start);

      for (var i = 1; i <= 5; i++) {
        tracker.addFix(fix(i * 10, north: (i - 1) * 13.0));
      }
      await tracker.stopTracking();

      expect(tracker.track, hasLength(5));
      expect(tracker.distanceMeters, closeTo(52, 1));
    });

    test('a coarse fix that agrees with a good one does not replace it', () {
      final tracker = SurveyGpsTracker();
      tracker.addFix(fix(0));
      tracker.addFix(fix(70, north: 400, accuracy: 500));
      expect(tracker.lastPoint!.timestamp, start);

      // Outside its own uncertainty: the device has moved.
      tracker.addFix(fix(140, north: 900, accuracy: 500));
      expect(
        tracker.lastPoint!.timestamp,
        start.add(const Duration(seconds: 140)),
      );
      expect(tracker.track, hasLength(1));
    });

    test('approximate location tags detections but draws no track', () async {
      final tracker = SurveyGpsTracker();
      tracker.addFix(fix(0, accuracy: 2000));
      tracker.addFix(fix(600, north: 1500, accuracy: 2000));
      await tracker.stopTracking();

      expect(tracker.track, isEmpty);
      expect(tracker.distanceMeters, 0);
      expect(
        tracker.lastPoint!.timestamp,
        start.add(const Duration(seconds: 600)),
      );
    });
  });

  group('gpsPointFromFix', () {
    test('maps a full fix and marks the height as ellipsoidal', () {
      final point = gpsPointFromFix({
        'lat': 52.5,
        'lon': 13.4,
        'acc': 3.5,
        'alt': 80.25,
        'vAcc': 2.0,
        't': start.millisecondsSinceEpoch,
      });

      expect(point.latitude, 52.5);
      expect(point.longitude, 13.4);
      expect(point.accuracy, 3.5);
      expect(point.altitude, 80.25);
      expect(point.altitudeAccuracy, 2.0);
      expect(point.altitudeReference, AltitudeReference.wgs84Ellipsoid);
      expect(point.timestamp, start);
      expect(point.measured, isTrue);
    });

    test('leaves height fields empty when the fix has no height', () {
      final point = gpsPointFromFix({
        'lat': 52,
        'lon': 13,
        't': start.millisecondsSinceEpoch,
      });

      expect(point.accuracy, isNull);
      expect(point.altitude, isNull);
      expect(point.altitudeAccuracy, isNull);
      expect(point.altitudeReference, isNull);
    });
  });
}
