import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/asset_pack_service.dart';
import '../inference/classifier_model.dart';
import '../inference/model_config.dart';
import 'device_stats_service.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class BenchmarkRun {
  const BenchmarkRun({
    required this.provider,
    required this.runs,
    required this.latencies,
    required this.windowSeconds,
    required this.timestamp,
    required this.threads,
    this.stats,
  });

  final String provider;
  final int runs;
  final List<int> latencies; // ms per inference
  final int windowSeconds;
  final DateTime timestamp;
  final int threads; // 0 = auto
  final DeviceStatsDelta? stats;

  int get minMs => latencies.reduce((a, b) => a < b ? a : b);
  int get maxMs => latencies.reduce((a, b) => a > b ? a : b);
  double get avgMs => latencies.fold(0, (a, b) => a + b) / latencies.length;
  double get realtimeFactor => (windowSeconds * 1000) / avgMs;

  String get providerLabel => switch (provider) {
        'accelerated' => 'Accelerated',
        'xnnpack' => 'XNNPACK',
        'nnapi_npu_only' => 'NNAPI NPU-only',
        _ => 'CPU',
      };

  /// True if this run used a mode that forces hardware execution.
  bool get isHardwareForced => provider == 'nnapi_npu_only';
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum _Phase { idle, loadingModel, running, done, error }

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class BenchmarkScreen extends ConsumerStatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  ConsumerState<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends ConsumerState<BenchmarkScreen> {
  _Phase _phase = _Phase.idle;
  String _errorMessage = '';
  String _selectedProvider = 'cpu';
  int _runs = 10;
  int _threads = 0; // 0 = auto
  int _currentRun = 0;

  final List<BenchmarkRun> _history = [];
  List<OrtProvider>? _availableProviders;

  static const _providerLabels = {
    'cpu': 'CPU',
    'xnnpack': 'XNNPACK (optimized CPU)',
    'accelerated': 'Accelerated (NNAPI / CoreML)',
    'nnapi_npu_only': 'NNAPI — NPU only (no CPU fallback)',
  };

  @override
  void initState() {
    super.initState();
    _availableProviders = OrtEnv.instance.availableProviders();
  }

  bool get _acceleratedAvailable {
    final ps = _availableProviders;
    if (ps == null) return false;
    return ps.contains(OrtProvider.nnapi) || ps.contains(OrtProvider.coreml);
  }

  bool _providerSupported(String key) {
    final ps = _availableProviders ?? [];
    return switch (key) {
      'cpu' => true,
      'xnnpack' => ps.contains(OrtProvider.xnnpack),
      'accelerated' => _acceleratedAvailable,
      'nnapi_npu_only' => _acceleratedAvailable,
      _ => false,
    };
  }

  String _supportLabel(String key) {
    if (key == 'cpu') return 'Always available';
    if (key == 'nnapi_npu_only') {
      return _acceleratedAvailable
          ? 'NNAPI required — crashes if model ops unsupported on NPU'
          : 'NNAPI not available on this device';
    }
    if (key == 'xnnpack') {
      final avail = _availableProviders?.contains(OrtProvider.xnnpack) ?? false;
      return avail
          ? 'XNNPACK ✓ — ARM NEON optimized CPU kernels'
          : 'Not reported by runtime';
    }
    if (!_acceleratedAvailable) {
      return Platform.isAndroid
          ? 'NNAPI not reported by runtime'
          : Platform.isIOS
              ? 'CoreML not reported by runtime'
              : 'Not supported on this platform';
    }
    final ps = _availableProviders!;
    return [
      if (ps.contains(OrtProvider.nnapi)) 'NNAPI ✓',
      if (ps.contains(OrtProvider.coreml)) 'CoreML ✓',
    ].join(' · ');
  }

  Future<void> _run() async {
    setState(() {
      _phase = _Phase.loadingModel;
      _currentRun = 0;
    });

    ClassifierModel? model;
    try {
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

      model = ClassifierModel();
      await model.loadModelFromFile(
        modelPath,
        inputName: config.onnx.inputName,
        predictionsName: config.onnx.predictionsName,
        embeddingsName: config.onnx.embeddingsName,
        executionProvider: _selectedProvider,
        intraOpThreads: _threads,
      );

      setState(() => _phase = _Phase.running);

      final windowSeconds = config.inference.defaultWindowSeconds;
      final windowSamples = windowSeconds * config.audio.sampleRate;
      final silence = Float32List(windowSamples);

      // Warm-up (not measured).
      await model.predict(silence, windowSamples: windowSamples);

      // Snapshot before.
      final before = await DeviceStatsService.snapshot();

      final latencies = <int>[];
      for (var i = 0; i < _runs; i++) {
        if (!mounted) break;
        setState(() => _currentRun = i + 1);
        final sw = Stopwatch()..start();
        await model.predict(silence, windowSamples: windowSamples);
        latencies.add(sw.elapsedMilliseconds);
      }

      // Snapshot after.
      final after = await DeviceStatsService.snapshot();
      final stats = DeviceStatsService.delta(before, after);

      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _history.insert(
          0,
          BenchmarkRun(
            provider: _selectedProvider,
            runs: _runs,
            latencies: latencies,
            windowSeconds: windowSeconds,
            timestamp: DateTime.now(),
            threads: _threads,
            stats: stats,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      final msg = _selectedProvider == 'nnapi_npu_only'
          ? 'NPU-only mode failed — the model contains ops not supported by '
              'the hardware accelerator on this device.\n\n$e'
          : e.toString();
      setState(() {
        _phase = _Phase.error;
        _errorMessage = msg;
      });
    } finally {
      await model?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final busy =
        _phase == _Phase.loadingModel || _phase == _Phase.running;

    return Scaffold(
      appBar: AppBar(title: const Text('Inference Benchmark')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Config card ─────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configuration',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _ProviderChips(providers: _availableProviders ?? []),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProvider,
                    decoration: const InputDecoration(
                      labelText: 'Execution Provider',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _providerLabels.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) => setState(() => _selectedProvider = v!),
                  ),
                  const SizedBox(height: 6),
                  _SupportBadge(
                    label: _supportLabel(_selectedProvider),
                    ok: _providerSupported(_selectedProvider),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: Text('Runs: $_runs',
                              style: theme.textTheme.bodyMedium)),
                      Text('(+1 warm-up)',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.outline)),
                    ],
                  ),
                  Slider(
                    value: _runs.toDouble(),
                    min: 5,
                    max: 50,
                    divisions: 9,
                    label: '$_runs',
                    onChanged: busy
                        ? null
                        : (v) => setState(() => _runs = v.toInt()),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Threads: ${_threads == 0 ? 'Auto' : '$_threads'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Slider(
                    value: _threads.toDouble(),
                    min: 0,
                    max: 8,
                    divisions: 8,
                    label: _threads == 0 ? 'Auto' : '$_threads',
                    onChanged: busy
                        ? null
                        : (v) => setState(() => _threads = v.toInt()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Run button ──────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: busy ? null : _run,
            icon: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onPrimary))
                : const Icon(Icons.speed),
            label: Text(busy ? _progressLabel() : 'Run Benchmark'),
          ),

          // ── Error ───────────────────────────────────────────────────────
          if (_phase == _Phase.error) ...[
            const SizedBox(height: 12),
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_errorMessage,
                    style: TextStyle(color: cs.onErrorContainer)),
              ),
            ),
          ],

          // ── Progress ────────────────────────────────────────────────────
          if (_phase == _Phase.running) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(value: _currentRun / _runs),
            const SizedBox(height: 6),
            Center(
                child: Text('Run $_currentRun of $_runs',
                    style: theme.textTheme.bodySmall)),
          ],

          // ── History ─────────────────────────────────────────────────────
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Results',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_history.length > 1)
                  TextButton(
                    onPressed: () => setState(() => _history.clear()),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ..._history.map((r) => _RunCard(run: r)),
          ],
        ],
      ),
    );
  }

  String _progressLabel() {
    if (_phase == _Phase.loadingModel) return 'Loading model…';
    return 'Run $_currentRun / $_runs';
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _ProviderChips extends StatelessWidget {
  const _ProviderChips({required this.providers});

  final List<OrtProvider> providers;

  static String _label(OrtProvider p) => switch (p) {
        OrtProvider.cpu => 'CPU',
        OrtProvider.nnapi => 'NNAPI',
        OrtProvider.coreml => 'CoreML',
        OrtProvider.cuda => 'CUDA',
        OrtProvider.rocm => 'ROCm',
        OrtProvider.directml => 'DirectML',
        OrtProvider.tensorrt => 'TensorRT',
        OrtProvider.openvino => 'OpenVINO',
        OrtProvider.dnnl => 'DNNL',
        OrtProvider.xnnpack => 'XNNPACK',
        OrtProvider.qnn => 'QNN',
        OrtProvider.cann => 'CANN',
        OrtProvider.migraphx => 'MIGraphX',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Available: ',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
        ...providers.map((p) => Chip(
              label: Text(_label(p), style: theme.textTheme.labelSmall),
              backgroundColor: cs.secondaryContainer,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )),
      ],
    );
  }
}

