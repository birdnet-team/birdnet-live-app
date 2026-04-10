// =============================================================================
// Audio Decoder — Decode WAV and FLAC files to raw PCM samples
// =============================================================================
//
// Provides file→PCM decoding for session review spectrograms.  Supports:
//
//   • **WAV** — Standard RIFF/WAVE mono 16-bit PCM.  Header is parsed to
//     locate the `data` chunk; samples are read directly.
//
//   • **FLAC** — Lossless codec.  The decoder handles the subset of FLAC
//     produced by our [FlacEncoder]: mono 16-bit with CONSTANT, VERBATIM,
//     and FIXED subframes (orders 0–4), Rice-coded residuals.
//
// ### Usage
//
// ```dart
// final audio = await AudioDecoder.decodeFile('session.flac');
// final window = audio.readFloat32(startSample, 32000); // 1 second
// ```
//
// ### Threading
//
// Decoding large files can take a few hundred milliseconds.  Callers should
// run [decodeFile] via `Isolate.run()` or `compute()` when the file size
// exceeds a few megabytes.
// =============================================================================

import 'dart:io';
import 'dart:typed_data';

/// Result of decoding an audio file to raw PCM.
class DecodedAudio {
  DecodedAudio({
    required this.samples,
    required this.sampleRate,
  });

  /// Raw mono PCM samples as signed 16-bit integers.
  final Int16List samples;

  /// Sample rate in Hz.
  final int sampleRate;

  /// Total number of samples in the file.
  int get totalSamples => samples.length;

  /// Duration of the audio.
  Duration get duration =>
      Duration(microseconds: totalSamples * 1000000 ~/ sampleRate);

  /// Read a range of samples as normalized Float32 ([-1.0, 1.0]).
  ///
  /// Returns exactly [count] samples.  If the range extends past the end
  /// of the file, trailing samples are zero-filled.
  Float32List readFloat32(int start, int count) {
    final result = Float32List(count);
    final safeStart = start.clamp(0, totalSamples);
    final safeEnd = (start + count).clamp(0, totalSamples);
    for (var i = safeStart; i < safeEnd; i++) {
      result[i - start] = samples[i] / 32768.0;
    }
    return result;
  }
}

/// Decodes audio files to raw PCM samples.
class AudioDecoder {
  AudioDecoder._();

  /// Check whether the file can be decoded by the pure-Dart decoders
  /// (WAV or FLAC), based on magic bytes.  Reads only the first 4 bytes.
  static Future<bool> canDecodeDart(String path) async {
    final file = File(path);
    final raf = await file.open();
    try {
      final header = await raf.read(4);
      if (header.length < 4) return false;
      // WAV: RIFF header.
      if (header[0] == 0x52 &&
          header[1] == 0x49 &&
          header[2] == 0x46 &&
          header[3] == 0x46) {
        return true;
      }
      // FLAC: fLaC header.
      if (header[0] == 0x66 &&
          header[1] == 0x4C &&
          header[2] == 0x61 &&
          header[3] == 0x43) {
        return true;
      }
      return false;
    } finally {
      await raf.close();
    }
  }

  /// Auto-detect format (WAV or FLAC) and decode.
  ///
  /// For compressed formats (MP3, OGG, AAC, etc.) this will throw a
  /// [FormatException].  Use [NativeAudioDecoder.decodeFile] instead.
  static Future<DecodedAudio> decodeFile(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    if (bytes.length < 4) {
      throw FormatException('File too small to be an audio file: $path');
    }

    // Check magic bytes.
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return _decodeWav(bytes);
    }
    if (bytes[0] == 0x66 &&
        bytes[1] == 0x4C &&
        bytes[2] == 0x61 &&
        bytes[3] == 0x43) {
      return _decodeFlac(bytes);
    }

