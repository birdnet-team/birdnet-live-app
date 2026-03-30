// =============================================================================
// Audio File Writer — Abstract interface for streaming audio file writers
// =============================================================================
//
// Common interface implemented by [WavWriter] and [FlacEncoder] so the
// recording service can write to either format without caring about the
// underlying codec.
// =============================================================================

import 'dart:typed_data';

/// Abstract interface for streaming audio file writers.
///
/// Implementations must support:
///   1. [open] — create the file and write a format header.
///   2. [writeSamples] — append float32 audio data (may be called many times).
///   3. [close] — finalize the file (rewrite header sizes, flush, etc.).
abstract class AudioFileWriter {
  /// Output file path.
  String get filePath;

  /// Whether the writer is currently open for writing.
  bool get isOpen;

  /// Open the file and write the initial header.
  Future<void> open();

  /// Append float32 audio samples normalized to [-1.0, 1.0].
  Future<void> writeSamples(Float32List samples);

  /// Finalize the header and close the file.
  Future<void> close();
}
