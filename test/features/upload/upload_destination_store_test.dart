import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/upload/upload_destination.dart';
import 'package:birdnet_live/features/upload/upload_destination_store.dart';

void main() {
  late Directory tempDir;
  late UploadDestinationStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('upload_dest_store_');
    store = UploadDestinationStore(documentsDirectory: () async => tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  UploadDestination destination(String id) => UploadDestination(
    id: id,
    name: 'Project $id',
    url: 'https://cloud.example.org/public.php/webdav/',
    username: 'token-$id',
    createdAt: DateTime.utc(2026, 10, 28, 12),
    lastUploadAt: id == 'b' ? DateTime.utc(2026, 10, 29, 8) : null,
    flatLayout: id == 'b',
    canReadRemote: id == 'a',
  );

  test('load returns an empty list when nothing was saved', () async {
    expect(await store.load(), isEmpty);
  });

  test('save and load round-trip every field', () async {
    final list = [destination('a'), destination('b')];
    await store.save(list);

    final loaded = await store.load();

    expect(loaded, list);
    expect(loaded[1].lastUploadAt, DateTime.utc(2026, 10, 29, 8));
    expect(loaded[1].flatLayout, isTrue);
    expect(loaded[0].canReadRemote, isTrue);
    expect(loaded[0].wifiOnly, isTrue);
    expect(loaded[0].autoUploadAru, isFalse);
  });

  test('the file never contains a secret key field', () async {
    await store.save([destination('a')]);
    final text = await File(
      '${tempDir.path}/${UploadDestinationStore.fileName}',
    ).readAsString();
    expect(text, isNot(contains('secret')));
    expect(text, contains('"version": 1'));
  });

  test('a corrupt file reads as empty instead of throwing', () async {
    await File('${tempDir.path}/${UploadDestinationStore.fileName}')
        .writeAsString('{not json');
    expect(await store.load(), isEmpty);
  });

  test('deleteAll removes the file', () async {
    await store.save([destination('a')]);
    await store.deleteAll();
    expect(
      await File('${tempDir.path}/${UploadDestinationStore.fileName}').exists(),
      isFalse,
    );
    expect(await store.load(), isEmpty);
  });
}
