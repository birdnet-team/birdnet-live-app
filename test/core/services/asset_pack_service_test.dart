import 'dart:io';

import 'package:birdnet_live/core/services/asset_pack_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const key = 'assets/models/BirdNET+_V3.0_FP16.onnx';

  group('AssetPackService.bundledAssetPathFor', () {
    test('iOS assets live in App.framework next to the executable', () {
      expect(
        AssetPackService.bundledAssetPathFor(
          key,
          executablePath:
              '/private/var/containers/Bundle/Application/'
              'ABC/Runner.app/Runner',
          operatingSystem: 'ios',
        ),
        '/private/var/containers/Bundle/Application/ABC/Runner.app/'
        'Frameworks/App.framework/flutter_assets/assets/models/'
        'BirdNET+_V3.0_FP16.onnx',
      );
    });

    test('macOS assets live under Contents/Frameworks', () {
      expect(
        AssetPackService.bundledAssetPathFor(
          key,
          executablePath:
              '/Applications/BirdNET Live.app/Contents/MacOS/'
              'birdnet_live',
          operatingSystem: 'macos',
        ),
        '/Applications/BirdNET Live.app/Contents/Frameworks/App.framework/'
        'Resources/flutter_assets/assets/models/BirdNET+_V3.0_FP16.onnx',
      );
    });

    test('Windows assets live in data/flutter_assets beside the exe', () {
      expect(
        AssetPackService.bundledAssetPathFor(
          key,
          executablePath: r'C:\Program Files\BirdNET Live\birdnet_live.exe',
          operatingSystem: 'windows',
        ),
        r'C:\Program Files\BirdNET Live\data\flutter_assets\assets\models'
        r'\BirdNET+_V3.0_FP16.onnx',
      );
    });

    test('Linux assets live in data/flutter_assets beside the binary', () {
      expect(
        AssetPackService.bundledAssetPathFor(
          key,
          executablePath: '/opt/birdnet_live/birdnet_live',
          operatingSystem: 'linux',
        ),
        '/opt/birdnet_live/data/flutter_assets/assets/models/'
        'BirdNET+_V3.0_FP16.onnx',
      );
    });

    test('Android assets are not reachable as files', () {
      expect(
        AssetPackService.bundledAssetPathFor(
          key,
          executablePath: '/system/bin/app_process64',
          operatingSystem: 'android',
        ),
        isNull,
      );
    });

    test('an unknown executable path yields no candidate', () {
      expect(
        AssetPackService.bundledAssetPathFor(
          key,
          executablePath: '',
          operatingSystem: 'ios',
        ),
        isNull,
      );
    });
  });

  group('AssetPackService.removeStaleExtractions', () {
    const fileName = 'BirdNET+_V3.0_FP16.onnx';
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('asset_pack_test');
    });

    tearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    File stub(String relative) =>
        File('${tmp.path}/$relative')..writeAsStringSync('x');

    test(
      'deletes every versioned copy and partial copy of the model',
      () async {
        final current = stub('${fileName}_v3.0');
        final older = stub('${fileName}_v2.4');
        final partial = stub('${fileName}_v3.0.tmp');

        await AssetPackService.removeStaleExtractions(tmp, fileName);

        expect(current.existsSync(), isFalse);
        expect(older.existsSync(), isFalse);
        expect(partial.existsSync(), isFalse);
      },
    );

    test('leaves other files and subdirectories alone', () async {
      final otherModel = stub('geo_v3.0');
      final unrelated = stub('notes.txt');
      Directory('${tmp.path}/recordings').createSync();
      final nested = stub('recordings/${fileName}_v3.0');

      await AssetPackService.removeStaleExtractions(tmp, fileName);

      expect(otherModel.existsSync(), isTrue);
      expect(unrelated.existsSync(), isTrue);
      expect(nested.existsSync(), isTrue);
    });

    test('a missing directory is not an error', () async {
      await AssetPackService.removeStaleExtractions(
        Directory('${tmp.path}/absent'),
        fileName,
      );
    });
  });
}
