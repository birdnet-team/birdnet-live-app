// =============================================================================
// ORT Session Options — shared ONNX Runtime session configuration
// =============================================================================
//
// Every ONNX session the app creates goes through [buildOrtSessionOptions] so
// runtime-level safety settings apply to all models at once (audio classifier
// and geo-model alike).
//
// ### KleidiAI kill switch
//
// Starting with ONNX Runtime 1.23, fp32 GEMM and convolution on arm64 are
// routed through Arm KleidiAI SME/SME2 kernels. ORT 1.23.0 faulted inside
// `OrtSession.run` on arm64 Android, which shipped as the 1.0.2 "app closes
// when a recording starts" crash, and 1.24–1.28 carried further KleidiAI
// memory-retention and correctness regressions (microsoft/onnxruntime#29538).
//
// ORT 1.28 added the session config key `mlas.disable_kleidiai`. It is read
// into `MLAS_BACKEND_KERNEL_SELECTOR_CONFIG.use_kleidiai`, which the Conv and
// MatMul kernels and the NHWC graph optimizer all consult, so with it set the
// runtime follows the same NEON MLAS path that ORT 1.22.0 used. Keep it set;
// see docs/developer/onnxruntime-pin.md for the evidence and the re-check
// procedure before changing it.
// =============================================================================

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Session config entries applied to every ONNX session.
///
/// Values are passed verbatim to ONNX Runtime's `AddSessionConfigEntry` on
/// every platform. Runtimes that predate a key accept and ignore it.
const Map<String, String> ortSessionConfigs = {
  // Disable the Arm KleidiAI SME kernels; see the file header.
  'mlas.disable_kleidiai': '1',
};

/// Builds the session options shared by all models.
///
/// [intraOpNumThreads] limits intra-op parallelism when set. When it is
/// `null` the thread pool, inter-op setting, and arena are left at the
/// runtime defaults, matching the behavior before this helper existed.
OrtSessionOptions buildOrtSessionOptions({int? intraOpNumThreads}) {
  return OrtSessionOptions(
    intraOpNumThreads: intraOpNumThreads,
    interOpNumThreads: intraOpNumThreads == null ? null : 1,
    useArena: intraOpNumThreads == null ? null : true,
    sessionConfigs: ortSessionConfigs,
  );
}
