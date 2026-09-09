import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:birdnet_live/features/audio/ring_buffer.dart';
import 'package:birdnet_live/features/inference/detection_accumulator.dart';
import 'package:birdnet_live/features/inference/detection_clip_writer.dart';
import 'package:birdnet_live/features/inference/models/detection.dart';
import 'package:birdnet_live/features/inference/models/species.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/recording/recording_service.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const species = Species(
    index: 0,
    id: 1,
    scientificName: 'Turdus merula',
    commonName: 'Common Blackbird',
    className: 'Aves',
    order: 'Passeriformes',
  );
  final start = DateTime.utc(2026, 8, 6, 12);

  late Directory tempDir;
  late RingBuffer ringBuffer;
  late RecordingService recordingService;
  late List<DetectionRecord> records;
  late DetectionAccumulator accumulator;
  late List<DetectionRecord> settled;
  late DetectionClipWriter writer;
  var currentSession = true;

  Detection detection(double confidence, DateTime timestamp) =>
      Detection(species: species, confidence: confidence, timestamp: timestamp);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clip_writer_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    ringBuffer = RingBuffer(capacity: 10000);
    final audio = Float32List(2000);
    for (var i = 0; i < audio.length; i++) {
      audio[i] = ((i % 20) - 10) / 10;
    }
    ringBuffer.write(audio);

    recordingService = RecordingService(
      ringBuffer: ringBuffer,
      sampleRate: 1000,
      clipContextSeconds: 0,
      windowSeconds: 1,
    );
    await recordingService.startRecording(
      sessionId: 'clip-writer',
      mode: RecordingMode.detectionsOnly,
      format: 'wav',
    );

    records = [];
    accumulator = DetectionAccumulator(sessionStart: start, records: records);
    settled = [];
    currentSession = true;
    writer = DetectionClipWriter(
      recordingService: recordingService,
      debugLabel: 'test',
      accumulatorOf: () => accumulator,
      isCurrentSession: () => currentSession,
      onRecordsChanged: () {},
      onClipsSettled: settled.add,
    );
  });

  tearDown(() async {
    recordingService.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('only the strongest in-flight window remains attached', () async {
    final first = accumulator.processCycle(
      detections: [detection(0.5, start)],
      windowEnd: start.add(const Duration(seconds: 1)),
    );
    writer.requestClips(
      changes: first.changes,
      clipTimestamp: start,
      windowEndSample: 1000,
    );

    final stronger = accumulator.processCycle(
      detections: [detection(0.6, start.add(const Duration(seconds: 1)))],
      windowEnd: start.add(const Duration(seconds: 2)),
    );
    writer.requestClips(
      changes: stronger.changes,
      clipTimestamp: start.add(const Duration(seconds: 1)),
      windowEndSample: 2000,
    );

    await writer.drain();

    expect(records.single.confidence, 0.6);
    expect(records.single.clipTimestamp, start.add(const Duration(seconds: 1)));
    expect(records.single.audioClipPath, isNotNull);
    final clipFiles = Directory(recordingService.sessionDir!).listSync();
    expect(clipFiles.whereType<File>(), hasLength(1));
  });

  test('a closed record settles only after its clip is attached', () async {
    final cycle = accumulator.processCycle(
      detections: [detection(0.5, start)],
      windowEnd: start.add(const Duration(seconds: 1)),
    );
    writer.requestClips(
      changes: cycle.changes,
      clipTimestamp: start,
      windowEndSample: 1000,
    );
    final closed = accumulator.processCycle(
      detections: const [],
      windowEnd: start.add(const Duration(seconds: 2)),
    );

    expect(closed.closedRecords.single.audioClipPath, isNull);
    expect(writer.hasPendingWrite(closed.closedRecords.single), isTrue);
    expect(settled, isEmpty);

    await writer.drain();

    expect(settled, hasLength(1));
    expect(settled.single.endTimestamp, start.add(const Duration(seconds: 1)));
    expect(settled.single.audioClipPath, isNotNull);
  });

  test(
    'a stale session deletes its completed file instead of attaching it',
    () async {
      final cycle = accumulator.processCycle(
        detections: [detection(0.5, start)],
        windowEnd: start.add(const Duration(seconds: 1)),
      );
      writer.requestClips(
        changes: cycle.changes,
        clipTimestamp: start,
        windowEndSample: 1000,
      );
      currentSession = false;

      await writer.drain();

      expect(records.single.audioClipPath, isNull);
      final clipFiles = Directory(recordingService.sessionDir!).listSync();
      expect(clipFiles.whereType<File>(), isEmpty);
    },
  );
}
