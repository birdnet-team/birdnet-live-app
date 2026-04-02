// =============================================================================
// FLAC Encoder — Pure Dart FLAC audio file encoder
// =============================================================================
//
// Encodes raw PCM audio samples into the FLAC (Free Lossless Audio Codec)
// format. Designed for mono 16-bit audio at 32 kHz (BirdNET's native rate),
// but works with any sample rate and bit depth up to 24-bit.
//
// ### Why a custom encoder?
//
// The recording pipeline captures raw PCM via the `record` package for
// real-time inference.  There is no mature pure-Dart FLAC encoder on pub.dev,
// and platform encoders (MediaCodec, AVAudioConverter) would add complexity
// without cross-platform parity.  A fixed-predictor FLAC encoder is
// straightforward (~350 lines) and achieves 50–60 % compression on typical
// bird audio.
//
// ### FLAC format overview
//
// A FLAC file consists of:
//
//   1. **Magic number** — 4 bytes: `fLaC`
//   2. **STREAMINFO metadata block** — 38 bytes (4-byte header + 34-byte body)
//      describing sample rate, channels, bit depth, total samples, and
//      min/max block & frame sizes.
//   3. **Audio frames** — each frame encodes a fixed-size block of samples
//      (default 4096) with a frame header, one subframe per channel, byte
//      padding, and a CRC-16 footer.
//
// Each subframe uses the best of three strategies:
//
//   • **CONSTANT** — all samples identical (e.g., silence): 1 sample value.
//   • **VERBATIM** — raw uncompressed samples (fallback).
//   • **FIXED predictor** (orders 0–4) with Rice-coded residuals — the main
//     compression path.  The encoder tries all five orders, picks the one
//     with the smallest residual energy, then Rice-codes the residuals.
//
// ### Streaming API
//
// ```dart
// final enc = FlacEncoder(filePath: 'out.flac');
// await enc.open();
// await enc.writeSamples(chunk1);  // call as many times as needed
// await enc.writeSamples(chunk2);
// await enc.close();               // finalizes STREAMINFO
// ```
//
// ### One-shot API
//
// ```dart
// await FlacEncoder.writeFile(filePath: 'out.flac', samples: allSamples);
// ```
//
// ### References
//
// - FLAC format specification: https://xiph.org/flac/format.html
// - FLAC reference encoder source (libFLAC): https://github.com/xiph/flac
// =============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'audio_file_writer.dart';

/// Default FLAC block size in samples.
///
/// 4096 is a common choice balancing compression ratio and seek granularity.
const int kFlacBlockSize = 4096;

// =============================================================================
// CRC lookup tables
// =============================================================================
//
// FLAC uses two checksums:
//   - CRC-8  (polynomial 0x07) for the frame header.
//   - CRC-16 (polynomial 0x8005) for the entire frame.

final List<int> _crc8Table = List<int>.generate(256, (i) {
  int crc = i;
  for (int j = 0; j < 8; j++) {
    crc = (crc & 0x80) != 0 ? ((crc << 1) ^ 0x07) & 0xFF : (crc << 1) & 0xFF;
  }
  return crc;
});

int _crc8(List<int> data) {
  int crc = 0;
  for (final b in data) {
    crc = _crc8Table[(crc ^ b) & 0xFF];
  }
  return crc;
}

final List<int> _crc16Table = List<int>.generate(256, (i) {
  int crc = i << 8;
  for (int j = 0; j < 8; j++) {
    crc = (crc & 0x8000) != 0
        ? ((crc << 1) ^ 0x8005) & 0xFFFF
        : (crc << 1) & 0xFFFF;
  }
  return crc;
});

int _crc16(List<int> data) {
  int crc = 0;
  for (final b in data) {
    crc = (((crc << 8) & 0xFFFF) ^ _crc16Table[((crc >> 8) ^ b) & 0xFF]);
  }
  return crc;
}

// =============================================================================
// Bit-level writer (MSB-first)
// =============================================================================

