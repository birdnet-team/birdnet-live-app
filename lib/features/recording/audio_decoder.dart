// =============================================================================
// Audio Decoder — Decode WAV and FLAC files to raw PCM samples
// =============================================================================
//
// Provides file→PCM decoding for session review spectrograms.  Supports:
//
//   • **WAV** — RIFF/WAVE files: 8/16/24/32-bit PCM and 32/64-bit IEEE
//     float.  Multi-channel files are downmixed by taking channel 0.
//     All bit depths are converted to signed 16-bit output.
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
  DecodedAudio({required this.samples, required this.sampleRate});

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

  /// Resample to [targetRate] Hz using linear interpolation.
  ///
  /// Returns `this` unchanged if [sampleRate] already equals [targetRate].
  DecodedAudio resampleTo(int targetRate) {
    if (sampleRate == targetRate) return this;

    final ratio = sampleRate / targetRate;
    final newLength = (samples.length / ratio).floor();
    final resampled = Int16List(newLength);

    for (var i = 0; i < newLength; i++) {
      final srcPos = i * ratio;
      final srcIndex = srcPos.toInt();
      final frac = srcPos - srcIndex;

      if (srcIndex + 1 < samples.length) {
        resampled[i] =
            (samples[srcIndex] * (1.0 - frac) + samples[srcIndex + 1] * frac)
                .round();
      } else {
        resampled[i] = samples[srcIndex];
      }
    }

    return DecodedAudio(samples: resampled, sampleRate: targetRate);
  }
}

/// Lightweight audio metadata that can be read without decoding full PCM.
class AudioMetadata {
  const AudioMetadata({
    required this.sampleRate,
    required this.totalSamples,
    required this.format,
  });

  /// Audio sample rate in Hz.
  final int sampleRate;

  /// Total mono sample frames reported by the container/header.
  final int totalSamples;

  /// Container label, such as WAV, FLAC, MP3, or AAC.
  final String format;

  /// Duration of the audio.
  Duration get duration =>
      Duration(microseconds: totalSamples * 1000000 ~/ sampleRate);

  /// Estimated mono 16-bit PCM size after decode.
  int get decodedPcmBytes => totalSamples * 2;
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

