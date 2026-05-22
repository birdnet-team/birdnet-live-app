// =============================================================================
// App Data Clear Service Tests
// =============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/core/services/app_data_clear_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentsDir;
  late Directory temporaryDir;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('birdnet_docs_');
    temporaryDir = await Directory.systemTemp.createTemp('birdnet_temp_');
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
  });

  tearDown(() async {
    if (await documentsDir.exists()) {
      await documentsDir.delete(recursive: true);
    }
    if (await temporaryDir.exists()) {
      await temporaryDir.delete(recursive: true);
    }
  });

  Future<void> writeFile(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('data');
  }

  test(
    'clears user data stores while preserving unrelated app assets',
    () async {
      await writeFile('${documentsDir.path}/sessions/session.json');
      await writeFile('${documentsDir.path}/recordings/session/full.flac');
      await writeFile('${documentsDir.path}/species_lists/watchlist.txt');
      await writeFile('${documentsDir.path}/models/audio.onnx');
      await writeFile('${temporaryDir.path}/birdnet_norm_cache/clip.wav');
      await writeFile('${temporaryDir.path}/birdnet_spec_wav/session.wav');
      await writeFile('${temporaryDir.path}/shared_clips/clip.flac');
      await writeFile('${temporaryDir.path}/other_cache/keep.tmp');

      var mapTileCacheCleared = false;
      final service = AppDataClearService(
        documentsDirectoryProvider: () async => documentsDir,
        temporaryDirectoryProvider: () async => temporaryDir,
        mapTileCacheClearer: () async => mapTileCacheCleared = true,
      );

      await service.clearAllData();

      expect(Directory('${documentsDir.path}/sessions').existsSync(), isFalse);
      expect(
        Directory('${documentsDir.path}/recordings').existsSync(),
        isFalse,
      );
      expect(
        Directory('${documentsDir.path}/species_lists').existsSync(),
        isFalse,
      );
      expect(
        File('${documentsDir.path}/models/audio.onnx').existsSync(),
        isTrue,
      );
      expect(
        Directory('${temporaryDir.path}/birdnet_norm_cache').existsSync(),
        isFalse,
      );
      expect(
        Directory('${temporaryDir.path}/birdnet_spec_wav').existsSync(),
        isFalse,
      );
      expect(
        Directory('${temporaryDir.path}/shared_clips').existsSync(),
        isFalse,
      );
      expect(
        File('${temporaryDir.path}/other_cache/keep.tmp').existsSync(),
        isTrue,
      );
      expect(mapTileCacheCleared, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    },
  );

  test('attempts remaining stores before reporting clear failures', () async {
    final service = AppDataClearService(
      documentsDirectoryProvider: () async => documentsDir,
      temporaryDirectoryProvider: () async => temporaryDir,
      mapTileCacheClearer: () async => throw StateError('cache locked'),
    );

    await expectLater(
      service.clearAllData(),
      throwsA(isA<AppDataClearException>()),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
