// =============================================================================
// PlaybackNormalizer — Boost quiet recordings at playback time only
// =============================================================================
//
// Detection clips can come back very quiet — distant birds, low-gain mic,
// FLAC compression preserves whatever the mic captured exactly. Users
// should still be able to hear them at normal phone volume without
// cranking the system slider.
//
// This helper computes the peak amplitude of a decoded clip and, when
// it falls below [_quietThreshold], writes a peak-normalized WAV copy
// to a process-local cache directory and returns its path. Otherwise it
// returns the original path unchanged.
//
// **The original recording on disk is never modified.** Saving FLAC
// clips with normalization applied would defeat the codec's lossless
// compression (FLAC compresses better when the dynamic range matches
// the recorded reality, and a normalized copy adds bytes for no
// scientific gain). Normalization is purely a playback-time
// convenience.
//
// ### Cache strategy
//
// Normalized copies live in `<temp>/birdnet_norm_cache/`. The cache
// filename embeds a stable digest of the source path + size + mtime so
// repeated opens of the same clip are O(1) after the first decode. The
// directory is best-effort cleaned to a small ceiling on each access
// to keep the temp area bounded; the OS reclaims everything on uninstall
// or when temp is purged.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audio_decoder.dart';
import 'wav_writer.dart';

/// Static helper for resolving a playback source path, optionally
/// substituting a peak-normalized copy when the original is too quiet.
class PlaybackNormalizer {
  PlaybackNormalizer._();

  /// Below this normalized peak (0..1), the clip gets boosted on
  /// playback. Picked so that obviously-quiet recordings get help while
  /// already-healthy clips pass through untouched (their dynamic range
  /// is preserved).
  static const double _quietThreshold = 0.5;

  /// Target peak after normalization. Stays just below 0 dBFS to leave
  /// a tiny headroom against int16 quantization rounding so a bit-perfect
  /// re-decode never clips.
  static const double _targetPeak = 0.95;

  /// Maximum number of files to keep in the on-disk cache before
  /// the oldest entries get pruned. Each entry is at most a few MB
  /// (clips are short by construction), so 32 entries caps the cache
  /// well under 100 MB.
  static const int _cacheMaxEntries = 32;

  /// Files larger than this skip normalization entirely. Full-decode-
  /// and-rewrite scales linearly with PCM size, so a 1 h FLAC would
  /// blow up to ~230 MB of int16 in RAM plus ~460 MB of Float32 on
  /// disk — all on whichever isolate calls us. For long field
  /// recordings that's both impractical and unnecessary (they're
  /// usually loud enough already), so we just play the original.
  static const int _maxNormalizeBytes = 30 * 1024 * 1024;

  /// Resolve a playback path for [originalPath]. When [decoded] is
  /// provided it is used directly to compute the peak (saves a redundant
  /// decode in callers that already needed the samples for a
  /// spectrogram); otherwise the file is decoded inline.
  ///
  /// Returns the original path unchanged when the clip is already loud
  /// enough, or when normalization fails for any reason — playback must
  /// always work, even if the boost didn't.
  static Future<String> resolveSource(
    String originalPath, {
    DecodedAudio? decoded,
  }) async {
    try {
      final file = File(originalPath);
      if (!await file.exists()) return originalPath;

      // Skip normalization for large source files — the full decode is
      // far too expensive even in the background, and quiet long
      // recordings are rare in practice.
      if (decoded == null) {
        final size = await file.length();
        if (size > _maxNormalizeBytes) return originalPath;
      }

      final cacheDir = await _ensureCacheDir();
      final stat = await file.stat();
      final key = _cacheKey(originalPath, stat.size, stat.modified);
      final cachePath = p.join(cacheDir.path, '$key.wav');

      // Reuse a previous normalized copy when stale-free. Checking this
      // before decoding is what makes a reopened clip O(1).
      if (await File(cachePath).exists()) {
        return cachePath;
      }

      final bool wroteCache;
      if (decoded != null) {
        // The caller already paid for the decode (it needed the samples for
        // a spectrogram), so there is nothing heavy left to move off-thread.
        wroteCache = await _writeNormalizedIfQuiet(decoded, cachePath);
      } else if (await AudioDecoder.canDecodeDart(originalPath)) {
        // Decoding even a few megabytes takes hundreds of milliseconds and
        // this runs while a screen is opening, so it goes to a background
        // isolate. Only paths and primitives cross the boundary; the
        // temp-directory lookup (a plugin call) already happened above.
        wroteCache = await Isolate.run(
          () => _decodeAndWriteNormalized(originalPath, cachePath),
        );
      } else {
        // Native decoder path: we don't reach for it here. Without a
        // decoded buffer we can't compute the peak, so play untouched.
        return originalPath;
      }

      if (!wroteCache) return originalPath;

      // Best-effort prune; never block on it.
      unawaited(_pruneCache(cacheDir));

      return cachePath;
    } catch (_) {
      // Any failure (decode error, disk full, etc.) falls back to the
      // original recording — the user still hears something.
      return originalPath;
    }
  }

  // --------------------------------------------------------------------------
  // Internals
  // --------------------------------------------------------------------------

  /// Decode [originalPath] and write a boosted copy to [cachePath] when it is
  /// quiet enough to warrant one. Returns whether the cache file was written.
  ///
  /// Pure file I/O and arithmetic — no plugin channels — so it is safe to run
  /// through [Isolate.run].
  static Future<bool> _decodeAndWriteNormalized(
    String originalPath,
    String cachePath,
  ) async {
    final audio = await AudioDecoder.decodeFile(originalPath);
    return _writeNormalizedIfQuiet(audio, cachePath);
  }

  static Future<bool> _writeNormalizedIfQuiet(
    DecodedAudio audio,
    String cachePath,
  ) async {
    final peak = _computePeak(audio.samples);
    if (peak >= _quietThreshold || peak == 0.0) return false;

    final boosted = _normalizedFloat32(audio.samples, peak);
    await WavWriter.writeFile(
      filePath: cachePath,
      samples: boosted,
      sampleRate: audio.sampleRate,
    );
    return true;
  }

  static double _computePeak(Int16List samples) {
    var peak = 0;
    for (var i = 0; i < samples.length; i++) {
      final v = samples[i];
      final abs = v < 0 ? -v : v;
      if (abs > peak) peak = abs;
    }
    return peak / 32768.0;
  }

  static Float32List _normalizedFloat32(Int16List samples, double peak) {
    final gain = _targetPeak / peak;
    final out = Float32List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      var v = samples[i] / 32768.0 * gain;
      if (v > 1.0) v = 1.0;
      if (v < -1.0) v = -1.0;
      out[i] = v;
    }
    return out;
  }

  static String _cacheKey(String path, int size, DateTime mtime) {
    final digest = sha1.convert(
      utf8.encode('$path|$size|${mtime.millisecondsSinceEpoch}'),
    );
    return digest.toString().substring(0, 16);
  }

  static Future<Directory> _ensureCacheDir() async {
    final temp = await getTemporaryDirectory();
    final dir = Directory(p.join(temp.path, 'birdnet_norm_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> _pruneCache(Directory dir) async {
    try {
      final entries =
          await dir.list().where((e) => e is File).cast<File>().toList();
      if (entries.length <= _cacheMaxEntries) return;
      entries.sort(
        (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
      );
      final toDelete = entries.length - _cacheMaxEntries;
      for (var i = 0; i < toDelete; i++) {
        try {
          await entries[i].delete();
        } catch (_) {
          // Ignore individual failures.
        }
      }
    } catch (_) {
      // Pruning is best-effort.
    }
  }
}
