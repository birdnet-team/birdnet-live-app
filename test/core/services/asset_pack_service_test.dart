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

  group('AssetPackService.configuredExtractionNames', () {
    test('names the audio and the geo model', () {
      expect(
        AssetPackService.configuredExtractionNames('''
          {
            "audioModel": {
              "version": "3.0",
              "onnx": {"modelFile": "BirdNET+_V3.0_FP16.onnx"}
            },
            "geoModel": {
              "version": "3.0.4-Nov2026",
              "modelFile": "BirdNET+_Geomodel_FP16.onnx"
            }
          }
        '''),
        {
          'BirdNET+_V3.0_FP16.onnx_v3.0',
          'BirdNET+_Geomodel_FP16.onnx_v3.0.4-Nov2026',
        },
      );
    });

    test('the shipped model_config.json yields two extractable names', () {
      final names = AssetPackService.configuredExtractionNames(
        File('assets/models/model_config.json').readAsStringSync(),
      );

      expect(names, hasLength(2));
      expect(names.every(AssetPackService.isExtractedModelName), isTrue);
    });

    test('a config without both models throws instead of guessing', () {
      expect(
        () => AssetPackService.configuredExtractionNames(
          '{"audioModel": {"version": "3.0", "onnx": {"modelFile": "a.onnx"}}}',
        ),
        throwsA(anything),
      );
    });
  });

  group('AssetPackService.isExtractedModelName', () {
    test('matches extracted model copies and their partial copies', () {
      for (final name in [
        'BirdNET+_V3.0_FP16.onnx_v3.0',
        'BirdNET+_V3.0_FP16.onnx_v3.0.tmp',
        'BirdNET+_Geomodel_V3.0.4_Global_10K-pruned_FP16.onnx_v3.0.4',
      ]) {
        expect(
          AssetPackService.isExtractedModelName(name),
          isTrue,
          reason: name,
        );
      }
    });

    test('matches nothing else', () {
      for (final name in [
        'BirdNET+_V3.0_FP16.onnx',
        'BirdNET+_V3.0_FP16.onnx.tmp',
        'BirdNET+_V3.0_Labels.csv',
        'foo.onnx',
        'foo.onnx_v3.0',
        'notes.txt',
        'x.json',
        '.onnx_v3.0',
      ]) {
        expect(
          AssetPackService.isExtractedModelName(name),
          isFalse,
          reason: name,
        );
      }
    });
  });

  group('AssetPackService.removeStaleExtractions', () {
    const audio = 'BirdNET+_V3.0_FP16.onnx_v3.0';
    const geo = 'BirdNET+_Geomodel_V3.0.4-Nov2026_FP16.onnx_v3.0.4-Nov2026';
    const keep = {audio, geo};
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('asset_pack_test');
    });

    tearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    File stub(String relative) =>
        File('${tmp.path}/$relative')..writeAsStringSync('x');

    test('deletes copies under an old file name or an old version', () async {
      final oldName = stub(
        'BirdNET+_V3.0-preview3.1_Global_10K-pruned_FP16.onnx_v3.0-preview3.1',
      );
      final oldGeoName = stub(
        'BirdNET+_Geomodel_V3.0.4_Global_10K-pruned_FP16.onnx_v3.0.4',
      );
      final oldVersion = stub('BirdNET+_V3.0_FP16.onnx_v2.4');

      await AssetPackService.removeStaleExtractions(tmp, keep);

      expect(oldName.existsSync(), isFalse);
      expect(oldGeoName.existsSync(), isFalse);
      expect(oldVersion.existsSync(), isFalse);
    });

    test('keeps the current copies of both models', () async {
      final audioFile = stub(audio);
      final geoFile = stub(geo);
      final audioInProgress = stub('$audio.tmp');

      await AssetPackService.removeStaleExtractions(tmp, keep);

      expect(audioFile.existsSync(), isTrue);
      expect(geoFile.existsSync(), isTrue);
      expect(audioInProgress.existsSync(), isTrue);
    });

    test('deletes the partial copy of a model that is not kept', () async {
      final partial = stub('BirdNET+_V3.0_FP16.onnx_v2.4.tmp');

      await AssetPackService.removeStaleExtractions(tmp, keep);

      expect(partial.existsSync(), isFalse);
    });

    test('deletes every copy when nothing is kept', () async {
      final audioFile = stub(audio);
      final partial = stub('$geo.tmp');

      await AssetPackService.removeStaleExtractions(tmp, const {});

      expect(audioFile.existsSync(), isFalse);
      expect(partial.existsSync(), isFalse);
    });

    test('leaves other files and subdirectories alone', () async {
      Directory('${tmp.path}/sessions').createSync();
      Directory('${tmp.path}/recordings').createSync();
      final untouched = [
        stub('sessions/x.json'),
        stub('recordings/BirdNET+_V3.0_FP16.onnx_v2.4'),
        stub('foo.onnx'),
        stub('foo.onnx_v2.4'),
        stub('notes.txt'),
        stub('BirdNET+_V3.0_FP16.onnx'),
        stub('BirdNET+_V3.0_Labels.csv'),
      ];
      final lookalikeDir = Directory('${tmp.path}/BirdNET+_V3.0_FP16.onnx_v2.4')
        ..createSync();

      await AssetPackService.removeStaleExtractions(tmp, const {});

      for (final file in untouched) {
        expect(file.existsSync(), isTrue, reason: file.path);
      }
      expect(lookalikeDir.existsSync(), isTrue);
    });

    test('a copy that cannot be deleted does not throw', () async {
      // An open handle blocks the delete on Windows; elsewhere the delete
      // simply succeeds. Either way the call completes and moves on.
      final locked = stub('BirdNET+_V3.0_FP16.onnx_v2.3');
      final other = stub('BirdNET+_V3.0_FP16.onnx_v2.4');
      final handle = locked.openSync();
      try {
        await AssetPackService.removeStaleExtractions(tmp, keep);
      } finally {
        handle.closeSync();
      }

      expect(other.existsSync(), isFalse);
    });

    test('a missing directory is not an error', () async {
      await AssetPackService.removeStaleExtractions(
        Directory('${tmp.path}/absent'),
        keep,
      );
    });
  });
}
