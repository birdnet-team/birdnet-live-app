// =============================================================================
// Location Service Tests
// =============================================================================
//
// Verifies the AppLocation data class and LocationService manual override.
// GPS integration tests are skipped (platform-dependent).
// =============================================================================

import 'package:birdnet_live/core/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  });
}
