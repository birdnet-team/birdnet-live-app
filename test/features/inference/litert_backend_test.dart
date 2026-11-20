// =============================================================================
// LiteRT backend tests
// =============================================================================
//
// Covers the Dart side of the experimental LiteRT backend without a device:
//   - backend setting -> accelerator mapping per workload
//   - `litert` section of model_config.json (bundled file + defaults)
//   - window preparation (pad / truncate / clamp) matching the ONNX path
//   - channel contract: request arguments and batch splitting
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:birdnet_live/features/inference/inference_backend.dart';
import 'package:birdnet_live/features/inference/litert_classifier_model.dart';
import 'package:birdnet_live/features/inference/model_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InferenceBackends.liteRtAccelerator', () {
    // The mapping is platform-gated; the host running the tests is not Android.
    test('is null off Android for every setting', () {
      if (Platform.isAndroid) return;
      for (final s in InferenceBackends.all) {
        for (final w in InferenceWorkload.values) {
          expect(InferenceBackends.liteRtAccelerator(s, w), isNull);
        }
      }
    });

    test('lists onnx first as the default', () {
      expect(InferenceBackends.all.first, InferenceBackends.onnx);
    });
  });

  group('LiteRtConfig', () {
    test('bundled model_config.json has a LiteRT build whose files exist', () {
      final json = jsonDecode(
        File('assets/models/model_config.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final cfg = ModelConfig.fromJson(
        json['audioModel'] as Map<String, dynamic>,
      );
      final litert = cfg.litert;
      expect(litert, isNotNull);
      expect(litert!.windowSeconds, 3);
      expect(cfg.inference.supportedWindowSeconds, contains(3));
      for (final f in [litert.frontendFile, litert.classifierFile]) {
        expect(File('assets/models/$f').existsSync(), isTrue, reason: f);
      }
    });

    test('is optional and round-trips', () {
      final base = <String, dynamic>{
        'name': 'm',
        'audio': {'sampleRate': 32000, 'channels': 1},
        'onnx': {'modelFile': 'm.onnx'},
        'labels': {'file': 'l.csv'},
        'inference': <String, dynamic>{},
      };
      expect(ModelConfig.fromJson(base).litert, isNull);
      expect(ModelConfig.fromJson(base).toJson().containsKey('litert'), false);

      final withLiteRt = {
        ...base,
        'litert': {'frontendFile': 'f.tflite', 'classifierFile': 'c.tflite'},
      };
      final cfg = ModelConfig.fromJson(withLiteRt);
      expect(cfg.litert!.windowSeconds, 3);
      final again = ModelConfig.fromJson(
        jsonDecode(jsonEncode(cfg.toJson())) as Map<String, dynamic>,
      );
      expect(again.litert!.classifierFile, 'c.tflite');
    });
  });

  group('LiteRtClassifierModel.prepareWindow', () {
    test('pads short audio with zeros', () {
      final r = LiteRtClassifierModel.prepareWindow(
        Float32List.fromList([0.1, 0.2]),
        5,
      );
      expect(r.length, 5);
      expect(r[1], closeTo(0.2, 1e-6));
      expect(r.sublist(2), everyElement(0.0));
    });

    test('truncates and clamps long audio', () {
      final r = LiteRtClassifierModel.prepareWindow(
        Float32List.fromList([1.5, -2.0, 0.3, 0.4]),
        3,
      );
      expect(r, [1.0, -1.0, closeTo(0.3, 1e-6)]);
    });

    test('passes exact-length windows through untouched', () {
      final a = Float32List.fromList([0.5, 0.6]);
      expect(identical(LiteRtClassifierModel.prepareWindow(a, 2), a), isTrue);
    });
  });

  group('LiteRtClassifierModel channel contract', () {
    const channel = MethodChannel('com.birdnet/litert');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    const window = 4;
    const classes = 3;

    setUp(() {
      calls.clear();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'load':
            return {
              'accelerator': 'gpu', // pretend the TPU fell back natively
              'requested': (call.arguments as Map)['accelerator'],
              'loadMs': 12,
              'windowSamples': window,
              'numClasses': classes,
            };
          case 'predict':
            final batch = (call.arguments as Map)['batch'] as int;
            return {
              'predictions': Float32List.fromList([
                for (var i = 0; i < batch * classes; i++) i.toDouble(),
              ]),
              'embeddings': Float32List(0),
            };
          case 'close':
            return null;
        }
        return null;
      });
    });

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('reports the accelerator actually used', () async {
      final m = LiteRtClassifierModel();
      final info = await m.load(
        frontendPath: '/f',
        classifierPath: '/c',
        accelerator: 'tpu',
      );
      expect(info.requested, 'tpu');
      expect(info.accelerator, 'gpu');
      expect(m.isLoaded, isTrue);
      expect(m.windowSamples, window);
    });

    test('sends one flat batch and splits the scores per window', () async {
      final m = LiteRtClassifierModel();
      await m.load(
        frontendPath: '/f',
        classifierPath: '/c',
        accelerator: 'tpu',
      );
      final out = await m.predictBatch([
        Float32List(window),
        Float32List(2), // padded on the Dart side
      ], windowSamples: window);
      final args = calls.last.arguments as Map;
      expect(args['batch'], 2);
      expect((args['audio'] as Float32List).length, 2 * window);
      expect(out.length, 2);
      expect(out[1].predictions, [3.0, 4.0, 5.0]);
      expect(out[0].embeddings, isNull);
    });

    test('rejects window lengths the fixed graphs cannot take', () async {
      final m = LiteRtClassifierModel();
      await m.load(
        frontendPath: '/f',
        classifierPath: '/c',
        accelerator: 'cpu',
      );
      expect(
        () => m.predict(Float32List(window * 2), windowSamples: window * 2),
        throwsUnsupportedError,
      );
    });

    test('dispose closes the native models once', () async {
      final m = LiteRtClassifierModel();
      await m.load(
        frontendPath: '/f',
        classifierPath: '/c',
        accelerator: 'cpu',
      );
      await m.dispose();
      await m.dispose();
      expect(calls.where((c) => c.method == 'close').length, 1);
      expect(m.isLoaded, isFalse);
    });
  });
}
