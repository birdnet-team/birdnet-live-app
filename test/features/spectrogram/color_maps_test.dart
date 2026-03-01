import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/spectrogram/color_maps.dart';

void main() {
  group('SpectrogramColorMap', () {
    // ─── Name registry ─────────────────────────────────────────────────────

    group('names', () {
      test('contains expected colour map names', () {
        expect(SpectrogramColorMap.names, contains('viridis'));
        expect(SpectrogramColorMap.names, contains('magma'));
        expect(SpectrogramColorMap.names, contains('inferno'));
        expect(SpectrogramColorMap.names, contains('grayscale'));
        expect(SpectrogramColorMap.names, contains('birdnet'));
      });

      test('names list is non-empty', () {
        expect(SpectrogramColorMap.names.length, greaterThanOrEqualTo(3));
      });
    });

    // ─── LUT generation ────────────────────────────────────────────────────

    group('lut', () {
      for (final name in SpectrogramColorMap.names) {
        test('$name returns a 256-entry Int32List', () {
          final table = SpectrogramColorMap.lut(name);
          expect(table, isA<Int32List>());
          expect(table.length, 256);
        });

        test('$name entries have full alpha', () {
          final table = SpectrogramColorMap.lut(name);
          for (var i = 0; i < 256; i++) {
            final alpha = (table[i] >> 24) & 0xFF;
            expect(alpha, 255,
                reason: '$name LUT[$i] should have alpha=255, got $alpha');
          }
        });
      }

      test('throws ArgumentError for unknown name', () {
        expect(
          () => SpectrogramColorMap.lut('does_not_exist'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('second call returns cached table (same reference)', () {
        final a = SpectrogramColorMap.lut('viridis');
        final b = SpectrogramColorMap.lut('viridis');
        expect(identical(a, b), isTrue);
      });
    });

    // ─── color() convenience ───────────────────────────────────────────────

    group('color', () {
      test('returns a Color for value 0.0', () {
        final c = SpectrogramColorMap.color('viridis', 0.0);
        expect(c, isA<Color>());
      });

      test('returns a Color for value 1.0', () {
        final c = SpectrogramColorMap.color('viridis', 1.0);
        expect(c, isA<Color>());
      });

      test('clamps out-of-range values gracefully', () {
        // Values slightly outside [0, 1] should not crash.
        expect(() => SpectrogramColorMap.color('magma', -0.1), returnsNormally);
        expect(() => SpectrogramColorMap.color('magma', 1.1), returnsNormally);
      });
    });

    // ─── Gradient continuity ───────────────────────────────────────────────

    group('gradient continuity', () {
      for (final name in SpectrogramColorMap.names) {
        test('$name has monotonically distinct entries (no large jumps)', () {
          final table = SpectrogramColorMap.lut(name);
          // Check that no two adjacent entries have an absurdly large RGB jump
          // (which would indicate a bug in interpolation).
          for (var i = 1; i < 256; i++) {
            final prev = table[i - 1];
            final curr = table[i];
            final dr = (((curr >> 16) & 0xFF) - ((prev >> 16) & 0xFF)).abs();
            final dg = (((curr >> 8) & 0xFF) - ((prev >> 8) & 0xFF)).abs();
            final db = ((curr & 0xFF) - (prev & 0xFF)).abs();
            final maxDelta = [dr, dg, db].reduce((a, b) => a > b ? a : b);
            expect(maxDelta, lessThan(30),
                reason:
                    '$name LUT[$i] has a $maxDelta-step jump from LUT[${i - 1}]');
          }
        });
      }
    });

    // ─── Specific palette spot checks ──────────────────────────────────────

    group('spot checks', () {
      test('grayscale starts black and ends white', () {
        final table = SpectrogramColorMap.lut('grayscale');
        // Index 0 → black.
        expect(table[0] & 0x00FFFFFF, 0x00000000);
        // Index 255 → white.
        expect(table[255] & 0x00FFFFFF, 0x00FFFFFF);
      });

      test('birdnet mid-range is near brand blue (#0D6EFD)', () {
        final table = SpectrogramColorMap.lut('birdnet');
        // The brand blue stop is at 0.55 → index ≈ 140.
        final index = 140;
        final r = (table[index] >> 16) & 0xFF;
        final g = (table[index] >> 8) & 0xFF;
        final b = table[index] & 0xFF;
        // Should be roughly (13, 110, 253) ± tolerance.
        expect(r, closeTo(13, 30));
        expect(g, closeTo(110, 30));
        expect(b, closeTo(253, 30));
      });
    });
  });
}
