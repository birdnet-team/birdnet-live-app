import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/spectrogram/spectrogram_size.dart';

void main() {
  group('SpectrogramSize', () {
    test('parses stored values and falls back to full', () {
      expect(SpectrogramSize.fromPrefValue('medium'), SpectrogramSize.medium);
      expect(SpectrogramSize.fromPrefValue('off'), SpectrogramSize.off);
      expect(SpectrogramSize.fromPrefValue(null), SpectrogramSize.full);
      expect(SpectrogramSize.fromPrefValue('huge'), SpectrogramSize.full);
    });

    test('only off hides the spectrogram', () {
      for (final size in SpectrogramSize.values) {
        expect(size.isVisible, size != SpectrogramSize.off);
      }
    });

    test('flexFor scales the spectrogram and keeps the combined weight', () {
      expect(SpectrogramSize.full.flexFor(spectrogram: 2, other: 3), (
        spectrogram: 8,
        other: 12,
      ));
      expect(SpectrogramSize.medium.flexFor(spectrogram: 2, other: 3), (
        spectrogram: 6,
        other: 14,
      ));
      expect(SpectrogramSize.small.flexFor(spectrogram: 2, other: 3), (
        spectrogram: 4,
        other: 16,
      ));
    });

    test(
      'ownColumnFlex shortens the spectrogram and leaves the rest empty',
      () {
        expect(SpectrogramSize.full.ownColumnFlex, (spectrogram: 4, other: 0));
        expect(SpectrogramSize.medium.ownColumnFlex, (
          spectrogram: 3,
          other: 1,
        ));
        expect(SpectrogramSize.small.ownColumnFlex, (spectrogram: 2, other: 2));
      },
    );

    test('medium and small keep 75% and 50% of the full height', () {
      const fullShare = 2 / 5;
      final medium = SpectrogramSize.medium.flexFor(spectrogram: 2, other: 3);
      final small = SpectrogramSize.small.flexFor(spectrogram: 2, other: 3);
      expect(
        medium.spectrogram / (medium.spectrogram + medium.other),
        closeTo(fullShare * 0.75, 1e-9),
      );
      expect(
        small.spectrogram / (small.spectrogram + small.other),
        closeTo(fullShare * 0.5, 1e-9),
      );
    });
  });
}
