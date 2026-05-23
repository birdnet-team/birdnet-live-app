// =============================================================================
// On-Device Inference Benchmark
// =============================================================================
//
// Runs the ONNX model with every combination of execution provider and thread
// count on the connected device and prints a Markdown result table.
//
// Usage:
//   flutter test integration_test/inference_benchmark_test.dart \
//     --no-pub --device-id <device-id>
//
// Optional env vars:
//   BENCHMARK_RUNS   Number of measured runs per configuration (default: 10)
//   BENCHMARK_WARMUP Number of warm-up runs discarded (default: 2)
//
// Results are printed to stdout AND reported via IntegrationTestBinding so
// they appear in the JSON output when captured with --reporter json.
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/core/services/asset_pack_service.dart';
import 'package:birdnet_live/features/benchmark/device_stats_service.dart';
import 'package:birdnet_live/features/inference/classifier_model.dart';
import 'package:birdnet_live/features/inference/model_config.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const _defaultRuns = 10;
const _defaultWarmup = 2;
const _defaultBatches = 1;
const _defaultPauseSeconds = 30;

/// Number of high-performance cores to sweep (default 4 = 1×X4 + 3×A720 on
/// Pixel 9 Pro). Override via BENCHMARK_BIG_CORES env var.
const _defaultBigCores = 4;

/// Build the benchmark matrix at runtime so the CPU thread sweep is
/// always 1..bigCores, labelled "1 Thread", "2 Threads", etc.
List<_Config> _buildMatrix(int bigCores) => [
      for (var t = 1; t <= bigCores; t++)
        _Config('CPU ${t}T', 'cpu', t),
      _Config('XNNPACK', 'xnnpack', 0),
      _Config('Accelerated', 'accelerated', 0),
      _Config('NPU-only', 'nnapi_npu_only', 0),
    ];

class _Config {
  const _Config(this.label, this.provider, this.threads);
  final String label;
  final String provider;
  final int threads;
}

// ---------------------------------------------------------------------------
// Result
// ---------------------------------------------------------------------------

class _Result {
  _Result({
    required this.config,
    required this.latencies,
    required this.windowSeconds,
    required this.batch,
    this.stats,
    this.error,
  });

  final _Config config;
  final List<int> latencies;
  final int windowSeconds;
  final int batch;
  final DeviceStatsDelta? stats;
  final String? error;

  bool get ok => error == null && latencies.isNotEmpty;

  double get avgMs =>
      latencies.fold(0, (a, b) => a + b) / latencies.length;
  int get minMs => latencies.reduce((a, b) => a < b ? a : b);
  int get maxMs => latencies.reduce((a, b) => a > b ? a : b);
  double get realtimeFactor => (windowSeconds * 1000) / avgMs;
}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  int topLevelBatches = _defaultBatches;
  try {
    final f = File('/data/local/tmp/benchmark_config.json');
    if (f.existsSync()) {
      final c = json.decode(f.readAsStringSync()) as Map<String, dynamic>;
      topLevelBatches = (c['batches'] as int?) ?? _defaultBatches;
    }
  } catch (_) {}

  testWidgets('Inference benchmark matrix', (tester) async {
    OrtEnv.instance.init();

    // Read config from file written by the Python script via ADB.
    // Platform.environment is empty inside the Android sandbox, so env vars
    // from the host never reach the app — a config file is the reliable path.
    Map<String, dynamic> cfg = {};
    try {
      final cfgFile = File('/data/local/tmp/benchmark_config.json');
      if (cfgFile.existsSync()) {
        cfg = json.decode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
      }
    } catch (_) {}

    final runs         = (cfg['runs']         as int?) ?? _defaultRuns;
    final warmup       = (cfg['warmup']        as int?) ?? _defaultWarmup;
    final bigCores     = (cfg['bigCores']      as int?) ?? _defaultBigCores;
    final batches      = (cfg['batches']       as int?) ?? _defaultBatches;
    final pauseSeconds = (cfg['pauseSeconds']  as int?) ?? _defaultPauseSeconds;
    final randomize    = (cfg['randomize']     as bool?) ?? true;

    final matrix = _buildMatrix(bigCores);

    // Load model config.
    final configJson =
        await rootBundle.loadString(AppConstants.modelConfigAssetPath);
    final config = ModelConfig.fromJson(
      (json.decode(configJson) as Map<String, dynamic>)['audioModel']
          as Map<String, dynamic>,
    );
    final modelPath = await AssetPackService.resolveModelPath(
      fileName: config.onnx.modelFile,
      version: config.version,
    );

    final windowSeconds = config.inference.defaultWindowSeconds;
    final windowSamples = windowSeconds * config.audio.sampleRate;
    final silence = Float32List(windowSamples);

    // Query available providers once.
    final available = OrtEnv.instance.availableProviders();
    _log('Available providers: ${available.map((p) => p.name).join(', ')}');
    _log('Runs: $runs  Warm-up: $warmup  Batches: $batches'
        '  Pause: ${pauseSeconds}s  Randomize: $randomize'
        '  Window: ${windowSeconds}s\n');

    final rng = Random();
    final results = <_Result>[];

    for (var batch = 1; batch <= batches; batch++) {
      if (batch > 1) {
        _log('BATCH_PAUSE:$pauseSeconds');
        _log('Cooling down ${pauseSeconds}s before batch $batch/$batches...');
        // Use Future.delayed for a real wall-clock pause (not simulated time).
        await Future.delayed(Duration(seconds: pauseSeconds));
      }
      _log('BATCH_START:$batch');

      // Randomise config order each batch to avoid ordering bias.
      final batchConfigs = [...matrix];
      if (randomize) batchConfigs.shuffle(rng);

    for (final cfg in batchConfigs) {
      _log('▶ ${cfg.label} (provider=${cfg.provider}, threads=${cfg.threads == 0 ? 'auto' : cfg.threads})');

      ClassifierModel? model;
      try {
        model = ClassifierModel();
        await model.loadModelFromFile(
          modelPath,
          inputName: config.onnx.inputName,
          predictionsName: config.onnx.predictionsName,
          embeddingsName: config.onnx.embeddingsName,
          executionProvider: cfg.provider,
          intraOpThreads: cfg.threads,
        );

        // Warm-up runs (model loading done, now signal Python to start Perfetto).
        for (var i = 0; i < warmup; i++) {
          await model.predict(silence, windowSamples: windowSamples);
        }
        _log('BENCHMARK_START:${cfg.label}:$batch');

        final before = await DeviceStatsService.snapshot();
        final latencies = <int>[];

        for (var i = 0; i < runs; i++) {
          final sw = Stopwatch()..start();
          await model.predict(silence, windowSamples: windowSamples);
          latencies.add(sw.elapsedMilliseconds);
          // Yield to let the OS breathe between runs.
          await tester.pump(const Duration(milliseconds: 10));
        }

        final after = await DeviceStatsService.snapshot();
        final stats = DeviceStatsService.delta(before, after);

        results.add(_Result(
          config: cfg,
          latencies: latencies,
          windowSeconds: windowSeconds,
          batch: batch,
          stats: stats,
        ));
        _log('  ✓ avg=${_avg(latencies).toStringAsFixed(0)}ms');
        _log('BENCHMARK_END:${cfg.label}:$batch');
      } catch (e) {
        _log('BENCHMARK_END:${cfg.label}:$batch');
        results.add(_Result(
          config: cfg,
          latencies: const [],
          windowSeconds: windowSeconds,
          batch: batch,
          error: e.toString().split('\n').first,
        ));
        _log('  ✗ $e');
      } finally {
        await model?.dispose();
        // Small gap between sessions.
        await tester.pump(const Duration(milliseconds: 500));
      }
    } // end cfg loop

    _log('BATCH_END:$batch');
  } // end batch loop

    // Print result table.
    final table = _buildTable(results, runs, warmup);
    _log('\n$table');

    // Report structured data back to host.
    binding.reportData = {
      'benchmark': results.map((r) => _resultToMap(r)).toList(),
      'table': table,
      'device': results.firstWhere((r) => r.stats?.socModel != null,
              orElse: () => results.first)
          .stats
          ?.socModel ??
          'unknown',
    };
  }, timeout: Timeout(Duration(minutes: 15 * topLevelBatches)));
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _log(String msg) {
  // ignore: avoid_print
  print(msg);
}

