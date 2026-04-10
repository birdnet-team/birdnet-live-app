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

import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'audio_decoder.dart';

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

  /// Decode [path] to mono 16-bit PCM via the platform channel.
  ///
  /// Throws [PlatformException] if the native decoder fails.
  static Future<DecodedAudio> decodeFile(String path) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'decode',
      {'path': path},
    );

    if (result == null) {
      throw const FormatException('Native audio decoder returned null');
    }

    final sampleRate = result['sampleRate'] as int;
    final totalSamples = result['totalSamples'] as int;
    final pcmBytes = result['samples'] as Uint8List;

    // Convert little-endian byte pairs to Int16List.
    final samples = Int16List(totalSamples);
    final bd = ByteData.sublistView(pcmBytes);
    for (var i = 0; i < totalSamples; i++) {
      samples[i] = bd.getInt16(i * 2, Endian.little);
    }

    return DecodedAudio(
      samples: samples,
      sampleRate: sampleRate,
    );
  }
}
