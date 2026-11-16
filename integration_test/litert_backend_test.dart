// =============================================================================
// LiteRT Backend Integration Test — ONNX vs LiteRT (Edge TPU / GPU / CPU)
// =============================================================================
//
// Runs the same real audio windows through the shipped ONNX model and the
// experimental LiteRT build on every accelerator, inside the app, and reports
// per-window latency and agreement with ONNX (top-1 class, max score
// difference, detections >= 0.35).
//
// Audio: raw little-endian float32, N x 96 000 samples (32 kHz, 3 s), placed in
// the app's external files dir. Without it the test uses synthetic noise.
//
//   adb push windows.f32 \
//     /sdcard/Android/data/de.tu_chemnitz.mi.kahst.birdnet_live/files/litert_windows.f32
//   flutter test integration_test/litert_backend_test.dart -d <device_id>
//
// research/edge-tpu-v3/scripts/export_windows.py writes windows.f32 from the
// field test set used in the README.
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:birdnet_live/core/services/asset_pack_service.dart';
import 'package:birdnet_live/features/inference/audio_classifier.dart';
import 'package:birdnet_live/features/inference/classifier_model.dart';
import 'package:birdnet_live/features/inference/litert_classifier_model.dart';
import 'package:birdnet_live/features/inference/model_config.dart';

const _threshold = 0.35;
const _batch = 16;

