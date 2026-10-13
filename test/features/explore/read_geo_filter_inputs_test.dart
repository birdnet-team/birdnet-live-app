import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A geo-model load that failed once used to fail every later session start:
// [geoModelProvider] caches the error, and the start paths rethrew it.
void main() {
  late ProviderContainer container;
  late List<ProviderOrFamily> invalidated;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    invalidated = [];
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentLocationProvider.overrideWith((ref) async => null),
        audioLabelClassesProvider.overrideWith(
          (ref) async => const {
            'Turdus merula': 'Aves',
            'Vulpes vulpes': 'Mammalia',
          },
        ),
        geoModelProvider.overrideWith(
          (ref) async => throw StateError('session create refused'),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('starts without the geo filter when the geo model failed', () async {
    final inputs = await readGeoFilterInputs(
      read: container.read,
      invalidate: invalidated.add,
    );

    expect(inputs.geoScores, isNull);
    expect(inputs.geoModelSpeciesNames, isNull);
    expect(inputs.ignoredSpeciesNames, isEmpty);
    expect(invalidated, [geoModelProvider]);
  });

  test('keeps the taxon ignore rules without a geo model', () async {
    await container.read(ignoreMammalsProvider.notifier).set(true);

    final inputs = await readGeoFilterInputs(
      read: container.read,
      invalidate: invalidated.add,
    );

    expect(inputs.ignoredSpeciesNames, {'Vulpes vulpes'});
  });
}
