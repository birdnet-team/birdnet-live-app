// =============================================================================
// Native Audio Decoder — Platform channel wrapper for native audio decoding
// =============================================================================
//
// Provides [decodeFile] which calls into the platform's native audio pipeline
// to decode compressed audio formats (MP3, OGG, AAC/M4A, OPUS, etc.) to raw
// mono 16-bit PCM.
//
//   • **Android**: MediaExtractor + MediaCodec (NativeAudioDecoder.kt)
//   • **iOS**: AVAssetReader + AVAssetReaderTrackOutput (NativeAudioDecoder.swift)
//
// Falls back formats not handled by the pure Dart WAV/FLAC decoder in
// [AudioDecoder].
// =============================================================================

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_decoder.dart';

/// Result of a native range decode, including whether the platform decoder
/// reached input EOF before filling the requested range.
class NativeDecodeRangeResult {
  const NativeDecodeRangeResult({
    required this.audio,
    required this.reachedEnd,
  });

  final DecodedAudio audio;
  final bool reachedEnd;
}

/// Result of decoding native audio to a temporary mono PCM16 file.
///
/// The caller owns [pcmPath] and must delete it when done.
class NativePcmFileDecodeResult {
  const NativePcmFileDecodeResult({
    required this.pcmPath,
    required this.sampleRate,
    required this.totalSamples,
  });

  final String pcmPath;
  final int sampleRate;
  final int totalSamples;
}

/// Decodes audio files via the platform's native audio framework.
///
/// Android: MediaExtractor + MediaCodec.
/// iOS: AVAssetReader (AVFoundation).
///
/// Supports any format the platform can handle:
/// MP3, OGG Vorbis, AAC (M4A), OPUS, AMR, WMA, FLAC, WAV, and more.
class NativeAudioDecoder {
  NativeAudioDecoder._();

  static const _channel = MethodChannel('com.birdnet/audio_decoder');

  /// Cancel any running native decode operation.
  static Future<void> cancelDecode() async {
    try {
      await _channel.invokeMethod<void>('cancelDecode');
    } catch (e) {
      // Ignore
    }
  }

  /// Inspect [path] via the platform audio stack without decoding full PCM.
  static Future<AudioMetadata> inspectFile(String path, String format) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('inspect', {
      'path': path,
    });

    if (result == null) {
      throw const FormatException('Native audio inspector returned null');
    }

    final sampleRate = result['sampleRate'] as int;
    final totalSamples = result['totalSamples'] as int;
    return AudioMetadata(
      sampleRate: sampleRate,
      totalSamples: totalSamples,
      format: format,
    );
  }

  /// Decode [path] to mono 16-bit PCM via the platform channel.
  ///
  /// Throws [PlatformException] if the native decoder fails.
  static Future<DecodedAudio> decodeFile(String path) async {
    final decoded = await decodeToTempPcmFile(path);
    final tempFile = File(decoded.pcmPath);
    try {
      final pcmBytes = await tempFile.readAsBytes();

      // Zero-copy convert little-endian byte pairs to Int16List.
      final samples = pcmBytes.buffer.asInt16List(
        pcmBytes.offsetInBytes,
        pcmBytes.lengthInBytes ~/ 2,
      );

      return DecodedAudio(samples: samples, sampleRate: decoded.sampleRate);
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {
          // Ignore
        }
      }
    }
  }

  /// Decode [path] to a temporary mono 16-bit PCM file via the platform channel.
  ///
  /// This avoids transferring or allocating the full decoded PCM buffer in Dart.
  /// The returned file is little-endian PCM16 and must be deleted by the caller.
  static Future<NativePcmFileDecodeResult> decodeToTempPcmFile(
    String path,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final tempPcmPath =
        '${tempDir.path}/temp_decoded_${DateTime.now().microsecondsSinceEpoch}.pcm';
    final tempFile = File(tempPcmPath);

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('decode', {
        'path': path,
        'tempPcmPath': tempPcmPath,
      });

      if (result == null) {
        throw const FormatException('Native audio decoder returned null');
      }

      final sampleRate = result['sampleRate'] as int;
      final totalSamples = result['totalSamples'] as int?;

      if (!await tempFile.exists()) {
        throw const FormatException('Temporary decoded PCM file not found');
      }

      return NativePcmFileDecodeResult(
        pcmPath: tempPcmPath,
        sampleRate: sampleRate,
        totalSamples: totalSamples ?? await tempFile.length() ~/ 2,
      );
    } catch (_) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {
          // Ignore
        }
      }
      rethrow;
    }
  }

  /// Decode a range of samples from [path] to mono 16-bit PCM.
  static Future<DecodedAudio> decodeRange(
    String path, {
    required int startSample,
    required int count,
  }) async {
    final result = await decodeRangeWithStatus(
      path,
      startSample: startSample,
      count: count,
    );
    return result.audio;
  }

  /// Decode a range of samples and report whether native decoding reached EOF.
  static Future<NativeDecodeRangeResult> decodeRangeWithStatus(
    String path, {
    required int startSample,
    required int count,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'decodeRange',
      {'path': path, 'startSample': startSample, 'count': count},
    );

    if (result == null) {
      throw const FormatException('Native audio range decoder returned null');
    }

    final sampleRate = result['sampleRate'] as int;
    final pcmBytes = result['samples'] as Uint8List;
    final reachedEnd = result['reachedEnd'] as bool? ?? false;

    // Zero-copy convert little-endian byte pairs to Int16List.
    final samples = pcmBytes.buffer.asInt16List(
      pcmBytes.offsetInBytes,
      pcmBytes.lengthInBytes ~/ 2,
    );

    return NativeDecodeRangeResult(
      audio: DecodedAudio(samples: samples, sampleRate: sampleRate),
      reachedEnd: reachedEnd,
    );
  }
}