/// Bit-level MSB-first writer backed by a [BytesBuilder].
///
/// Uses [BytesBuilder] (internally a [Uint8List]) instead of a plain
/// [List<int>] to avoid the 8× memory overhead that Dart's tagged-pointer
/// representation imposes on growable integer lists.  Each byte is stored
/// as a single byte rather than an 8-byte heap slot, cutting the temporary
/// allocation per FLAC frame from ~40 KB down to ~5 KB.
class _BitWriter {
  final _bb = BytesBuilder();
  int _buffer = 0;
  int _bits = 0;

  /// Write [n] bits of [value], MSB first.
  void writeBits(int value, int n) {
    for (int i = n - 1; i >= 0; i--) {
      _buffer = (_buffer << 1) | ((value >> i) & 1);
      _bits++;
      if (_bits == 8) {
        _bb.addByte(_buffer & 0xFF);
        _buffer = 0;
        _bits = 0;
      }
    }
  }

  /// Write unary code: [value] zeros followed by a one.
  void writeUnary(int value) {
    for (int i = 0; i < value; i++) {
      writeBits(0, 1);
    }
    writeBits(1, 1);
  }

  /// Pad the current byte with trailing zeros.
  void padToByte() {
    if (_bits > 0) writeBits(0, 8 - _bits);
  }

  /// Return all accumulated bytes as a [Uint8List].
  Uint8List toBytes() => _bb.toBytes();
}

// =============================================================================
// UTF-8 frame number encoding (FLAC variant, up to 36 bits)
// =============================================================================

List<int> _utf8Encode(int v) {
  if (v < 0x80) return [v];
  if (v < 0x800) {
    return [0xC0 | (v >> 6), 0x80 | (v & 0x3F)];
  }
  if (v < 0x10000) {
    return [
      0xE0 | (v >> 12),
      0x80 | ((v >> 6) & 0x3F),
      0x80 | (v & 0x3F),
    ];
  }
  if (v < 0x200000) {
    return [
      0xF0 | (v >> 18),
      0x80 | ((v >> 12) & 0x3F),
      0x80 | ((v >> 6) & 0x3F),
      0x80 | (v & 0x3F),
    ];
  }
  if (v < 0x4000000) {
    return [
      0xF8 | (v >> 24),
      0x80 | ((v >> 18) & 0x3F),
      0x80 | ((v >> 12) & 0x3F),
      0x80 | ((v >> 6) & 0x3F),
      0x80 | (v & 0x3F),
    ];
  }
  return [
    0xFC | (v >> 30),
    0x80 | ((v >> 24) & 0x3F),
    0x80 | ((v >> 18) & 0x3F),
    0x80 | ((v >> 12) & 0x3F),
    0x80 | ((v >> 6) & 0x3F),
    0x80 | (v & 0x3F),
  ];
}

// =============================================================================
// Field encoding helpers
// =============================================================================

/// 4-bit block size code for the frame header.
int _blockSizeCode(int size) {
  if (size == 192) return 1;
  if (size == 576) return 2;
  if (size == 1152) return 3;
  if (size == 2304) return 4;
  if (size == 4608) return 5;
  // Powers of two from 256 to 32768.
  if (size >= 256 && size <= 32768 && (size & (size - 1)) == 0) {
    int n = 0, s = size >> 8;
    while (s > 1) {
      s >>= 1;
      n++;
    }
    return 8 + n;
  }
  // Explicit size in end-of-header bytes.
  return (size <= 256) ? 6 : 7;
}

/// 4-bit sample rate code.
int _sampleRateCode(int rate) {
  const codes = <int, int>{
    88200: 1, 176400: 2, 192000: 3, 8000: 4, 16000: 5, //
    22050: 6, 24000: 7, 32000: 8, 44100: 9, 48000: 10, 96000: 11,
  };
  return codes[rate] ?? 0; // 0 = read from STREAMINFO
}

/// 3-bit sample size code.
int _sampleSizeCode(int bits) {
  const codes = <int, int>{8: 1, 12: 2, 16: 4, 20: 5, 24: 6};
  return codes[bits] ?? 0;
}

// =============================================================================
// Fixed-order prediction and Rice coding
// =============================================================================

