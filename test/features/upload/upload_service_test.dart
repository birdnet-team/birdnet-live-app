import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:birdnet_live/features/history/services/share_export_config.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/upload/connectivity.dart';
import 'package:birdnet_live/features/upload/secret_store.dart';
import 'package:birdnet_live/features/upload/upload_destination.dart';
import 'package:birdnet_live/features/upload/upload_job.dart';
import 'package:birdnet_live/features/upload/upload_queue_store.dart';
import 'package:birdnet_live/features/upload/upload_service.dart';
import 'package:birdnet_live/features/upload/webdav_client.dart';

/// Records every request; answers PUT/MKCOL with [putStatus] (or a per-path
/// override) and stores PUT bodies by path.
class _FakeDav {
  int putStatus = 201;
  final Map<String, int> overrides = {};
  final List<http.BaseRequest> requests = [];
  final Map<String, List<int>> bodies = {};
  int failuresLeft = 0;

  http.Client get client => MockClient.streaming((request, bodyStream) async {
    requests.add(request);
    if (failuresLeft > 0) {
      failuresLeft--;
      throw const SocketException('connection reset');
    }
    final body = await bodyStream.toBytes();
    if (request.method == 'PUT') bodies[request.url.path] = body;
    final status =
        overrides[request.url.path] ??
        (request.method == 'MKCOL' ? 201 : putStatus);
    return http.StreamedResponse(const Stream.empty(), status);
  });

  List<String> paths(String method) => [
    for (final r in requests)
      if (r.method == method) r.url.path,
  ];
}

