// =============================================================================
// Session Repository Tests
// =============================================================================

import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_providers.dart';
import 'package:birdnet_live/features/live/live_session.dart';

void main() {
  late Directory tempDir;
  late SessionRepository repo;

  // ── Helpers ──────────────────────────────────────────────────────────

  LiveSession makeSession({
    String id = 'test-session-1',
    DateTime? startTime,
    DateTime? endTime,
    List<DetectionRecord>? detections,
    String? recordingPath,
  }) {
    return LiveSession(
      id: id,
      startTime: startTime ?? DateTime(2025, 6, 15, 10, 0),
      endTime: endTime ?? DateTime(2025, 6, 15, 10, 30),
      detections: detections,
      recordingPath: recordingPath,
      settings: const SessionSettings(
        windowDuration: 3,
        confidenceThreshold: 25,
        inferenceRate: 1.0,
        speciesFilterMode: 'off',
      ),
    );
  }

  DetectionRecord makeDetection({
    String scientific = 'Turdus merula',
    String common = 'Eurasian Blackbird',
    double confidence = 0.85,
    DateTime? timestamp,
    String? audioClipPath,
    String? voiceMemoPath,
  }) {
    return DetectionRecord(
      scientificName: scientific,
      commonName: common,
      confidence: confidence,
      timestamp: timestamp ?? DateTime(2025, 6, 15, 10, 5),
      audioClipPath: audioClipPath,
      voiceMemoPath: voiceMemoPath,
    );
  }

  // ── Setup / teardown ────────────────────────────────────────────────

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_repo_test_');
    repo = SessionRepository();
    repo.basePath = tempDir.path;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ── save / load ──────────────────────────────────────────────────────

  group('save and load', () {
    test('saves and loads a session round-trip', () async {
      final session = makeSession(
        detections: [
          makeDetection(),
          makeDetection(
            scientific: 'Parus major',
            common: 'Great Tit',
            confidence: 0.72,
          ),
        ],
      );

      await repo.save(session);
      final loaded = await repo.load('test-session-1');

      expect(loaded, isNotNull);
      expect(loaded!.id, 'test-session-1');
      expect(
        loaded.startTime.isAtSameMomentAs(DateTime(2025, 6, 15, 10, 0)),
        isTrue,
      );
      expect(
        loaded.endTime!.isAtSameMomentAs(DateTime(2025, 6, 15, 10, 30)),
        isTrue,
      );
      expect(loaded.detections.length, 2);
      expect(loaded.detections[0].scientificName, 'Turdus merula');
      expect(loaded.detections[1].commonName, 'Great Tit');
      expect(loaded.settings.windowDuration, 3);
      expect(loaded.settings.speciesFilterMode, 'off');
    });

    test('load returns null for missing session', () async {
      final loaded = await repo.load('nonexistent');
      expect(loaded, isNull);
    });

    test('save overwrites existing session', () async {
      final session1 = makeSession(detections: [makeDetection()]);
      await repo.save(session1);

      final session2 = makeSession(
        detections: [
          makeDetection(),
          makeDetection(scientific: 'Parus major', common: 'Great Tit'),
        ],
      );
      await repo.save(session2);

      final loaded = await repo.load('test-session-1');
      expect(loaded!.detections.length, 2);
    });

    test(
      'checkpoint is recoverable without ending the running session',
      () async {
        final active = LiveSession(
          id: 'active-checkpoint',
          startTime: DateTime.now().subtract(const Duration(minutes: 2)),
          settings: const SessionSettings(
            windowDuration: 3,
            confidenceThreshold: 25,
            inferenceRate: 1,
            speciesFilterMode: 'off',
          ),
        )..startSegment();

        await repo.saveCheckpoint(active);

        expect(active.endTime, isNull);
        final recovered = await repo.load(active.id);
        expect(recovered?.endTime, isNotNull);
        expect((await repo.listAll()).single.id, active.id);
      },
    );

    test('ARU checkpoint appears ended with an interrupted cycle', () async {
      final start = DateTime.now().subtract(const Duration(seconds: 20));
      final session = makeSession(id: 'aru-checkpoint')
        ..type = SessionType.aru
        ..endTime = null
        ..aruMetadata = AruDeploymentMetadata(
          scheduleStart: start,
          cycleDurationSeconds: 60,
          repeatIntervalSeconds: 120,
          eachCycleIsSession: false,
          cycles: [
            AruCycleMetadata(
              index: 1,
              plannedStart: start,
              plannedEnd: start.add(const Duration(seconds: 60)),
              actualStart: start,
              status: AruCycleStatus.recording,
            ),
          ],
        );

      await repo.saveCheckpoint(session);

      final recovered = await repo.load(session.id);
      expect(session.endTime, isNull);
      expect(
        session.aruMetadata!.cycles.single.status,
        AruCycleStatus.recording,
      );
      expect(recovered?.endTime, isNotNull);
      expect(
        recovered?.aruMetadata?.cycles.single.status,
        AruCycleStatus.partial,
      );
      expect(recovered?.aruMetadata?.cycles.single.actualEnd, isNotNull);
    });

    test('recovers an interrupted replacement from the backup', () async {
      final session = makeSession();
      await repo.save(session);
      final primary = File(p.join(tempDir.path, '${session.id}.json'));
      final backup = File(p.join(tempDir.path, '${session.id}.recovery.json'));
      await primary.rename(backup.path);

      expect((await repo.load(session.id))?.id, session.id);
      expect((await repo.listAll()).map((item) => item.id), [session.id]);
      expect(await repo.count(), 1);
    });

    test('recovers the first checkpoint from a flushed pending file', () async {
      final session = makeSession(id: 'first-checkpoint');
      await repo.saveCheckpoint(session);
      final primary = File(p.join(tempDir.path, '${session.id}.json'));
      await primary.rename(p.join(tempDir.path, '${session.id}.pending'));

      expect((await repo.load(session.id))?.id, session.id);
      expect((await repo.listAll()).map((item) => item.id), [session.id]);
      expect(await repo.count(), 1);
    });

    test('prefers a newer pending snapshot over the old primary', () async {
      final session = makeSession()..customName = 'old';
      await repo.save(session);
      final primary = File(p.join(tempDir.path, '${session.id}.json'));
      final oldPrimary = File(p.join(tempDir.path, '${session.id}.old'));
      await primary.copy(oldPrimary.path);

      session.customName = 'new';
      await repo.save(session);
      await primary.rename(p.join(tempDir.path, '${session.id}.pending'));
      await oldPrimary.rename(primary.path);

      expect((await repo.load(session.id))?.customName, 'new');
      expect((await repo.listAll()).single.customName, 'new');
    });

    test('uses backup when the primary is corrupt', () async {
      final session = makeSession();
      await repo.save(session);
      final primary = File(p.join(tempDir.path, '${session.id}.json'));
      final backup = File(p.join(tempDir.path, '${session.id}.recovery.json'));
      await primary.copy(backup.path);
      await primary.writeAsString('{broken', flush: true);

      expect((await repo.load(session.id))?.id, session.id);
      expect((await repo.listAll()).map((item) => item.id), [session.id]);
    });

    test('deleteAll drains saves that already started', () async {
      final session = makeSession(
        id: 'concurrent-save',
        detections: List.generate(2000, (_) => makeDetection()),
      );

      final save = repo.saveCheckpoint(session);
      await repo.deleteAll();
      await save;

      expect(await repo.count(), 0);
      expect(await repo.listAll(), isEmpty);
    });

    test('an early Point Count remains alongside the previous count', () async {
      final previous = makeSession(id: 'point-count-previous')
        ..type = SessionType.pointCount
        ..sessionNumber = 1;
      await repo.save(previous);

      final current = makeSession(
        id: 'point-count-current',
        startTime: DateTime(2025, 6, 15, 11),
        endTime: DateTime(2025, 6, 15, 11, 3),
      )..type = SessionType.pointCount;
      current.sessionNumber = await repo.nextSessionNumber(current.type);
      await repo.save(current);

      final listed = await repo.listAll();
      expect(listed.map((session) => session.id), [current.id, previous.id]);
      expect((await repo.load(current.id))?.sessionNumber, 2);
    });

    test('library refresh includes the newly saved Point Count', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [sessionRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final previous = makeSession(id: 'previous')
        ..type = SessionType.pointCount;
      await repo.save(previous);
      expect(
        (await container.read(sessionListProvider.future)).map((s) => s.id),
        [previous.id],
      );

      final current = makeSession(
        id: 'current',
        startTime: DateTime(2025, 6, 15, 11),
      )..type = SessionType.pointCount;
      await repo.save(current);
      expect(
        (await container.refresh(sessionListProvider.future)).map((s) => s.id),
        [current.id, previous.id],
      );
    });

    test('preserves session without detections', () async {
      final session = makeSession();
      await repo.save(session);

      final loaded = await repo.load('test-session-1');
      expect(loaded!.detections, isEmpty);
    });

    test('preserves session without endTime', () async {
      // Create a session without endTime (constructor default).
      final activeSession = LiveSession(
        id: 'active-session',
        startTime: DateTime(2025, 6, 15, 10, 0),
        settings: const SessionSettings(
          windowDuration: 3,
          confidenceThreshold: 25,
          inferenceRate: 1.0,
          speciesFilterMode: 'off',
        ),
      );

      await repo.save(activeSession);
      final loaded = await repo.load('active-session');
      expect(loaded!.endTime, isNull);
    });

    test('stores app-owned recording paths relative to Documents', () async {
      final documentsDir = tempDir.parent.path;
      final session = makeSession(
        recordingPath: p.join(
          documentsDir,
          'recordings',
          'test-session-1',
          'full.flac',
        ),
        detections: [
          makeDetection(
            audioClipPath: p.join(
              documentsDir,
              'recordings',
              'test-session-1',
              'clip_1.flac',
            ),
            voiceMemoPath: p.join(
              documentsDir,
              'recordings',
              'test-session-1',
              'memos',
              'memo_1.m4a',
            ),
          ),
        ],
      );
      session.annotations.add(
        SessionAnnotation(
          text: '',
          createdAt: DateTime(2025, 6, 15, 10, 10),
          voiceMemoPath: p.join(
            documentsDir,
            'recordings',
            'test-session-1',
            'memos',
            'annotation_1.m4a',
          ),
        ),
      );
      session.aruMetadata = AruDeploymentMetadata(
        scheduleStart: DateTime(2025, 6, 15, 10),
        cycleDurationSeconds: 60,
        repeatIntervalSeconds: 120,
        eachCycleIsSession: true,
        cycles: [
          AruCycleMetadata(
            index: 0,
            plannedStart: DateTime(2025, 6, 15, 10),
            plannedEnd: DateTime(2025, 6, 15, 10, 1),
            recordingPath: p.join(
              documentsDir,
              'recordings',
              'test-session-1',
              'cycle_000',
              'full.flac',
            ),
          ),
        ],
      );

      await repo.save(session);

      final raw =
          jsonDecode(
                await File(
                  '${tempDir.path}/test-session-1.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(raw['recordingPath'], 'recordings/test-session-1/full.flac');
      final detections = raw['detections'] as List<dynamic>;
      final detection = detections.single as Map<String, dynamic>;
      expect(
        detection['audioClipPath'],
        'recordings/test-session-1/clip_1.flac',
      );
      expect(
        detection['voiceMemoPath'],
        'recordings/test-session-1/memos/memo_1.m4a',
      );
      final annotations = raw['annotations'] as List<dynamic>;
      expect(
        (annotations.single as Map<String, dynamic>)['voiceMemoPath'],
        'recordings/test-session-1/memos/annotation_1.m4a',
      );
      final aru = raw['aru'] as Map<String, dynamic>;
      final cycles = aru['cycles'] as List<dynamic>;
      expect(
        (cycles.single as Map<String, dynamic>)['recordingPath'],
        'recordings/test-session-1/cycle_000/full.flac',
      );

      final loaded = await repo.load('test-session-1');
      expect(
        loaded!.recordingPath,
        p.join(documentsDir, 'recordings', 'test-session-1', 'full.flac'),
      );
      expect(
        loaded.detections.single.audioClipPath,
        p.join(documentsDir, 'recordings', 'test-session-1', 'clip_1.flac'),
      );
      expect(
        loaded.detections.single.voiceMemoPath,
        p.join(
          documentsDir,
          'recordings',
          'test-session-1',
          'memos',
          'memo_1.m4a',
        ),
      );
    });

    test('remaps stale iOS Documents paths when loading', () async {
      final staleIosPath =
          '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/'
          'recordings/legacy/full.flac';
      final json = makeSession(
        id: 'legacy',
        recordingPath: staleIosPath,
        detections: [
          makeDetection(
            audioClipPath:
                '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/'
                'recordings/legacy/clip_1.flac',
          ),
        ],
      ).toJson();
      await File('${tempDir.path}/legacy.json').writeAsString(jsonEncode(json));

      final loaded = await repo.load('legacy');

      expect(
        loaded!.recordingPath,
        p.join(tempDir.parent.path, 'recordings', 'legacy', 'full.flac'),
      );
      expect(
        loaded.detections.single.audioClipPath,
        p.join(tempDir.parent.path, 'recordings', 'legacy', 'clip_1.flac'),
      );
    });
  });

  // ── listAll ──────────────────────────────────────────────────────────

  group('listAll', () {
    test('returns empty for fresh repo', () async {
      final sessions = await repo.listAll();
      expect(sessions, isEmpty);
    });

    test('returns all saved sessions sorted newest first', () async {
      await repo.save(
        makeSession(
          id: 'session-1',
          startTime: DateTime(2025, 1, 1),
          endTime: DateTime(2025, 1, 1, 1),
        ),
      );
      await repo.save(
        makeSession(
          id: 'session-3',
          startTime: DateTime(2025, 3, 1),
          endTime: DateTime(2025, 3, 1, 1),
        ),
      );
      await repo.save(
        makeSession(
          id: 'session-2',
          startTime: DateTime(2025, 2, 1),
          endTime: DateTime(2025, 2, 1, 1),
        ),
      );

      final sessions = await repo.listAll();
      expect(sessions.length, 3);
      expect(sessions[0].id, 'session-3');
      expect(sessions[1].id, 'session-2');
      expect(sessions[2].id, 'session-1');
    });

    test('skips corrupt files gracefully', () async {
      await repo.save(makeSession());

      // Write a corrupt file.
      final corruptFile = File('${tempDir.path}/corrupt.json');
      await corruptFile.writeAsString('not valid json{{{');

      final sessions = await repo.listAll();
      expect(sessions.length, 1);
    });

    test('ignores non-json files', () async {
      await repo.save(makeSession());

      // Write a non-JSON file.
      final textFile = File('${tempDir.path}/notes.txt');
      await textFile.writeAsString('some notes');

      final sessions = await repo.listAll();
      expect(sessions.length, 1);
    });
  });

  // ── delete ───────────────────────────────────────────────────────────

  group('delete', () {
    test('removes a saved session', () async {
      await repo.save(makeSession());
      expect(await repo.count(), 1);

      await repo.delete('test-session-1');
      expect(await repo.count(), 0);
      expect(await repo.load('test-session-1'), isNull);
    });

    test('delete is safe for non-existent session', () async {
      // Should not throw.
      await repo.delete('nonexistent');
    });

    test('deleteMetadataOnly keeps associated recording directory', () async {
      await repo.save(makeSession(id: 'aru-1'));
      final recordingsDir = Directory(
        '${tempDir.parent.path}/recordings/aru-1',
      );
      await recordingsDir.create(recursive: true);
      await File('${recordingsDir.path}/clip.flac').writeAsString('audio');

      await repo.deleteMetadataOnly('aru-1');

      expect(await repo.load('aru-1'), isNull);
      expect(await recordingsDir.exists(), isTrue);
    });
  });

  // ── deleteAll ────────────────────────────────────────────────────────

  group('deleteAll', () {
    test('removes all sessions', () async {
      await repo.save(makeSession(id: 'a'));
      await repo.save(makeSession(id: 'b'));
      await repo.save(makeSession(id: 'c'));
      expect(await repo.count(), 3);

      await repo.deleteAll();
      expect(await repo.count(), 0);
    });

    test('deleteAll on empty repo does not throw', () async {
      await repo.deleteAll();
      expect(await repo.count(), 0);
    });
  });

  // ── count ────────────────────────────────────────────────────────────

  group('count', () {
    test('returns 0 for empty repo', () async {
      expect(await repo.count(), 0);
    });

    test('returns correct count', () async {
      await repo.save(makeSession(id: 'a'));
      await repo.save(makeSession(id: 'b'));
      expect(await repo.count(), 2);
    });
  });

  // ── nextSessionNumber ────────────────────────────────────────────────

  group('nextSessionNumber', () {
    test('returns 1 when no sessions exist', () async {
      expect(await repo.nextSessionNumber(SessionType.live), 1);
    });

    test('returns correct sequential number for type', () async {
      final s1 = makeSession(id: 's1');
      s1.type = SessionType.live;
      s1.sessionNumber = 5;
      await repo.save(s1);

      final s2 = makeSession(id: 's2');
      s2.type = SessionType.live;
      s2.sessionNumber = 2;
      await repo.save(s2);

      // A session of a different type should not affect it.
      final s3 = makeSession(id: 's3');
      s3.type = SessionType.pointCount;
      s3.sessionNumber = 10;
      await repo.save(s3);

      expect(await repo.nextSessionNumber(SessionType.live), 6);
      expect(await repo.nextSessionNumber(SessionType.pointCount), 11);
    });
  });

  // ── ID sanitisation ──────────────────────────────────────────────────

  group('ID sanitisation', () {
    test('handles IDs with special characters', () async {
      final session = makeSession(id: '2025-06-15T10:30:00.000');
      await repo.save(session);

      final loaded = await repo.load('2025-06-15T10:30:00.000');
      expect(loaded, isNotNull);
      expect(loaded!.id, '2025-06-15T10:30:00.000');
    });
  });
}