/// Compute prediction residuals for a given fixed predictor [order] (0–4).
///
/// The returned list has `samples.length - order` elements.
Int32List _computeResiduals(Int16List samples, int order) {
  final n = samples.length;
  final r = Int32List(n - order);
  switch (order) {
    case 0:
      for (int i = 0; i < n; i++) {
        r[i] = samples[i];
      }
    case 1:
      for (int i = order; i < n; i++) {
        r[i - order] = samples[i] - samples[i - 1];
      }
    case 2:
      for (int i = order; i < n; i++) {
        r[i - order] = samples[i] - 2 * samples[i - 1] + samples[i - 2];
      }
    case 3:
      for (int i = order; i < n; i++) {
        r[i - order] = samples[i] -
            3 * samples[i - 1] +
            3 * samples[i - 2] -
            samples[i - 3];
      }
    case 4:
      for (int i = order; i < n; i++) {
        r[i - order] = samples[i] -
            4 * samples[i - 1] +
            6 * samples[i - 2] -
            4 * samples[i - 3] +
            samples[i - 4];
      }
  }
  return r;
}

/// Zigzag-encode a signed integer to unsigned (FLAC convention).
int _zigzag(int v) => v >= 0 ? v << 1 : ((-v) << 1) - 1;

/// Total bits needed to Rice-encode [residuals] with parameter [k].
int _riceEncodedBits(Int32List residuals, int k) {
  int bits = 0;
  for (final r in residuals) {
    final u = _zigzag(r);
    bits += (u >> k) + 1 + k;
  }
  return bits;
}

/// Find the Rice parameter (0–14) that minimizes encoded size.
int _bestRiceParam(Int32List residuals) {
  if (residuals.isEmpty) return 0;

  // Quick estimate from mean absolute value.
  int sum = 0;
  for (final r in residuals) {
    sum += r < 0 ? -r : r;
  }
  final mean = sum ~/ residuals.length;
  int est = 0;
  int m = mean;
  while (m > 1) {
    est++;
    m >>= 1;
  }

  // Search around the estimate.
  int bestK = est.clamp(0, 14);
  int bestBits = _riceEncodedBits(residuals, bestK);

  for (int k = (est - 2).clamp(0, 14); k <= (est + 2).clamp(0, 14); k++) {
    if (k == bestK) continue;
    final bits = _riceEncodedBits(residuals, k);
    if (bits < bestBits) {
      bestBits = bits;
      bestK = k;
    }
  }
  return bestK;
}

// =============================================================================
// Subframe selection
// =============================================================================

enum _SubframeType { constant, verbatim, fixed }

class _SubframeChoice {
  const _SubframeChoice(this.type, this.order, this.riceParam, this.bits);
  final _SubframeType type;
  final int order;
  final int riceParam;
  final int bits;
}

/// Choose the smallest subframe encoding for [samples] at [bps] bits/sample.
_SubframeChoice _bestSubframe(Int16List samples, int bps) {
  final n = samples.length;

  // ── CONSTANT ──────────────────────────────────────────────────────────
  bool allSame = true;
  for (int i = 1; i < n; i++) {
    if (samples[i] != samples[0]) {
      allSame = false;
      break;
    }
  }
  if (allSame) {
    return _SubframeChoice(_SubframeType.constant, 0, 0, 8 + bps);
  }

  // ── VERBATIM ──────────────────────────────────────────────────────────
  final verbatimBits = 8 + n * bps;

  // ── FIXED predictors (orders 0–4) ────────────────────────────────────
  int bestOrder = -1;
  int bestK = 0;
  int bestFixedBits = verbatimBits + 1; // worse than verbatim by default

  for (int order = 0; order <= 4 && order < n; order++) {
    final residuals = _computeResiduals(samples, order);
    final k = _bestRiceParam(residuals);
    // 8 header + warm-up + 2 coding method + 4 partition order + 4 rice param
    final bits = 8 + order * bps + 2 + 4 + 4 + _riceEncodedBits(residuals, k);
    if (bits < bestFixedBits) {
      bestFixedBits = bits;
      bestOrder = order;
      bestK = k;
    }
  }

  if (bestFixedBits < verbatimBits) {
    return _SubframeChoice(
        _SubframeType.fixed, bestOrder, bestK, bestFixedBits);
  }
  return _SubframeChoice(_SubframeType.verbatim, 0, 0, verbatimBits);
}

