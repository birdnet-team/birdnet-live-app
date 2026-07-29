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
//
// ### "Use GPS" setting
//
// When the user turns off Settings → Location → Use GPS, the service stops
// touching location hardware entirely and hands back the manually entered
// coordinates instead.  Permission requests become no-ops.  This is enforced
// here rather than at each call site so no feature can prompt behind the
// user's back.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Build the platform [LocationSettings] used for **every** fix this app
/// requests — one-shot reads and continuous survey tracking alike.
///
/// On Android this pins `forceLocationManager: true`, which makes geolocator
/// talk to the platform `LocationManager` instead of the Play Services fused
/// provider.  The fused client runs `checkLocationSettings()` before each
/// request and, when the user has declined Google Location Accuracy, resolves
/// it by showing Google's own "turn on location services" dialog — a system
/// dialog we cannot suppress or attach a "never ask again" option to, and one
/// that reappears on every request (issue #184).
///
/// The trade-off is a slower first fix indoors and no fused sensor blending.
/// Both are irrelevant for field recording, and [LocationService] already
/// falls back to the OS last-known position when a fix times out.
LocationSettings buildLocationSettings({
  LocationAccuracy accuracy = LocationAccuracy.high,
  int distanceFilter = 0,
  Duration? timeLimit,
  Duration? intervalDuration,
  bool background = false,
}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AndroidSettings(
        forceLocationManager: true,
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: intervalDuration,
        timeLimit: timeLimit,
      );
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: timeLimit,
        allowBackgroundLocationUpdates: background,
        showBackgroundLocationIndicator: background,
      );
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: timeLimit,
      );
  }
}

/// Check the platform location-service switch without selecting the Android
/// Play Services fused client.
///
/// Always use this instead of `Geolocator.isLocationServiceEnabled()`, which
/// is the one geolocator call that does not honour `forceLocationManager` —
/// it hardcodes the fused client, and `play-services-location` is excluded
/// from our Android build (see `android/app/build.gradle`).
Future<bool> isPlatformLocationServiceEnabled() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return Permission.locationWhenInUse.serviceStatus.then(
      (status) => status.isEnabled,
    );
  }
  return Geolocator.isLocationServiceEnabled();
}

/// Simplified location data — lat/lon only.
class AppLocation {
  const AppLocation({required this.latitude, required this.longitude});

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
  /// [gpsEnabled] and [manualLocation] are read on every call so the service
  /// always sees the current setting.  Both default to "GPS on, no manual
  /// fallback" when omitted (tests, standalone use).
  LocationService({
    bool Function()? gpsEnabled,
    AppLocation Function()? manualLocation,
  }) : _gpsEnabled = gpsEnabled,
       _manualLocation = manualLocation;

  final bool Function()? _gpsEnabled;
  final AppLocation Function()? _manualLocation;

  /// Whether the user allows the app to use location hardware at all.
  bool get isGpsEnabled => _gpsEnabled?.call() ?? true;

  AppLocation? _lastKnownLocation;
  DateTime? _lastFetchAt;

  /// True when [lastKnownLocation] came from the manual-coordinates setting
  /// rather than a GPS fix.  Used to keep the two apart in the [maxAge] cache
  /// so toggling "Use GPS" back on doesn't serve manual coordinates as a fix.
  bool _lastFixWasManual = false;

  /// Whether [lastKnownLocation] came from the OS's last-known-position
  /// fallback (because the live fix timed out). Callers can read this to
  /// surface a "GPS is stale" warning.
  bool _lastFetchUsedCachedFallback = false;

  AppLocation? get _lastGpsLocation =>
      _lastFixWasManual ? null : _lastKnownLocation;

  /// The most recently fetched location (may be stale).
  AppLocation? get lastKnownLocation => _lastKnownLocation;

  /// Wall-clock time the cached fix was retrieved. Set on both a live fix
  /// and the timeout fallback — callers that need to distinguish freshness
  /// can check [lastFetchUsedCachedFallback].
  DateTime? get lastFetchAt => _lastFetchAt;

  /// True when the most recent fetch returned the OS last-known-position
  /// fallback instead of a live fix.
  bool get lastFetchUsedCachedFallback => _lastFetchUsedCachedFallback;