void main() {
  late Directory tempDir;
  late _FakeDav dav;
  late FixedConnectivity connectivity;
  late UploadDestination destination;
  late LiveSession session;
  late UploadService service;
  late String? exportPath;
  var now = DateTime.utc(2026, 10, 28, 12);
  Future<String?> Function(UploadDestination) secretFor = (_) async => 'pw';

  final config = ShareExportConfig(formats: const {'csv'}, includeAudio: false);

  UploadService build({UploadDestination? dest}) {
    return UploadService(
      store: UploadQueueStore(documentsDirectory: () async => tempDir),
      client: WebDavClient(client: dav.client),
      connectivity: connectivity,
      deviceId: () => 'device-1',
      appVersion: () async => '9.9.9',
      loadSession: (id) async => id == session.id ? session : null,
      findDestination: (id) async =>
          id == (dest ?? destination).id ? (dest ?? destination) : null,
      secretFor: (d) => secretFor(d),
      buildExport: (_, _) async {
        final path = exportPath;
        if (path == null) return null;
        // The service deletes the staged export after each upload; a real
        // builder produces a fresh file every time.
        await File(path).writeAsBytes(List<int>.generate(1000, (i) => i % 251));
        return path;
      },
      buildJson: (s) async => jsonEncode({'uuid': s.uuid, 'id': s.id}),
      now: () => now,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('upload_service_');
    dav = _FakeDav();
    connectivity = FixedConnectivity(NetworkType.wifi);
    destination = UploadDestination(
      id: 'dest-1',
      name: 'Project',
      url: 'https://cloud.example.org/public.php/webdav/',
      username: 'token',
      createdAt: now,
    );
    session = LiveSession(
      id: '2026-10-28T10-00-00.000',
      startTime: DateTime(2026, 10, 28, 10),
      endTime: DateTime(2026, 10, 28, 10, 30),
      settings: const SessionSettings(
        windowDuration: 3,
        confidenceThreshold: 25,
        inferenceRate: 1.0,
        speciesFilterMode: 'off',
      ),
    );
    final export = File('${tempDir.path}/BirdNET_Live_export_#13.zip');
    await export.writeAsBytes(List<int>.generate(1000, (i) => i % 251));
    exportPath = export.path;
    service = build();
  });

  tearDown(() async {
    // A run kicked off by the last enqueue may still be writing.
    await service.processQueue();
    service.dispose();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('uploads the record, the export, and the completion marker', () async {
    final job = await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();

    final folder = '/public.php/webdav/device-1/${session.uuid}/v1/';
    expect(dav.paths('MKCOL'), [
      '/public.php/webdav/device-1/',
      '/public.php/webdav/device-1/${session.uuid}/',
      folder,
    ]);
    expect(dav.paths('PUT'), [
      '${folder}session.json',
      '${folder}BirdNET_Live_export_%2313.zip',
      '${folder}_complete.json',
    ]);
    // The `#` travels percent-encoded, never as a fragment.
    expect(
      dav.requests[4].url.toString(),
      endsWith('/v1/BirdNET_Live_export_%2313.zip'),
    );
    final first = dav.requests.first;
    expect(first.headers['Authorization'], startsWith('Basic '));

    final complete = jsonDecode(
      utf8.decode(dav.bodies['${folder}_complete.json']!),
    ) as Map<String, dynamic>;
    expect(complete['sessionUuid'], session.uuid);
    expect(complete['version'], 1);
    expect(complete['appVersion'], '9.9.9');
    final files = complete['files'] as Map<String, dynamic>;
    expect(
      files.keys,
      containsAll(['session.json', 'BirdNET_Live_export_#13.zip']),
    );
    expect(
      (files['BirdNET_Live_export_#13.zip'] as Map<String, dynamic>)['size'],
      1000,
    );

    final done = service.jobsForSession(session.id).single;
    expect(done.id, job.id);
    expect(done.state, UploadJobState.uploaded);
    expect(done.finishedAt, now);
    expect(done.remotePath, 'device-1/${session.uuid}/v1/');
    // The staged export is cleaned up; it was not a session asset.
    expect(await File(exportPath!).exists(), isFalse);
  });

  test('flat layout folds the folder path into file names', () async {
    final flat = destination.copyWith(flatLayout: true);
    service.dispose();
    service = build(dest: flat);
    await service.enqueue(session: session, destination: flat, config: config);
    await service.processQueue();

    expect(dav.paths('MKCOL'), isEmpty);
    expect(
      dav.paths('PUT').first,
      '/public.php/webdav/device-1__${session.uuid}__v1__session.json',
    );
  });

  test('a metadata-only configuration skips the export file', () async {
    exportPath = null;
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();

    expect(dav.paths('PUT').length, 2);
    expect(
      service.jobsForSession(session.id).single.state,
      UploadJobState.uploaded,
    );
  });

  test('a network failure backs off and a later run succeeds', () async {
    dav.failuresLeft = 1;
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();

    var job = service.jobsForSession(session.id).single;
    expect(job.state, UploadJobState.failed);
    expect(job.attempts, 1);
    expect(job.lastError, UploadErrorCode.network);
    expect(job.nextAttemptAt, now.add(const Duration(minutes: 1)));

    // Not due yet: nothing happens.
    final before = dav.requests.length;
    await service.processQueue();
    expect(dav.requests.length, before);

    now = now.add(const Duration(minutes: 2));
    await service.processQueue();
    job = service.jobsForSession(session.id).single;
    expect(job.state, UploadJobState.uploaded);
  });

  test('a 401 is reported as unauthorized', () async {
    dav.putStatus = 401;
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    expect(
      service.jobsForSession(session.id).single.lastError,
      UploadErrorCode.unauthorized,
    );
  });

  test('a 412 on an existing path counts as written', () async {
    dav.overrides['/public.php/webdav/device-1/${session.uuid}/v1/session.json'] =
        412;
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    expect(
      service.jobsForSession(session.id).single.state,
      UploadJobState.uploaded,
    );
  });

  test(
    'Wi-Fi-only destinations wait on cellular, offline stops the run',
    () async {
      connectivity.type = NetworkType.cellular;
      await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
      await service.processQueue();
      var job = service.jobsForSession(session.id).single;
      expect(job.state, UploadJobState.queued);
      expect(job.lastError, UploadErrorCode.waitingForWifi);
      expect(dav.requests, isEmpty);

      connectivity.type = NetworkType.none;
      await service.processQueue();
      job = service.jobsForSession(session.id).single;
      expect(job.lastError, UploadErrorCode.offline);
      expect(dav.requests, isEmpty);

      connectivity.type = NetworkType.wifi;
      await service.processQueue();
      expect(
        service.jobsForSession(session.id).single.state,
        UploadJobState.uploaded,
      );
    },
  );

  test('enqueue is idempotent while pending and versions afterwards', () async {
    connectivity.type = NetworkType.none;
    final a = await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    final b = await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    expect(b.id, a.id);

    connectivity.type = NetworkType.wifi;
    await service.processQueue();
    final c = await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    expect(c.version, 2);
    await service.processQueue();
    expect(
      dav.paths('PUT'),
      contains('/public.php/webdav/device-1/${session.uuid}/v2/_complete.json'),
    );
  });

  test('jobs survive a restart and an interrupted upload is retried', () async {
    connectivity.type = NetworkType.none;
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    // Simulate a kill mid-upload by persisting the job as uploading.
    final store = UploadQueueStore(documentsDirectory: () async => tempDir);
    final stored = await store.load();
    await store.save([stored.single.copyWith(state: UploadJobState.uploading)]);

    service.dispose();
    connectivity.type = NetworkType.wifi;
    service = build();
    await service.processQueue();
    expect(
      service.jobsForSession(session.id).single.state,
      UploadJobState.uploaded,
    );
  });

  test('a removed destination gives up without retrying', () async {
    service.dispose();
    service = build(dest: destination.copyWith(name: 'x'));
    await service.enqueue(
      session: session,
      destination: UploadDestination(
        id: 'gone',
        name: 'Gone',
        url: 'https://x.example.org/',
        username: '',
        createdAt: now,
      ),
      config: config,
    );
    await service.processQueue();
    final job = service.jobsForSession(session.id).single;
    expect(job.gaveUp, isTrue);
    expect(job.lastError, UploadErrorCode.destinationMissing);
  });

  test('cancelForDestination drops pending jobs and keeps the log', () async {
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    final other = LiveSession(
      id: 'other',
      startTime: DateTime(2026, 10, 28, 11),
      endTime: DateTime(2026, 10, 28, 11, 10),
      settings: session.settings,
    );
    connectivity.type = NetworkType.none;
    await service.enqueue(
      session: other,
      destination: destination,
      config: config,
    );
    await service.processQueue();
    expect(service.pendingCount, 1);

    await service.cancelForDestination(destination.id);

    expect(service.pendingCount, 0);
    expect(
      service.jobsForSession(session.id).single.state,
      UploadJobState.uploaded,
    );
    expect(service.jobsForSession(other.id), isEmpty);
  });

  test('enqueue keys on the stored UUID, not the copy handed in', () async {
    // A library listing of a legacy session carries a fresh, unsaved UUID.
    final listed = LiveSession(
      id: session.id,
      startTime: session.startTime,
      endTime: session.endTime,
      settings: session.settings,
    );
    expect(listed.uuid, isNot(session.uuid));

    final job = await service.enqueue(
      session: listed,
      destination: destination,
      config: config,
    );
    expect(job.sessionUuid, session.uuid);
    await service.processQueue();

    final again = await service.enqueue(
      session: listed,
      destination: destination,
      config: config,
    );
    expect(again.version, 2);
    // Let the run the second enqueue started finish before the temp
    // directory is deleted.
    await service.processQueue();
  });

  test('a keychain failure fails the job and the run continues', () async {
    secretFor = (_) async => throw const SecretStoreException('locked');
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();

    final job = service.jobsForSession(session.id).single;
    expect(job.state, UploadJobState.failed);
    expect(job.lastError, UploadErrorCode.secretMissing);
    expect(job.nextAttemptAt, isNotNull);

    secretFor = (_) async => 'pw';
    now = now.add(const Duration(minutes: 2));
    await service.processQueue();
    expect(
      service.jobsForSession(session.id).single.state,
      UploadJobState.uploaded,
    );
  });

  test('an export the pipeline refuses fails the job instead of uploading '
      'without audio', () async {
    exportPath = null;
    final withAudio = LiveSession(
      id: 'audio',
      startTime: session.startTime,
      endTime: session.endTime,
      settings: session.settings,
      recordingPath: '${tempDir.path}/full.flac',
    );
    await File(withAudio.recordingPath!).writeAsBytes([1, 2, 3]);
    final previous = session;
    session = withAudio;
    addTearDown(() => session = previous);
    final audioConfig = ShareExportConfig(
      formats: const {'csv'},
      includeAudio: true,
    );

    await service.enqueue(
      session: withAudio,
      destination: destination,
      config: audioConfig,
    );
    await service.processQueue();

    final job = service.jobsForSession(withAudio.id).single;
    expect(job.state, UploadJobState.failed);
    expect(job.lastError, UploadErrorCode.exportFailed);
    expect(dav.paths('PUT'), isNot(contains(endsWith('_complete.json'))));
  });

  test('the export is moved into staging before upload and the original '
      'path is left alone afterwards', () async {
    await service.enqueue(
      session: session,
      destination: destination,
      config: config,
    );
    await service.processQueue();

    expect(await File(exportPath!).exists(), isFalse);
    final staging = Directory('${tempDir.path}/upload_staging');
    expect(
      await staging.exists() ? await staging.list().toList() : const [],
      isEmpty,
    );
    expect(
      service.jobsForSession(session.id).single.state,
      UploadJobState.uploaded,
    );
  });

  test(
    'a second service on the same file sees what the first one did',
    () async {
      // The foreground app enqueues while offline.
      connectivity.type = NetworkType.none;
      await service.enqueue(
        session: session,
        destination: destination,
        config: config,
      );
      await service.processQueue();

      // The background worker (another isolate) uploads it.
      final worker = build();
      connectivity.type = NetworkType.wifi;
      await worker.processQueue();
      expect(
        worker.jobsForSession(session.id).single.state,
        UploadJobState.uploaded,
      );
      worker.dispose();

      // The app's next run must not re-upload, and a later write by the app
      // must keep the worker's result.
      final puts = dav.paths('PUT').length;
      await service.processQueue();
      expect(dav.paths('PUT').length, puts);
      expect(
        service.jobsForSession(session.id).single.state,
        UploadJobState.uploaded,
      );
      final other = LiveSession(
        id: 'other',
        startTime: session.startTime,
        endTime: session.endTime,
        settings: session.settings,
      );
      await service.enqueue(
        session: other,
        destination: destination,
        config: config,
      );
      await service.processQueue();
      final reloaded = await UploadQueueStore(
        documentsDirectory: () async => tempDir,
      ).load();
      // The app knows nothing about 'other' on disk, so that job fails; the
      // point is that the worker's finished job survives the app's write.
      expect(reloaded.length, 2);
      expect(
        reloaded.singleWhere((j) => j.sessionId == session.id).state,
        UploadJobState.uploaded,
      );
    },
  );

  test('backoff doubles from one minute and caps at six hours', () {
    expect(UploadService.backoff(1), const Duration(minutes: 1));
    expect(UploadService.backoff(2), const Duration(minutes: 2));
    expect(UploadService.backoff(5), const Duration(minutes: 16));
    expect(UploadService.backoff(10), const Duration(hours: 6));
    expect(UploadService.backoff(25), const Duration(hours: 6));
  });
}