// =============================================================================
// Subframe writing
// =============================================================================

void _writeSubframe(
    _BitWriter w, Int16List samples, int bps, _SubframeChoice choice) {
  w.writeBits(0, 1); // zero padding bit

  switch (choice.type) {
    case _SubframeType.constant:
      w.writeBits(0, 6); // type = CONSTANT
      w.writeBits(0, 1); // no wasted bits
      w.writeBits(samples[0] & ((1 << bps) - 1), bps);

    case _SubframeType.verbatim:
      w.writeBits(1, 6); // type = VERBATIM
      w.writeBits(0, 1); // no wasted bits
      for (int i = 0; i < samples.length; i++) {
        w.writeBits(samples[i] & ((1 << bps) - 1), bps);
      }

    case _SubframeType.fixed:
      w.writeBits(8 + choice.order, 6); // type = FIXED, order in low 3 bits
      w.writeBits(0, 1); // no wasted bits
      // Warm-up samples (signed, bps bits each).
      for (int i = 0; i < choice.order; i++) {
        w.writeBits(samples[i] & ((1 << bps) - 1), bps);
      }
      // Residual.
      final residuals = _computeResiduals(samples, choice.order);
      w.writeBits(0, 2); // coding method 00 = Rice, 4-bit param
      w.writeBits(0, 4); // partition order 0 = 1 partition
      w.writeBits(choice.riceParam, 4);
      for (final r in residuals) {
        final u = _zigzag(r);
        w.writeUnary(u >> choice.riceParam);
        if (choice.riceParam > 0) {
          w.writeBits(u & ((1 << choice.riceParam) - 1), choice.riceParam);
        }
      }
  }
}

// =============================================================================
// Frame encoding
// =============================================================================

/// Encode one FLAC frame containing [samples] for the given [frameNumber].
Uint8List _encodeFrame(
    Int16List samples, int frameNumber, int sampleRate, int bps) {
  final bsc = _blockSizeCode(samples.length);

  // ── Frame header ──────────────────────────────────────────────────────
  final hw = _BitWriter();
  hw.writeBits(0x3FFE, 14); // sync code
  hw.writeBits(0, 1); //       reserved
  hw.writeBits(0, 1); //       blocking strategy = fixed block size
  hw.writeBits(bsc, 4); //     block size code
  hw.writeBits(_sampleRateCode(sampleRate), 4);
  hw.writeBits(0, 4); //       channel assignment (0 = mono)
  hw.writeBits(_sampleSizeCode(bps), 3);
  hw.writeBits(0, 1); //       reserved
  for (final b in _utf8Encode(frameNumber)) {
    hw.writeBits(b, 8);
  }
  // Optional block size bytes.
  if (bsc == 6) hw.writeBits(samples.length - 1, 8);
  if (bsc == 7) hw.writeBits(samples.length - 1, 16);

  final headerBytes = hw.toBytes();
  final crc8 = _crc8(headerBytes);

  // ── Subframe ──────────────────────────────────────────────────────────
  final choice = _bestSubframe(samples, bps);
  final sw = _BitWriter();
  _writeSubframe(sw, samples, bps, choice);
  sw.padToByte();
  final subBytes = sw.toBytes();

  // ── Assemble: header + CRC-8 + subframe + CRC-16 ─────────────────────
  // Build the whole frame in a single allocation to avoid an intermediate
  // `prelude` copy.  CRC-16 covers all bytes except the last two.
  final frame = Uint8List(headerBytes.length + 1 + subBytes.length + 2);
  frame.setAll(0, headerBytes);
  frame[headerBytes.length] = crc8;
  frame.setAll(headerBytes.length + 1, subBytes);
  final crc16 = _crc16(Uint8List.sublistView(frame, 0, frame.length - 2));
  frame[frame.length - 2] = (crc16 >> 8) & 0xFF;
  frame[frame.length - 1] = crc16 & 0xFF;
  return frame;
}

