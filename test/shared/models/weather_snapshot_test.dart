import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/shared/models/weather_snapshot.dart';

void main() {
  group('WeatherSnapshot serialization', () {
    test('round-trips full payload through toJson and fromJson', () {
      final snapshot = WeatherSnapshot(
        fetchedAt: DateTime.utc(2026, 5, 28, 10, 0, 0),
        observedAt: DateTime.utc(2026, 5, 28, 9, 0, 0),
        temperatureC: 12.5,
        precipitationMm: 0.3,
        windSpeedMs: 3.2,
        windDirectionDeg: 180.0,
        cloudCoverPercent: 75,
        weatherCode: 61,
      );

      final parsed = WeatherSnapshot.fromJson(snapshot.toJson());

      expect(parsed, isNotNull);
      expect(parsed!.fetchedAt, snapshot.fetchedAt);
      expect(parsed.observedAt, snapshot.observedAt);
      expect(parsed.temperatureC, snapshot.temperatureC);
      expect(parsed.precipitationMm, snapshot.precipitationMm);
      expect(parsed.windSpeedMs, snapshot.windSpeedMs);
      expect(parsed.windDirectionDeg, snapshot.windDirectionDeg);
      expect(parsed.cloudCoverPercent, snapshot.cloudCoverPercent);
      expect(parsed.weatherCode, snapshot.weatherCode);
    });

    test('omits nullable fields from toJson when values are missing', () {
      final snapshot = WeatherSnapshot(
        fetchedAt: DateTime.utc(2026, 5, 28, 10, 0, 0),
      );

      final json = snapshot.toJson();

      expect(json.containsKey('fetchedAt'), isTrue);
      expect(json.containsKey('observedAt'), isFalse);
      expect(json.containsKey('temperatureC'), isFalse);
      expect(json.containsKey('weatherCode'), isFalse);
    });
  });

  group('WeatherSnapshot.fromJson', () {
    test('returns null for non-map payloads', () {
      expect(WeatherSnapshot.fromJson(null), isNull);
      expect(WeatherSnapshot.fromJson('invalid'), isNull);
      expect(WeatherSnapshot.fromJson(123), isNull);
    });

    test('returns null when fetchedAt is missing or invalid', () {
      expect(WeatherSnapshot.fromJson(const <String, dynamic>{}), isNull);
      expect(
        WeatherSnapshot.fromJson(const <String, dynamic>{'fetchedAt': 42}),
        isNull,
      );
      expect(
        WeatherSnapshot.fromJson(
          const <String, dynamic>{'fetchedAt': 'not-a-date'},
        ),
        isNull,
      );
    });

    test('coerces numeric values from int and double inputs', () {
      final parsed = WeatherSnapshot.fromJson(const <String, dynamic>{
        'fetchedAt': '2026-05-28T10:00:00Z',
        'temperatureC': 10,
        'precipitationMm': 1,
        'windSpeedMs': 2,
        'windDirectionDeg': 270,
        'cloudCoverPercent': 80.9,
        'weatherCode': 95.7,
      });

      expect(parsed, isNotNull);
      expect(parsed!.temperatureC, 10.0);
      expect(parsed.precipitationMm, 1.0);
      expect(parsed.windSpeedMs, 2.0);
      expect(parsed.windDirectionDeg, 270.0);
      expect(parsed.cloudCoverPercent, 80);
      expect(parsed.weatherCode, 95);
    });
  });
}
