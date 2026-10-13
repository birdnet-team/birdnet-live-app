import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../recording/audio_decoder.dart';
import '../../recording/flac_encoder.dart';
import '../../recording/wav_writer.dart';

/// Boosts quiet shared audio so it is audible on the receiving side.
///
/// Two streaming passes over the file — a peak scan, then a re-encode through
/// a temporary file — so a full-length recording never sits in memory as a
/// whole. Both passes are pure Dart over a path and run in a background
/// isolate: the UI isolate is also the platform thread on Android and iOS,
/// and re-encoding an hour of FLAC takes seconds.
class AudioExportNormalizer {
  AudioExportNormalizer._();

  static const double quietThreshold = 0.5;
  static const double targetPeak = 0.95;

  /// Samples read per chunk when scanning or rewriting a WAV (2 MB of PCM16).
  static const int _wavChunkSamples = 1 << 20;

  /// Boosts [file] in place when its peak is below [quietThreshold].
  ///
  /// Only WAV and FLAC are handled; anything else, and any failure, leaves the
  /// file untouched. Only the path and extension cross the isolate boundary.
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
    final tmpPath = '$path.normalizing.tmp';
    try {
      final ext = extension.toLowerCase();
      if (ext != '.wav' && ext != '.flac') return;
      final file = File(path);
      if (!await file.exists()) return;
      if (!await AudioDecoder.canDecodeDart(path)) return;
      final isWav = await AudioDecoder.isWav(path);

      final peak = await _scanPeak(path, isWav: isWav);
      if (peak == 0.0 || peak >= quietThreshold) return;
      final gain = targetPeak / peak;

      final sampleRate = isWav
          ? (await AudioDecoder.inspectFile(path)).sampleRate
          : await AudioDecoder.flacSampleRate(path);
      final writer = ext == '.flac'
          ? FlacEncoder(filePath: tmpPath, sampleRate: sampleRate)
          : WavWriter(filePath: tmpPath, sampleRate: sampleRate);
      await writer.open();
      try {
        await _forEachChunk(
          path,
          isWav: isWav,
          onChunk: (samples) async {
            await writer.writeSamples(scaledFloat32(samples, gain));
          },
        );
      } finally {
        await writer.close();
      }
      await File(tmpPath).rename(path);
    } catch (_) {
      // Export must still succeed if normalization fails.
      try {
        final tmp = File(tmpPath);
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {
        // Best-effort cleanup of the staging file.
      }
    }
  }

  /// Peak absolute amplitude in [0, 1] over the whole file.
  static Future<double> _scanPeak(String path, {required bool isWav}) async {
    var peak = 0;
    await _forEachChunk(
      path,
      isWav: isWav,
      onChunk: (samples) async {
        final chunkPeak = peakOf(samples);
        if (chunkPeak > peak) peak = chunkPeak;
      },
    );
    return peak / 32768.0;
  }

  /// Walks the file's PCM in bounded chunks, in order.
  static Future<void> _forEachChunk(
    String path, {
    required bool isWav,
    required Future<void> Function(Int16List samples) onChunk,
  }) async {
    if (isWav) {
      final total = (await AudioDecoder.inspectFile(path)).totalSamples;
      var position = 0;
      while (position < total) {
        final chunk = await AudioDecoder.decodeRange(
          path,
          startSample: position,
          count: _wavChunkSamples,
        );
        if (chunk.totalSamples == 0) break;
        await onChunk(chunk.samples);
        position += chunk.totalSamples;
      }
      return;
    }
    await AudioDecoder.decodeFlacFrames(
      path,
      onFrame: (_, samples) async {
        await onChunk(samples);
        return true;
      },
    );
  }

  /// Largest absolute PCM16 value in [samples].
  static int peakOf(Int16List samples) {
    var peak = 0;
    for (var i = 0; i < samples.length; i++) {
      final v = samples[i];
      final abs = v < 0 ? -v : v;
      if (abs > peak) peak = abs;
    }
    return peak;
  }

  /// Peak absolute amplitude of [samples] in [0, 1].
  static double computePeak(Int16List samples) => peakOf(samples) / 32768.0;

  /// [samples] scaled by [gain] as clipped float32 in [-1, 1].
  static Float32List scaledFloat32(Int16List samples, double gain) {
    final out = Float32List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      var v = samples[i] / 32768.0 * gain;
      if (v > 1.0) v = 1.0;
      if (v < -1.0) v = -1.0;
      out[i] = v;
    }
    return out;
  }

  /// [samples] boosted so that [peak] lands on [targetPeak].
  static Float32List normalizedFloat32(Int16List samples, double peak) =>
      scaledFloat32(samples, targetPeak / peak);
}