// =============================================================================
// STREAMINFO metadata block
// =============================================================================

/// Build the 38-byte STREAMINFO metadata block (4-byte header + 34-byte body).
Uint8List _buildStreamInfo({
  required int minBlockSize,
  required int maxBlockSize,
  required int minFrameSize,
  required int maxFrameSize,
  required int sampleRate,
  required int channels,
  required int bitsPerSample,
  required int totalSamples,
  bool isLast = true,
}) {
  final d = ByteData(38);

  // Metadata block header: is-last (1 bit) | type 0 (7 bits) | length (24 bits).
  d.setUint8(0, (isLast ? 0x80 : 0x00));
  d.setUint8(1, 0);
  d.setUint8(2, 0);
  d.setUint8(3, 34);

  // STREAMINFO body (34 bytes at offset 4).
  d.setUint16(4, minBlockSize);
  d.setUint16(6, maxBlockSize);
  d.setUint8(8, (minFrameSize >> 16) & 0xFF);
  d.setUint8(9, (minFrameSize >> 8) & 0xFF);
  d.setUint8(10, minFrameSize & 0xFF);
  d.setUint8(11, (maxFrameSize >> 16) & 0xFF);
  d.setUint8(12, (maxFrameSize >> 8) & 0xFF);
  d.setUint8(13, maxFrameSize & 0xFF);

  // 20-bit sample rate | 3-bit (channels-1) | 5-bit (bps-1) | 36-bit total.
  d.setUint8(14, (sampleRate >> 12) & 0xFF);
  d.setUint8(15, (sampleRate >> 4) & 0xFF);
  d.setUint8(
      16,
      ((sampleRate & 0xF) << 4) |
          (((channels - 1) & 0x7) << 1) |
          (((bitsPerSample - 1) >> 4) & 0x1));
  d.setUint8(
      17, (((bitsPerSample - 1) & 0xF) << 4) | ((totalSamples >> 32) & 0xF));
  d.setUint32(18, totalSamples & 0xFFFFFFFF);

  // Bytes 22–37: MD5 signature — left as zeros (allowed by spec).
  return d.buffer.asUint8List();
}

// =============================================================================
// FlacEncoder — public API
// =============================================================================

/// Pure Dart FLAC encoder with a streaming API matching [AudioFileWriter].
///
/// Encodes mono 16-bit PCM audio into FLAC using fixed predictors and Rice
/// coding.  Typical compression ratio is 50–60 % on bird audio.
///
/// Usage:
/// ```dart
/// final encoder = FlacEncoder(filePath: 'session.flac');
/// await encoder.open();
/// for (final chunk in audioChunks) {
///   await encoder.writeSamples(chunk);
/// }
/// await encoder.close();
/// ```
class FlacEncoder implements AudioFileWriter {
  FlacEncoder({
    required this.filePath,
    this.sampleRate = 32000,
    this.channels = 1,
    this.bitsPerSample = 16,
    this.blockSize = kFlacBlockSize,
  });

  @override
  final String filePath;

  /// Audio sample rate in Hz.
  final int sampleRate;

  /// Number of channels (1 = mono).
  final int channels;

  /// Bits per sample (16 for standard PCM).
  final int bitsPerSample;

  /// Samples per FLAC frame (last frame may be shorter).
  final int blockSize;

  RandomAccessFile? _file;
  bool _closed = false;
  int _totalSamples = 0;
  int _frameNumber = 0;
  Int16List _pending = Int16List(0);
  int _minBlockSize = 0;
  int _maxBlockSize = 0;
  int _minFrameSize = 0x7FFFFFFF;
  int _maxFrameSize = 0;

  @override
  bool get isOpen => _file != null && !_closed;

  /// Total samples received (including those still buffered in [_pending]).
  int get totalSamples => _totalSamples + _pending.length;

  /// Duration of audio received so far.
  Duration get duration =>
      Duration(microseconds: totalSamples * 1000000 ~/ sampleRate);

  // ── Streaming API ───────────────────────────────────────────────────────

