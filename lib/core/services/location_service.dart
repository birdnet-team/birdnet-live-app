// =============================================================================
// Location Service — GPS position provider
// =============================================================================
//
// Wraps the `geolocator` package to provide a clean, reusable interface for
// obtaining the device's GPS coordinates.  Used by:
//
//   - **Explore screen** — to fetch species for the current location
//   - **Live mode** — to run the geo-model before starting inference
//   - **Survey / Point Count** — for geotagging sessions
//
// The service handles permission checking, position fetching, and error
// reporting.  It does NOT request permissions — that responsibility lies
// with the UI layer (onboarding, permission prompts).
//
// ### Position caching
//
// The last known position is cached so that callers can display stale data
// while a fresh fix is being acquired.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Simplified location data — lat/lon only.
class AppLocation {
  const AppLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  String toString() =>
      'AppLocation(${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
}

/// GPS location provider.
///
/// Provides current position, permission status, and a cached last position.
/// Designed to be held as a long-lived singleton or Riverpod provider.
class LocationService {
  LocationService();

  AppLocation? _lastKnownLocation;

  /// The most recently fetched location (may be stale).
  AppLocation? get lastKnownLocation => _lastKnownLocation;

  /// Check whether the device's location services are enabled.
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Check the current location permission status.
  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  /// Request location permission from the user.
  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  /// Returns true if we have at least [LocationPermission.whileInUse].
  Future<bool> hasPermission() async {
    final perm = await checkPermission();
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  /// Get the current GPS position.
  ///
  /// Returns the position or `null` if location services are disabled or
  /// permission is denied.  Updates [lastKnownLocation] on success.
  Future<AppLocation?> getCurrentLocation() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] location services disabled');
        return _lastKnownLocation;
      }

      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] permission denied: $permission');
        return _lastKnownLocation;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _lastKnownLocation = AppLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      debugPrint('[LocationService] got position: $_lastKnownLocation');
      return _lastKnownLocation;
    } catch (e) {
      debugPrint('[LocationService] error getting position: $e');
      return _lastKnownLocation;
    }
  }

  /// Set a manual location (for testing or user override).
  void setManualLocation(double latitude, double longitude) {
    _lastKnownLocation = AppLocation(
      latitude: latitude,
      longitude: longitude,
    );
  }
}
