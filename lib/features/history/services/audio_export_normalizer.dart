import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../recording/audio_decoder.dart';
import '../../recording/flac_encoder.dart';
import '../../recording/wav_writer.dart';

class AudioExportNormalizer {
  AudioExportNormalizer._();

  static const double quietThreshold = 0.5;
  static const double targetPeak = 0.95;

  /// Boosts a quiet WAV or FLAC file in place so shared audio is audible.
  ///
  /// Decoding, the peak scan and the re-encode are pure Dart over the file
  /// at [file]'s path, so they run in a background isolate: the UI isolate is
  /// also the platform thread on Android and iOS, and a full-length recording
  /// takes seconds to re-encode. Only the path and extension cross the
  /// isolate boundary.
  static Future<void> normalizeFileInPlace(File file, String extension) async {
    final path = file.path;
    try {
      await Isolate.run(
        () => _normalizeInPlace(path, extension),
        debugName: 'audio-export-normalizer',
      );
    } catch (_) {
      // Export must still succeed if normalization fails.
    }
  }

  static Future<void> _normalizeInPlace(String path, String extension) async {
    try {
      final ext = extension.toLowerCase();
      if (ext != '.wav' && ext != '.flac') return;
      final file = File(path);
      if (!await file.exists()) return;

      final decoded = await AudioDecoder.decodeFile(path);
      final peak = computePeak(decoded.samples);
      if (peak == 0.0 || peak >= quietThreshold) return;

      final normalized = normalizedFloat32(decoded.samples, peak);
      if (ext == '.flac') {
        await FlacEncoder.writeFile(
          filePath: path,
          samples: normalized,
          sampleRate: decoded.sampleRate,
        );
      } else {
        await WavWriter.writeFile(
          filePath: path,
          samples: normalized,
          sampleRate: decoded.sampleRate,
        );
      }
    } catch (_) {
      // Export must still succeed if normalization fails.
    }
  }

  static double computePeak(Int16List samples) {
    var peak = 0;
    for (var i = 0; i < samples.length; i++) {
      final v = samples[i];
      final abs = v < 0 ? -v : v;
      if (abs > peak) peak = abs;
    }
    return peak / 32768.0;
  }

  static Float32List normalizedFloat32(Int16List samples, double peak) {
    final gain = targetPeak / peak;
    final out = Float32List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      var v = samples[i] / 32768.0 * gain;
      if (v > 1.0) v = 1.0;
      if (v < -1.0) v = -1.0;
      out[i] = v;
    }
    return out;
  }
}
