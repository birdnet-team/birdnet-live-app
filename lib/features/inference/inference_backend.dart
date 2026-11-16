// =============================================================================
// Inference Backend — which runtime and accelerator runs the audio classifier
// =============================================================================
//
// `onnx` is the default and the only backend on iOS / desktop. The LiteRT
// backends are experimental and Android-only (see LiteRtChannel.kt):
//
// | Setting | Classifier runs on                                               |
// |---------|------------------------------------------------------------------|
// | onnx    | ONNX Runtime, CPU                                                |
// | auto    | LiteRT: Edge TPU for file analysis, GPU for live / survey modes  |
// | tpu     | LiteRT: Edge TPU via NNAPI (`google-edgetpu`, fp16)              |
// | gpu     | LiteRT: GPU delegate (fp16)                                      |
// | cpu     | LiteRT: XNNPACK, 4 threads                                       |
//
// Why `auto` splits by mode: File Analysis wants throughput, where the Edge TPU
// is fastest (about 3x ONNX). Live modes run one window per second, where
// preliminary power readings on a Pixel 9 Pro favoured the GPU, because the
// TPU powers up for every call. Those readings still need a reliable re-run;
// see "Preliminary: power" in research/edge-tpu-v3/README.md.
//
// Every LiteRT choice falls back (tpu -> gpu -> cpu natively, then to ONNX in
// Dart) when the device lacks the accelerator or the model has no LiteRT build.
// =============================================================================

import 'dart:io';

/// What the inference will be used for; picks the accelerator for `auto`.
enum InferenceWorkload {
  /// One window at a time, paced by the microphone (Live, Survey, Point Count).
  realtime,

  /// As fast as possible over stored audio (File Analysis).
  batch,
}

abstract final class InferenceBackends {
  static const String onnx = 'onnx';
  static const String auto = 'auto';
  static const String tpu = 'tpu';
  static const String gpu = 'gpu';
  static const String cpu = 'cpu';

  static const List<String> all = [onnx, auto, tpu, gpu, cpu];

  /// Whether the LiteRT backends can run on this platform at all.
  static bool get liteRtSupported => Platform.isAndroid;

  /// LiteRT accelerator for [setting] and [workload], or `null` for ONNX.
  static String? liteRtAccelerator(String setting, InferenceWorkload workload) {
    if (!liteRtSupported) return null;
    return switch (setting) {
      auto => workload == InferenceWorkload.batch ? tpu : gpu,
      tpu || gpu || cpu => setting,
      _ => null,
    };
  }
}
