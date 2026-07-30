// =============================================================================
// ARU Deployment Integration Test
// =============================================================================
//
// Exercises the ARU deployment lifecycle against real on-device storage:
//   * a full multi-cycle schedule driven through waiting -> recording ->
//     completed, with every transition persisted to and re-read from disk
//     via the real SessionRepository,
//   * recovery-from-disk restore resuming an in-progress deployment, and
//   * detection-clip retention/eviction writing and deleting real files.
//
// These paths are device-backed (real filesystem, JSON round-trip, flush
// semantics) but do not require microphone permission, so they run reliably
// in the integration harness. The microphone/recording and notification
// paths remain covered by the unit suite via injected hooks.
//
// Run on a connected device:
//   flutter test integration_test/aru_deployment_test.dart -d <device_id>
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:birdnet_live/features/aru/aru_controller.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Fixed schedule anchor. Cycles are 10 min long, repeating hourly.
  final scheduleStart = DateTime.utc(2026, 6, 1, 4);

  const settings = SessionSettings(
    windowDuration: 3,
    confidenceThreshold: 35,
    inferenceRate: 1.0,
    speciesFilterMode: 'off',
  );

  late Directory sandbox;
  late SessionRepository repository;

  setUp(() async {
    // Isolate from the user's real session library while still using the
    // actual device documents filesystem.
    final docs = await getApplicationDocumentsDirectory();
    sandbox = await Directory(
      '${docs.path}/aru_integration_${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    // The repository only auto-creates its sessions dir when it resolves the
    // base path itself; an explicit basePath override skips that, so create it.
    final sessionsDir = await Directory(
      '${sandbox.path}/sessions',
    ).create(recursive: true);
    repository = SessionRepository()..basePath = sessionsDir.path;
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  AruDeploymentMetadata combinedMetadata({
    int maxCycles = 2,
    String recordingMode = 'detectionsOnly',
    String samplingMode = 'smart',
    int topNPerSpecies = 10,
  }) {
    return AruDeploymentMetadata(
      deploymentName: 'Integration Plot',
      stationId: 'ARU-IT',
      scheduleStart: scheduleStart,
      eachCycleIsSession: false,
      cycleDurationSeconds: 600,
      repeatIntervalSeconds: 3600,
      maxCycles: maxCycles,
      recordingMode: recordingMode,
      samplingMode: samplingMode,
      topNPerSpecies: topNPerSpecies,
    );
  }

  testWidgets(
    'drives a full multi-cycle deployment and persists each transition to disk',
    (tester) async {
      final controller = AruController(
        saveSession: repository.save,
        now: () => scheduleStart.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-it-1',
        settings: settings,
        metadata: combinedMetadata(maxCycles: 2),
      );

      // Before the first cycle the deployment is waiting and already on disk.
      expect(controller.state, AruControllerState.waiting);
      var persisted = await repository.load('aru-it-1');
      expect(persisted, isNotNull);
      expect(persisted!.type, SessionType.aru);
      expect(persisted.endTime, isNull);

      // Inside cycle 0 -> recording, one cycle row tracked on disk.
      await controller.evaluate(
        now: scheduleStart.add(const Duration(minutes: 5)),
      );
      expect(controller.state, AruControllerState.recording);
      persisted = await repository.load('aru-it-1');
      expect(persisted!.aruMetadata!.cycles.map((c) => c.index), contains(0));

      // Between cycles -> waiting, cycle 0 finalized as completed on disk.
      await controller.evaluate(
        now: scheduleStart.add(const Duration(minutes: 30)),
      );
      expect(controller.state, AruControllerState.waiting);
      persisted = await repository.load('aru-it-1');
      final cycle0 = persisted!.aruMetadata!.cycles.firstWhere(
        (c) => c.index == 0,
      );
      expect(cycle0.status, AruCycleStatus.completed);
      expect(cycle0.actualEnd, isNotNull);

      // Inside cycle 1 -> recording again.
      await controller.evaluate(
        now: scheduleStart.add(const Duration(minutes: 65)),
      );
      expect(controller.state, AruControllerState.recording);

      // Past the planned end -> completed and finalized on disk.
      await controller.evaluate(
        now: scheduleStart.add(const Duration(hours: 2)),
      );
      expect(controller.state, AruControllerState.completed);
      persisted = await repository.load('aru-it-1');
      expect(persisted!.endTime, isNotNull);
      expect(
        persisted.aruMetadata!.cycles.where(
          (c) => c.status == AruCycleStatus.completed,
        ),
        hasLength(2),
      );
    },
  );

  testWidgets(
    'restores an in-progress deployment from disk into the recording state',
    (tester) async {
      // First controller starts and enters cycle 0, persisting to disk.
      final first = AruController(
        saveSession: repository.save,
        now: () => scheduleStart.subtract(const Duration(minutes: 5)),
      );
      await first.startDeployment(
        sessionId: 'aru-it-restore',
        settings: settings,
        metadata: combinedMetadata(maxCycles: 2),
      );
      await first.evaluate(
        now: scheduleStart.add(const Duration(minutes: 5)),
      );
      expect(first.state, AruControllerState.recording);

      // Simulate a process restart: reload the persisted session from disk.
      final reloaded = await repository.load('aru-it-restore');
      expect(reloaded, isNotNull);
      expect(reloaded!.endTime, isNull);

      // A fresh controller restores it and resumes inside the live cycle.
      final restored = AruController(saveSession: repository.save);
      await restored.restoreDeployment(
        reloaded,
        now: scheduleStart.add(const Duration(minutes: 6)),
      );
      expect(restored.state, AruControllerState.recording);
      expect(restored.session!.id, 'aru-it-restore');
      expect(
        restored.session!.aruMetadata!.cycles.map((c) => c.index),
        contains(0),
      );

      // Driving the restored controller to completion still persists cleanly.
      await restored.evaluate(
        now: scheduleStart.add(const Duration(hours: 2)),
      );
      expect(restored.state, AruControllerState.completed);
      final finalState = await repository.load('aru-it-restore');
      expect(finalState!.endTime, isNotNull);
    },
  );

  testWidgets(
    'retains and evicts detection clips on disk across a cycle',
    (tester) async {
      final clipsDir = await Directory(
        '${sandbox.path}/clips',
      ).create(recursive: true);

      // Real clip saver: writes a small file per record in the round and
      // returns their paths, mirroring the detections-only retention path.
      Future<Map<DetectionRecord, String>> saveClips(
        LiveSession session,
        List<DetectionRecord> records,
      ) async {
        final written = <DetectionRecord, String>{};
        for (final record in records) {
          final safeTs = record.timestamp.toIso8601String().replaceAll(
                ':',
                '-',
              );
          final path =
              '${clipsDir.path}/clip_${record.scientificName}_$safeTs.wav';
          await File(path).writeAsBytes(
            List<int>.filled(64, 0),
            flush: true,
          );
          written[record] = path;
        }
        return written;
      }

      final controller = AruController(
        saveSession: repository.save,
        saveDetectionClips: saveClips,
        now: () => scheduleStart.subtract(const Duration(minutes: 5)),
      );

      // topN = 1: only the strongest clip per species+cycle is retained.
      await controller.startDeployment(
        sessionId: 'aru-it-clips',
        settings: settings,
        metadata: combinedMetadata(
          maxCycles: 1,
          samplingMode: 'topN',
          topNPerSpecies: 1,
        ),
      );
      await controller.evaluate(
        now: scheduleStart.add(const Duration(minutes: 5)),
      );
      expect(controller.state, AruControllerState.recording);

      final weakTs = scheduleStart.add(const Duration(minutes: 6));
      final strongTs = scheduleStart.add(const Duration(minutes: 7));

      // Weaker detection appears, then closes -> clip written and retained.
      await controller.syncDetections([
        DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.60,
          timestamp: weakTs,
        ),
      ]);
      await controller.syncDetections([
        DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.60,
          timestamp: weakTs,
          endTimestamp: weakTs.add(const Duration(seconds: 3)),
        ),
      ]);

      final weakClips =
          clipsDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.contains('06-00'))
              .toList();
      expect(weakClips, hasLength(1), reason: 'weak clip should be written');

      // Stronger detection of the same species in the same cycle closes ->
      // it is retained and the weaker clip is evicted from disk.
      await controller.syncDetections([
        DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.90,
          timestamp: strongTs,
        ),
      ]);
      await controller.syncDetections([
        DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.90,
          timestamp: strongTs,
          endTimestamp: strongTs.add(const Duration(seconds: 3)),
        ),
      ]);

      final remaining = clipsDir.listSync().whereType<File>().toList();
      debugPrint(
        '[AruClipsTest] remaining clips: '
        '${remaining.map((f) => f.uri.pathSegments.last).toList()}',
      );
      expect(
        remaining,
        hasLength(1),
        reason: 'only the strongest clip should remain on disk',
      );
      expect(remaining.single.path, contains('07-00'));

      // Both detections are still recorded; only the weaker clip path is gone.
      final blackbirds = controller.session!.detections
          .where((d) => d.scientificName == 'Turdus merula')
          .toList();
      expect(blackbirds, hasLength(2));
      final weak = blackbirds.firstWhere((d) => d.timestamp == weakTs);
      final strong = blackbirds.firstWhere((d) => d.timestamp == strongTs);
      expect(weak.audioClipPath, isNull);
      expect(strong.audioClipPath, isNotNull);
      expect(File(strong.audioClipPath!).existsSync(), isTrue);
    },
  );

  testWidgets(
    'leaves no aggregate session on disk for a full per-cycle deployment',
    (tester) async {
      final controller = AruController(
        saveSession: repository.save,
        discardSession: repository.deleteMetadataOnly,
        now: () => scheduleStart.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-it-percycle',
        settings: settings,
        metadata: AruDeploymentMetadata(
          deploymentName: 'Per-cycle Plot',
          stationId: 'ARU-IT',
          scheduleStart: scheduleStart,
          eachCycleIsSession: true,
          cycleDurationSeconds: 600,
          repeatIntervalSeconds: 3600,
          maxCycles: 2,
          recordingMode: 'full',
        ),
      );

      // While in progress the aggregate is persisted so it can be restored
      // after a process kill.
      var aggregate = await repository.load('aru-it-percycle');
      expect(aggregate, isNotNull);
      expect(aggregate!.endTime, isNull);

      // Run both cycles to completion.
      await controller.evaluate(
        now: scheduleStart.add(const Duration(minutes: 5)),
      );
      await controller.evaluate(
        now: scheduleStart.add(const Duration(minutes: 30)),
      );
      await controller.evaluate(
        now: scheduleStart.add(const Duration(hours: 1, minutes: 5)),
      );
      await controller.evaluate(
        now: scheduleStart.add(const Duration(hours: 2)),
      );
      expect(controller.state, AruControllerState.completed);

      // The aggregate JSON is gone; only the per-cycle sessions remain on disk.
      aggregate = await repository.load('aru-it-percycle');
      expect(aggregate, isNull);
      final cycle0 = await repository.load('aru-it-percycle_cycle_0');
      final cycle1 = await repository.load('aru-it-percycle_cycle_1');
      expect(cycle0, isNotNull);
      expect(cycle1, isNotNull);
      expect(cycle0!.endTime, isNotNull);
      expect(cycle1!.endTime, isNotNull);
    },
  );
}