double _avg(List<int> xs) => xs.fold(0, (a, b) => a + b) / xs.length;

String _buildTable(List<_Result> results, int runs, int warmup) {
  final buf = StringBuffer();
  final now = DateTime.now();
  buf.writeln('## Inference Benchmark');
  buf.writeln('${now.year}-${_pad(now.month)}-${_pad(now.day)} '
      '${_pad(now.hour)}:${_pad(now.minute)}  '
      '· $runs runs + $warmup warm-up  '
      '· window=${results.first.windowSeconds}s @ 32 kHz');
  buf.writeln();

  // Find CPU baseline for relative column.
  final baseline = results
      .where((r) => r.config.provider == 'cpu' && r.config.threads == 0 && r.ok)
      .firstOrNull;

  buf.writeln(
    '| Configuration   | Avg (ms) | Min | Max | RT factor | vs CPU   | Power (mW) | Thermal |',
  );
  buf.writeln(
    '|:----------------|:--------:|:---:|:---:|:---------:|:--------:|:----------:|:-------:|',
  );

  for (final r in results) {
    if (!r.ok) {
      buf.writeln(
        '| ${r.config.label.padRight(15)} | ❌ ${_truncate(r.error ?? 'error', 38)} |||||||',
      );
      continue;
    }

    final rel = baseline != null
        ? '${(baseline.avgMs / r.avgMs * 100).round()}%'
        : '—';
    final power = r.stats?.avgPowerMw != null
        ? r.stats!.avgPowerMw!.toStringAsFixed(0)
        : '—';
    final thermal = r.stats?.thermalTrendLabel ?? '—';

    buf.writeln(
      '| ${r.config.label.padRight(15)} '
      '| ${r.avgMs.toStringAsFixed(1).padLeft(8)} '
      '| ${r.minMs.toString().padLeft(3)} '
      '| ${r.maxMs.toString().padLeft(3)} '
      '| ${r.realtimeFactor.toStringAsFixed(1).padLeft(9)}× '
      '| ${rel.padLeft(8)} '
      '| ${power.padLeft(10)} '
      '| ${thermal.padLeft(7)} |',
    );
  }

  return buf.toString();
}

String _pad(int n) => n.toString().padLeft(2, '0');

String _truncate(String s, int max) =>
    s.length > max ? '${s.substring(0, max - 1)}…' : s;

Map<String, dynamic> _resultToMap(_Result r) => {
      'label': r.config.label,
      'provider': r.config.provider,
      'threads': r.config.threads,
      'batch': r.batch,
      if (r.ok) ...{
        'avg_ms': r.avgMs,
        'min_ms': r.minMs,
        'max_ms': r.maxMs,
        'realtime_factor': r.realtimeFactor,
        'power_mw': r.stats?.avgPowerMw,
        'cpu_pct': r.stats?.cpuUsagePercent,
        'thermal': r.stats?.thermalTrendLabel,
        'soc': r.stats?.socModel,
      },
      if (!r.ok) 'error': r.error,
    };
