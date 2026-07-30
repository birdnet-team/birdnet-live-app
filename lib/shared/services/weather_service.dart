// =============================================================================
// WeatherService
// =============================================================================
//
// Thin Open-Meteo client used to capture a one-shot [WeatherSnapshot]
// for a session at save time. Open-Meteo is free, key-less, and does
// not require attribution beyond a polite User-Agent header.
//
// Design notes:
//   • This is *fire-and-forget* from the controller's perspective: a
//     network failure must never block saving a session, so every call
//     site wraps the future in a `try/catch` (or simply ignores the
//     null return).
//   • Privacy gate: the [PrefKeys.privacyAllowWeather] toggle is
//     checked on every call. When the user has not consented, this
//     service returns `null` *without* hitting the network.
//   • The lookup picks the hour closest to [observedAt] from the
//     hourly forecast/observation block returned by Open-Meteo, which
//     gives consistent values regardless of whether the session ended
//     a few minutes into a new hour.
//   • A small in-process cache deduplicates repeated lookups for the same
//     coarse cell + hour, while an in-flight request map deduplicates active
//     network calls for the same coarse cell (e.g. setup preview → ready
//     preview → session save at the same site). On top of that, every
//     successful fetch is persisted to [SharedPreferences]
//     under [PrefKeys.weatherCachePrefix] so that a fresh app launch reuses a
//     snapshot observed within ±2 hours at the same coarse cell instead of
//     re-hitting Open-Meteo. The persistent cache is keyed by a 0.1° cell
//     (~10 km) so trips that stay around the same site share one fetch for
//     several sessions. Entries older than 30 days are pruned on each write.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/weather_snapshot.dart';

class WeatherService {
  WeatherService({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final http.Client _client;
  final Map<String, WeatherSnapshot> _cache = {};
  final Map<String, Future<WeatherSnapshot?>> _inFlight = {};

  /// Open-Meteo forecast endpoint. Returns hourly observations for the
  /// current day; we extract the hour closest to [observedAt].
  static const String _endpoint = 'https://api.open-meteo.com/v1/forecast';

  /// Fetches a [WeatherSnapshot] for the given coordinates and time.
  ///
  /// Returns `null` when:
  ///   • the user has not enabled the weather privacy gate,
  ///   • the network request fails, times out, or returns a malformed
  ///     payload, or
  ///   • Open-Meteo returns no hourly data for the requested cell
  ///     (e.g. polar regions outside the model's coverage).
  Future<WeatherSnapshot?> fetch({
    required double latitude,
    required double longitude,
    DateTime? observedAt,
  }) async {
    // Privacy gate.
    final prefs = await SharedPreferences.getInstance();
    final allowed = prefs.getBool(PrefKeys.privacyAllowWeather) ?? false;
    if (!allowed) return null;

    final at = (observedAt ?? DateTime.now()).toUtc();

    // Cache key: 0.1° cell + truncated hour. Open-Meteo's spatial
    // resolution is much coarser than 0.1°, so this is a safe dedupe
    // key without losing meaningful precision.
    final cellLat = (latitude * 10).round() / 10;
    final cellLon = (longitude * 10).round() / 10;
    final hourKey = DateTime.utc(at.year, at.month, at.day, at.hour);
    final cacheKey = '$cellLat,$cellLon,${hourKey.toIso8601String()}';

    // In-process cache check: search for any snapshot for the same cell
    // observed within 2 hours of `at`.
    final cellPrefix = '$cellLat,$cellLon,';
    for (final key in _cache.keys) {
      if (key.startsWith(cellPrefix)) {
        final snap = _cache[key]!;
        final snapObserved = snap.observedAt;
        if (snapObserved != null) {
          final diff = snapObserved.difference(at).abs();
          if (diff <= const Duration(hours: 2)) {
            return snap;
          }
        }
      }
    }

    // Persistent cache check: search for any snapshot for the same cell
    // observed within 2 hours of `at`.
    final cellLatStr = cellLat.toStringAsFixed(1);
    final cellLonStr = cellLon.toStringAsFixed(1);
    final persistentPrefix =
        '${PrefKeys.weatherCachePrefix}${cellLatStr}_${cellLonStr}_';
    final persistentKey = '$persistentPrefix${hourKey.toIso8601String()}';

    final inFlight = _inFlight[persistentKey];
    if (inFlight != null) return inFlight;

    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(persistentPrefix)) {
        final persistedRaw = prefs.getString(key);
        if (persistedRaw != null) {
          try {
            final decoded = json.decode(persistedRaw) as Map<String, dynamic>;
            final snap = WeatherSnapshot.fromJson(decoded);
            if (snap != null) {
              final snapObserved = snap.observedAt;
              if (snapObserved != null) {
                final diff = snapObserved.difference(at).abs();
                if (diff <= const Duration(hours: 2)) {
                  _cache[cacheKey] = snap;
                  return snap;
                }
              }
            }
          } catch (_) {
            // Ignore corrupt cache entries.
          }
        }
      }
    }

    // Determine query parameters and endpoint.
    final daysAgo = DateTime.now().toUtc().difference(at).inDays;
    final Uri uri;
    if (daysAgo > 90) {
      // Historical API
      final dateStr =
          '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
      uri = Uri.parse('https://archive-api.open-meteo.com/v1/archive').replace(
        queryParameters: {
          'latitude': latitude.toStringAsFixed(4),
          'longitude': longitude.toStringAsFixed(4),
          'start_date': dateStr,
          'end_date': dateStr,
          'hourly':
              'temperature_2m,precipitation,wind_speed_10m,'
              'wind_direction_10m,cloud_cover,weather_code',
          'wind_speed_unit': 'ms',
          'timezone': 'UTC',
        },
      );
    } else {
      // Forecast API with dynamic past_days
      final pastDays = (daysAgo + 1).clamp(1, 92);
      uri = Uri.parse(_endpoint).replace(
        queryParameters: {
          'latitude': latitude.toStringAsFixed(4),
          'longitude': longitude.toStringAsFixed(4),
          'hourly':
              'temperature_2m,precipitation,wind_speed_10m,'
              'wind_direction_10m,cloud_cover,weather_code',
          'wind_speed_unit': 'ms',
          'timezone': 'UTC',
          'past_days': pastDays.toString(),
          'forecast_days': '1',
        },
      );
    }

    final request = _fetchAndCache(
      uri: uri,
      at: at,
      cacheKey: cacheKey,
      persistentKey: persistentKey,
      prefs: prefs,
    );
    _inFlight[persistentKey] = request;
    try {
      return await request;
    } finally {
      _inFlight.remove(persistentKey);
    }
  }

