// =============================================================================
// GpsPoint Tests — Serialization and equality
// =============================================================================

import 'package:birdnet_live/shared/models/gps_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ts = DateTime.utc(2025, 7, 1, 12, 0, 0);

  group('GpsPoint', () {
    test('roundtrips through JSON', () {
      final point = GpsPoint(
        latitude: 52.52,
        longitude: 13.405,
        altitude: 34.5,
        accuracy: 4.2,
        timestamp: ts,
      );

      final json = point.toJson();
      final restored = GpsPoint.fromJson(json);

      expect(restored.latitude, 52.52);
      expect(restored.longitude, 13.405);
      expect(restored.altitude, 34.5);
      expect(restored.accuracy, 4.2);
      expect(restored.timestamp, ts);
      expect(restored.measured, isTrue);
    });

    test('compact JSON keys', () {
      final point = GpsPoint(latitude: 52.52, longitude: 13.405, timestamp: ts);

      final json = point.toJson();
      expect(json.containsKey('lat'), isTrue);
      expect(json.containsKey('lon'), isTrue);
      expect(json.containsKey('t'), isTrue);
      // Optional fields omitted when null.
      expect(json.containsKey('alt'), isFalse);
      expect(json.containsKey('acc'), isFalse);
      // measured=true is omitted (default).
      expect(json.containsKey('m'), isFalse);
    });

    test('interpolated flag roundtrips', () {
      final point = GpsPoint(
        latitude: 52.52,
        longitude: 13.405,
        timestamp: ts,
        measured: false,
      );

      final json = point.toJson();
      expect(json['m'], isFalse);

      final restored = GpsPoint.fromJson(json);
      expect(restored.measured, isFalse);
    });

    test('equality by lat/lon/timestamp', () {
      final a = GpsPoint(latitude: 52.52, longitude: 13.405, timestamp: ts);
      final b = GpsPoint(
        latitude: 52.52,
        longitude: 13.405,
        timestamp: ts,
        altitude: 100,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when coordinates differ', () {
      final a = GpsPoint(latitude: 52.52, longitude: 13.405, timestamp: ts);
      final b = GpsPoint(latitude: 52.53, longitude: 13.405, timestamp: ts);

      expect(a, isNot(equals(b)));
    });

    test('toString includes measured/interpolated', () {
      final measured = GpsPoint(
        latitude: 52.52,
        longitude: 13.405,
        timestamp: ts,
      );
      final interp = GpsPoint(
        latitude: 52.52,
        longitude: 13.405,
        timestamp: ts,
        measured: false,
      );

      expect(measured.toString(), contains('measured'));
      expect(interp.toString(), contains('interpolated'));
    });
  });
}