  /// Check whether the device's location services are enabled.
  Future<bool> isLocationServiceEnabled() async {
    if (!isGpsEnabled) return false;

    // Geolocator's Android implementation does not accept
    // forceLocationManager for this check and may instantiate its fused
    // client. permission_handler reads the native service state directly.
    return isPlatformLocationServiceEnabled();
  }

  /// Check the current location permission status.
  ///
  /// Reports [LocationPermission.denied] while "Use GPS" is off, so callers
  /// gated on permission state don't light up location UI.
  Future<LocationPermission> checkPermission() async {
    if (!isGpsEnabled) return LocationPermission.denied;
    return Geolocator.checkPermission();
  }

  /// Request location permission from the user.
  ///
  /// A no-op while "Use GPS" is off — the user has already said no, and the
  /// app must not re-prompt.
  Future<LocationPermission> requestPermission() async {
    if (!isGpsEnabled) return LocationPermission.denied;
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
  /// If [maxAge] is non-null and a fix has been retrieved within that
  /// window, the cached value is returned without touching GPS hardware —
  /// opening a setup wizard, dismissing it, and reopening seconds later
  /// should not trigger another 10-second `getCurrentPosition` call.
  ///
  /// Default: `null` (always fetch fresh). UI-only contexts (setup wizards,
  /// pickers) should opt in with a generous [maxAge] like
  /// `Duration(minutes: 2)`. Contexts that record a position for an actual
  /// measurement (session start, file-analysis tagging) should leave it
  /// `null` so the saved coordinates reflect the user's current position.
  ///
  /// Returns `null` if location services are disabled, permission is
  /// denied, and no cached value is available.
  Future<AppLocation?> getCurrentLocation({Duration? maxAge}) async {
    // "Use GPS" off — hand back the manual coordinates without touching
    // location hardware or the permission system.
    if (!isGpsEnabled) {
      final manual = _manualLocation?.call();
      if (manual != null) {
        _lastKnownLocation = manual;
        _lastFetchAt = DateTime.now();
        _lastFetchUsedCachedFallback = false;
        _lastFixWasManual = true;
      }
      return manual;
    }

    // Cache hit — return immediately, no I/O, no GPS hardware wake. A manual
    // entry never satisfies a GPS request.
    if (maxAge != null && maxAge > Duration.zero && !_lastFixWasManual) {
      final cached = _lastKnownLocation;
      final cachedAt = _lastFetchAt;
      if (cached != null && cachedAt != null) {
        final age = DateTime.now().difference(cachedAt);
        if (age < maxAge) {
          debugPrint(
            '[LocationService] cache hit (age=${age.inSeconds}s, '
            'fallback=$_lastFetchUsedCachedFallback)',
          );
          return cached;
        }
      }
    }

    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] location services disabled');
        return _lastGpsLocation;
      }

      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        debugPrint('[LocationService] permission denied: $permission');
        return _lastGpsLocation;
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: buildLocationSettings(
            timeLimit: const Duration(seconds: 10),
          ),
        );
        _lastKnownLocation = AppLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _lastFetchAt = DateTime.now();
        _lastFetchUsedCachedFallback = false;
        _lastFixWasManual = false;
        debugPrint('[LocationService] got position: $_lastKnownLocation');
        return _lastKnownLocation;
      } on TimeoutException {
        // No fresh fix within the timeout (e.g. weak GPS signal or first cold
        // start indoors). Fall back to the OS-cached last-known position so
        // callers still get something usable, then return whatever we have.
        debugPrint(
          '[LocationService] no fresh fix within 10s, using last known',
        );
        final cached = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true,
        );
        if (cached != null) {
          _lastKnownLocation = AppLocation(
            latitude: cached.latitude,
            longitude: cached.longitude,
          );
          _lastFetchAt = DateTime.now();
          _lastFixWasManual = false;
        }
        _lastFetchUsedCachedFallback = true;
        return _lastGpsLocation;
      }
    } catch (e) {
      debugPrint('[LocationService] error getting position: $e');
      return _lastGpsLocation;
    }
  }

  /// Set a manual location (for testing or user override).
  void setManualLocation(double latitude, double longitude) {
    _lastKnownLocation = AppLocation(latitude: latitude, longitude: longitude);
    _lastFetchAt = DateTime.now();
    _lastFixWasManual = true;
  }
}
