import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'mask changes reuse one cached current-location geo prediction',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var geoPredictionCount = 0;

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          audioLabelClassesProvider.overrideWith(
            (ref) async => const {
              'Very common species': 'Aves',
              'Common species': 'Aves',
            },
          ),
          rawGeoScoresProvider.overrideWith((ref) async {
            geoPredictionCount++;
            return const {'Very common species': 1.0, 'Common species': 0.85};
          }),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(ignoredSpeciesNamesProvider.future), isEmpty);
      expect(geoPredictionCount, 1);

      await container
          .read(ignoreCommonGeoScoreCutoffProvider.notifier)
          .set(0.8);
      expect(await container.read(ignoredSpeciesNamesProvider.future), {
        'Very common species',
        'Common species',
      });

      await container.read(ignoreBirdsProvider.notifier).set(true);
      expect(
        (await container.read(ignoredSpeciesNamesProvider.future)).length,
        2,
      );
      expect(geoPredictionCount, 1);
    },
  );
}
