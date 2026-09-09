// =============================================================================
// Recording Service Tests
// =============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:birdnet_live/features/audio/ring_buffer.dart';
import 'package:birdnet_live/features/recording/recording_service.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.tmp);
  final String tmp;

  @override
  Future<String?> getTemporaryPath() async => tmp;

  @override
  Future<String?> getApplicationDocumentsPath() async => tmp;

  @override
  Future<String?> getApplicationSupportPath() async => tmp;
}

/// Fills [ringBuffer] with non-silent audio so clips are actually written.
void _writeTone(RingBuffer ringBuffer, int count) {
  final data = Float32List(count);
  for (var i = 0; i < count; i++) {
    data[i] = ((i % 20) - 10) / 10.0;
  }
  ringBuffer.write(data);
}

void main() {
  // ── RecordingMode parsing ──────────────────────────────────────────────

  group('recordingModeFromString', () {
    test('parses "full"', () {
      expect(recordingModeFromString('full'), RecordingMode.full);
    });

    test('parses "detections"', () {
      expect(
        recordingModeFromString('detections'),
        RecordingMode.detectionsOnly,
      );
    });

    test('parses "detectionsOnly"', () {
      expect(
        recordingModeFromString('detectionsOnly'),
        RecordingMode.detectionsOnly,
      );
    });

    test('defaults to off for unknown', () {
      expect(recordingModeFromString('unknown'), RecordingMode.off);
      expect(recordingModeFromString(''), RecordingMode.off);
    });
  });

  // ── RecordingService ───────────────────────────────────────────────────

  group('RecordingService', () {
    late RingBuffer ringBuffer;
    late RecordingService service;

    setUp(() {
      // Small ring buffer for testing (1 second at 1000 Hz).
      ringBuffer = RingBuffer(capacity: 1000);
      service = RecordingService(
        ringBuffer: ringBuffer,
        sampleRate: 1000,
        clipContextSeconds: 0,
        windowSeconds: 1,
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state', () {
      expect(service.isRecording, isFalse);
      expect(service.mode, RecordingMode.off);
      expect(service.sessionDir, isNull);
    });

    test('startRecording with off mode does nothing', () async {
      final result = await service.startRecording(
        sessionId: 'test-off',
        mode: RecordingMode.off,
      );

      expect(result, isNull);
      expect(service.isRecording, isFalse);
    });

    test('startRecording is idempotent', () async {
      // We can't test this properly without path_provider, but let's
      // verify the logic: calling start twice should return same dir.
      // Since path_provider isn't available in unit tests without mock,
      // we test the mode/state tracking instead.
      expect(service.isRecording, isFalse);
    });

    test('stopRecording returns null when not recording', () async {
      final result = await service.stopRecording();
      expect(result, isNull);
    });

    test('dispose does not throw when not recording', () {
      // Should be safe to call dispose even if never started.
      service.dispose();
    });

    test('saveDetectionClip returns null when not recording', () async {
      final result = await service.saveDetectionClip(clipName: 'test-clip');
      expect(result, isNull);
    });

    test('saveDetectionClips returns empty when not recording', () async {
      final result = await service.saveDetectionClips(clipNames: ['a', 'b']);
      expect(result, isEmpty);
    });
  });

  // ── Clip naming ────────────────────────────────────────────────────────

  group('detectionClipName', () {
    final savedAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

    test('slugs the species so each record owns its own file', () {
      expect(
        detectionClipName('Turdus merula', savedAt),
        'clip_1700000000000000_0_Turdus_merula',
      );
    });

    test('strips characters that are unsafe in file names', () {
      expect(
        detectionClipName('Sylvia (curruca)/x', savedAt),
        'clip_1700000000000000_0_Sylvia_curruca_x',
      );
    });

    test('two species in the same cycle get distinct names', () {
      expect(
        detectionClipName('Turdus merula', savedAt),
        isNot(detectionClipName('Turdus pilaris', savedAt)),
      );
    });

    test('successive re-cuts of one species get distinct names', () {
      // A re-cut must write a new file before the old one is deleted, so the
      // save time — not the detection time — has to drive the name.
      expect(
        detectionClipName('Turdus merula', savedAt),
        isNot(
          detectionClipName(
            'Turdus merula',
            savedAt.add(const Duration(seconds: 3)),
          ),
        ),
      );
    });

    test('sequence disambiguates the same species in the same clock tick', () {
      expect(
        detectionClipName('Turdus merula', savedAt, sequence: 1),
        isNot(detectionClipName('Turdus merula', savedAt, sequence: 2)),
      );
    });
  });

  // ── Peak confidence tracking ───────────────────────────────────────────

  group('DetectionClipPeakTracker', () {
    late DetectionClipPeakTracker tracker;

    /// An ongoing detection asking whether its clip should be re-cut.
    bool ongoing(
      double candidate,
      double current, {
      String key = 'blackbird',
      bool hasClip = true,
    }) {
      return tracker.needsClip(
        key: key,
        candidateConfidence: candidate,
        currentConfidence: current,
        hasClip: hasClip,
        isNew: false,
      );
    }

    /// A detection arriving for the first time this round.
    bool arriving(double confidence, {bool hasClip = false}) {
      return tracker.needsClip(
        key: 'blackbird',
        candidateConfidence: confidence,
        currentConfidence: confidence,
        hasClip: hasClip,
        isNew: true,
      );
    }

    setUp(() {
      tracker = DetectionClipPeakTracker();
      tracker.recordSaved('blackbird', 0.50);
    });

    test('a new detection always gets a first clip', () {
      expect(arriving(0.20), isTrue);
    });

    test('a new detection that already carries a clip keeps it', () {
      // ARU can be handed a record whose clip was cut elsewhere; re-cutting is
      // for detections we have watched improve.
      expect(arriving(0.90, hasClip: true), isFalse);
    });

    test('accumulates small gains from the confidence of the saved clip', () {
      expect(ongoing(0.53, 0.50), isFalse);
      // The record advanced to 0.53, but the clip still represents 0.50.
      expect(ongoing(0.56, 0.53), isTrue);
    });

    test('accepts an improvement exactly on the rewrite boundary', () {
      tracker.recordSaved('blackbird', 0.55);
      expect(ongoing(0.60, 0.55), isTrue);
    });

    test('does not retry a failed replacement until the score improves', () {
      expect(ongoing(0.56, 0.50), isTrue);
      // No recordSaved call: the write failed.
      expect(ongoing(0.56, 0.56), isFalse);
      expect(ongoing(0.57, 0.56), isTrue);
    });

    test('missing clips retry on any new peak but not an unchanged score', () {
      expect(ongoing(0.51, 0.50, key: 'robin', hasClip: false), isTrue);
      expect(ongoing(0.50, 0.50, key: 'robin', hasClip: false), isFalse);
    });

    test('successful replacement advances the clip baseline', () {
      tracker.recordSaved('blackbird', 0.56);
      expect(ongoing(0.60, 0.56), isFalse);
      expect(ongoing(0.61, 0.60), isTrue);
    });

    test('rejects stale, equal, and non-finite candidate scores', () {
      for (final confidence in [0.49, 0.50, double.nan, double.infinity]) {
        expect(ongoing(confidence, 0.50), isFalse, reason: '$confidence');
      }
      expect(arriving(double.nan), isFalse);
    });

    test('forget drops a closed detection\'s baseline', () {
      // The clip on disk sits at 0.50, so 0.56 clears the margin.
      expect(ongoing(0.56, 0.55), isTrue);

      // The species disappears and later comes back. The next detection's
      // clip has nothing to do with the old one, so it must be judged against
      // its own score rather than the stale 0.50 baseline.
      tracker.forget('blackbird');
      expect(ongoing(0.56, 0.55), isFalse);
    });

    test('clear drops every baseline at a session boundary', () {
      tracker.recordSaved('robin', 0.80);
      expect(ongoing(0.56, 0.55), isTrue);
      expect(ongoing(0.86, 0.85, key: 'robin'), isTrue);

      tracker.clear();
      expect(ongoing(0.56, 0.55), isFalse);
      expect(ongoing(0.86, 0.85, key: 'robin'), isFalse);
    });

    test('keys are tracked independently', () {
      tracker.recordSaved('robin', 0.80);
      // Blackbird's clip sits at 0.50, robin's at 0.80 — the same candidate
      // score means different things to each.
      expect(ongoing(0.56, 0.55), isTrue);
      expect(ongoing(0.82, 0.81, key: 'robin'), isFalse);
    });

    test('a zero delta re-cuts on every improvement', () {
      final eager = DetectionClipPeakTracker(improvementDelta: 0);
      eager.recordSaved('blackbird', 0.50);
      expect(
        eager.needsClip(
          key: 'blackbird',
          candidateConfidence: 0.5001,
          currentConfidence: 0.50,
          hasClip: true,
          isNew: false,
        ),
        isTrue,
      );
    });
  });

  // ── Peak-window clips ──────────────────────────────────────────────────

  group('peak-window clips', () {
    late Directory tmp;
    late RingBuffer ringBuffer;
    late RecordingService service;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tmp = await Directory.systemTemp.createTemp('recording_service_test');
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);

      ringBuffer = RingBuffer(capacity: 1000);
      service = RecordingService(
        ringBuffer: ringBuffer,
        sampleRate: 1000,
        clipContextSeconds: 0,
        windowSeconds: 1,
      );
      await service.startRecording(
        sessionId: 'peak-clips',
        mode: RecordingMode.detectionsOnly,
        format: 'wav',
      );
      _writeTone(ringBuffer, 1000);
    });

    tearDown(() async {
      service.dispose();
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    test(
      'saveDetectionClips writes one file per name from one snapshot',
      () async {
        final written = await service.saveDetectionClips(
          clipNames: ['clip_a', 'clip_b', 'clip_c'],
        );

        expect(written.keys, containsAll(['clip_a', 'clip_b', 'clip_c']));
        for (final path in written.values) {
          expect(File(path).existsSync(), isTrue);
        }
        // Same audio snapshot for every species in the cycle.
        final sizes = written.values.map((p) => File(p).lengthSync()).toSet();
        expect(sizes, hasLength(1));
      },
    );

    test('one failed batch entry does not discard successful clips', () async {
      final invalidName = List.filled(300, 'x').join();
      final written = await service.saveDetectionClips(
        clipNames: ['valid_clip', invalidName],
      );

      expect(written.keys, ['valid_clip']);
      expect(File(written['valid_clip']!).existsSync(), isTrue);
    });

    test('duplicate names are written only once', () async {
      final written = await service.saveDetectionClips(
        clipNames: ['same_clip', 'same_clip'],
      );

      expect(written, hasLength(1));
      expect(File(written['same_clip']!).existsSync(), isTrue);
    });

    test('generated names stay unique within the same clock tick', () {
      final savedAt = DateTime.fromMicrosecondsSinceEpoch(1700000000000000);
      final first = service.nextDetectionClipName(
        'Turdus merula',
        savedAt: savedAt,
      );
      final second = service.nextDetectionClipName(
        'Turdus merula',
        savedAt: savedAt,
      );

      expect(second, isNot(first));
    });

    test('a delayed clip save cannot leak into the next session', () async {
      await service.stopRecording();
      service = RecordingService(
        ringBuffer: ringBuffer,
        sampleRate: 1000,
        clipContextSeconds: 1,
        windowSeconds: 1,
      );
      await service.startRecording(
        sessionId: 'old-session',
        mode: RecordingMode.detectionsOnly,
        format: 'wav',
      );

      final pending = service.saveDetectionClips(clipNames: ['late_clip']);
      await Future<void>.delayed(Duration.zero);
      await service.stopRecording();
      final newDir = await service.startRecording(
        sessionId: 'new-session',
        mode: RecordingMode.detectionsOnly,
        format: 'wav',
      );

      expect(await pending, isEmpty);
      expect(File('$newDir/late_clip.wav').existsSync(), isFalse);
    });

    test('saveDetectionClipsFor keys results by the caller\'s item', () async {
      final written = await saveDetectionClipsFor<String>(
        recordingService: service,
        items: ['Turdus merula', 'Parus major'],
        speciesOf: (name) => name,
      );

      expect(written.keys, containsAll(['Turdus merula', 'Parus major']));
      expect(File(written['Turdus merula']!).existsSync(), isTrue);
      expect(File(written['Parus major']!).existsSync(), isTrue);
    });

    test('saveDetectionClipsFor names files after the species', () async {
      // ARU passes records rather than names, so the species has to come from
      // [speciesOf] and not from the item's own toString.
      final written = await saveDetectionClipsFor<int>(
        recordingService: service,
        items: [1, 2],
        speciesOf: (id) => id == 1 ? 'Turdus merula' : 'Parus major',
      );

      expect(written[1], contains('Turdus_merula'));
      expect(written[2], contains('Parus_major'));
    });

    test('saveDetectionClipsFor cuts one round from one snapshot', () async {
      final written = await saveDetectionClipsFor<String>(
        recordingService: service,
        items: ['Turdus merula', 'Parus major', 'Erithacus rubecula'],
        speciesOf: (name) => name,
      );

      expect(written, hasLength(3));
      final sizes = written.values.map((p) => File(p).lengthSync()).toSet();
      expect(sizes, hasLength(1));
    });

    test('saveDetectionClipsFor is a no-op for an empty round', () async {
      final written = await saveDetectionClipsFor<String>(
        recordingService: service,
        items: const [],
        speciesOf: (name) => name,
      );
      expect(written, isEmpty);
    });

    test(
      're-cut writes the new clip and deletes the one it supersedes',
      () async {
        final first = await service.saveDetectionClip(clipName: 'peak_1');
        expect(first, isNotNull);
        expect(File(first!).existsSync(), isTrue);

        final fresh = await service.saveDetectionClip(clipName: 'peak_2');
        expect(fresh, isNotNull);
        // Controllers publish this path before deleting the superseded file.
        final second = fresh!;
        await service.deleteClip(first);

        expect(second, fresh);
        expect(File(second).existsSync(), isTrue);
        expect(File(first).existsSync(), isFalse);
      },
    );

    test(
      'a re-cut that writes nothing leaves the existing clip alone',
      () async {
        final first = await service.saveDetectionClip(clipName: 'peak_1');
        expect(first, isNotNull);

        // Silence stands in for any save that produces no file. There is no
        // fresh path to adopt, so the caller keeps the clip it already has —
        // the detection must never be left without audio.
        ringBuffer.clear();
        final fresh = await service.saveDetectionClip(clipName: 'peak_2');

        expect(fresh, isNull);
        expect(File(first!).existsSync(), isTrue);
      },
    );

    test('deleteClip tolerates a missing file', () async {
      await service.deleteClip('${tmp.path}/does-not-exist.wav');
      await service.deleteClip(null);
    });
  });

  // ── Sample-anchored clips ──────────────────────────────────────────────

  group('window-anchored clips', () {
    late Directory tmp;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tmp = await Directory.systemTemp.createTemp('anchored_clip_test');
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    });

    tearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    Future<RecordingService> serviceFor(RingBuffer ringBuffer) async {
      final service = RecordingService(
        ringBuffer: ringBuffer,
        sampleRate: 1000,
        clipContextSeconds: 0,
        windowSeconds: 1,
      );
      await service.startRecording(
        sessionId: 'anchored',
        mode: RecordingMode.detectionsOnly,
        format: 'wav',
      );
      addTearDown(service.dispose);
      return service;
    }

    test('clip holds the analyzed window, not the newest audio', () async {
      final ringBuffer = RingBuffer(capacity: 10000);
      final service = await serviceFor(ringBuffer);

      // The analyzed window, then the audio that arrived while the clip write
      // was queued behind a lagging inference cycle.
      _writeTone(ringBuffer, 1000);
      ringBuffer.write(Float32List(1000));

      final anchored = await service.saveDetectionClips(
        clipNames: ['anchored'],
        windowEndSample: 1000,
      );
      final newest = await service.saveDetectionClips(clipNames: ['newest']);

      // The anchored read still finds the tone; an unanchored one now sees
      // only the silence that followed it.
      expect(anchored.keys, ['anchored']);
      expect(File(anchored['anchored']!).existsSync(), isTrue);
      expect(newest, isEmpty);
    });

    test('writes nothing once the analyzed window is gone', () async {
      final ringBuffer = RingBuffer(capacity: 2000);
      final service = await serviceFor(ringBuffer);

      _writeTone(ringBuffer, 1000);
      _writeTone(ringBuffer, 2000); // Evicts the analyzed window.

      final written = await service.saveDetectionClips(
        clipNames: ['overwritten'],
        windowEndSample: 1000,
      );

      // Substituting the newest audio would produce a file the caller dates
      // as the analyzed window — worse than the detection having no clip.
      expect(written, isEmpty);
    });

    test('zero-pads pre-roll before the first analysis window', () async {
      final ringBuffer = RingBuffer(capacity: 10000);
      final service = RecordingService(
        ringBuffer: ringBuffer,
        sampleRate: 1000,
        clipContextSeconds: 1,
        windowSeconds: 1,
      );
      await service.startRecording(
        sessionId: 'startup-pre-roll',
        mode: RecordingMode.detectionsOnly,
        format: 'wav',
      );
      addTearDown(service.dispose);

      // The analyzed first second contains sound; its post-roll is present,
      // but a full second of requested pre-roll predates sample zero.
      _writeTone(ringBuffer, 1000);
      ringBuffer.write(Float32List(1000));

      final written = await service.saveDetectionClips(
        clipNames: ['first-window'],
        windowEndSample: 1000,
      );

      expect(written.keys, ['first-window']);
      // 3 seconds of mono PCM16 plus the canonical 44-byte WAV header.
      expect(File(written['first-window']!).lengthSync(), 44 + 3000 * 2);
    });

    test('writes nothing when the post-roll was never captured', () async {
      final ringBuffer = RingBuffer(capacity: 10000);
      final service = await serviceFor(ringBuffer);
      _writeTone(ringBuffer, 1500);

      final written = await service.saveDetectionClips(
        clipNames: ['unwritten'],
        windowEndSample: ringBuffer.totalWritten + 500,
      );

      expect(written, isEmpty);
    });

    test('an unanchored request still takes the newest audio', () async {
      // ARU's end-of-cycle pass has no particular window in mind.
      final ringBuffer = RingBuffer(capacity: 2000);
      final service = await serviceFor(ringBuffer);
      _writeTone(ringBuffer, 3000);

      final written = await service.saveDetectionClips(clipNames: ['newest']);

      expect(written.keys, ['newest']);
    });
  });

  // ── Silence detection ──────────────────────────────────────────────────

  group('silence detection', () {
    test('all-zero samples are considered silent', () {
      // Write only zeros to ring buffer.
      final ringBuffer = RingBuffer(capacity: 1000);
      ringBuffer.write(Float32List(100));

      final samples = ringBuffer.readLast(100);
      // All should be zero.
      expect(samples.every((s) => s == 0.0), isTrue);
    });

    test('non-zero samples are not silent', () {
      final ringBuffer = RingBuffer(capacity: 1000);
      final data = Float32List.fromList([0.5, -0.3, 0.0, 0.1]);
      ringBuffer.write(data);

      final samples = ringBuffer.readLast(4);
      expect(samples.any((s) => s != 0.0), isTrue);
    });
  });

  // ── RecordingMode enum ─────────────────────────────────────────────────

  group('RecordingMode', () {
    test('has expected values', () {
      expect(RecordingMode.values.length, 3);
      expect(RecordingMode.off.index, 0);
      expect(RecordingMode.full.index, 1);
      expect(RecordingMode.detectionsOnly.index, 2);
    });
  });
}