/// Whether [_loadWindows] found real audio; agreement on noise is meaningless.
var _realWindows = false;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ONNX vs LiteRT accelerators on real windows', (tester) async {
    final config = ModelConfig.fromJson(
      (jsonDecode(
            await rootBundle.loadString('assets/models/model_config.json'),
          ) as Map<String, dynamic>)['audioModel']
          as Map<String, dynamic>,
    );
    final litert = config.litert!;
    final windowSamples = litert.windowSeconds * config.audio.sampleRate;
    final windows = await _loadWindows(windowSamples);
    final results = <Map<String, Object?>>[];

    Future<String> path(String f) =>
        AssetPackService.resolveModelPath(fileName: f, version: config.version);

    // ── ONNX reference ────────────────────────────────────────────────
    final onnx = ClassifierModel();
    await onnx.loadModelFromFile(
      await path(config.onnx.modelFile),
      inputName: config.onnx.inputName,
      predictionsName: config.onnx.predictionsName,
      embeddingsName: config.onnx.embeddingsName,
    );
    final ref = await _run(
      'ONNX CPU',
      onnx,
      windows,
      windowSamples,
      null,
      results,
    );
    await onnx.dispose();

    // ── LiteRT on each accelerator ────────────────────────────────────
    final frontend = await path(litert.frontendFile);
    final classifier = await path(litert.classifierFile);
    for (final acc in ['tpu', 'gpu', 'cpu']) {
      final m = LiteRtClassifierModel();
      try {
        final info = await m.load(
          frontendPath: frontend,
          classifierPath: classifier,
          accelerator: acc,
        );
        await _run(
          'LiteRT $acc (ran on ${info.accelerator}, load ${info.loadMs} ms)',
          m,
          windows,
          windowSamples,
          ref,
          results,
        );
      } on PlatformException catch (e) {
        results.add({'label': 'LiteRT $acc', 'error': e.message});
      } finally {
        await m.dispose();
      }
    }

    final table = _table(results, windows.length);
    // ignore: avoid_print
    print('\n$table');
    for (final r in results) {
      // ignore: avoid_print
      print('LITERT_BENCH ${jsonEncode(r)}');
    }
    binding.reportData = {'results': results, 'table': table};

    // LiteRT on the TPU must agree with ONNX at least as well as fp16 does.
    final tpu = results.firstWhere(
      (r) => (r['label'] as String).startsWith('LiteRT tpu'),
    );
    if (_realWindows && tpu['error'] == null && ref.isNotEmpty) {
      expect(tpu['top1Agree'] as double, greaterThan(0.9));
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

/// Real windows from the external files dir, or 16 windows of noise.
Future<List<Float32List>> _loadWindows(int windowSamples) async {
  _realWindows = false;
  final dir = await getExternalStorageDirectory();
  final f = File('${dir?.path}/litert_windows.f32');
  if (dir != null && f.existsSync()) {
    final bytes = await f.readAsBytes();
    final all = bytes.buffer.asFloat32List(
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 4,
    );
    final n = all.length ~/ windowSamples;
    _realWindows = true;
    // ignore: avoid_print
    print('loaded $n real windows from ${f.path}');
    return [
      for (var i = 0; i < n; i++)
        Float32List.fromList(
          all.sublist(i * windowSamples, (i + 1) * windowSamples),
        ),
    ];
  }
  // ignore: avoid_print
  print('no ${f.path}; using synthetic noise');
  final rnd = math.Random(1);
  return [
    for (var i = 0; i < 16; i++)
      Float32List.fromList([
        for (var s = 0; s < windowSamples; s++) (rnd.nextDouble() - 0.5) * 0.1,
      ]),
  ];
}

/// Runs [windows] one by one (latency) and in batches of [_batch]
/// (throughput); returns the per-window predictions.
Future<List<List<double>>> _run(
  String label,
  AudioClassifier model,
  List<Float32List> windows,
  int windowSamples,
  List<List<double>>? ref,
  List<Map<String, Object?>> results,
) async {
  // Warm-up.
  await model.predict(windows.first, windowSamples: windowSamples);

  final lat = <double>[];
  final preds = <List<double>>[];
  final stage = <String, double>{};
  for (final w in windows) {
    final sw = Stopwatch()..start();
    final out = await model.predict(w, windowSamples: windowSamples);
    lat.add(sw.elapsedMicroseconds / 1000);
    preds.add(out.predictions);
  }

  final swBatch = Stopwatch()..start();
  for (var i = 0; i < windows.length; i += _batch) {
    await model.predictBatch(
      windows.sublist(i, math.min(i + _batch, windows.length)),
      windowSamples: windowSamples,
    );
  }
  final batchMsPerWindow = swBatch.elapsedMicroseconds / 1000 / windows.length;

  lat.sort();
  if (model is LiteRtClassifierModel) {
    // Native stage split (frontend CPU vs classifier on the accelerator) over
    // one batch call, to separate compute from platform-channel overhead.
    const ch = MethodChannel('com.birdnet/litert');
    final n = math.min(_batch, windows.length);
    final flat = Float32List(n * windowSamples);
    for (var i = 0; i < n; i++) {
      flat.setRange(i * windowSamples, (i + 1) * windowSamples, windows[i]);
    }
    final sw = Stopwatch()..start();
    final raw = await ch.invokeMapMethod<String, Object?>('predict', {
      'audio': flat,
      'batch': n,
    });
    final totalMs = sw.elapsedMicroseconds / 1000 / n;
    final fe = (raw!['frontendUs']! as num) / 1000 / n;
    final cl = (raw['classifierUs']! as num) / 1000 / n;
    stage
      ..['frontendMs'] = fe
      ..['classifierMs'] = cl
      ..['overheadMs'] = totalMs - fe - cl;
  }

  final r = <String, Object?>{
    ...stage,
    'label': label,
    'n': windows.length,
    'meanMs': lat.reduce((a, b) => a + b) / lat.length,
    'p50Ms': lat[lat.length ~/ 2],
    'p95Ms': lat[(lat.length * 0.95).floor().clamp(0, lat.length - 1)],
    'batchMsPerWindow': batchMsPerWindow,
    'realTimeX': 3000 / batchMsPerWindow,
  };
  if (ref != null) r.addAll(_agreement(preds, ref));
  results.add(r);
  return preds;
}

Map<String, Object?> _agreement(List<List<double>> p, List<List<double>> r) {
  var top1 = 0, detRef = 0, detCand = 0, detBoth = 0;
  var maxDiff = 0.0;
  int argmax(List<double> v) {
    var best = 0;
    for (var i = 1; i < v.length; i++) {
      if (v[i] > v[best]) best = i;
    }
    return best;
  }

  for (var w = 0; w < p.length; w++) {
    if (argmax(p[w]) == argmax(r[w])) top1++;
    for (var c = 0; c < p[w].length; c++) {
      final a = p[w][c], b = r[w][c];
      maxDiff = math.max(maxDiff, (a - b).abs());
      final inR = b >= _threshold, inP = a >= _threshold;
      if (inR) detRef++;
      if (inP) detCand++;
      if (inR && inP) detBoth++;
    }
  }
  return {
    'top1Agree': top1 / p.length,
    'maxAbsDiff': maxDiff,
    'detRef': detRef,
    'detCand': detCand,
    'detBoth': detBoth,
  };
}

String _table(List<Map<String, Object?>> results, int n) {
  String f(Object? v, [int d = 1]) => v is num ? v.toStringAsFixed(d) : '–';
  final b = StringBuffer()
    ..writeln('## LiteRT backend comparison ($n windows of 3 s)\n')
    ..writeln(
      '| Backend | mean ms | p95 ms | batch-16 ms/window | × real-time | '
      'frontend / classifier / channel ms | '
      'top-1 vs ONNX | max |Δ| | det ≥0.35 (ONNX → this, both) |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|---|');
  for (final r in results) {
    if (r['error'] != null) {
      b.writeln('| ${r['label']} | failed: ${r['error']} ||||||||');
      continue;
    }
    b.writeln(
      '| ${r['label']} | ${f(r['meanMs'])} | ${f(r['p95Ms'])} | '
      '${f(r['batchMsPerWindow'])} | ${f(r['realTimeX'], 0)} | '
      '${r['frontendMs'] == null ? '–' : '${f(r['frontendMs'])} / ${f(r['classifierMs'])} / ${f(r['overheadMs'])}'} | '
      '${r['top1Agree'] == null ? '–' : '${((r['top1Agree'] as double) * 100).toStringAsFixed(1)} %'} | '
      '${f(r['maxAbsDiff'], 3)} | '
      '${r['detRef'] == null ? '–' : '${r['detRef']} → ${r['detCand']}, ${r['detBoth']}'} |',
    );
  }
  return b.toString();
}