  /// Check whether the file is a WAV file based on RIFF magic bytes.
  static Future<bool> isWav(String path) async {
    final file = File(path);
    final raf = await file.open();
    try {
      final header = await raf.read(4);
      if (header.length < 4) return false;
      return header[0] == 0x52 &&
          header[1] == 0x49 &&
          header[2] == 0x46 &&
          header[3] == 0x46;
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

  /// Read WAV/FLAC metadata without decoding the full audio stream.
  static Future<AudioMetadata> inspectFile(String path) async {
    final file = File(path);
    final raf = await file.open();
    try {
      final header = await raf.read(12);
      if (header.length < 4) {
        throw FormatException('File too small to be an audio file: $path');
      }

      if (header[0] == 0x52 &&
          header[1] == 0x49 &&
          header[2] == 0x46 &&
          header[3] == 0x46) {
        final info = await _readWavInfo(file);
        return AudioMetadata(
          sampleRate: info.sampleRate,
          totalSamples: info.totalFrames,
          format: 'WAV',
        );
      }

      if (header[0] == 0x66 &&
          header[1] == 0x4C &&
          header[2] == 0x61 &&
          header[3] == 0x43) {
        final bytes = await file
            .openRead(0, 42)
            .fold<BytesBuilder>(
              BytesBuilder(),
              (builder, chunk) => builder..add(chunk),
            );
        final metadata = _inspectFlac(bytes.toBytes());
        return metadata;
      }
    } finally {
      await raf.close();
    }

    throw FormatException('Unknown audio format (not WAV or FLAC): $path');
  }

  /// Decode a bounded sample range from a WAV/FLAC file.
  ///
  /// This avoids allocating full-file PCM for long File Analysis inputs.
  static Future<DecodedAudio> decodeRange(
    String path, {
    required int startSample,
    required int count,
  }) async {
    final file = File(path);
    final raf = await file.open();
    try {
      final header = await raf.read(4);
      if (header.length < 4) {
        throw FormatException('File too small to be an audio file: $path');
      }
      if (header[0] == 0x52 &&
          header[1] == 0x49 &&
          header[2] == 0x46 &&
          header[3] == 0x46) {
        return _decodeWavRange(file, startSample: startSample, count: count);
      }
      if (header[0] == 0x66 &&
          header[1] == 0x4C &&
          header[2] == 0x61 &&
          header[3] == 0x43) {
        return decodeFlacRange(path, startSample: startSample, count: count);
      }
    } finally {
      await raf.close();
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
    int audioFormat = 0; // 1 = PCM, 3 = IEEE float
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
        audioFormat = bd.getUint16(pos + 8, Endian.little);
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

    // Read samples from channel 0, converting to Int16.
    final bytesPerSample = bitsPerSample ~/ 8;
    final frameSize = bytesPerSample * channels;
    final totalFrames = dataSize ~/ frameSize;
    final samples = Int16List(totalFrames);
    final dataView = ByteData.sublistView(bytes, dataOffset);

    if (audioFormat == 3 && bitsPerSample == 32) {
      // IEEE 32-bit float → Int16.
      for (var i = 0; i < totalFrames; i++) {
        final f = dataView.getFloat32(i * frameSize, Endian.little);
        samples[i] = (f * 32767.0).round().clamp(-32768, 32767);
      }
    } else if (audioFormat == 3 && bitsPerSample == 64) {
      // IEEE 64-bit float → Int16.
      for (var i = 0; i < totalFrames; i++) {
        final f = dataView.getFloat64(i * frameSize, Endian.little);
        samples[i] = (f * 32767.0).round().clamp(-32768, 32767);
      }
    } else if (bitsPerSample == 16) {
      // 16-bit PCM — direct read.
      for (var i = 0; i < totalFrames; i++) {
        samples[i] = dataView.getInt16(i * frameSize, Endian.little);
      }
    } else if (bitsPerSample == 24) {
      // 24-bit PCM → Int16 (drop lower 8 bits).
      for (var i = 0; i < totalFrames; i++) {
        final offset = i * frameSize;
        final lo = bytes[dataOffset + offset + 1];
        final hi = bytes[dataOffset + offset + 2];
        // Combine upper 16 bits: hi is signed, lo is unsigned.
        samples[i] = (hi << 8) | lo;
      }
    } else if (bitsPerSample == 32 && audioFormat == 1) {
      // 32-bit integer PCM → Int16 (take upper 16 bits).
      for (var i = 0; i < totalFrames; i++) {
        final v = dataView.getInt32(i * frameSize, Endian.little);
        samples[i] = (v >> 16).clamp(-32768, 32767);
      }
    } else if (bitsPerSample == 8) {
      // 8-bit unsigned PCM → Int16.
      for (var i = 0; i < totalFrames; i++) {
        samples[i] = (bytes[dataOffset + i * frameSize] - 128) << 8;
      }
    } else {
      throw FormatException(
        'Unsupported WAV format: $bitsPerSample-bit, format=$audioFormat',
      );
    }

    return DecodedAudio(samples: samples, sampleRate: sampleRate);
  }

  static AudioMetadata _inspectFlac(Uint8List bytes) {
    if (bytes.length < 42) {
      throw const FormatException('FLAC file too short for STREAMINFO');
    }
    final sampleRate = (bytes[18] << 12) | (bytes[19] << 4) | (bytes[20] >> 4);
    final bps = ((bytes[20] & 0x01) << 4) | (bytes[21] >> 4);
    final bitsPerSample = bps + 1;
    if (bitsPerSample != 16) {
      throw FormatException(
        'Only 16-bit FLAC supported, got $bitsPerSample-bit',
      );
    }
    final totalHigh = bytes[21] & 0x0F;
    final totalLow = ByteData.sublistView(
      bytes,
      22,
      26,
    ).getUint32(0, Endian.big);
    return AudioMetadata(
      sampleRate: sampleRate,
      totalSamples: (totalHigh << 32) | totalLow,
      format: 'FLAC',
    );
  }

  static Future<_WavInfo> _readWavInfo(File file) async {
    final raf = await file.open();
    try {
      final fileLen = await raf.length();
      if (fileLen < 12) {
        throw const FormatException('WAV header too short');
      }
      await raf.setPosition(0);
      final header = await raf.read(12);
      if (String.fromCharCodes(header, 0, 4) != 'RIFF' ||
          String.fromCharCodes(header, 8, 12) != 'WAVE') {
        throw const FormatException('Not a valid WAVE file');
      }

      int audioFormat = 0;
      int sampleRate = 0;
      int bitsPerSample = 0;
      int channels = 0;
      int dataOffset = 0;
      int dataSize = 0;

      var pos = 12;
      while (pos + 8 <= fileLen) {
        await raf.setPosition(pos);
        final chunkHeader = await raf.read(8);
        if (chunkHeader.length < 8) break;
        final chunkId = String.fromCharCodes(chunkHeader, 0, 4);
        final chunkSize = ByteData.sublistView(
          Uint8List.fromList(chunkHeader),
          4,
          8,
        ).getUint32(0, Endian.little);

        if (chunkId == 'fmt ') {
          final fmt = await raf.read(chunkSize);
          if (fmt.length < 16) {
            throw const FormatException('WAV fmt chunk too short');
          }
          final bd = ByteData.sublistView(Uint8List.fromList(fmt));
          audioFormat = bd.getUint16(0, Endian.little);
          channels = bd.getUint16(2, Endian.little);
          sampleRate = bd.getUint32(4, Endian.little);
          bitsPerSample = bd.getUint16(14, Endian.little);
        } else if (chunkId == 'data') {
          dataOffset = pos + 8;
          final available = fileLen - dataOffset;
          dataSize = chunkSize > available ? available : chunkSize;
        }

        pos += 8 + chunkSize;
        if (pos.isOdd) pos++;
      }

      if (sampleRate == 0 || dataOffset == 0 || channels == 0) {
        throw const FormatException('WAV file missing fmt or data chunk');
      }
      return _WavInfo(
        audioFormat: audioFormat,
        sampleRate: sampleRate,
        bitsPerSample: bitsPerSample,
        channels: channels,
        dataOffset: dataOffset,
        dataSize: dataSize,
      );
    } finally {
      await raf.close();
    }
  }

  static Future<DecodedAudio> _decodeWavRange(
    File file, {
    required int startSample,
    required int count,
  }) async {
    final info = await _readWavInfo(file);
    final bytesPerSample = info.bitsPerSample ~/ 8;
    final frameSize = bytesPerSample * info.channels;
    if (bytesPerSample <= 0 || frameSize <= 0) {
      throw FormatException('Unsupported WAV bit depth: ${info.bitsPerSample}');
    }

    final totalFrames = info.totalFrames;
    final safeStart = startSample.clamp(0, totalFrames);
    final safeEnd = (startSample + count).clamp(0, totalFrames);
    final framesToRead = safeEnd - safeStart;
    if (framesToRead <= 0) {
      return DecodedAudio(samples: Int16List(0), sampleRate: info.sampleRate);
    }

    final raf = await file.open();
    try {
      await raf.setPosition(info.dataOffset + safeStart * frameSize);
      final bytes = await raf.read(framesToRead * frameSize);
      final samples = Int16List(framesToRead);
      final dataView = ByteData.sublistView(Uint8List.fromList(bytes));

      if (info.audioFormat == 3 && info.bitsPerSample == 32) {
        for (var i = 0; i < framesToRead; i++) {
          final f = dataView.getFloat32(i * frameSize, Endian.little);
          samples[i] = (f * 32767.0).round().clamp(-32768, 32767);
        }
      } else if (info.audioFormat == 3 && info.bitsPerSample == 64) {
        for (var i = 0; i < framesToRead; i++) {
          final f = dataView.getFloat64(i * frameSize, Endian.little);
          samples[i] = (f * 32767.0).round().clamp(-32768, 32767);
        }
      } else if (info.bitsPerSample == 16) {
        for (var i = 0; i < framesToRead; i++) {
          samples[i] = dataView.getInt16(i * frameSize, Endian.little);
        }
      } else if (info.bitsPerSample == 24) {
        for (var i = 0; i < framesToRead; i++) {
          final offset = i * frameSize;
          final lo = bytes[offset + 1];
          final hi = bytes[offset + 2];
          samples[i] = (hi << 8) | lo;
        }
      } else if (info.bitsPerSample == 32 && info.audioFormat == 1) {
        for (var i = 0; i < framesToRead; i++) {
          final v = dataView.getInt32(i * frameSize, Endian.little);
          samples[i] = (v >> 16).clamp(-32768, 32767);
        }
      } else if (info.bitsPerSample == 8) {
        for (var i = 0; i < framesToRead; i++) {
          samples[i] = (bytes[i * frameSize] - 128) << 8;
        }
      } else {
        throw FormatException(
          'Unsupported WAV format: ${info.bitsPerSample}-bit, '
          'format=${info.audioFormat}',
        );
      }

      return DecodedAudio(samples: samples, sampleRate: info.sampleRate);
    } finally {
      await raf.close();
    }
  }

  // ── FLAC Decoder ────────────────────────────────────────────────────────

  /// Decode just `[startSample, startSample + count)` from a FLAC file.
  ///
  /// Walks frames sequentially (FLAC has no built-in random access) but
  /// only allocates `count` Int16 output samples — so a 7-second slice
  /// from a 30-minute recording uses ~448 KB instead of ~115 MB. Frames
  /// outside the range are still bit-decoded (FLAC frame lengths aren't
  /// readable without decoding) but their samples are dropped.
  ///
  /// If the source has fewer than `startSample + count` total samples,
  /// the trailing remainder of the output stays zero-filled.
  ///
  /// Tolerates an unfinalized STREAMINFO (`totalSamples == 0`) — the
  /// frame loop terminates on EOF instead of trusting the header.
  static Future<DecodedAudio> decodeFlacRange(
    String path, {
    required int startSample,
    required int count,
  }) async {
    final file = File(path);
    final raf = await file.open();
    try {
      final info = await _readFlacStreamInfo(raf, path);
      final reader = _StreamingBitReader(
        file: raf,
        fileLength: await raf.length(),
        startByte: info.firstFrameOffset,
      );
      return _decodeFlacFrames(
        reader,
        info,
        rangeStart: startSample,
        rangeCount: count,
      );
    } finally {
      await raf.close();
    }
  }

  /// Decode a FLAC file sequentially and emit fixed-size analysis windows.
  ///
  /// Unlike [decodeFlacRange], this walks the FLAC frames only once. It is the
  /// right path for long File Analysis runs where windows are processed in
  /// chronological order; repeatedly range-decoding an hour-long FLAC would
  /// otherwise re-read and re-decode the beginning of the stream for every
  /// window.
  static Future<void> decodeFlacWindows(
    String path, {
    required int windowSamples,
    required int stepSamples,
    required int maxWindows,
    required Future<bool> Function(
      int windowIndex,
      int startSample,
      DecodedAudio window,
    )
    onWindow,
  }) async {
    final file = File(path);
    final raf = await file.open();
    try {
      final info = await _readFlacStreamInfo(raf, path);
      final reader = _StreamingBitReader(
        file: raf,
        fileLength: await raf.length(),
        startByte: info.firstFrameOffset,
      );
      await _decodeFlacWindowsFromReader(
        reader,
        info,
        windowSamples: windowSamples,
        stepSamples: stepSamples,
        maxWindows: maxWindows,
        onWindow: onWindow,
      );
    } finally {
      await raf.close();
    }
  }

  static Future<_FlacStreamInfo> _readFlacStreamInfo(
    RandomAccessFile raf,
    String path,
  ) async {
    final fileLen = await raf.length();
    await raf.setPosition(0);
    final magic = await raf.read(4);
    if (magic.length < 4 ||
        magic[0] != 0x66 ||
        magic[1] != 0x4C ||
        magic[2] != 0x61 ||
        magic[3] != 0x43) {
      throw FormatException('Not a valid FLAC file: $path');
    }

    _FlacStreamInfo? streamInfo;
    var pos = 4;
    while (pos + 4 <= fileLen) {
      await raf.setPosition(pos);
      final header = await raf.read(4);
      if (header.length < 4) {
        throw const FormatException('Truncated FLAC metadata header');
      }
      final isLast = (header[0] & 0x80) != 0;
      final blockType = header[0] & 0x7F;
      final blockLen = (header[1] << 16) | (header[2] << 8) | header[3];
      pos += 4;

      if (pos + blockLen > fileLen) {
        throw const FormatException('Truncated FLAC metadata block');
      }

      if (blockType == 0) {
        final body = await raf.read(blockLen);
        streamInfo = _parseFlacStreamInfoBody(body, firstFrameOffset: 0);
      }

      pos += blockLen;
      if (isLast) break;
    }

    if (streamInfo == null) {
      throw const FormatException('FLAC file missing STREAMINFO metadata');
    }
    return streamInfo.copyWith(firstFrameOffset: pos);
  }

  static _FlacStreamInfo _readFlacStreamInfoFromBytes(Uint8List bytes) {
    if (bytes.length < 42) {
      throw const FormatException('FLAC file too short for STREAMINFO');
    }
    if (bytes[0] != 0x66 ||
        bytes[1] != 0x4C ||
        bytes[2] != 0x61 ||
        bytes[3] != 0x43) {
      throw const FormatException('Not a valid FLAC file');
    }

    _FlacStreamInfo? streamInfo;
    var pos = 4;
    while (pos + 4 <= bytes.length) {
      final isLast = (bytes[pos] & 0x80) != 0;
      final blockType = bytes[pos] & 0x7F;
      final blockLen =
          (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) | bytes[pos + 3];
      pos += 4;
      if (pos + blockLen > bytes.length) {
        throw const FormatException('Truncated FLAC metadata block');
      }
      if (blockType == 0) {
        streamInfo = _parseFlacStreamInfoBody(
          Uint8List.sublistView(bytes, pos, pos + blockLen),
          firstFrameOffset: 0,
        );
      }
      pos += blockLen;
      if (isLast) break;
    }

    if (streamInfo == null) {
      throw const FormatException('FLAC file missing STREAMINFO metadata');
    }
    return streamInfo.copyWith(firstFrameOffset: pos);
  }

  static _FlacStreamInfo _parseFlacStreamInfoBody(
    Uint8List body, {
    required int firstFrameOffset,
  }) {
    if (body.length < 34) {
      throw const FormatException('FLAC STREAMINFO block too short');
    }
    final si = ByteData.sublistView(body, 0, 34);
    final maxBlock = si.getUint16(2, Endian.big);
    final sampleRate = (body[10] << 12) | (body[11] << 4) | (body[12] >> 4);
    final bps = ((body[12] & 0x01) << 4) | (body[13] >> 4);
    final bitsPerSample = bps + 1;
    final totalHigh = body[13] & 0x0F;
    final totalLow = ByteData.sublistView(
      body,
      14,
      18,
    ).getUint32(0, Endian.big);
    return _FlacStreamInfo(
      maxBlockSize: maxBlock,
      sampleRate: sampleRate,
      bitsPerSample: bitsPerSample,
      totalSamples: (totalHigh << 32) | totalLow,
      firstFrameOffset: firstFrameOffset,
    );
  }

  static DecodedAudio _decodeFlac(
    Uint8List bytes, {
    int? rangeStart,
    int? rangeCount,
  }) {
    final info = _readFlacStreamInfoFromBytes(bytes);
    return _decodeFlacFrames(
      _MemoryBitReader(bytes, info.firstFrameOffset),
      info,
      rangeStart: rangeStart,
      rangeCount: rangeCount,
    );
  }

  static DecodedAudio _decodeFlacFrames(
    _FlacBitReader reader,
    _FlacStreamInfo info, {
    int? rangeStart,
    int? rangeCount,
  }) {
    if (info.bitsPerSample != 16) {
      throw FormatException(
        'Only 16-bit FLAC supported, got ${info.bitsPerSample}-bit',
      );
    }

    // Range-decode mode: only allocate what the caller asked for, and
    // stop walking frames once the requested window is filled.
    final useRange = rangeStart != null && rangeCount != null;
    // `totalSamples == 0` happens when the encoder hasn't finalized
    // STREAMINFO yet (mid-recording). Treat that as "decode until EOF".
    final hasKnownTotal = info.totalSamples > 0;

    final collectUntilEof = !useRange && !hasKnownTotal;
    final outLen = useRange ? rangeCount : info.totalSamples;
    final allSamples = collectUntilEof ? null : Int16List(outLen);
    final frameChunks = collectUntilEof ? <Int16List>[] : null;
    final outStart = useRange ? rangeStart : 0;
    final outEnd = outStart + outLen;

    // Decode audio frames.
    var samplePos = 0;

    while (reader.bytesRemaining > 2) {
      if (hasKnownTotal && samplePos >= info.totalSamples) break;
      if (!collectUntilEof && samplePos >= outEnd) break;

      final frameResult = _decodeFrame(
        reader,
        info.maxBlockSize,
        info.bitsPerSample,
      );
      if (frameResult == null) break;

      if (collectUntilEof) {
        frameChunks!.add(frameResult);
        samplePos += frameResult.length;
        continue;
      }

      final frameStart = samplePos;
      final frameEnd = samplePos + frameResult.length;

      // Compute overlap with the output window and copy only that span.
      final copyFrom = frameStart > outStart ? frameStart : outStart;
      final copyTo = frameEnd < outEnd ? frameEnd : outEnd;
      if (copyTo > copyFrom) {
        for (var i = copyFrom; i < copyTo; i++) {
          allSamples![i - outStart] = frameResult[i - frameStart];
        }
      }
      samplePos = frameEnd;
    }

    if (collectUntilEof) {
      if (samplePos <= 0) {
        return DecodedAudio(samples: Int16List(0), sampleRate: info.sampleRate);
      }
      final samples = Int16List(samplePos);
      var offset = 0;
      for (final chunk in frameChunks!) {
        samples.setAll(offset, chunk);
        offset += chunk.length;
      }
      return DecodedAudio(samples: samples, sampleRate: info.sampleRate);
    }

    // Trim trailing zero-padding when the source ran out of audio
    // before the requested range was filled. Without this, callers see
    // [DecodedAudio.totalSamples] equal to the requested count even
    // when the file was shorter — that has bitten us in the share path
    // where a "5 s" slice carried 6 s of silence at the tail.
    final filled = (samplePos < outEnd ? samplePos : outEnd) - outStart;
    if (filled <= 0) {
      return DecodedAudio(samples: Int16List(0), sampleRate: info.sampleRate);
    }
    if (filled < outLen) {
      return DecodedAudio(
        samples: Int16List.sublistView(allSamples!, 0, filled),
        sampleRate: info.sampleRate,
      );
    }
    return DecodedAudio(samples: allSamples!, sampleRate: info.sampleRate);
  }

  static Future<void> _decodeFlacWindowsFromReader(
    _FlacBitReader reader,
    _FlacStreamInfo info, {
    required int windowSamples,
    required int stepSamples,
    required int maxWindows,
    required Future<bool> Function(
      int windowIndex,
      int startSample,
      DecodedAudio window,
    )
    onWindow,
  }) async {
    if (info.bitsPerSample != 16) {
      throw FormatException(
        'Only 16-bit FLAC supported, got ${info.bitsPerSample}-bit',
      );
    }

    final hasKnownTotal = info.totalSamples > 0;
    var decodedSamples = 0;
    var bufferStartSample = 0;
    var nextWindowStart = 0;
    var windowIndex = 0;
    var pending = <int>[];

    while (reader.bytesRemaining > 2 && windowIndex < maxWindows) {
      if (hasKnownTotal && decodedSamples >= info.totalSamples) break;

      final frame = _decodeFrame(reader, info.maxBlockSize, info.bitsPerSample);
      if (frame == null) break;
      pending.addAll(frame);
      decodedSamples += frame.length;

      while (windowIndex < maxWindows &&
          nextWindowStart + windowSamples <= decodedSamples) {
        final offset = nextWindowStart - bufferStartSample;
        if (offset < 0 || offset + windowSamples > pending.length) break;
        final samples = Int16List(windowSamples);
        for (var i = 0; i < windowSamples; i++) {
          samples[i] = pending[offset + i];
        }
        final keepGoing = await onWindow(
          windowIndex,
          nextWindowStart,
          DecodedAudio(samples: samples, sampleRate: info.sampleRate),
        );
        windowIndex++;
        nextWindowStart += stepSamples;

        final discardCount = nextWindowStart - bufferStartSample;
        if (discardCount > 0) {
          if (discardCount >= pending.length) {
            pending = <int>[];
            bufferStartSample = nextWindowStart;
          } else {
            pending = pending.sublist(discardCount);
            bufferStartSample += discardCount;
          }
        }

        if (!keepGoing) return;
      }
    }
  }

  /// Decode a single FLAC audio frame.  Returns the decoded Int16 samples,
  /// or null if no more frames can be read.
  static Int16List? _decodeFrame(
    _FlacBitReader reader,
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
  static bool _syncToFrame(_FlacBitReader reader) {
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
  static int _readFlacUtf8(_FlacBitReader reader) {
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
    _FlacBitReader reader,
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
    } else if (typeBits >= 0x20 && typeBits <= 0x3F) {
      // LPC predictor, order = typeBits - 31.
      final order = typeBits - 0x1F;
      samples = _decodeLpcSubframe(reader, blockSize, effectiveBps, order);
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

  /// Decode an LPC-predictor subframe.
  static Int16List _decodeLpcSubframe(
    _FlacBitReader reader,
    int blockSize,
    int bps,
    int order,
  ) {
    final samples = Int16List(blockSize);

    for (var i = 0; i < order; i++) {
      samples[i] = reader.readSignedBits(bps);
    }

    final coefficientPrecision = reader.readBits(4) + 1;
    if (coefficientPrecision == 16) {
      throw const FormatException('Invalid FLAC LPC coefficient precision');
    }
    final quantizationShift = reader.readSignedBits(5);
    final coefficients = Int32List(order);
    for (var i = 0; i < order; i++) {
      coefficients[i] = reader.readSignedBits(coefficientPrecision);
    }

    final residuals = _decodeRicePartition(reader, blockSize, order);
    final residualCount = blockSize - order;
    if (residuals.length < residualCount) {
      throw const FormatException('Truncated FLAC LPC residuals');
    }

    for (var i = order; i < blockSize; i++) {
      var sum = 0;
      for (var j = 0; j < order; j++) {
        sum += coefficients[j] * samples[i - j - 1];
      }
      final predicted =
          quantizationShift >= 0
              ? (sum >> quantizationShift)
              : (sum << -quantizationShift);
      samples[i] = (predicted + residuals[i - order]).clamp(-32768, 32767);
    }

    return samples;
  }

  /// Decode a FIXED-predictor subframe.
  static Int16List _decodeFixedSubframe(
    _FlacBitReader reader,
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
    final residualCount = blockSize - order;
    if (residuals.length < residualCount) {
      throw const FormatException('Truncated FLAC fixed residuals');
    }

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
          predicted =
              4 * samples[i - 1] -
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
    _FlacBitReader reader,
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
      final samplesInPartition =
          p == 0
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

class _WavInfo {
  const _WavInfo({
    required this.audioFormat,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.channels,
    required this.dataOffset,
    required this.dataSize,
  });

  final int audioFormat;
  final int sampleRate;
  final int bitsPerSample;
  final int channels;
  final int dataOffset;
  final int dataSize;

  int get totalFrames => dataSize ~/ (channels * (bitsPerSample ~/ 8));
}

class _FlacStreamInfo {
  const _FlacStreamInfo({
    required this.maxBlockSize,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.totalSamples,
    required this.firstFrameOffset,
  });

  final int maxBlockSize;
  final int sampleRate;
  final int bitsPerSample;
  final int totalSamples;
  final int firstFrameOffset;

  _FlacStreamInfo copyWith({int? firstFrameOffset}) => _FlacStreamInfo(
    maxBlockSize: maxBlockSize,
    sampleRate: sampleRate,
    bitsPerSample: bitsPerSample,
    totalSamples: totalSamples,
    firstFrameOffset: firstFrameOffset ?? this.firstFrameOffset,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Bit Reader — MSB-first bit-level reader for FLAC bitstream
// ─────────────────────────────────────────────────────────────────────────────

abstract class _FlacBitReader {
  int get bytePosition;
  int get bytesRemaining;

  int peekByte();
  void seekByte(int pos);
  void alignToByte();

  /// Read [n] bits as an unsigned integer (MSB-first).
  int readBits(int n);

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

class _MemoryBitReader extends _FlacBitReader {
  _MemoryBitReader(this._data, this._bytePos);

  final Uint8List _data;
  int _bytePos;
  int _bitPos = 0; // 0 = MSB, 7 = LSB within current byte.

  @override
  int get bytePosition => _bytePos;

  @override
  int get bytesRemaining => _data.length - _bytePos;

  @override
  int peekByte() => _data[_bytePos];

  @override
  void seekByte(int pos) {
    _bytePos = pos;
    _bitPos = 0;
  }

  @override
  void alignToByte() {
    if (_bitPos > 0) {
      _bytePos++;
      _bitPos = 0;
    }
  }

  @override
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
}

/// Buffered file-backed bit reader for sequential FLAC frame walks.
///
/// It keeps only a small compressed-byte window in memory while exposing the
/// same byte-seek/bit-read operations the frame decoder already uses. This is
/// what lets File Analysis walk an hour-long FLAC once without allocating the
/// entire compressed file first.
class _StreamingBitReader extends _FlacBitReader {
  _StreamingBitReader({
    required RandomAccessFile file,
    required int fileLength,
    required int startByte,
    int bufferSize = 64 * 1024,
  }) : _file = file,
       _fileLength = fileLength,
       _bytePos = startByte,
       _buffer = Uint8List(bufferSize);

  final RandomAccessFile _file;
  final int _fileLength;
  final Uint8List _buffer;
  int _bufferStart = 0;
  int _bufferLength = 0;
  int _bytePos;
  int _bitPos = 0;

  @override
  int get bytePosition => _bytePos;

  @override
  int get bytesRemaining => _bytePos < _fileLength ? _fileLength - _bytePos : 0;

  @override
  int peekByte() => _byteAt(_bytePos) ?? 0;

  @override
  void seekByte(int pos) {
    _bytePos = pos;
    _bitPos = 0;
  }

  @override
  void alignToByte() {
    if (_bitPos > 0) {
      _bytePos++;
      _bitPos = 0;
    }
  }

  @override
  int readBits(int n) {
    var result = 0;
    for (var i = 0; i < n; i++) {
      final byte = _byteAt(_bytePos);
      if (byte == null) return result;
      result = (result << 1) | ((byte >> (7 - _bitPos)) & 1);
      _bitPos++;
      if (_bitPos == 8) {
        _bitPos = 0;
        _bytePos++;
      }
    }
    return result;
  }

  int? _byteAt(int pos) {
    if (pos < 0 || pos >= _fileLength) return null;
    final inBuffer = pos >= _bufferStart && pos < _bufferStart + _bufferLength;
    if (!inBuffer) {
      _file.setPositionSync(pos);
      _bufferLength = _file.readIntoSync(_buffer);
      _bufferStart = pos;
      if (_bufferLength <= 0) return null;
    }
    final index = pos - _bufferStart;
    if (index < 0 || index >= _bufferLength) return null;
    return _buffer[index];
  }
}
