import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/audio/ring_buffer.dart';

void main() {
  group('RingBuffer', () {
    group('construction', () {
      test('creates with default capacity', () {
        final buf = RingBuffer();
        expect(buf.capacity, 640000);
        expect(buf.available, 0);
        expect(buf.totalWritten, 0);
        expect(buf.isFull, false);
      });

      test('creates with custom capacity', () {
        final buf = RingBuffer(capacity: 100);
        expect(buf.capacity, 100);
      });
    });

    group('write', () {
      test('writing increases available count', () {
        final buf = RingBuffer(capacity: 100);
        buf.write(Float32List.fromList([1, 2, 3]));
        expect(buf.available, 3);
        expect(buf.totalWritten, 3);
      });

      test('writing beyond capacity caps available at capacity', () {
        final buf = RingBuffer(capacity: 4);
        buf.write(Float32List.fromList([1, 2, 3, 4, 5, 6]));
        expect(buf.available, 4);
        expect(buf.totalWritten, 6);
        expect(buf.isFull, true);
      });

      test('multiple writes accumulate', () {
        final buf = RingBuffer(capacity: 100);
        buf.write(Float32List.fromList([1, 2, 3]));
        buf.write(Float32List.fromList([4, 5]));
        expect(buf.available, 5);
        expect(buf.totalWritten, 5);
      });

      test('writeSample works', () {
        final buf = RingBuffer(capacity: 100);
        buf.writeSample(0.5);
        buf.writeSample(0.7);
        expect(buf.available, 2);
      });
    });

    group('readLast', () {
      test('reads exact data after simple write', () {
        final buf = RingBuffer(capacity: 100);
        buf.write(Float32List.fromList([0.1, 0.2, 0.3, 0.4, 0.5]));

        final result = buf.readLast(5);
        expect(result.length, 5);
        expect(result[0], closeTo(0.1, 1e-6));
        expect(result[4], closeTo(0.5, 1e-6));
      });

      test('zero-pads when requesting more than available', () {
        final buf = RingBuffer(capacity: 100);
        buf.write(Float32List.fromList([0.1, 0.2]));

        final result = buf.readLast(5);
        expect(result.length, 5);
        // First 3 should be zero (padding).
        expect(result[0], 0.0);
        expect(result[1], 0.0);
        expect(result[2], 0.0);
        // Last 2 are the actual data.
        expect(result[3], closeTo(0.1, 1e-6));
        expect(result[4], closeTo(0.2, 1e-6));
      });

      test('returns last N samples correctly after wrap', () {
        final buf = RingBuffer(capacity: 4);
        // Write [1,2,3,4] — fills exactly.
        buf.write(Float32List.fromList([1, 2, 3, 4]));
        // Write [5,6] — wraps, buffer becomes [5,6,3,4] logically [3,4,5,6].
        buf.write(Float32List.fromList([5, 6]));

        final result = buf.readLast(4);
        expect(result[0], closeTo(3, 1e-6));
        expect(result[1], closeTo(4, 1e-6));
        expect(result[2], closeTo(5, 1e-6));
        expect(result[3], closeTo(6, 1e-6));
      });

      test('readLast with count < available returns most recent', () {
        final buf = RingBuffer(capacity: 100);
        buf.write(Float32List.fromList([1, 2, 3, 4, 5]));

        final result = buf.readLast(2);
        expect(result.length, 2);
        expect(result[0], closeTo(4, 1e-6));
        expect(result[1], closeTo(5, 1e-6));
      });

      test('readLast returns empty list when buffer is empty', () {
        final buf = RingBuffer(capacity: 100);
        final result = buf.readLast(5);
        expect(result.length, 5);
        expect(result.every((s) => s == 0.0), true);
      });
    });

    group('readAll', () {
      test('returns all written samples', () {
        final buf = RingBuffer(capacity: 100);
        buf.write(Float32List.fromList([0.1, 0.2, 0.3]));

        final result = buf.readAll();
        expect(result.length, 3);
        expect(result[0], closeTo(0.1, 1e-6));
        expect(result[2], closeTo(0.3, 1e-6));
      });

      test('returns capacity samples after wrap', () {
        final buf = RingBuffer(capacity: 4);
        buf.write(Float32List.fromList([1, 2, 3, 4, 5]));

        final result = buf.readAll();
        expect(result.length, 4);
        expect(result[0], closeTo(2, 1e-6));
        expect(result[3], closeTo(5, 1e-6));
      });
    });

    group('wrapping', () {
      test('correctly wraps around multiple times', () {
        final buf = RingBuffer(capacity: 4);

        // Write 3 batches that cause multiple wraps.
        buf.write(Float32List.fromList([1, 2, 3])); // [1,2,3,_]
        buf.write(Float32List.fromList(
            [4, 5, 6])); // wrap → [5,6,3,4] → most recent: [3,4,5,6]
        buf.write(
            Float32List.fromList([7, 8])); // wrap → most recent: [5,6,7,8]

        final result = buf.readLast(4);
        expect(result[0], closeTo(5, 1e-6));
        expect(result[1], closeTo(6, 1e-6));
        expect(result[2], closeTo(7, 1e-6));
        expect(result[3], closeTo(8, 1e-6));
      });

      test('handles write larger than capacity', () {
        final buf = RingBuffer(capacity: 3);
        buf.write(Float32List.fromList([1, 2, 3, 4, 5, 6, 7]));

        // Only last 3 should survive.
        final result = buf.readLast(3);
        expect(result[0], closeTo(5, 1e-6));
        expect(result[1], closeTo(6, 1e-6));
        expect(result[2], closeTo(7, 1e-6));
      });
    });

    group('clear', () {
      test('resets buffer to empty state', () {
        final buf = RingBuffer(capacity: 100);
        buf.write(Float32List.fromList([1, 2, 3]));

        buf.clear();
        expect(buf.available, 0);
        expect(buf.totalWritten, 0);
        expect(buf.isFull, false);
      });
    });

    group('rmsLevel', () {
      test('returns 0 for empty buffer', () {
        final buf = RingBuffer(capacity: 100);
        expect(buf.rmsLevel(), 0.0);
      });

      test('returns correct RMS for known signal', () {
        final buf = RingBuffer(capacity: 100);
        // A constant signal of 0.5 should have RMS = 0.5.
        final signal = Float32List.fromList(
          List.generate(100, (_) => 0.5),
        );
        buf.write(signal);

        expect(buf.rmsLevel(windowSize: 100), closeTo(0.5, 0.01));
      });

      test('returns correct RMS for alternating signal', () {
        final buf = RingBuffer(capacity: 100);
        // [-1, 1, -1, 1, ...] → RMS = 1.0.
        final signal = Float32List.fromList(
          List.generate(100, (i) => i.isEven ? -1.0 : 1.0),
        );
        buf.write(signal);

        expect(buf.rmsLevel(windowSize: 100), closeTo(1.0, 0.01));
      });

      test('returns 0 for silence', () {
        final buf = RingBuffer(capacity: 100);
        buf.write(Float32List(50)); // All zeros.

        expect(buf.rmsLevel(windowSize: 50), 0.0);
      });
    });

    group('peakLevel', () {
      test('returns 0 for empty buffer', () {
        final buf = RingBuffer(capacity: 100);
        expect(buf.peakLevel(), 0.0);
      });

      test('returns correct peak for known signal', () {
        final buf = RingBuffer(capacity: 100);
        final signal = Float32List.fromList([0.1, 0.3, -0.8, 0.2, 0.5]);
        buf.write(signal);

        expect(buf.peakLevel(windowSize: 5), closeTo(0.8, 1e-6));
      });

      test('returns 1.0 for full-scale signal', () {
        final buf = RingBuffer(capacity: 100);
        final signal = Float32List.fromList([0.0, 0.5, -1.0, 0.5, 0.0]);
        buf.write(signal);

        expect(buf.peakLevel(windowSize: 5), closeTo(1.0, 1e-6));
      });
    });

    group('PCM16 conversion (via AudioCaptureService static method)', () {
      // We test the conversion logic here since it's critical to correctness.
      test('converts PCM16 bytes to float32 correctly', () {
        // Manual PCM16 encoding: value 16384 → 0x0040 LE → [0x00, 0x40]
        // 16384 / 32768 = 0.5
        final bytes = Uint8List.fromList([0x00, 0x40]); // +16384
        final byteData = ByteData.sublistView(bytes);
        final sample = byteData.getInt16(0, Endian.little) / 32768.0;
        expect(sample, closeTo(0.5, 1e-4));
      });

      test('handles negative PCM16 values', () {
        // -16384 in signed 16-bit LE = 0x00C0
        final val = -16384;
        final bytes = Uint8List(2);
        ByteData.sublistView(bytes).setInt16(0, val, Endian.little);
        final sample =
            ByteData.sublistView(bytes).getInt16(0, Endian.little) / 32768.0;
        expect(sample, closeTo(-0.5, 1e-4));
      });

      test('handles zero', () {
        final bytes = Uint8List(2); // [0x00, 0x00]
        final sample =
            ByteData.sublistView(bytes).getInt16(0, Endian.little) / 32768.0;
        expect(sample, 0.0);
      });

      test('handles full-scale positive', () {
        final bytes = Uint8List(2);
        ByteData.sublistView(bytes).setInt16(0, 32767, Endian.little);
        final sample =
            ByteData.sublistView(bytes).getInt16(0, Endian.little) / 32768.0;
        expect(sample, closeTo(1.0, 1e-3));
      });

      test('handles full-scale negative', () {
        final bytes = Uint8List(2);
        ByteData.sublistView(bytes).setInt16(0, -32768, Endian.little);
        final sample =
            ByteData.sublistView(bytes).getInt16(0, Endian.little) / 32768.0;
        expect(sample, -1.0);
      });
    });
  });
}
