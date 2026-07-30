import 'package:birdnet_live/features/aru/aru_controller.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/recording/recording_service.dart';
import 'package:birdnet_live/features/survey/detection_sampler.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapts a per-record clip stub to the batched saver the controller expects.
///
/// [cut] returns the path written for a record, or null when nothing was
/// written. [rounds] records the batch handed to each call, so tests can assert
/// that a sync round cuts its clips together rather than one at a time.
AruDetectionClipSaver clipSaver(
  String? Function(DetectionRecord record) cut, {
  List<List<DetectionRecord>>? rounds,
}) {
  return (session, records) async {
    rounds?.add(List<DetectionRecord>.of(records));
    final written = <DetectionRecord, String>{};
    for (final record in records) {
      final path = cut(record);
      if (path != null) written[record] = path;
    }
    return written;
  };
}

void main() {
  final start = DateTime.utc(2026, 6, 1, 4);
  final settings = SessionSettings(
    windowDuration: 3,
    confidenceThreshold: 35,
    inferenceRate: 1.0,
    speciesFilterMode: 'off',
  );

  AruDeploymentMetadata metadata({
    int maxCycles = 2,
    String recordingMode = 'full',
    String samplingMode = 'smart',
    int topNPerSpecies = 10,
  }) {
    return AruDeploymentMetadata(
      deploymentName: 'Dawn Station',
      stationId: 'ARU-07',
      scheduleStart: start,
      eachCycleIsSession: false,
      cycleDurationSeconds: 600,
      repeatIntervalSeconds: 3600,
      maxCycles: maxCycles,
      recordingMode: recordingMode,
      samplingMode: samplingMode,
      topNPerSpecies: topNPerSpecies,
      cycles: [],
    );
  }

  group('AruController', () {
    test('starts a deployment and persists initial waiting state', () async {
      final saved = <LiveSession>[];
      final controller = AruController(
        saveSession: (session) async => saved.add(session),
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
        observerName: 'Jane',
        latitude: 52.52,
        longitude: 13.405,
      );

      expect(controller.state, AruControllerState.waiting);
      expect(controller.session?.type, SessionType.aru);
      expect(controller.session?.observerName, 'Jane');
      expect(controller.session?.latitude, 52.52);
      expect(controller.session?.customName, 'Dawn Station - ARU-07');
      expect(controller.session?.aruMetadata?.stationId, 'ARU-07');
      expect(saved.length, 2);
    });

    test(
      'uses station ID as session name when deployment name is empty',
      () async {
        final controller = AruController(
          saveSession: (session) async {},
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: AruDeploymentMetadata(
            stationId: 'ARU-09',
            scheduleStart: start,
            eachCycleIsSession: false,
            cycleDurationSeconds: 600,
            repeatIntervalSeconds: 3600,
            maxCycles: 1,
          ),
        );

        expect(controller.session?.customName, 'ARU-09');
      },
    );

    test('enters recording state inside a scheduled cycle', () async {
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));

      final session = controller.session!;
      final cycle = session.aruMetadata!.cycles.single;

      expect(controller.state, AruControllerState.recording);
      expect(session.segments.length, 1);
      expect(session.segments.single.startTime, start);
      expect(cycle.index, 0);
      expect(cycle.status, AruCycleStatus.recording);
      expect(cycle.actualStart, start);
    });

    test('does not persist unchanged waiting evaluations', () async {
      final saved = <LiveSession>[];
      final controller = AruController(
        saveSession: (session) async => saved.add(session),
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
      );

      final changed = await controller.evaluate(
        now: start.subtract(const Duration(minutes: 4)),
      );

      expect(changed, isFalse);
      expect(controller.state, AruControllerState.waiting);
      expect(saved.length, 2);
    });

    test('does not persist unchanged recording evaluations', () async {
      final saved = <LiveSession>[];
      final controller = AruController(
        saveSession: (session) async => saved.add(session),
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));
      final savedAfterEnteringCycle = saved.length;

      final changed = await controller.evaluate(
        now: start.add(const Duration(minutes: 6)),
      );

      expect(changed, isFalse);
      expect(controller.state, AruControllerState.recording);
      expect(controller.session?.aruMetadata?.cycles.length, 1);
      expect(saved.length, savedAfterEnteringCycle);
    });

    test('restores an unfinished deployment and resumes scheduling', () async {
      final saved = <LiveSession>[];
      final session = LiveSession(
        id: 'aru-restore',
        type: SessionType.aru,
        startTime: start,
        settings: settings,
        aruMetadata: metadata(maxCycles: 2),
      );
      final controller = AruController(
        saveSession: (session) async => saved.add(session),
        now: () => start.add(const Duration(minutes: 5)),
      );

      await controller.restoreDeployment(session);

      expect(controller.state, AruControllerState.recording);
      expect(controller.session?.id, 'aru-restore');
      expect(controller.session?.aruMetadata?.cycles.single.index, 0);
      expect(
        controller.session?.aruMetadata?.cycles.single.status,
        AruCycleStatus.recording,
      );
      expect(saved, isNotEmpty);
    });

    test('marks stale recording cycles partial during restore', () async {
      final session = LiveSession(
        id: 'aru-restore',
        type: SessionType.aru,
        startTime: start,
        settings: settings,
        aruMetadata: metadata(maxCycles: 2)
          ..cycles.add(
            AruCycleMetadata(
              index: 0,
              plannedStart: start,
              plannedEnd: start.add(const Duration(minutes: 10)),
              actualStart: start,
              status: AruCycleStatus.recording,
              recordingPath: '/recordings/aru/cycle_0.flac',
            ),
          ),
      );
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.add(const Duration(minutes: 30)),
      );

      await controller.restoreDeployment(session);

      final cycle = controller.session!.aruMetadata!.cycles.single;
      expect(controller.state, AruControllerState.waiting);
      expect(cycle.status, AruCycleStatus.partial);
      expect(cycle.actualEnd, start.add(const Duration(minutes: 10)));
      expect(cycle.recordingPath, '/recordings/aru/cycle_0.flac');
    });

    test('finalizes a late cycle at planned end, not wakeup time', () async {
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));
      await controller.evaluate(now: start.add(const Duration(minutes: 30)));

      final session = controller.session!;
      final cycle = session.aruMetadata!.cycles.single;

      expect(controller.state, AruControllerState.waiting);
      expect(cycle.status, AruCycleStatus.completed);
      expect(cycle.actualEnd, start.add(const Duration(minutes: 10)));
      expect(
        session.segments.single.endTime,
        start.add(const Duration(minutes: 10)),
      );
      expect(session.recordedDurationSeconds, 600);
    });

    test('starts the next cycle and keeps cycle metadata sorted', () async {
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));
      await controller.evaluate(
        now: start.add(const Duration(hours: 1, minutes: 1)),
      );

      final cycles = controller.session!.aruMetadata!.cycles;

      expect(controller.state, AruControllerState.recording);
      expect(cycles.map((c) => c.index), <int>[0, 1]);
      expect(cycles.first.status, AruCycleStatus.completed);
      expect(cycles.last.status, AruCycleStatus.recording);
      expect(controller.session!.segments.length, 2);
    });

    test('runs optional sanity check cycle immediately', () async {
      final deployedAt = DateTime.utc(2026, 6, 1, 4, 17);
      final controller = AruController(
        saveSession: (session) async {},
        now: () => deployedAt,
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: AruDeploymentMetadata(
          scheduleStart: deployedAt,
          eachCycleIsSession: false,
          cycleDurationSeconds: 600,
          repeatIntervalSeconds: 3600,
          maxCycles: 1,
          testCycleEnabled: true,
        ),
      );

      expect(controller.state, AruControllerState.recording);
      expect(controller.session!.segments.single.startTime, deployedAt);
      expect(
        controller.session!.aruMetadata!.cycles.single.plannedEnd,
        deployedAt.add(const Duration(minutes: 1)),
      );
    });

    test('completes after the final configured cycle', () async {
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(maxCycles: 1),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));
      await controller.evaluate(now: start.add(const Duration(hours: 1)));

      expect(controller.state, AruControllerState.completed);
      expect(controller.session!.endTime, start.add(const Duration(hours: 1)));
      expect(
        controller.session!.aruMetadata!.cycles.single.status,
        AruCycleStatus.completed,
      );
    });

    test('manual stop closes active cycle as stopped', () async {
      final controller = AruController(
        saveSession: (session) async {},
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));
      final stopped = await controller.stop(
        now: start.add(const Duration(minutes: 7)),
      );

      expect(controller.state, AruControllerState.completed);
      expect(stopped.stopReason, SessionStopReason.manual);
      expect(stopped.endTime, start.add(const Duration(minutes: 7)));
      expect(stopped.recordedDurationSeconds, 7 * 60);
      expect(stopped.aruMetadata!.cycles.single.status, AruCycleStatus.stopped);
      expect(
        stopped.aruMetadata!.cycles.single.actualEnd,
        start.add(const Duration(minutes: 7)),
      );
    });

    test(
      'starts and stops cycle recording hooks at schedule boundaries',
      () async {
        final events = <String>[];
        final controller = AruController(
          saveSession: (session) async {},
          startCycleRecording: (session, window) async {
            events.add('start:${window.index}');
            return '/recordings/aru/cycle_${window.index}.flac';
          },
          stopCycleRecording: (session, cycle, endedAt) async {
            events.add('stop:${cycle.index}:${endedAt.toIso8601String()}');
            return '${cycle.recordingPath}.closed';
          },
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(),
        );
        await controller.evaluate(now: start.add(const Duration(minutes: 5)));
        await controller.evaluate(now: start.add(const Duration(minutes: 30)));

        final cycle = controller.session!.aruMetadata!.cycles.single;
        expect(events, [
          'start:0',
          'stop:0:${start.add(const Duration(minutes: 10)).toIso8601String()}',
        ]);
        expect(cycle.recordingPath, '/recordings/aru/cycle_0.flac.closed');
        // Combined deployments stay clips-only: per-cycle audio lives on the
        // cycle metadata, and the aggregate session must not claim a single
        // recordingPath that would point at only the last cycle.
        expect(controller.session!.recordingPath, isNull);
        expect(cycle.status, AruCycleStatus.completed);
      },
    );

    test('does not start cycle recording hook when recording is off', () async {
      var starts = 0;
      final controller = AruController(
        saveSession: (session) async {},
        startCycleRecording: (session, window) async {
          starts++;
          return '/recordings/aru/cycle_${window.index}.flac';
        },
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(recordingMode: RecordingMode.off.name),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));

      expect(starts, 0);
      expect(
        controller.session!.aruMetadata!.cycles.single.recordingPath,
        isNull,
      );
    });

    test(
      'syncDetections saves detection clips and updates cycle counts',
      () async {
        final savedClips = <String>[];
        final controller = AruController(
          saveSession: (session) async {},
          saveDetectionClips: clipSaver((record) {
            final path = '/recordings/${record.scientificName}.flac';
            savedClips.add(path);
            return path;
          }),
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(recordingMode: RecordingMode.detectionsOnly.name),
        );
        await controller.evaluate(now: start.add(const Duration(minutes: 1)));

        final detectedAt = start.add(const Duration(minutes: 2));
        final open = DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.6,
          timestamp: detectedAt,
        );
        final closed = DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.8,
          timestamp: detectedAt,
          endTimestamp: detectedAt.add(const Duration(seconds: 20)),
        );

        await controller.syncDetections([open]);
        await controller.syncDetections([closed]);

        final session = controller.session!;
        final cycle = session.aruMetadata!.cycles.single;
        expect(savedClips, ['/recordings/Turdus merula.flac']);
        expect(session.detections, hasLength(1));
        expect(session.detections.single.confidence, 0.8);
        expect(session.detections.single.endTimestamp, closed.endTimestamp);
        expect(session.detections.single.audioClipPath, savedClips.single);
        expect(cycle.detectionCount, 1);
        expect(cycle.retainedClipCount, 1);
        expect(cycle.droppedClipCount, 0);
      },
    );

    test('syncDetections cuts a round\'s clips in a single batch', () async {
      // Every clip in a round has to come from one post-roll wait and one
      // slice of audio, the way the Live and Survey inference loops cut
      // theirs. Cutting them one at a time made each clip after the first
      // read the ring buffer later than the window that earned the score, so
      // the same bird landed on a different window depending on how many
      // other species happened to peak alongside it.
      final rounds = <List<DetectionRecord>>[];
      final controller = AruController(
        saveSession: (session) async {},
        saveDetectionClips: clipSaver(
          (record) => '/recordings/${record.scientificName}.flac',
          rounds: rounds,
        ),
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(recordingMode: RecordingMode.detectionsOnly.name),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 1)));

      final detectedAt = start.add(const Duration(minutes: 2));
      DetectionRecord at(String species, double confidence) => DetectionRecord(
        scientificName: species,
        commonName: species,
        confidence: confidence,
        timestamp: detectedAt,
      );

      // Three species arriving together: one batch, not three.
      await controller.syncDetections([
        at('Turdus merula', 0.55),
        at('Parus major', 0.60),
        at('Erithacus rubecula', 0.70),
      ]);

      expect(rounds, hasLength(1));
      expect(rounds.single.map((r) => r.scientificName), [
        'Turdus merula',
        'Parus major',
        'Erithacus rubecula',
      ]);

      // A round mixing a re-cut with a first cut is still one batch, and a
      // species that has not moved enough is left out of it.
      await controller.syncDetections([
        at('Turdus merula', 0.62), // +0.07 over its clip → re-cut
        at('Parus major', 0.61), // +0.01 → not yet
        at('Erithacus rubecula', 0.70), // unchanged → no
        at('Sylvia atricapilla', 0.40), // new → first cut
      ]);

      expect(rounds, hasLength(2));
      expect(rounds.last.map((r) => r.scientificName), [
        'Turdus merula',
        'Sylvia atricapilla',
      ]);
    });

    test('syncDetections cuts no clips when nothing needs one', () async {
      // An unchanged round must not reach the saver at all — no post-roll
      // wait, no ring-buffer read.
      final rounds = <List<DetectionRecord>>[];
      final controller = AruController(
        saveSession: (session) async {},
        saveDetectionClips: clipSaver(
          (record) => '/recordings/${record.scientificName}.flac',
          rounds: rounds,
        ),
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(recordingMode: RecordingMode.detectionsOnly.name),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 1)));

      final detectedAt = start.add(const Duration(minutes: 2));
      DetectionRecord at(double confidence) => DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: confidence,
        timestamp: detectedAt,
      );

      await controller.syncDetections([at(0.55)]);
      await controller.syncDetections([at(0.56)]);
      await controller.syncDetections([at(0.56)]);

      expect(rounds, hasLength(1));
    });

    test(
      'syncDetections cuts no clips when the mode is not clip-only',
      () async {
        final rounds = <List<DetectionRecord>>[];
        final controller = AruController(
          saveSession: (session) async {},
          saveDetectionClips: clipSaver(
            (record) => '/recordings/${record.scientificName}.flac',
            rounds: rounds,
          ),
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(recordingMode: RecordingMode.full.name),
        );
        await controller.evaluate(now: start.add(const Duration(minutes: 1)));

        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.9,
            timestamp: start.add(const Duration(minutes: 2)),
          ),
        ]);

        expect(rounds, isEmpty);
        expect(controller.session!.detections.single.audioClipPath, isNull);
      },
    );

    test('syncDetections keeps a clip a record already arrived with', () async {
      // Nothing to cut: the record was handed to us with audio attached, and
      // it becomes the baseline later peaks are measured against.
      final rounds = <List<DetectionRecord>>[];
      final controller = AruController(
        saveSession: (session) async {},
        saveDetectionClips: clipSaver(
          (record) => '/recordings/recut.flac',
          rounds: rounds,
        ),
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(recordingMode: RecordingMode.detectionsOnly.name),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 1)));

      final detectedAt = start.add(const Duration(minutes: 2));
      DetectionRecord at(double confidence, {String? clip}) => DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: confidence,
        timestamp: detectedAt,
        audioClipPath: clip,
      );

      await controller.syncDetections([at(0.55, clip: '/recordings/pre.flac')]);
      expect(rounds, isEmpty);
      expect(
        controller.session!.detections.single.audioClipPath,
        '/recordings/pre.flac',
      );

      // A gain measured from 0.55 — the score of the clip it arrived with.
      await controller.syncDetections([at(0.57)]);
      expect(rounds, isEmpty);
      await controller.syncDetections([at(0.61)]);
      expect(rounds, hasLength(1));
      expect(
        controller.session!.detections.single.audioClipPath,
        '/recordings/recut.flac',
      );
    });

    test('syncDetections dates each clip from the audio it holds', () async {
      // The detection keeps its own start and end — that is when the bird
      // was heard. The clip window moves with the audio, so the two drift
      // apart as the detection climbs to its peak. Conflating them is what
      // made session review advertise a whole detection's worth of audio
      // next to a file holding one analysis window.
      var clock = start.add(const Duration(minutes: 2));
      final controller = AruController(
        saveSession: (session) async {},
        saveDetectionClips: clipSaver(
          (record) => '/recordings/clip_${clock.minute}.flac',
        ),
        now: () => clock,
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(recordingMode: RecordingMode.detectionsOnly.name),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 1)));

      final detectedAt = start.add(const Duration(minutes: 2));
      DetectionRecord at(double confidence) => DetectionRecord(
        scientificName: 'Turdus merula',
        commonName: 'Eurasian Blackbird',
        confidence: confidence,
        timestamp: detectedAt,
      );

      // First cut: the clip holds the window ending now.
      await controller.syncDetections([at(0.55)]);
      final firstWindow = clock.subtract(
        Duration(seconds: settings.windowDuration),
      );
      expect(controller.session!.detections.single.clipTimestamp, firstWindow);

      // Three minutes later the detection peaks and the clip is re-cut. The
      // detection still starts where it always did; the clip does not.
      clock = start.add(const Duration(minutes: 5));
      await controller.syncDetections([at(0.61)]);

      final synced = controller.session!.detections.single;
      expect(synced.timestamp, detectedAt);
      expect(
        synced.clipTimestamp,
        clock.subtract(Duration(seconds: settings.windowDuration)),
      );
      expect(synced.clipTimestamp!.isAfter(synced.timestamp), isTrue);
    });

    test('clip timing is captured before the post-roll wait', () async {
      var clock = start.add(const Duration(minutes: 2));
      final cutAt = clock;
      final controller = AruController(
        saveSession: (session) async {},
        saveDetectionClips: (session, records) async {
          // Stand in for RecordingService waiting for clip context.
          clock = clock.add(const Duration(seconds: 2));
          return {records.single: '/recordings/clip.flac'};
        },
        now: () => clock,
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: metadata(recordingMode: RecordingMode.detectionsOnly.name),
      );
      await controller.evaluate(now: start.add(const Duration(minutes: 1)));
      await controller.syncDetections([
        DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: 0.55,
          timestamp: cutAt,
        ),
      ]);

      expect(
        controller.session!.detections.single.clipTimestamp,
        cutAt.subtract(Duration(seconds: settings.windowDuration)),
      );
    });

    test(
      'syncDetections leaves the clip window alone without a re-cut',
      () async {
        // A gain too small to re-cut must not move the window: the file on
        // disk is still the old one.
        var clock = start.add(const Duration(minutes: 2));
        final controller = AruController(
          saveSession: (session) async {},
          saveDetectionClips: clipSaver((record) => '/recordings/clip.flac'),
          now: () => clock,
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(recordingMode: RecordingMode.detectionsOnly.name),
        );
        await controller.evaluate(now: start.add(const Duration(minutes: 1)));

        DetectionRecord at(double confidence) => DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: confidence,
          timestamp: start.add(const Duration(minutes: 2)),
        );

        await controller.syncDetections([at(0.55)]);
        final firstWindow = controller.session!.detections.single.clipTimestamp;
        expect(firstWindow, isNotNull);

        clock = start.add(const Duration(minutes: 5));
        await controller.syncDetections([at(0.57)]);

        expect(
          controller.session!.detections.single.clipTimestamp,
          firstWindow,
        );
      },
    );

    test(
      'syncDetections re-cuts an open detection clip at its confidence peak',
      () async {
        // A merged detection spans many analysis windows but its clip holds
        // one, so the clip must follow the peak rather than stay on the first
        // (usually weakest) window the species appeared in.
        final savedClips = <String>[];
        final controller = AruController(
          saveSession: (session) async {},
          saveDetectionClips: clipSaver((record) {
            final path = '/recordings/clip_${savedClips.length}.flac';
            savedClips.add(path);
            return path;
          }),
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(recordingMode: RecordingMode.detectionsOnly.name),
        );
        await controller.evaluate(now: start.add(const Duration(minutes: 1)));

        final detectedAt = start.add(const Duration(minutes: 2));
        DetectionRecord at(double confidence) => DetectionRecord(
          scientificName: 'Turdus merula',
          commonName: 'Eurasian Blackbird',
          confidence: confidence,
          timestamp: detectedAt,
        );

        await controller.syncDetections([at(0.55)]);
        // Each individual gain is below the improvement margin, so the clip
        // must not churn before their cumulative gain reaches the threshold.
        await controller.syncDetections([at(0.57)]);
        await controller.syncDetections([at(0.59)]);
        expect(savedClips, ['/recordings/clip_0.flac']);
        expect(
          controller.session!.detections.single.audioClipPath,
          '/recordings/clip_0.flac',
        );

        // 0.61 is only two points above the latest record, but six points
        // above the 0.55 window represented by the saved clip: re-cut here.
        await controller.syncDetections([at(0.61)]);

        expect(savedClips, [
          '/recordings/clip_0.flac',
          '/recordings/clip_1.flac',
        ]);
        final synced = controller.session!.detections.single;
        expect(synced.audioClipPath, '/recordings/clip_1.flac');
        expect(synced.confidence, 0.61);
      },
    );

    test(
      'syncDetections does not re-cut a clip once the detection has closed',
      () async {
        // After the species stops vocalizing the ring buffer holds later,
        // unrelated audio — the same reason the first clip is cut on arrival.
        final savedClips = <String>[];
        final controller = AruController(
          saveSession: (session) async {},
          saveDetectionClips: clipSaver((record) {
            final path = '/recordings/clip_${savedClips.length}.flac';
            savedClips.add(path);
            return path;
          }),
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(recordingMode: RecordingMode.detectionsOnly.name),
        );
        await controller.evaluate(now: start.add(const Duration(minutes: 1)));

        final detectedAt = start.add(const Duration(minutes: 2));
        final endedAt = detectedAt.add(const Duration(seconds: 20));
        DetectionRecord at(double confidence, {DateTime? end}) =>
            DetectionRecord(
              scientificName: 'Turdus merula',
              commonName: 'Eurasian Blackbird',
              confidence: confidence,
              timestamp: detectedAt,
              endTimestamp: end,
            );

        await controller.syncDetections([at(0.5)]);
        // Closing sync carries the final peak; still no re-cut.
        await controller.syncDetections([at(0.95, end: endedAt)]);
        // A late re-sync of the already-closed record must not re-cut either.
        await controller.syncDetections([at(0.99, end: endedAt)]);

        expect(savedClips, ['/recordings/clip_0.flac']);
        expect(
          controller.session!.detections.single.audioClipPath,
          '/recordings/clip_0.flac',
        );
      },
    );

    test(
      'syncDetections keeps saved clip paths attached to their timestamps',
      () async {
        final controller = AruController(
          saveSession: (session) async {},
          saveDetectionClips: clipSaver((record) {
            final timestamp = record.timestamp.toUtc().millisecondsSinceEpoch;
            return '/recordings/clip_$timestamp.flac';
          }),
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(
            maxCycles: 3,
            recordingMode: RecordingMode.detectionsOnly.name,
            samplingMode: SamplingMode.smart.name,
            topNPerSpecies: 1,
          ),
        );

        await controller.evaluate(now: start.add(const Duration(minutes: 1)));
        final firstAt = start.add(const Duration(minutes: 2));
        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.8,
            timestamp: firstAt,
          ),
        ]);
        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.9,
            timestamp: firstAt,
            endTimestamp: firstAt.add(const Duration(seconds: 20)),
          ),
        ]);

        await controller.evaluate(now: start.add(const Duration(minutes: 30)));
        await controller.evaluate(
          now: start.add(const Duration(hours: 1, minutes: 1)),
        );
        final secondAt = start.add(const Duration(hours: 1, minutes: 2));
        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.95,
            timestamp: secondAt,
            endTimestamp: secondAt.add(const Duration(seconds: 20)),
          ),
        ]);

        final detections = controller.session!.detections;
        expect(detections, hasLength(2));
        for (final detection in detections) {
          final expectedTimestamp =
              detection.timestamp.toUtc().millisecondsSinceEpoch;
          if (detection.audioClipPath == null) continue;
          expect(detection.audioClipPath, contains('$expectedTimestamp'));
        }
        expect(
          detections.where((detection) => detection.audioClipPath != null),
          hasLength(1),
        );
        expect(detections.first.audioClipPath, isNull);
        expect(
          detections.last.audioClipPath,
          contains('${secondAt.toUtc().millisecondsSinceEpoch}'),
        );
      },
    );

    test(
      'smart clip sampling spreads each species across ARU cycles in one session',
      () async {
        final controller = AruController(
          saveSession: (session) async {},
          saveDetectionClips: clipSaver((record) {
            final timestamp = record.timestamp.toUtc().millisecondsSinceEpoch;
            final species = record.scientificName.replaceAll(' ', '_');
            return '/recordings/clip_${timestamp}_$species.flac';
          }),
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(
            maxCycles: 3,
            recordingMode: RecordingMode.detectionsOnly.name,
            samplingMode: SamplingMode.smart.name,
            topNPerSpecies: 2,
          ),
        );

        await controller.evaluate(now: start.add(const Duration(minutes: 1)));
        final cycle0Low = start.add(const Duration(minutes: 2));
        final cycle0Mid = start.add(const Duration(minutes: 3));
        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.4,
            timestamp: cycle0Low,
            endTimestamp: cycle0Low.add(const Duration(seconds: 20)),
          ),
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.5,
            timestamp: cycle0Mid,
            endTimestamp: cycle0Mid.add(const Duration(seconds: 20)),
          ),
        ]);

        await controller.evaluate(now: start.add(const Duration(minutes: 30)));
        await controller.evaluate(
          now: start.add(const Duration(hours: 1, minutes: 1)),
        );
        final cycle1 = start.add(const Duration(hours: 1, minutes: 2));
        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.6,
            timestamp: cycle1,
            endTimestamp: cycle1.add(const Duration(seconds: 20)),
          ),
          DetectionRecord(
            scientificName: 'Erithacus rubecula',
            commonName: 'European Robin',
            confidence: 0.3,
            timestamp: cycle1.add(const Duration(minutes: 1)),
            endTimestamp: cycle1.add(const Duration(minutes: 1, seconds: 20)),
          ),
        ]);

        final detections = controller.session!.detections;
        final retainedBlackbirds =
            detections
                .where(
                  (detection) =>
                      detection.scientificName == 'Turdus merula' &&
                      detection.audioClipPath != null,
                )
                .toList();
        final retainedRobin =
            detections
                .where(
                  (detection) =>
                      detection.scientificName == 'Erithacus rubecula' &&
                      detection.audioClipPath != null,
                )
                .toList();

        expect(retainedBlackbirds, hasLength(2));
        expect(
          retainedBlackbirds.map((detection) => detection.timestamp),
          containsAll([cycle0Mid, cycle1]),
        );
        expect(
          detections
              .singleWhere((detection) => detection.timestamp == cycle0Low)
              .audioClipPath,
          isNull,
        );
        expect(retainedRobin, hasLength(1));
      },
    );

    test('saves a separate session per cycle and keeps no aggregate when '
        'eachCycleIsSession is true', () async {
      final store = <String, LiveSession>{};
      final controller = AruController(
        saveSession: (session) async => store[session.id] = session,
        discardSession: (sessionId) async => store.remove(sessionId),
        now: () => start.subtract(const Duration(minutes: 5)),
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: AruDeploymentMetadata(
          deploymentName: 'eBird plot',
          scheduleStart: start,
          cycleDurationSeconds: 600,
          repeatIntervalSeconds: 3600,
          maxCycles: 3,
          eachCycleIsSession: true,
        ),
        sessionNumber: 12,
      );

      // Enter and leave cycles 0, 1, and 2.
      await controller.evaluate(now: start.add(const Duration(minutes: 5)));
      await controller.evaluate(now: start.add(const Duration(minutes: 30)));
      await controller.evaluate(
        now: start.add(const Duration(hours: 1, minutes: 5)),
      );
      await controller.evaluate(
        now: start.add(const Duration(hours: 1, minutes: 30)),
      );
      await controller.evaluate(
        now: start.add(const Duration(hours: 2, minutes: 5)),
      );
      await controller.evaluate(
        now: start.add(const Duration(hours: 2, minutes: 30)),
      );

      // Only the per-cycle sessions remain; the aggregate (full-audio mode
      // included) is discarded so it never lingers in the library.
      final cycleSessions =
          store.values.where((s) => s.id.contains('_cycle_')).toList();
      final aggregateSessions =
          store.values.where((s) => !s.id.contains('_cycle_')).toList();
      expect(aggregateSessions, isEmpty);
      expect(cycleSessions, hasLength(3));
      expect(cycleSessions.first.id, 'aru-1_cycle_0');
      expect(cycleSessions.first.sessionNumber, 12);
      expect(cycleSessions.first.customName, 'eBird plot - Cycle 1');
      expect(cycleSessions.last.id, 'aru-1_cycle_2');
      expect(cycleSessions.last.sessionNumber, 12);
      expect(cycleSessions.last.customName, 'eBird plot - Cycle 3');
      expect(cycleSessions.first.startTime, start);
      expect(
        cycleSessions.first.endTime,
        start.add(const Duration(minutes: 10)),
      );
      expect(cycleSessions.first.aruMetadata, isNotNull);
      expect(cycleSessions.first.aruMetadata!.cycles.single.index, 0);
      expect(
        cycleSessions.first.aruMetadata!.cycles.single.status,
        AruCycleStatus.completed,
      );
      expect(cycleSessions.first.aruMetadata!.eachCycleIsSession, isTrue);
      expect(controller.reviewSession, cycleSessions.last);
    });

    test(
      'does not persist aggregate session for clip-only per-cycle deployment',
      () async {
        final store = <String, LiveSession>{};
        final discarded = <String>[];
        final controller = AruController(
          saveSession: (session) async => store[session.id] = session,
          discardSession: (sessionId) async {
            discarded.add(sessionId);
            store.remove(sessionId);
          },
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: AruDeploymentMetadata(
            deploymentName: 'eBird plot',
            scheduleStart: start,
            cycleDurationSeconds: 600,
            repeatIntervalSeconds: 3600,
            maxCycles: 1,
            recordingMode: RecordingMode.detectionsOnly.name,
            eachCycleIsSession: true,
          ),
          sessionNumber: 12,
        );

        await controller.evaluate(now: start.add(const Duration(minutes: 5)));
        await controller.syncDetections([
          DetectionRecord(
            scientificName: 'Turdus merula',
            commonName: 'Eurasian Blackbird',
            confidence: 0.8,
            timestamp: start.add(const Duration(minutes: 6)),
          ),
        ]);
        await controller.evaluate(now: start.add(const Duration(minutes: 30)));
        await controller.evaluate(now: start.add(const Duration(hours: 2)));

        final cycleSessions =
            store.values.where((s) => s.id.contains('_cycle_')).toList();
        final aggregateSessions =
            store.values.where((s) => !s.id.contains('_cycle_')).toList();
        expect(cycleSessions, hasLength(1));
        expect(cycleSessions.single.id, 'aru-1_cycle_0');
        expect(cycleSessions.single.detections, hasLength(1));
        expect(aggregateSessions, isEmpty);
        expect(discarded, ['aru-1']);
        expect(controller.reviewSession, cycleSessions.single);
      },
    );

    test(
      'has no review session when a clip-only per-cycle deployment is stopped '
      'before any cycle completes',
      () async {
        final saved = <LiveSession>[];
        final discarded = <String>[];
        final controller = AruController(
          saveSession: (session) async => saved.add(session),
          discardSession: (sessionId) async => discarded.add(sessionId),
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: AruDeploymentMetadata(
            deploymentName: 'eBird plot',
            scheduleStart: start,
            cycleDurationSeconds: 600,
            repeatIntervalSeconds: 3600,
            maxCycles: 1,
            recordingMode: RecordingMode.detectionsOnly.name,
            eachCycleIsSession: true,
          ),
          sessionNumber: 12,
        );

        // Stop while still in the initial waiting window (the first cycle has
        // not started, so no per-cycle session exists yet).
        await controller.stop(now: start.subtract(const Duration(minutes: 1)));

        final cycleSessions =
            saved.where((s) => s.id.contains('_cycle_')).toList();
        expect(cycleSessions, isEmpty);
        expect(discarded, ['aru-1']);
        // The aggregate was discarded, so review must not open it.
        expect(controller.reviewSession, isNull);
      },
    );

    test('names per-cycle test run from deployment name', () async {
      final saved = <LiveSession>[];
      final controller = AruController(
        saveSession: (session) async => saved.add(session),
        now: () => start,
      );

      await controller.startDeployment(
        sessionId: 'aru-1',
        settings: settings,
        metadata: AruDeploymentMetadata(
          deploymentName: 'test',
          scheduleStart: start,
          cycleDurationSeconds: 600,
          repeatIntervalSeconds: 3600,
          maxCycles: 1,
          testCycleEnabled: true,
          eachCycleIsSession: true,
        ),
        sessionNumber: 12,
      );

      await controller.evaluate(now: start.add(const Duration(minutes: 2)));
      await controller.evaluate(
        now: start.add(const Duration(hours: 1, minutes: 5)),
      );
      await controller.evaluate(
        now: start.add(const Duration(hours: 1, minutes: 30)),
      );

      final cycleSessions =
          saved.where((s) => s.id.contains('_cycle_')).toList();
      expect(cycleSessions, hasLength(2));
      expect(cycleSessions.first.id, 'aru-1_cycle_0');
      expect(cycleSessions.first.customName, 'test - Test Run');
      expect(cycleSessions.last.id, 'aru-1_cycle_1');
      expect(cycleSessions.last.customName, 'test - Cycle 1');
    });

    test(
      'does not save per-cycle sessions when eachCycleIsSession is false',
      () async {
        final saved = <LiveSession>[];
        final controller = AruController(
          saveSession: (session) async => saved.add(session),
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(),
        );

        await controller.evaluate(now: start.add(const Duration(minutes: 5)));
        await controller.evaluate(now: start.add(const Duration(minutes: 30)));

        final cycleSessions =
            saved.where((s) => s.id.contains('_cycle_')).toList();
        expect(cycleSessions, isEmpty);
      },
    );

    test(
      'skips a scheduled cycle without recording when recording is suppressed',
      () async {
        var starts = 0;
        final controller = AruController(
          saveSession: (session) async {},
          startCycleRecording: (session, window) async {
            starts++;
            return '/recordings/aru/cycle_${window.index}.flac';
          },
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(),
        );
        await controller.evaluate(
          now: start.add(const Duration(minutes: 5)),
          recordingSuppressed: true,
        );

        final cycle = controller.session!.aruMetadata!.cycles.single;
        expect(controller.state, AruControllerState.waiting);
        expect(cycle.index, 0);
        expect(cycle.status, AruCycleStatus.skipped);
        expect(cycle.actualStart, isNull);
        expect(starts, 0);
        expect(controller.session!.segments, isEmpty);
      },
    );

    test(
      'does not re-record a window already skipped after battery recovers',
      () async {
        final controller = AruController(
          saveSession: (session) async {},
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(),
        );
        // Battery low at the start of cycle 0: skip it.
        await controller.evaluate(
          now: start.add(const Duration(minutes: 1)),
          recordingSuppressed: true,
        );
        // Battery recovers later in the same window: must not re-enter it.
        await controller.evaluate(now: start.add(const Duration(minutes: 5)));

        final cycle = controller.session!.aruMetadata!.cycles.single;
        expect(controller.state, AruControllerState.waiting);
        expect(cycle.status, AruCycleStatus.skipped);
        expect(controller.session!.segments, isEmpty);
      },
    );

    test(
      'records the next cycle once recording is no longer suppressed',
      () async {
        final controller = AruController(
          saveSession: (session) async {},
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(),
        );
        // Cycle 0 skipped for low battery.
        await controller.evaluate(
          now: start.add(const Duration(minutes: 5)),
          recordingSuppressed: true,
        );
        // Cycle 1 records normally after recovery.
        await controller.evaluate(
          now: start.add(const Duration(hours: 1, minutes: 1)),
        );

        final cycles = controller.session!.aruMetadata!.cycles;
        expect(cycles.map((c) => c.index), <int>[0, 1]);
        expect(cycles.first.status, AruCycleStatus.skipped);
        expect(cycles.last.status, AruCycleStatus.recording);
        expect(controller.state, AruControllerState.recording);
        expect(controller.session!.segments, hasLength(1));
      },
    );

    test(
      'marks an in-progress cycle partial when battery drops mid-cycle',
      () async {
        final controller = AruController(
          saveSession: (session) async {},
          now: () => start.subtract(const Duration(minutes: 5)),
        );

        await controller.startDeployment(
          sessionId: 'aru-1',
          settings: settings,
          metadata: metadata(),
        );
        // Cycle 0 starts recording normally.
        await controller.evaluate(now: start.add(const Duration(minutes: 2)));
        // Battery drops mid-cycle: suppress recording.
        await controller.evaluate(
          now: start.add(const Duration(minutes: 5)),
          recordingSuppressed: true,
        );

        final cycle = controller.session!.aruMetadata!.cycles.single;
        expect(controller.state, AruControllerState.waiting);
        expect(cycle.status, AruCycleStatus.partial);
        expect(cycle.actualEnd, start.add(const Duration(minutes: 5)));
      },
    );
  });
}
