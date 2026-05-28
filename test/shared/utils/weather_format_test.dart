import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/shared/models/weather_snapshot.dart';
import 'package:birdnet_live/shared/utils/weather_format.dart';

void main() {
  group('weatherConditionFromCode', () {
    test('maps supported weather buckets', () {
      expect(weatherConditionFromCode(0), WeatherCondition.clear);
      expect(weatherConditionFromCode(2), WeatherCondition.partlyCloudy);
      expect(weatherConditionFromCode(3), WeatherCondition.cloudy);
      expect(weatherConditionFromCode(45), WeatherCondition.fog);
      expect(weatherConditionFromCode(53), WeatherCondition.drizzle);
      expect(weatherConditionFromCode(61), WeatherCondition.rain);
      expect(weatherConditionFromCode(71), WeatherCondition.snow);
      expect(weatherConditionFromCode(95), WeatherCondition.thunder);
    });

    test('returns unknown for null or unsupported codes', () {
      expect(weatherConditionFromCode(null), WeatherCondition.unknown);
      expect(weatherConditionFromCode(999), WeatherCondition.unknown);
    });
  });

  group('compassFromBearing', () {
    test('normalizes negatives and wraps values above 360', () {
      expect(compassFromBearing(-1), 'N');
      expect(compassFromBearing(361), 'N');
    });

    test('maps common quadrants', () {
      expect(compassFromBearing(45), 'NE');
      expect(compassFromBearing(180), 'S');
      expect(compassFromBearing(270), 'W');
    });
  });

  group('format helpers', () {
    test('formatWind includes compass when direction exists', () {
      expect(formatWind(3.25, 225), '3.3 m/s SW');
    });

    test('formatWeatherCompactStats uses available values only', () {
      final snapshot = WeatherSnapshot(
        fetchedAt: DateTime(2026, 1, 1),
        temperatureC: 20.12,
        windSpeedMs: 3.24,
        windDirectionDeg: 180,
      );

      expect(formatWeatherCompactStats(snapshot), '20.1 °C · 3.2 m/s S');
    });

    test('formatWeatherOneLine includes condition label and wind', () {
      final snapshot = WeatherSnapshot(
        fetchedAt: DateTime(2026, 1, 1),
        temperatureC: 8.2,
        weatherCode: 61,
        windSpeedMs: 1.0,
        windDirectionDeg: 0,
      );

      final line = formatWeatherOneLine(snapshot, (cond) {
        if (cond == WeatherCondition.rain) return 'Rain';
        return 'Other';
      });

      expect(line, '8.2 °C · Rain · 1.0 m/s N');
    });
  });
}
