// =============================================================================
// WAV Writer — Write raw PCM audio samples to a WAV file
// =============================================================================
//
// Provides a pure-Dart utility for writing mono/stereo float32 audio data
// to standard 16-bit PCM WAV files.  Supports both:
//
//   • **One-shot** writing via [WavWriter.writeFile] (in-memory).
//   • **Streaming** writing via [WavWriter] instance (for ongoing recording).
//
// ### WAV Format (RIFF)
//
// ```
// Offset  Size  Field
//   0       4   "RIFF"
//   4       4   File size – 8
//   8       4   "WAVE"
//  12       4   "fmt "
//  16       4   Sub-chunk 1 size (16 for PCM)
//  20       2   Audio format (1 = PCM)
//  22       2   Number of channels
//  24       4   Sample rate
//  28       4   Byte rate (SampleRate × NumChannels × BitsPerSample / 8)
//  32       2   Block align (NumChannels × BitsPerSample / 8)
//  34       2   Bits per sample (16)
//  36       4   "data"
//  40       4   Data sub-chunk size (NumSamples × NumChannels × 2)
//  44      ..   PCM data
// ```
// =============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'audio_file_writer.dart';

/// Utility for writing audio samples to WAV files.
///
/// Supports streaming writes for ongoing recording and one-shot writes for
/// saving audio clips.
class WavWriter implements AudioFileWriter {
  /// Create a streaming WAV writer.
  ///
  /// The file header is written immediately with a placeholder data size.
  /// Call [writeSamples] to append audio data, then [close] to finalize the
  /// header with the correct data size.
  WavWriter({
    required this.filePath,
    this.sampleRate = 32000,
    this.channels = 1,
    this.bitsPerSample = 16,
  });

  @override
  final String filePath;

  /// Audio sample rate in Hz.
  final int sampleRate;

  /// Number of audio channels (1 = mono, 2 = stereo).
  final int channels;

  /// Bits per sample (16 for standard PCM).
  final int bitsPerSample;

  RandomAccessFile? _file;
  int _dataSize = 0;
  bool _closed = false;

  /// Whether the writer has been opened.
  @override
  bool get isOpen => _file != null && !_closed;

  /// Total bytes of PCM data written so far.
  int get dataSize => _dataSize;

  /// Total samples written so far.
  int get samplesWritten => _dataSize ~/ (channels * bitsPerSample ~/ 8);

  /// Duration of audio written so far.
  Duration get duration =>
      Duration(microseconds: (samplesWritten * 1000000 ~/ sampleRate));

  /// Open the file and write the WAV header (with placeholder sizes).
  @override
  Future<void> open() async {
    if (_file != null) return;
    final file = File(filePath);
    await file.parent.create(recursive: true);
    _file = await file.open(mode: FileMode.write);
    _dataSize = 0;
    _closed = false;
    await _writeHeader(_file!, 0);
  }

  /// Append audio samples.
  ///
  /// [samples] should contain float32 values normalized to [-1.0, 1.0].
  /// They are converted to 16-bit PCM integers before writing.
  @override
  Future<void> writeSamples(Float32List samples) async {
    if (_file == null || _closed) {
      throw StateError('WavWriter is not open. Call open() first.');
    }
    final pcm = _float32ToPcm16(samples);
    await _file!.writeFrom(pcm);
    _dataSize += pcm.length;
  }

  /// Finalize the WAV header and close the file.
  ///
  /// After calling this, the writer cannot be used again.
  @override
  Future<void> close() async {
    if (_file == null || _closed) return;
    _closed = true;

    // Rewrite header with correct sizes.
    await _file!.setPosition(0);
    await _writeHeader(_file!, _dataSize);
    await _file!.close();
    _file = null;
  }

  // ---------------------------------------------------------------------------
  // One-shot API
  // ---------------------------------------------------------------------------

