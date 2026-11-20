// =============================================================================
// LiteRT Classifier Model — experimental Edge TPU / GPU backend (Android)
// =============================================================================
//
// Dart half of the `com.birdnet/litert` channel (LiteRtChannel.kt). The native
// side chains two LiteRT graphs per window: the spectrogram frontend on the
// CPU and the classifier on the requested accelerator. Audio and scores cross
// the channel as Float32List (StandardMessageCodec maps them to FloatArray).
//
// The graphs have fixed shapes: only windows of [windowSamples] are accepted.
// [InferenceService] keeps ONNX for other window lengths.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_classifier.dart';
import 'classifier_model.dart';

/// Result of [LiteRtClassifierModel.load].
class LiteRtLoadInfo {
  const LiteRtLoadInfo({
    required this.accelerator,
    required this.requested,
    required this.loadMs,
    required this.windowSamples,
  });

  /// Accelerator actually in use (`tpu`, `gpu` or `cpu`).
  final String accelerator;

  /// Accelerator that was asked for; differs from [accelerator] after a
  /// native fallback.
  final String requested;

  /// Load + compile + warm-up time. The first TPU load compiles the model
  /// (seconds); later loads read the NNAPI compilation cache.
  final int loadMs;

  /// Window length the graphs were exported for.
  final int windowSamples;
}

class LiteRtClassifierModel implements AudioClassifier {
  static const MethodChannel _channel = MethodChannel('com.birdnet/litert');

  LiteRtLoadInfo? _info;

  /// Load info, or `null` before [load].
  LiteRtLoadInfo? get info => _info;

  @override
  bool get isLoaded => _info != null;

  /// Window length the loaded graphs accept, or 0 before [load].
  int get windowSamples => _info?.windowSamples ?? 0;

  /// Load the frontend and classifier graphs and run one warm-up window.
  ///
  /// [accelerator] is `tpu`, `gpu` or `cpu`. Throws [PlatformException] if no
  /// accelerator (not even the CPU) can run the model.
  Future<LiteRtLoadInfo> load({
    required String frontendPath,
    required String classifierPath,
    required String accelerator,
    bool lowPower = false,
  }) async {
    final raw = await _channel.invokeMapMethod<String, Object?>('load', {
      'frontendPath': frontendPath,
      'classifierPath': classifierPath,
      'accelerator': accelerator,
      'lowPower': lowPower,
    });
    final info = LiteRtLoadInfo(
      accelerator: raw!['accelerator']! as String,
      requested: raw['requested']! as String,
      loadMs: (raw['loadMs']! as num).toInt(),
      windowSamples: (raw['windowSamples']! as num).toInt(),
    );
    _info = info;
    debugPrint(
      '[LiteRtClassifierModel] ready on ${info.accelerator} '
      '(requested ${info.requested}) in ${info.loadMs} ms',
    );
    return info;
  }

  @override
  Future<ModelOutput> predict(
    Float32List audioSamples, {
    required int windowSamples,
  }) async =>
      (await predictBatch([audioSamples], windowSamples: windowSamples)).single;

  @override
  Future<List<ModelOutput>> predictBatch(
    List<Float32List> audioWindows, {
    required int windowSamples,
  }) async {
    final info = _info;
    if (info == null) throw StateError('LiteRT model not loaded');
    if (windowSamples != info.windowSamples) {
      throw UnsupportedError(
        'LiteRT graphs take ${info.windowSamples} samples, got $windowSamples',
      );
    }
    if (audioWindows.isEmpty) {
      throw ArgumentError.value(audioWindows, 'audioWindows', 'empty');
    }
    final input = Float32List(audioWindows.length * windowSamples);
    for (var b = 0; b < audioWindows.length; b++) {
      input.setRange(
        b * windowSamples,
        (b + 1) * windowSamples,
        prepareWindow(audioWindows[b], windowSamples),
      );
    }
    final raw = await _channel.invokeMapMethod<String, Object?>('predict', {
      'audio': input,
      'batch': audioWindows.length,
    });
    final emb = raw!['embeddings'] as Float32List?;
    return ModelOutput.splitBatch(
      predictions: raw['predictions']! as Float32List,
      embeddings: emb == null || emb.isEmpty ? null : emb,
      batchSize: audioWindows.length,
    );
  }

  @override
  Future<void> dispose() async {
    if (_info == null) return;
    _info = null;
    try {
      await _channel.invokeMethod<void>('close');
    } on MissingPluginException {
      // Engine already detached.
    }
  }

  /// Zero-pad or truncate to [windowSamples] and clamp to [-1, 1], exactly
  /// like the ONNX path.
  @visibleForTesting
  static Float32List prepareWindow(Float32List audio, int windowSamples) {
    if (audio.length == windowSamples) return audio;
    final out = Float32List(windowSamples);
    final n = audio.length < windowSamples ? audio.length : windowSamples;
    for (var i = 0; i < n; i++) {
      out[i] = audio[i].clamp(-1.0, 1.0);
    }
    return out;
  }
}
