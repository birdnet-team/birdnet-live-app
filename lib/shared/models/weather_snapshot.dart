// =============================================================================
// WeatherSnapshot
// =============================================================================
//
// Lightweight, JSON-serializable record of the weather at a session's
// recording site, captured once per session via the Open-Meteo API.
//
// Why this lives separately from [LiveSession]:
//   • Weather is *optional* and *external* — it should never block a
//     session from being saved or replayed offline. Embedding it as a
//     nullable field on [LiveSession] keeps existing serialization
//     stable: legacy sessions deserialize with `weather == null` and
//     keep working unchanged.
//   • All fields except [fetchedAt] are nullable so the model gracefully
//     degrades when Open-Meteo only returns a partial response (or when
//     a future provider exposes a different field set).
//   • [weatherCode] is the WMO weather interpretation code as documented
//     by Open-Meteo (https://open-meteo.com/en/docs#weathervariables).
//     We keep it as an int rather than mapping eagerly to an enum so
//     that newer codes added by WMO can still be persisted without an
//     app update; UI mapping happens in the presentation layer.
// =============================================================================

import 'dart:convert';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.fetchedAt,
    this.observedAt,
    this.temperatureC,
    this.precipitationMm,
    this.windSpeedMs,
    this.windDirectionDeg,
    this.cloudCoverPercent,
    this.weatherCode,
  });

  /// Wall-clock time when the snapshot was retrieved from the provider.
  /// Used to age out stale data and to display "as of …" timestamps.
  final DateTime fetchedAt;

  /// Wall-clock time the weather observation refers to (the closest
  /// hour returned by Open-Meteo). May differ from [fetchedAt] by up
  /// to one hour. Null for legacy snapshots.
  final DateTime? observedAt;

  /// Temperature at 2 m above ground, in degrees Celsius.
  final double? temperatureC;

  /// Precipitation in millimetres for the observation hour.
  final double? precipitationMm;

  /// Wind speed at 10 m above ground, in metres per second.
  final double? windSpeedMs;

  /// Wind direction at 10 m, in degrees clockwise from north.
  final double? windDirectionDeg;

  /// Cloud cover, in percent (0 = clear, 100 = overcast).
  final int? cloudCoverPercent;

  /// WMO weather interpretation code (see Open-Meteo docs).
  final int? weatherCode;

  /// Serialize to a JSON-safe map. Always emits ISO-8601 timestamps so
  /// the snapshot survives a round trip through the session repository.
  Map<String, dynamic> toJson() => {
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    if (observedAt != null) 'observedAt': observedAt!.toUtc().toIso8601String(),
    if (temperatureC != null) 'temperatureC': temperatureC,
    if (precipitationMm != null) 'precipitationMm': precipitationMm,
    if (windSpeedMs != null) 'windSpeedMs': windSpeedMs,
    if (windDirectionDeg != null) 'windDirectionDeg': windDirectionDeg,
    if (cloudCoverPercent != null) 'cloudCoverPercent': cloudCoverPercent,
    if (weatherCode != null) 'weatherCode': weatherCode,
  };

  /// Tolerant JSON deserializer. Returns `null` when the input is null
  /// or unparseable so callers can safely chain
  /// `WeatherSnapshot.fromJson(json['weather'])`.
  static WeatherSnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    final fetchedAtRaw = json['fetchedAt'];
    if (fetchedAtRaw is! String) return null;
    DateTime? parsed;
    try {
      parsed = DateTime.parse(fetchedAtRaw);
    } catch (_) {
      return null;
    }
    return WeatherSnapshot(
      fetchedAt: parsed,
      observedAt: json['observedAt'] is String
          ? DateTime.tryParse(json['observedAt'] as String)
          : null,
      temperatureC: (json['temperatureC'] as num?)?.toDouble(),
      precipitationMm: (json['precipitationMm'] as num?)?.toDouble(),
      windSpeedMs: (json['windSpeedMs'] as num?)?.toDouble(),
      windDirectionDeg: (json['windDirectionDeg'] as num?)?.toDouble(),
      cloudCoverPercent: (json['cloudCoverPercent'] as num?)?.toInt(),
      weatherCode: (json['weatherCode'] as num?)?.toInt(),
    );
  }

  @override
  String toString() => 'WeatherSnapshot(${jsonEncode(toJson())})';
}
