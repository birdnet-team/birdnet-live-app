import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/shared/services/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      PrefKeys.privacyAllowWeather: true,
    });
  });

  test('fetch returns without HTTP when the device is offline', () async {
    var requested = false;
    final service = WeatherService(
      httpClient: MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      }),
      networkAvailable: () async => false,
    );
    addTearDown(service.dispose);

    final result = await service.fetch(
      latitude: 50.83,
      longitude: 12.92,
      observedAt: DateTime.utc(2026, 9, 10, 8),
    );

    expect(result, isNull);
    expect(requested, isFalse);
  });

  test('negative network probes are reused briefly', () async {
    var probes = 0;
    final service = WeatherService(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      networkAvailable: () async {
        probes++;
        return false;
      },
    );
    addTearDown(service.dispose);

    await service.fetch(latitude: 1, longitude: 2);
    await service.fetch(latitude: 3, longitude: 4);

    expect(probes, 1);
  });
}