  Future<WeatherSnapshot?> _fetchAndCache({
    required Uri uri,
    required DateTime at,
    required String cacheKey,
    required String persistentKey,
    required SharedPreferences prefs,
  }) async {
    try {
      final resp = await _client
          .get(
            uri,
            headers: const {'User-Agent': AppConstants.networkUserAgent},
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final body = json.decode(resp.body) as Map<String, dynamic>;
      final hourly = body['hourly'];
      if (hourly is! Map<String, dynamic>) return null;
      final times = hourly['time'];
      if (times is! List || times.isEmpty) return null;

      // Find the index of the hour closest to `at`.
      var bestIdx = 0;
      var bestDelta = const Duration(days: 365);
      for (var i = 0; i < times.length; i++) {
        final raw = times[i];
        if (raw is! String) continue;
        final t = DateTime.tryParse(raw);
        if (t == null) continue;
        final delta = (t.difference(at)).abs();
        if (delta < bestDelta) {
          bestDelta = delta;
          bestIdx = i;
        }
      }

      double? readDouble(String key) {
        final list = hourly[key];
        if (list is! List || bestIdx >= list.length) return null;
        final v = list[bestIdx];
        if (v is num) return v.toDouble();
        return null;
      }

      int? readInt(String key) => readDouble(key)?.toInt();

      final observedRaw = times[bestIdx];
      final observed =
          observedRaw is String ? DateTime.tryParse(observedRaw) : null;

      final snapshot = WeatherSnapshot(
        fetchedAt: DateTime.now().toUtc(),
        observedAt: observed,
        temperatureC: readDouble('temperature_2m'),
        precipitationMm: readDouble('precipitation'),
        windSpeedMs: readDouble('wind_speed_10m'),
        windDirectionDeg: readDouble('wind_direction_10m'),
        cloudCoverPercent: readInt('cloud_cover'),
        weatherCode: readInt('weather_code'),
      );

      _cache[cacheKey] = snapshot;
      try {
        await prefs.setString(persistentKey, json.encode(snapshot.toJson()));

        // Clean up old entries (older than 30 days) to prevent SharedPreferences bloat
        final allKeys = prefs.getKeys();
        final nowTime = DateTime.now().toUtc();
        for (final key in allKeys) {
          if (key.startsWith(PrefKeys.weatherCachePrefix)) {
            final raw = prefs.getString(key);
            if (raw != null) {
              try {
                final decoded = json.decode(raw) as Map<String, dynamic>;
                final fetchedAtStr = decoded['fetchedAt'] as String?;
                if (fetchedAtStr != null) {
                  final fetchedAt = DateTime.tryParse(fetchedAtStr);
                  if (fetchedAt != null &&
                      nowTime.difference(fetchedAt).inDays > 30) {
                    await prefs.remove(key);
                  }
                }
              } catch (_) {}
            }
          }
        }
      } catch (_) {
        /* non-fatal */
      }
      return snapshot;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _inFlight.clear();
    _client.close();
  }
}

/// App-wide singleton [WeatherService]. Disposed when the provider
/// container is disposed (which only happens at app shutdown).
final weatherServiceProvider = Provider<WeatherService>((ref) {
  final svc = WeatherService();
  ref.onDispose(svc.dispose);
  return svc;
});
