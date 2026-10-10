// =============================================================================
// Location Service Tests
// =============================================================================
//
// Verifies the AppLocation data class and LocationService manual override.
// GPS integration tests are skipped (platform-dependent).
// =============================================================================

import 'package:birdnet_live/core/services/location_service.dart';
import 'package:birdnet_live/shared/models/altitude_reference.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AppLocation
  // ─────────────────────────────────────────────────────────────────────────

  group('AppLocation', () {
    test('stores latitude and longitude', () {
      const loc = AppLocation(latitude: 52.52, longitude: 13.405);
      expect(loc.latitude, 52.52);
      expect(loc.longitude, 13.405);
    });

    test('toString formats to 4 decimal places', () {
      const loc = AppLocation(latitude: 52.520008, longitude: 13.404954);
      final str = loc.toString();
      expect(str, contains('52.5200'));
      expect(str, contains('13.4050'));
    });

    Position fix({
      required double altitude,
      bool hasAltitude = true,
      double altitudeAccuracy = 8,
      bool hasAltitudeAccuracy = true,
      DateTime? timestamp,
    }) => Position(
      longitude: 13.405,
      latitude: 52.52,
      timestamp: timestamp ?? DateTime.now(),
      accuracy: 5,
      altitude: altitude,
      altitudeAccuracy: altitudeAccuracy,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      hasAltitude: hasAltitude,
      hasAltitudeAccuracy: hasAltitudeAccuracy,
    );

    test('keeps a measured zero and omits an unavailable zero', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppLocation.fromPosition(fix(altitude: 0)).altitude, 0);
      expect(
        AppLocation.fromPosition(fix(altitude: 0, hasAltitude: false)).altitude,
        isNull,
      );
    });

    test('stores uncertainty and the iOS reference', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final location = AppLocation.fromPosition(fix(altitude: -4.5));
      expect(location.altitude, -4.5);
      expect(location.altitudeAccuracy, 8);
      expect(location.altitudeReference, AltitudeReference.meanSeaLevel);
    });

    test('omits stale height and ambiguous Windows zero', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        AppLocation.fromPosition(
          fix(
            altitude: 123,
            timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ).altitude,
        isNull,
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(
        AppLocation.fromPosition(fix(altitude: 0, altitudeAccuracy: 0))
            .altitude,
        isNull,
      );
      expect(
        AppLocation.fromPosition(
          fix(altitude: 0, altitudeAccuracy: double.infinity),
        ).altitude,
        isNull,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // LocationService (non-GPS)
  // ─────────────────────────────────────────────────────────────────────────

  group('LocationService', () {
    test('lastKnownLocation is null initially', () {
      final service = LocationService();
      expect(service.lastKnownLocation, isNull);
    });

    test('setManualLocation sets lastKnownLocation', () {
      final service = LocationService();
      service.setManualLocation(48.137, 11.576);

      expect(service.lastKnownLocation, isNotNull);
      expect(service.lastKnownLocation!.latitude, 48.137);
      expect(service.lastKnownLocation!.longitude, 11.576);
    });

    test('setManualLocation updates on subsequent calls', () {
      final service = LocationService();
      service.setManualLocation(48.137, 11.576);
      service.setManualLocation(40.7128, -74.006);

      expect(service.lastKnownLocation!.latitude, 40.7128);
      expect(service.lastKnownLocation!.longitude, -74.006);
    });

    test('isGpsEnabled defaults to true when no callback is supplied', () {
      expect(LocationService().isGpsEnabled, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // "Use GPS" off — the service must not touch location hardware or the
  // permission system (issue #184). These run without a plugin binding, so a
  // leak through to geolocator would throw rather than pass.
  // ─────────────────────────────────────────────────────────────────────────

  group('LocationService with GPS disabled', () {
    LocationService build() => LocationService(
      gpsEnabled: () => false,
      manualLocation: () =>
          const AppLocation(latitude: 48.137, longitude: 11.576),
    );

    test('getCurrentLocation returns the manual coordinates', () async {
      final loc = await build().getCurrentLocation();

      expect(loc, isNotNull);
      expect(loc!.latitude, 48.137);
      expect(loc.longitude, 11.576);
    });

    test(
      'getCurrentLocation returns null without manual coordinates',
      () async {
        final service = LocationService(gpsEnabled: () => false);
        expect(await service.getCurrentLocation(), isNull);
      },
    );

    test('requestPermission never prompts', () async {
      expect(await build().requestPermission(), LocationPermission.denied);
    });

    test('hasPermission reports false', () async {
      expect(await build().hasPermission(), isFalse);
    });

    test('checkPermission reports denied without querying the OS', () async {
      expect(await build().checkPermission(), LocationPermission.denied);
    });

    test('location service status is false without querying the OS', () async {
      expect(await build().isLocationServiceEnabled(), isFalse);
    });
  });

  group('buildLocationSettings', () {
    test('forces Android LocationManager and preserves request options', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final settings = buildLocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 12,
        timeLimit: const Duration(seconds: 8),
        intervalDuration: const Duration(seconds: 3),
      );

      expect(settings, isA<AndroidSettings>());
      final android = settings as AndroidSettings;
      expect(android.forceLocationManager, isTrue);
      expect(android.accuracy, LocationAccuracy.best);
      expect(android.distanceFilter, 12);
      expect(android.timeLimit, const Duration(seconds: 8));
      expect(android.intervalDuration, const Duration(seconds: 3));
    });
  });
}