    throw FormatException('Unknown audio format (not WAV or FLAC): $path');
  }

  // ── WAV Decoder ─────────────────────────────────────────────────────────

  static DecodedAudio _decodeWav(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);

    // Parse RIFF header.
    // Bytes 0-3: "RIFF"
    // Bytes 8-11: "WAVE"
    if (bytes[8] != 0x57 ||
        bytes[9] != 0x41 ||
        bytes[10] != 0x56 ||
        bytes[11] != 0x45) {
      throw const FormatException('Not a valid WAVE file');
    }

    // Scan for "fmt " and "data" chunks.
    int sampleRate = 0;
    int bitsPerSample = 0;
    int channels = 0;
    int dataOffset = 0;
    int dataSize = 0;

    var pos = 12;
    while (pos + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes, pos, pos + 4);
      final chunkSize = bd.getUint32(pos + 4, Endian.little);

      if (chunkId == 'fmt ') {
        channels = bd.getUint16(pos + 10, Endian.little);
        sampleRate = bd.getUint32(pos + 12, Endian.little);
        bitsPerSample = bd.getUint16(pos + 22, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = pos + 8;
        dataSize = chunkSize;
        break;
      }

      pos += 8 + chunkSize;
      if (pos.isOdd) pos++; // Chunks are word-aligned.
    }

    if (sampleRate == 0 || dataOffset == 0) {
      throw const FormatException('WAV file missing fmt or data chunk');
    }

    if (bitsPerSample != 16) {
      throw FormatException(
          'Only 16-bit WAV supported, got $bitsPerSample-bit');
    }

    // Read Int16 samples (mono channel 0 only).
    final bytesPerSample = bitsPerSample ~/ 8;
    final totalFrames = dataSize ~/ (bytesPerSample * channels);
    final samples = Int16List(totalFrames);
    final dataView = ByteData.sublistView(bytes, dataOffset);

    for (var i = 0; i < totalFrames; i++) {
      samples[i] =
          dataView.getInt16(i * channels * bytesPerSample, Endian.little);
    }

    return DecodedAudio(samples: samples, sampleRate: sampleRate);
  }

  // ── FLAC Decoder ────────────────────────────────────────────────────────

  static DecodedAudio _decodeFlac(Uint8List bytes) {
    // Parse STREAMINFO.
    if (bytes.length < 42) {
      throw const FormatException('FLAC file too short for STREAMINFO');
    }

    // Byte 4: metadata header.  Bytes 8–41: STREAMINFO body (34 bytes).
    final si = ByteData.sublistView(bytes, 8, 42);

    final maxBlock = si.getUint16(2, Endian.big);

    // Bytes 10-12: sample rate (20 bits), channels-1 (3 bits), bps-1 (5 bits).
    final sampleRate = (bytes[18] << 12) | (bytes[19] << 4) | (bytes[20] >> 4);
    final bps = ((bytes[20] & 0x01) << 4) | (bytes[21] >> 4);
    final bitsPerSample = bps + 1;

    // Total samples (36 bits at bytes 21[3:0] and 22-25).
    final totalHigh = bytes[21] & 0x0F;
    final totalLow =
        ByteData.sublistView(bytes, 22, 26).getUint32(0, Endian.big);
    final totalSamples = (totalHigh << 32) | totalLow;

    if (bitsPerSample != 16) {
      throw FormatException(
        'Only 16-bit FLAC supported, got $bitsPerSample-bit',
      );
    }

    // Skip metadata blocks to find the first audio frame.
    var pos = 4;
    while (pos + 4 <= bytes.length) {
      final isLast = (bytes[pos] & 0x80) != 0;
      final blockLen =
          (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) | bytes[pos + 3];
      pos += 4 + blockLen;
      if (isLast) break;
    }

    // Decode audio frames.
    final allSamples = Int16List(totalSamples);
    var samplePos = 0;
    final reader = _BitReader(bytes, pos);

    while (samplePos < totalSamples && reader.bytesRemaining > 2) {
      final frameResult = _decodeFrame(reader, maxBlock, bitsPerSample);
      if (frameResult == null) break;

      final count = frameResult.length.clamp(0, totalSamples - samplePos);
      for (var i = 0; i < count; i++) {
        allSamples[samplePos + i] = frameResult[i];
      }
      samplePos += count;
    }

    return DecodedAudio(samples: allSamples, sampleRate: sampleRate);
  }

  /// Decode a single FLAC audio frame.  Returns the decoded Int16 samples,
  /// or null if no more frames can be read.
  static Int16List? _decodeFrame(
    _BitReader reader,
    int maxBlockSize,
    int bitsPerSample,
  ) {
    // Scan for frame sync: 0xFFF8 (14 ones + reserved 0 + strategy 0).
    // The sync code is 0b 1111_1111 1111_10xx where xx encodes the
    // blocking strategy.
    if (!_syncToFrame(reader)) return null;

    // Already consumed 2 sync bytes.  Next nibble is block-size code.
    final bsAndSr = reader.readBits(8);
    final blockSizeCode = bsAndSr >> 4;
    final sampleRateCode = bsAndSr & 0x0F;

    reader.readBits(8);
    // ignore channel and bps — we know from STREAMINFO.

    // Frame number (FLAC UTF-8 encoding).
    _readFlacUtf8(reader);

    // Optional block size / sample rate fields.
    int blockSize;
    if (blockSizeCode == 0x06) {
      blockSize = reader.readBits(8) + 1;
    } else if (blockSizeCode == 0x07) {
      blockSize = reader.readBits(16) + 1;
    } else {
      blockSize = _blockSizeFromCode(blockSizeCode);
    }

    if (sampleRateCode == 0x0C) {
      reader.readBits(8); // sample rate in kHz
    } else if (sampleRateCode == 0x0D || sampleRateCode == 0x0E) {
      reader.readBits(16); // sample rate in Hz or 10×Hz
    }

    // CRC-8 of header.
    reader.readBits(8);

    // Decode subframe (mono = 1 channel).
    final samples = _decodeSubframe(reader, blockSize, bitsPerSample);

    // Byte-align.
    reader.alignToByte();

    // CRC-16.
    reader.readBits(16);

    return samples;
  }

  /// Scan forward to find the 0xFFF8/0xFFF9 frame sync pattern.
  static bool _syncToFrame(_BitReader reader) {
    reader.alignToByte();
    while (reader.bytesRemaining >= 2) {
      final b = reader.peekByte();
      if (b == 0xFF) {
        final pos = reader.bytePosition;
        reader.readBits(8);
        final next = reader.readBits(8);
        if ((next & 0xFC) == 0xF8) {
          return true;
        }
        // Not a sync — rewind to pos+1 and keep scanning.
        reader.seekByte(pos + 1);
      } else {
        reader.readBits(8);
      }
    }
    return false;
  }

  /// Decode a FLAC UTF-8 coded value (used for frame numbers).
  static int _readFlacUtf8(_BitReader reader) {
    var first = reader.readBits(8);
    if (first < 0x80) return first;

    int nExtra;
    int value;
    if (first < 0xC0) {
      return first; // Invalid, treat as literal.
    } else if (first < 0xE0) {
      nExtra = 1;
      value = first & 0x1F;
    } else if (first < 0xF0) {
      nExtra = 2;
      value = first & 0x0F;
    } else if (first < 0xF8) {
      nExtra = 3;
      value = first & 0x07;
    } else if (first < 0xFC) {
      nExtra = 4;
      value = first & 0x03;
    } else if (first < 0xFE) {
      nExtra = 5;
      value = first & 0x01;
    } else {
      nExtra = 6;
      value = 0;
    }
    for (var i = 0; i < nExtra; i++) {
      value = (value << 6) | (reader.readBits(8) & 0x3F);
    }
    return value;
  }

  /// Map block-size code to actual size.
  static int _blockSizeFromCode(int code) {
    switch (code) {
      case 0x01:
        return 192;
      case 0x02:
        return 576;
      case 0x03:
        return 1152;
      case 0x04:
        return 2304;
      case 0x05:
        return 4608;
      case 0x08:
        return 256;
      case 0x09:
        return 512;
      case 0x0A:
        return 1024;
      case 0x0B:
        return 2048;
      case 0x0C:
        return 4096;
      case 0x0D:
        return 8192;
      case 0x0E:
        return 16384;
      case 0x0F:
        return 32768;
      default:
        return 4096;
    }
  }

  /// Decode a single subframe from the bitstream.
  static Int16List _decodeSubframe(
    _BitReader reader,
    int blockSize,
    int bitsPerSample,
  ) {
    // Subframe header: 1 pad bit + 6 type bits + 1 wasted-bits flag.
    final header = reader.readBits(8);
    final typeBits = (header >> 1) & 0x3F;
    final hasWasted = (header & 0x01) != 0;

    int wastedBits = 0;
    if (hasWasted) {
      // Unary-coded wasted bits per sample.
      wastedBits = 1;
      while (reader.readBits(1) == 0) {
        wastedBits++;
      }
    }
    final effectiveBps = bitsPerSample - wastedBits;

    Int16List samples;

    if (typeBits == 0x00) {
      // CONSTANT: one sample value repeated.
      final value = reader.readSignedBits(effectiveBps);
      samples = Int16List(blockSize);
      for (var i = 0; i < blockSize; i++) {
        samples[i] = (value << wastedBits).toInt();
      }
    } else if (typeBits == 0x01) {
      // VERBATIM: raw samples.
      samples = Int16List(blockSize);
      for (var i = 0; i < blockSize; i++) {
        samples[i] = (reader.readSignedBits(effectiveBps) << wastedBits);
      }
    } else if (typeBits >= 0x08 && typeBits <= 0x0C) {
      // FIXED predictor, order = typeBits - 8.
      final order = typeBits - 0x08;
      samples = _decodeFixedSubframe(reader, blockSize, effectiveBps, order);
      if (wastedBits > 0) {
        for (var i = 0; i < blockSize; i++) {
          samples[i] = (samples[i] << wastedBits);
        }
      }
    } else {
      // Unsupported subframe type — fill with silence.
      samples = Int16List(blockSize);
    }

    return samples;
  }

  /// Decode a FIXED-predictor subframe.
  static Int16List _decodeFixedSubframe(
    _BitReader reader,
    int blockSize,
    int bps,
    int order,
  ) {
    final samples = Int16List(blockSize);

    // Read warm-up samples.
    for (var i = 0; i < order; i++) {
      samples[i] = reader.readSignedBits(bps);
    }

    // Read Rice-coded residuals.
    final residuals = _decodeRicePartition(reader, blockSize, order);

    // Apply fixed predictor restoration.
    for (var i = order; i < blockSize; i++) {
      int predicted;
      switch (order) {
        case 0:
          predicted = 0;
          break;
        case 1:
          predicted = samples[i - 1];
          break;
        case 2:
          predicted = 2 * samples[i - 1] - samples[i - 2];
          break;
        case 3:
          predicted = 3 * samples[i - 1] - 3 * samples[i - 2] + samples[i - 3];
          break;
        case 4:
          predicted = 4 * samples[i - 1] -
              6 * samples[i - 2] +
              4 * samples[i - 3] -
              samples[i - 4];
          break;
        default:
          predicted = 0;
      }
      samples[i] = (predicted + residuals[i - order]).toInt();
    }

    return samples;
  }

  /// Decode Rice-coded residual partition.
  static List<int> _decodeRicePartition(
    _BitReader reader,
    int blockSize,
    int predictorOrder,
  ) {
    final method = reader.readBits(2); // 0 = RICE, 1 = RICE2
    final partitionOrder = reader.readBits(4);
    final nPartitions = 1 << partitionOrder;
    final paramBits = method == 0 ? 4 : 5;
    final escapeCode = method == 0 ? 15 : 31;

    final residuals = <int>[];

    for (var p = 0; p < nPartitions; p++) {
      final samplesInPartition = p == 0
          ? (blockSize >> partitionOrder) - predictorOrder
          : (blockSize >> partitionOrder);

      final riceParam = reader.readBits(paramBits);

      if (riceParam == escapeCode) {
        // Escaped: raw signed samples.
        final rawBits = reader.readBits(5);
        for (var i = 0; i < samplesInPartition; i++) {
          residuals.add(reader.readSignedBits(rawBits));
        }
      } else {
        for (var i = 0; i < samplesInPartition; i++) {
          // Read unary quotient (count of 0s terminated by 1).
          var quotient = 0;
          while (reader.readBits(1) == 0) {
            quotient++;
          }
          // Read remainder.
          final remainder = riceParam > 0 ? reader.readBits(riceParam) : 0;
          final unsigned = (quotient << riceParam) | remainder;

          // Undo zigzag encoding.
          final signed =
              (unsigned & 1) == 0 ? unsigned >> 1 : -((unsigned >> 1) + 1);
          residuals.add(signed);
        }
      }
    }

    return residuals;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bit Reader — MSB-first bit-level reader for FLAC bitstream
// ─────────────────────────────────────────────────────────────────────────────

class _BitReader {
  _BitReader(this._data, this._bytePos);

  final Uint8List _data;
  int _bytePos;
  int _bitPos = 0; // 0 = MSB, 7 = LSB within current byte.

  int get bytePosition => _bytePos;
  int get bytesRemaining => _data.length - _bytePos;

  int peekByte() => _data[_bytePos];

  void seekByte(int pos) {
    _bytePos = pos;
    _bitPos = 0;
  }

  void alignToByte() {
    if (_bitPos > 0) {
      _bytePos++;
      _bitPos = 0;
    }
  }

  /// Read [n] bits as an unsigned integer (MSB-first).
  int readBits(int n) {
    var result = 0;
    for (var i = 0; i < n; i++) {
      if (_bytePos >= _data.length) return result;
      result = (result << 1) | ((_data[_bytePos] >> (7 - _bitPos)) & 1);
      _bitPos++;
      if (_bitPos == 8) {
        _bitPos = 0;
        _bytePos++;
      }
    }
    return result;
  }

  /// Read [n] bits as a signed two's-complement integer.
  int readSignedBits(int n) {
    if (n == 0) return 0;
    final unsigned = readBits(n);
    // Sign-extend.
    if (unsigned >= (1 << (n - 1))) {
      return unsigned - (1 << n);
    }
    return unsigned;
  }
}