  /// Write a complete WAV file from float32 samples.
  ///
  /// This is a convenience method for saving audio clips in one go.
  static Future<void> writeFile({
    required String filePath,
    required Float32List samples,
    int sampleRate = 32000,
    int channels = 1,
  }) async {
    final writer = WavWriter(
      filePath: filePath,
      sampleRate: sampleRate,
      channels: channels,
    );
    await writer.open();
    await writer.writeSamples(samples);
    await writer.close();
  }

  /// Generate a complete WAV file as bytes (in-memory).
  ///
  /// Useful for testing or when a file path is not needed.
  static Uint8List toBytes({
    required Float32List samples,
    int sampleRate = 32000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final pcmData = _float32ToPcm16(samples);
    final dataSize = pcmData.length;
    final fileSize = 44 + dataSize;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;

    final buffer = ByteData(fileSize);
    var offset = 0;

    // RIFF header
    buffer.setUint8(offset++, 0x52); // R
    buffer.setUint8(offset++, 0x49); // I
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint32(offset, fileSize - 8, Endian.little);
    offset += 4;

    // WAVE
    buffer.setUint8(offset++, 0x57); // W
    buffer.setUint8(offset++, 0x41); // A
    buffer.setUint8(offset++, 0x56); // V
    buffer.setUint8(offset++, 0x45); // E

    // fmt sub-chunk
    buffer.setUint8(offset++, 0x66); // f
    buffer.setUint8(offset++, 0x6D); // m
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x20); //
    buffer.setUint32(offset, 16, Endian.little); // Sub-chunk size
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM format
    offset += 2;
    buffer.setUint16(offset, channels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    buffer.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    buffer.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;

    // data sub-chunk
    buffer.setUint8(offset++, 0x64); // d
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // PCM data
    final result = buffer.buffer.asUint8List();
    result.setRange(44, fileSize, pcmData);

    return result;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Write a 44-byte WAV header to [file] with the given [dataSize].
  static Future<void> _writeHeader(
    RandomAccessFile file,
    int dataSize,
  ) async {
    final header = Uint8List(44);
    final view = ByteData.view(header.buffer);
    const sampleRate = 32000;
    const channels = 1;
    const bitsPerSample = 16;
    const byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;

    var offset = 0;
    // RIFF
    header[offset++] = 0x52;
    header[offset++] = 0x49;
    header[offset++] = 0x46;
    header[offset++] = 0x46;
    view.setUint32(offset, 36 + dataSize, Endian.little);
    offset += 4;
    // WAVE
    header[offset++] = 0x57;
    header[offset++] = 0x41;
    header[offset++] = 0x56;
    header[offset++] = 0x45;
    // fmt
    header[offset++] = 0x66;
    header[offset++] = 0x6D;
    header[offset++] = 0x74;
    header[offset++] = 0x20;
    view.setUint32(offset, 16, Endian.little);
    offset += 4;
    view.setUint16(offset, 1, Endian.little);
    offset += 2;
    view.setUint16(offset, channels, Endian.little);
    offset += 2;
    view.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    view.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    view.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    view.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;
    // data
    header[offset++] = 0x64;
    header[offset++] = 0x61;
    header[offset++] = 0x74;
    header[offset++] = 0x61;
    view.setUint32(offset, dataSize, Endian.little);

    await file.writeFrom(header);
  }

  /// Convert float32 samples ([-1.0, 1.0]) to 16-bit signed PCM bytes
  /// (little-endian).
  static Uint8List _float32ToPcm16(Float32List samples) {
    final length = samples.length;
    final bytes = Uint8List(length * 2);
    final view = ByteData.view(bytes.buffer);

    for (var i = 0; i < length; i++) {
      // Clamp to [-1.0, 1.0] then scale to int16 range.
      var sample = samples[i];
      if (sample > 1.0) sample = 1.0;
      if (sample < -1.0) sample = -1.0;
      final int16 = (sample * 32767).round();
      view.setInt16(i * 2, int16, Endian.little);
    }

    return bytes;
  }
}