class _SupportBadge extends StatelessWidget {
  const _SupportBadge({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = ok ? cs.primary : cs.error;
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});

  final BenchmarkRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final stats = run.stats;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.speed, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    run.providerLabel,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (run.isHardwareForced)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'HW confirmed',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onPrimaryContainer),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  _timeLabel(run.timestamp),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.outline),
                ),
              ],
            ),
            Text(
              '${run.runs} runs · ${run.windowSeconds}s window · '
              '${run.threads == 0 ? 'auto' : '${run.threads}'} threads',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
            ),
            const Divider(height: 20),

            // Latency
            _Row('Avg latency', '${run.avgMs.toStringAsFixed(1)} ms',
                highlight: true, theme: theme, cs: cs),
            _Row('Min / Max',
                '${run.minMs} ms / ${run.maxMs} ms',
                theme: theme, cs: cs),
            _Row('Real-time factor',
                '${run.realtimeFactor.toStringAsFixed(1)}×',
                highlight: true, theme: theme, cs: cs),

            // Device stats (if available)
            if (stats != null) ...[
              const Divider(height: 20),
              if (stats.socModel != null)
                _Row('SoC', stats.socModel!, theme: theme, cs: cs),
              if (stats.cpuUsagePercent != null)
                _Row('CPU usage',
                    '${stats.cpuUsagePercent!.toStringAsFixed(1)} %',
                    theme: theme, cs: cs),
              if (stats.avgCurrentUa != null)
                _Row('Avg current',
                    '${(stats.avgCurrentUa! / 1000).toStringAsFixed(1)} mA',
                    theme: theme, cs: cs),
              if (stats.avgPowerMw != null)
                _Row('Avg power',
                    '${stats.avgPowerMw!.toStringAsFixed(0)} mW',
                    highlight: true, theme: theme, cs: cs),
              if (stats.thermalStatus != null && stats.thermalStatus! >= 0)
                _Row('Thermal', stats.thermalLabel,
                    theme: theme,
                    cs: cs,
                    valueColor: _thermalColor(cs, stats.thermalStatus!)),
              if (stats.batteryLevel != null)
                _Row('Battery level', '${stats.batteryLevel} %',
                    theme: theme, cs: cs),
            ],
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color? _thermalColor(ColorScheme cs, int status) {
    if (status <= 1) return cs.primary;
    if (status == 2) return Colors.orange;
    return cs.error;
  }
}

class _Row extends StatelessWidget {
  const _Row(
    this.label,
    this.value, {
    this.highlight = false,
    this.valueColor,
    required this.theme,
    required this.cs,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color? valueColor;
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: highlight
                  ? theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)
                  : theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: highlight
                ? theme.textTheme.titleSmall?.copyWith(
                    color: valueColor ?? cs.primary,
                    fontWeight: FontWeight.bold)
                : theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
          ),
        ],
      ),
    );
  }
}
