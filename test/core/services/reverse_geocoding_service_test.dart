import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/core/services/reverse_geocoding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('cachedReverseGeocode', () {
    test('returns cached value for rounded 0.1 degree cell', () async {
      final key = '${PrefKeys.reverseGeocodeCachePrefix}10.0_20.1';
      SharedPreferences.setMockInitialValues({key: 'Berlin, Germany'});
      final prefs = await SharedPreferences.getInstance();

      final cached = cachedReverseGeocode(
        prefs: prefs,
        latitude: 10.04,
        longitude: 20.06,
      );

      expect(cached, 'Berlin, Germany');
    });

    test('returns null for missing cached entry', () async {
      final prefs = await SharedPreferences.getInstance();
      final cached = cachedReverseGeocode(
        prefs: prefs,
        latitude: 1,
        longitude: 2,
      );

      expect(cached, isNull);
    });
  });

  group('reverseGeocode', () {
    test('returns cached value even without privacy consent', () async {
      final key = '${PrefKeys.reverseGeocodeCachePrefix}10.0_20.1';
      SharedPreferences.setMockInitialValues({
        key: 'Cached Place',
        PrefKeys.privacyAllowReverseGeocoding: false,
      });

      final result = await reverseGeocode(latitude: 10.0, longitude: 20.1);

      expect(result, 'Cached Place');
    });

    test('returns null when uncached and consent is false', () async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.privacyAllowReverseGeocoding: false,
      });

      final result = await reverseGeocode(latitude: 50.0, longitude: 8.0);

      expect(result, isNull);
    });
  });
}
