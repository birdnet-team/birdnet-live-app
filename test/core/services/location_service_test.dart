// =============================================================================
// Location Service Tests
// =============================================================================
//
// Verifies the AppLocation data class and LocationService manual override.
// GPS integration tests are skipped (platform-dependent).
// =============================================================================

import 'package:birdnet_live/core/services/location_service.dart';
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
      manualLocation:
          () => const AppLocation(latitude: 48.137, longitude: 11.576),
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