  @override
  Future<void> open() async {
    if (_file != null) return;
    final file = File(filePath);
    await file.parent.create(recursive: true);
    _file = await file.open(mode: FileMode.write);
    _closed = false;
    _totalSamples = 0;
    _frameNumber = 0;
    _pending = Int16List(0);
    _minBlockSize = blockSize;
    _maxBlockSize = blockSize;
    _minFrameSize = 0x7FFFFFFF;
    _maxFrameSize = 0;

    // "fLaC" magic number.
    await _file!.writeFrom([0x66, 0x4C, 0x61, 0x43]);

    // Placeholder STREAMINFO (rewritten on close with final values).
    await _file!.writeFrom(_buildStreamInfo(
      minBlockSize: blockSize,
      maxBlockSize: blockSize,
      minFrameSize: 0,
      maxFrameSize: 0,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
      totalSamples: 0,
    ));
  }

  @override
  Future<void> writeSamples(Float32List samples) async {
    if (_file == null || _closed) {
      throw StateError('FlacEncoder is not open. Call open() first.');
    }

    final newSamples = _float32ToInt16(samples);

    // Append to pending buffer.
    if (_pending.isEmpty) {
      _pending = newSamples;
    } else {
      final merged = Int16List(_pending.length + newSamples.length);
      merged.setAll(0, _pending);
      merged.setAll(_pending.length, newSamples);
      _pending = merged;
    }

    // Encode complete blocks.
    int offset = 0;
    while (offset + blockSize <= _pending.length) {
      final block = Int16List(blockSize);
      block.setRange(0, blockSize, _pending, offset);
      await _emitFrame(block);
      offset += blockSize;
    }

    // Carry over remaining samples.
    if (offset > 0) {
      final rem = _pending.length - offset;
      final tail = Int16List(rem);
      tail.setRange(0, rem, _pending, offset);
      _pending = tail;
    }
    await _file!
        .flush(); // Prevent OS file caching from causing OOM on long recordings
  }

  @override
  Future<void> close() async {
    if (_file == null || _closed) return;
    _closed = true;

    // Flush leftover samples as a final (shorter) frame.
    if (_pending.isNotEmpty) {
      await _emitFrame(_pending);
      _pending = Int16List(0);
    }

    // Rewrite STREAMINFO with final values.
    await _file!.setPosition(4); // after "fLaC"
    await _file!.writeFrom(_buildStreamInfo(
      minBlockSize: _minBlockSize,
      maxBlockSize: _maxBlockSize,
      minFrameSize: _minFrameSize == 0x7FFFFFFF ? 0 : _minFrameSize,
      maxFrameSize: _maxFrameSize,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
      totalSamples: _totalSamples,
    ));

    await _file!.close();
    _file = null;
  }

  // ── One-shot API ────────────────────────────────────────────────────────

  /// Write a complete FLAC file from float32 samples.
  static Future<void> writeFile({
    required String filePath,
    required Float32List samples,
    int sampleRate = 32000,
  }) async {
    final encoder = FlacEncoder(filePath: filePath, sampleRate: sampleRate);
    await encoder.open();
    await encoder.writeSamples(samples);
    await encoder.close();
  }

  // ── Internal ────────────────────────────────────────────────────────────

  Future<void> _emitFrame(Int16List samples) async {
    final bytes =
        _encodeFrame(samples, _frameNumber, sampleRate, bitsPerSample);
    await _file!.writeFrom(bytes);

    _totalSamples += samples.length;
    _frameNumber++;

    if (samples.length < _minBlockSize) _minBlockSize = samples.length;
    if (samples.length > _maxBlockSize) _maxBlockSize = samples.length;
    if (bytes.length < _minFrameSize) _minFrameSize = bytes.length;
    if (bytes.length > _maxFrameSize) _maxFrameSize = bytes.length;
  }

  /// Convert float32 [-1.0, 1.0] samples to signed 16-bit integers.
  static Int16List _float32ToInt16(Float32List samples) {
    final pcm = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      pcm[i] = (samples[i] * 32767.0).round().clamp(-32768, 32767);
    }
    return pcm;
  }
}
