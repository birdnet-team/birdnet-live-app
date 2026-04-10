// =============================================================================
// Unit tests for DecodedAudio — resampleTo and readFloat32
// =============================================================================

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/recording/audio_decoder.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // resampleTo
  // ═══════════════════════════════════════════════════════════════════════

  group('DecodedAudio.resampleTo', () {
    test('returns same instance when rate matches', () {
      final audio = DecodedAudio(
        samples: Int16List.fromList([100, 200, 300]),
        sampleRate: 32000,
      );
      final result = audio.resampleTo(32000);
      expect(identical(result, audio), isTrue);
    });

    test('downsamples 48 kHz → 32 kHz', () {
      // 48000 samples at 48 kHz = 1 second.
      // After resample to 32 kHz → 32000 samples.
      final samples = Int16List(48000);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = (i % 1000).toInt();
      }
      final audio = DecodedAudio(samples: samples, sampleRate: 48000);
      final resampled = audio.resampleTo(32000);

      expect(resampled.sampleRate, 32000);
      expect(resampled.totalSamples, 32000);
      // Duration should be preserved (1 second).
      expect(resampled.duration.inMilliseconds, 1000);
    });

    test('upsamples 16 kHz → 32 kHz', () {
      final samples = Int16List(16000);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = i;
      }
      final audio = DecodedAudio(samples: samples, sampleRate: 16000);
      final resampled = audio.resampleTo(32000);

      expect(resampled.sampleRate, 32000);
      expect(resampled.totalSamples, 32000);
      expect(resampled.duration.inMilliseconds, 1000);
    });

    test('linear interpolation is accurate for simple ramp', () {
      // 6 samples at rate 3 → resample to rate 2 → 4 samples.
      // Source: [0, 10000, 20000, 30000, 20000, 10000]
      // Ratio = 3/2 = 1.5, so:
      //   out[0] = src[0.0] = 0
      //   out[1] = src[1.5] = lerp(10000, 20000, 0.5) = 15000
      //   out[2] = src[3.0] = 30000
      //   out[3] = src[4.5] = lerp(20000, 10000, 0.5) = 15000
      final audio = DecodedAudio(
        samples: Int16List.fromList([0, 10000, 20000, 30000, 20000, 10000]),
        sampleRate: 3,
      );
      final resampled = audio.resampleTo(2);

      expect(resampled.sampleRate, 2);
      expect(resampled.totalSamples, 4);
      expect(resampled.samples[0], 0);
      expect(resampled.samples[1], 15000);
      expect(resampled.samples[2], 30000);
      expect(resampled.samples[3], 15000);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // readFloat32
  // ═══════════════════════════════════════════════════════════════════════

  group('DecodedAudio.readFloat32', () {
    test('normalizes Int16 to [-1.0, 1.0] range', () {
      final audio = DecodedAudio(
        samples: Int16List.fromList([0, 16384, -16384, 32767]),
        sampleRate: 1,
      );
      final floats = audio.readFloat32(0, 4);
      expect(floats[0], closeTo(0.0, 1e-6));
      expect(floats[1], closeTo(0.5, 0.001));
      expect(floats[2], closeTo(-0.5, 0.001));
      expect(floats[3], closeTo(1.0, 0.001));
    });

    test('zero-fills past end of samples', () {
      final audio = DecodedAudio(
        samples: Int16List.fromList([1000, 2000]),
        sampleRate: 1,
      );
      final floats = audio.readFloat32(0, 5);
      expect(floats.length, 5);
      expect(floats[2], 0.0);
      expect(floats[3], 0.0);
      expect(floats[4], 0.0);
    });
  });
}
