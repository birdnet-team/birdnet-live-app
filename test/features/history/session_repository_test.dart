// =============================================================================
// Session Repository Tests
// =============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/history/session_repository.dart';
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
  }) {
    return LiveSession(
      id: id,
      startTime: startTime ?? DateTime(2025, 6, 15, 10, 0),
      endTime: endTime ?? DateTime(2025, 6, 15, 10, 30),
      detections: detections,
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
  }) {
    return DetectionRecord(
      scientificName: scientific,
      commonName: common,
      confidence: confidence,
      timestamp: timestamp ?? DateTime(2025, 6, 15, 10, 5),
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
      expect(loaded.startTime, DateTime(2025, 6, 15, 10, 0));
      expect(loaded.endTime, DateTime(2025, 6, 15, 10, 30));
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
      final session1 = makeSession(
        detections: [makeDetection()],
      );
      await repo.save(session1);

      final session2 = makeSession(
        detections: [
          makeDetection(),
          makeDetection(
            scientific: 'Parus major',
            common: 'Great Tit',
          ),
        ],
      );
      await repo.save(session2);

      final loaded = await repo.load('test-session-1');
      expect(loaded!.detections.length, 2);
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
  });

  // ── listAll ──────────────────────────────────────────────────────────

  group('listAll', () {
    test('returns empty for fresh repo', () async {
      final sessions = await repo.listAll();
      expect(sessions, isEmpty);
    });

    test('returns all saved sessions sorted newest first', () async {
      await repo.save(makeSession(
        id: 'session-1',
        startTime: DateTime(2025, 1, 1),
        endTime: DateTime(2025, 1, 1, 1),
      ));
      await repo.save(makeSession(
        id: 'session-3',
        startTime: DateTime(2025, 3, 1),
        endTime: DateTime(2025, 3, 1, 1),
      ));
      await repo.save(makeSession(
        id: 'session-2',
        startTime: DateTime(2025, 2, 1),
        endTime: DateTime(2025, 2, 1, 1),
      ));

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
