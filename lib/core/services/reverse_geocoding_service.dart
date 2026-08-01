// =============================================================================
// Reverse Geocoding Service
// =============================================================================
//
// Thin wrapper around the OpenStreetMap Nominatim API for reverse geocoding.
//
// The service converts latitude/longitude coordinates into a human-readable
// place name such as "Berlin, Germany". Results are persisted to disk in two
// independent layers:
//
//   1. **Per-session** — `LiveSession.locationName` carries the resolved
//      label so re-opening the same session never re-hits the network.
//   2. **Per-cell** — a 0.1° lat/lon grid cache in SharedPreferences keyed
//      by [PrefKeys.reverseGeocodeCachePrefix] lets *other* sessions in
//      roughly the same area reuse the label too. Place names don't change
//      on the timescale of a birding trip, so the cache has no TTL — entries
//      live until the user clears app data. This also means the session
//      library can backfill location labels for legacy sessions without
//      ever touching the network.
//
// The Nominatim Usage Policy requires:
//   • A descriptive User-Agent header (no generic strings).
//   • At most 1 request per second.
//   • No bulk/automated geocoding.
// We satisfy these by sending at most one request per *novel* 0.1° cell.
//
// Privacy: the *network call* is gated by
// [PrefKeys.privacyAllowReverseGeocoding]. Cache lookups (which involve
// no network traffic) are always allowed — they're just reading data the
// user already chose to acquire. When consent is off and the cell isn't
// cached, [reverseGeocode] returns `null` without making any request.
// =============================================================================

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Builds the persistent-cache key for a 0.1° lat/lon cell. Coarse enough
/// that "same trail, different start coordinate" still hits, fine enough
/// that two adjacent towns don't get conflated.
String _cellKey(double lat, double lon) {
  final cellLat = (lat * 10).round() / 10;
  final cellLon = (lon * 10).round() / 10;
  return '${PrefKeys.reverseGeocodeCachePrefix}'
      '${cellLat.toStringAsFixed(1)}_${cellLon.toStringAsFixed(1)}';
}

/// Synchronous cache lookup. Returns the cached place name for the 0.1°
/// cell containing [latitude]/[longitude], or `null` if no entry exists.
///
/// Always safe to call regardless of privacy consent: this only reads
/// strings already on disk, it never touches the network.
String? cachedReverseGeocode({
  required SharedPreferences prefs,
  required double latitude,
  required double longitude,
}) {
  final v = prefs.getString(_cellKey(latitude, longitude));
  return (v != null && v.isNotEmpty) ? v : null;
}

/// Attempts to reverse-geocode [latitude]/[longitude] into a short place name
/// localized for [localeName].
///
/// Returns a human-readable string (e.g. "Berlin, Germany") or `null` when
/// the cell isn't cached AND (the user has not consented to OpenStreetMap
/// network requests, the network is unavailable, or the API response is
/// unusable).
///
/// Uses the OpenStreetMap Nominatim API which is free and GDPR-friendly.
/// Network call is gated by [PrefKeys.privacyAllowReverseGeocoding]; cache
/// hits short-circuit before any consent check.
Future<String?> reverseGeocode({
  required double latitude,
  required double longitude,
  required String localeName,
}) async {
  final prefs = await SharedPreferences.getInstance();

  // Cache check first — a hit means we never need to ask Nominatim, which
  // is both faster and respects their "no bulk requests" rate-limit policy.
  final cached = cachedReverseGeocode(
    prefs: prefs,
    latitude: latitude,
    longitude: longitude,
  );
  if (cached != null) return cached;

  // Privacy gate: only proceed with the network call when the user has
  // approved Nominatim. Cache hits above are exempt because they read
  // already-on-device data.
  final hasConsent =
      prefs.getBool(PrefKeys.privacyAllowReverseGeocoding) ?? false;
  if (!hasConsent) return null;

  final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
    'lat': latitude.toString(),
    'lon': longitude.toString(),
    'format': 'json',
    'zoom': '10',
    'addressdetails': '1',
    'accept-language': localeName.replaceAll('_', '-'),
  });

  try {
    final response = await http
        .get(uri, headers: const {'User-Agent': AppConstants.networkUserAgent})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final address = json['address'] as Map<String, dynamic>?;
    String? label;
    if (address == null) {
      label = json['display_name'] as String?;
    } else {
      // Build a short, readable label from the address components.
      final city =
          address['city'] ??
          address['town'] ??
          address['village'] ??
          address['municipality'];
      final state = address['state'];
      final country = address['country'];

      final parts = <String>[
        if (city != null) city as String,
        if (state != null && state != city) state as String,
        if (country != null) country as String,
      ];
      label =
          parts.isNotEmpty ? parts.join(', ') : json['display_name'] as String?;
    }

    if (label != null && label.isNotEmpty) {
      // Persist (best-effort) so future lookups in this 0.1° cell skip
      // the network. A failed write isn't fatal — we still return the
      // label to the caller.
      try {
        await prefs.setString(_cellKey(latitude, longitude), label);
      } catch (_) {
        /* non-fatal */
      }
    }
    return label;
  } catch (_) {
    // Network error, timeout, or bad JSON — fail silently.
    return null;
  }
}
