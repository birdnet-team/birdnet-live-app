import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/features/upload/connectivity.dart';
import 'package:birdnet_live/features/upload/join_link.dart';
import 'package:birdnet_live/features/upload/secret_store.dart';
import 'package:birdnet_live/features/upload/upload_destination_store.dart';
import 'package:birdnet_live/features/upload/upload_providers.dart';
import 'package:birdnet_live/features/upload/upload_queue_store.dart';
import 'package:birdnet_live/features/upload/webdav_probe.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';

void main() {
  late Directory tempDir;
  late InMemorySecretStore secrets;
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('upload_providers_');
    secrets = InMemorySecretStore();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secretStoreProvider.overrideWithValue(secrets),
        uploadDestinationStoreProvider.overrideWithValue(
          UploadDestinationStore(documentsDirectory: () async => tempDir),
        ),
        uploadQueueStoreProvider.overrideWithValue(
          UploadQueueStore(documentsDirectory: () async => tempDir),
        ),
        connectivityProvider.overrideWithValue(
          FixedConnectivity(NetworkType.none),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  const request = JoinRequest(
    url: 'https://cloud.example.org/public.php/webdav/',
    username: 'share-token',
    secret: 'share-pw',
    name: 'Spring Survey',
    wifiOnly: false,
    source: JoinLinkSource.nextcloudShare,
  );
  const result = ProbeResult.success(
    resolvedUrl: 'https://cloud.example.org/public.php/webdav/',
    warnings: {ProbeWarning.canReadRemote},
    flatLayout: true,
  );

  test('device id is generated once and persisted', () {
    final first = container.read(uploadDeviceIdProvider);
    expect(first, isNotEmpty);
    expect(prefs.getString(PrefKeys.uploadDeviceId), first);
    container.invalidate(uploadDeviceIdProvider);
    expect(container.read(uploadDeviceIdProvider), first);
  });

  test('add stores the secret in the keychain and the rest on disk', () async {
    final notifier = container.read(uploadDestinationsProvider.notifier);
    await container.read(uploadDestinationsProvider.future);

    final added = await notifier.add(
      request: request,
      result: result,
      name: '  Spring Survey ',
    );

    expect(added.name, 'Spring Survey');
    expect(added.username, 'share-token');
    expect(added.wifiOnly, isFalse);
    expect(added.flatLayout, isTrue);
    expect(added.canReadRemote, isTrue);
    expect(added.shareWithoutPassword, isFalse);
    expect(secrets.values[added.secretKey], 'share-pw');
    expect(await notifier.secretFor(added), 'share-pw');

    final onDisk = await UploadDestinationStore(
      documentsDirectory: () async => tempDir,
    ).load();
    expect(onDisk.single, added);
    expect(container.read(uploadDestinationsProvider).value, [added]);
  });

  test('replace updates toggles in place', () async {
    final notifier = container.read(uploadDestinationsProvider.notifier);
    await container.read(uploadDestinationsProvider.future);
    final added = await notifier.add(
      request: request,
      result: result,
      name: 'A',
    );

    await notifier.replace(added.copyWith(autoUploadAru: true, name: 'B'));

    final current = container.read(uploadDestinationsProvider).value!.single;
    expect(current.id, added.id);
    expect(current.name, 'B');
    expect(current.autoUploadAru, isTrue);
  });

  test('remove deletes the destination and its secret', () async {
    final notifier = container.read(uploadDestinationsProvider.notifier);
    await container.read(uploadDestinationsProvider.future);
    final a = await notifier.add(request: request, result: result, name: 'A');
    final b = await notifier.add(request: request, result: result, name: 'B');

    await notifier.remove(a.id);

    expect(container.read(uploadDestinationsProvider).value, [b]);
    expect(secrets.values.containsKey(a.secretKey), isFalse);
    expect(secrets.values[b.secretKey], 'share-pw');
  });

  test('joinRegistrationRecord carries the device id and no secret', () {
    final record = joinRegistrationRecord(
      deviceId: '4ee91c8f-8383-4413-8320-3aa94f39221f',
      appVersion: '1.2.3',
      participant: 'Stefan',
    );
    expect(record['deviceId'], '4ee91c8f-8383-4413-8320-3aa94f39221f');
    expect(record['deviceCode'], '4ee91c8f');
    expect(record['participant'], 'Stefan');
    expect(
      joinRegistrationRecord(
        deviceId: 'd',
        appVersion: '1',
      ).containsKey('participant'),
      isFalse,
    );
    expect(record['appVersion'], '1.2.3');
    expect(record.values.join(), isNot(contains('share-pw')));
    expect(record['joinedAt'], isA<String>());
  });
}
