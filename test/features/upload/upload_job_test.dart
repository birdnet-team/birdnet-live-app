import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/history/services/share_export_config.dart';
import 'package:birdnet_live/features/upload/upload_job.dart';
import 'package:birdnet_live/features/upload/upload_queue_store.dart';

void main() {
  final config = ShareExportConfig(
    formats: const {'raven', 'gpx'},
    includeAudio: true,
    shareAudioAsWav: true,
    includeHtmlReport: true,
    includeAppMetadata: false,
  );

  UploadJob job({UploadJobState state = UploadJobState.queued}) => UploadJob(
    id: 'job-1',
    sessionId: 'session-1',
    sessionUuid: 'uuid-1',
    destinationId: 'dest-1',
    version: 2,
    config: config,
    state: state,
    attempts: 3,
    createdAt: DateTime.utc(2026, 10, 28, 12),
    nextAttemptAt: DateTime.utc(2026, 10, 28, 12, 8),
    lastError: 'network',
  );

  group('UploadJob', () {
    test('round-trips through JSON with its export configuration', () {
      final restored = UploadJob.fromJson(job().toJson());
      expect(restored.id, 'job-1');
      expect(restored.version, 2);
      expect(restored.attempts, 3);
      expect(restored.state, UploadJobState.queued);
      expect(restored.nextAttemptAt, DateTime.utc(2026, 10, 28, 12, 8));
      expect(restored.lastError, 'network');
      expect(restored.config.formats, {'gpx', 'raven'});
      expect(restored.config.includeAudio, isTrue);
      expect(restored.config.shareAudioAsWav, isTrue);
      expect(restored.config.includeHtmlReport, isTrue);
      expect(restored.config.includeAppMetadata, isFalse);
    });

    test('isDue honors the retry time for failed jobs', () {
      final failed = job(state: UploadJobState.failed);
      expect(failed.isDue(DateTime.utc(2026, 10, 28, 12, 5)), isFalse);
      expect(failed.isDue(DateTime.utc(2026, 10, 28, 12, 8)), isTrue);
      expect(failed.isPending, isTrue);
      expect(failed.gaveUp, isFalse);

      final gaveUp = failed.copyWith(clearNextAttempt: true);
      expect(gaveUp.gaveUp, isTrue);
      expect(gaveUp.isPending, isFalse);
      expect(gaveUp.isDue(DateTime.utc(2030)), isFalse);

      expect(job(state: UploadJobState.uploaded).isPending, isFalse);
      expect(job(state: UploadJobState.uploading).isPending, isTrue);
    });
  });

  group('UploadQueueStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('upload_queue_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test(
      'the run lock is exclusive, released, and expires when stale',
      () async {
        final store = UploadQueueStore(documentsDirectory: () async => tempDir);
        expect(await store.tryLock(), isTrue);
        expect(await store.tryLock(), isFalse);
        await store.unlock();
        expect(await store.tryLock(), isTrue);

        // A lock left behind by a killed process is taken over once stale.
        final lock = File('${tempDir.path}/${UploadQueueStore.lockFileName}');
        await lock.setLastModified(
          DateTime.now().subtract(UploadQueueStore.staleLock * 2),
        );
        expect(await store.tryLock(), isTrue);
        await store.unlock();
      },
    );

    test('saves and loads jobs, and tolerates a corrupt file', () async {
      final store = UploadQueueStore(documentsDirectory: () async => tempDir);
      expect(await store.load(), isEmpty);

      await store.save([job(), job(state: UploadJobState.uploaded)]);
      final loaded = await store.load();
      expect(loaded.length, 2);
      expect(loaded[1].state, UploadJobState.uploaded);

      await File('${tempDir.path}/${UploadQueueStore.fileName}')
          .writeAsString('nope');
      expect(await store.load(), isEmpty);

      await store.deleteAll();
      expect(
        await File('${tempDir.path}/${UploadQueueStore.fileName}').exists(),
        isFalse,
      );
    });
  });
}
