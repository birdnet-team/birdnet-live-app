# Inference speed exploration (Batch Analysis target: 100x real-time)

Working notes for #76 follow-up, measured 2026-10-30 on a Pixel 10 Pro (Tensor G5,
8 cores: 2x A520 @2.25 GHz, 5x A725 @3.05 GHz, 1x X4 @3.78 GHz), ONNX Runtime
1.28.0 (same build as `flutter_onnxruntime` 1.9.0), `mlas.disable_kleidiai=1`.

Numbers are model time only (no decode, no post-processing), 3 s windows,
random audio, 8-10 timed runs after warm-up. "RT" = seconds of audio per
wall-second. Everything here is reproducible with the scripts in this folder;
nothing has been wired into the app yet.

## Baseline (shipped FP16 model, `assets/models/*_10K-pruned_FP16.onnx`)

| threads | batch 1 | batch 4 | batch 8 |
| ------- | ------- | ------- | ------- |
| 4       | 41x     | 48x     | 47x     |
| 5       | 43x     | **53x** | 53x     |
| 8       | 30x     | 45x     | 44x     |

5 threads (the current Android file-analysis setting) and batch 4 are already
the sweet spot. 8 threads drags the little cores in and is slower.

## Where the time goes (on-device ORT profile, 5T, batch 4, 242 ms)

| op                            | ms  | share | note |
| ----------------------------- | --- | ----- | ---- |
| NhwcFusedConv (fp16)          | 75  | 32%   | the actual conv work; fp16 NHWC MLAS kernels **are** used on arm64 |
| Mul (fp16)                    | 65  | 28%   | the `x * sigmoid(x)` SiLU, scalar MLFloat16 path, ~1 Gelem/s |
| STFT                          | 31  | 13%   | ORT's STFT kernel is a scalar, single-threaded DFT |
| Sigmoid (fp16)                | 17  | 7%    | same slow fp16 elementwise path |
| Cast                          | 15  | 6%    | 277 casts inserted by ORT around ops with no fp16 kernel |
| Transpose                     | 8   | 3%    | NHWC<->NCHW around non-conv ops |
| Conv (fp16, depthwise)        | 9   | 4%    | |

Only ~35% of the time is convolution. The fp16 graph wins on conv speed
(fp32 convs take 196 ms for the same work) but loses it all again on the
elementwise ops, which have no vectorized fp16 kernels in ORT's CPU EP.

## Variants tried

All variants are generated from the shipped model (same species set) and
checked on 100 windows of `dev/optimize/XC561949 - Soundscape.wav` (offset
from the calibration windows). "top-1" = fraction of windows whose argmax
matches the shipped model.

| variant | how | 5T b4 | best | top-1 | verdict |
| ------- | --- | ----- | ---- | ----- | ------- |
| v0 fp16 (shipped) | - | 53x | 53x | 1.000 | baseline |
| v1 fp32 everywhere | `make_variants.py` | 46x | 48x (5T b1) | 1.000 | convs 2.3x slower than fp16 |
| v2 fixed 96000-sample input | `make_variants.py` | 53x | | 1.000 | no gain, shape ops are free |
| v6 drop SE casts | `make_variants.py` | 54x | | 1.000 | noise |
| XNNPACK EP (fp32) | bench app | 33x | | | slower than MLAS |
| NNAPI EP (fp16 / fp32) | bench app | 41x / 37x (b1) | | | deprecated, no gain |
| WebGPU EP (Vulkan, in the 1.28 AAR) | `make_webgpu_variant.py` + bench app | 10-13x | | 1.000 | GPU path works after rewriting `Pow`, but is 5x slower than CPU on this SoC |
| v8 STFT -> factorized DFT | `make_fft_variant.py` | 58x | | 1.000 (bit-exact) | -22 ms at b4 |
| v9 convs fp16, rest fp32 | `make_mixed_variant.py` | 67x | | 1.000 | kills the fp16 Mul/Sigmoid path |
| **v11 = v8 + v9** | both scripts | **79x** | **84x (6T b4)** | 1.000 | 143 ms per 4 windows |
| v12 = v11 without QuickGelu fusion | `make_nofuse_variant.py` | | 80x (6T b4) | 1.000 | transposes gone, no net gain |
| v7 naive INT8 QDQ (STFT kept) | `quantize_int8.py` | 86x | 93x (6T b4) | 0.71 | fast, wrong |
| v7x INT8, depthwise convs kept float | `quantize_int8.py ... dw` | | | 0.89 | depthwise convs are the quantization-sensitive part |
| v7x INT8, head Gemm kept float | `quantize_int8.py ... head` | | | 0.84 | |
| v7c INT8 with SiLU in int8 (percentile) | `quantize_int8.py percentile Sigmoid,Mul` | | | 0.86 | |
| v7e INT8 + FFT rewrite, depthwise + head float, percentile | `quantize_int8.py ... percentile "" 64 dw_head` | | **108x (6T b4)** | 0.77 | percentile calibration hurts here |
| v7f as v7e plus SE float | `... dw_head_se` | | 102x (6T b4) | 0.76 | |
| v7g as v7e with min-max calibration | `... minmax "" 64 dw_head` | | (same graph as v7e) | 0.83 | PTQ results swing 0.77-0.89 with calibration choices; not shippable without QAT |

Thread affinity pinning (`session.intra_op_thread_affinities`) and
`allow_spinning=0` were both slower than the defaults; 6 threads is marginally
better than 5 for the mixed variant, 7+ is worse.

## What v11 still spends (6T b4, profiled run)

| op | ms | share |
| -- | -- | ----- |
| NhwcFusedConv + Conv | 93 | 50% |
| QuickGelu (fp32 SiLU, fused by ORT) | 22 | 12% |
| Transpose | 21 | 11% |
| Cast | 19 | 10% |
| Add / MatMul (DFT) / Mul / misc | 30 | 17% |

The Transposes exist because ORT's transpose optimizer pushes NHWC<->NCHW
transposes through `Cast` and `Add` but not through the fused `QuickGelu`,
so each SiLU keeps a transpose pair. `make_nofuse_variant.py` defeats that
fusion with an `Add(x, 0)` in front of the Sigmoid; the transposes disappear
but the extra pass plus the unfused Sigmoid+Mul cost the same (80x vs 84x), so
it is not a win. Only a layout-agnostic fused SiLU would be.

## Takeaways

1. Two graph-only changes (no runtime, no plugin, no retraining) take the
   shipped model from 53x to ~80x: replace the STFT node with MatMul-based
   DFT stages and keep only the convolutions in fp16. Both are bit-for-bit
   or within 1e-2 of the shipped scores and stay single cross-platform ONNX
   files.
2. The remaining gap to 100x is glue (casts, transposes, SiLU) around fp16
   convolutions. Options: author the graph NHWC-native (contrib `NhwcConv`
   is present in the arm64 build but untested), or a tiny custom fp16 SiLU
   op (needs `registerCustomOpLibrary`, which `flutter_onnxruntime` does not
   expose; would be an upstream PR).
3. INT8 convolutions are ~2x faster than fp16 again (40 ms vs 84 ms for all
   convs at b4). The INT8 graph with the FFT rewrite and depthwise/head layers
   in float already runs at **108x** on the Pixel 10 Pro, so a QAT INT8 export
   of the backbone is the path to and past 100x. Post-training quantization of this
   EfficientNetV2-S backbone loses accuracy mainly in the depthwise convs and
   the 9.8K-class head; keeping those in float recovers most of it.
4. GPU (WebGPU EP) and NNAPI are not worth pursuing on Tensor G5.

## Files

- `bench_app/` - standalone Android app (Java, ORT Java API) that sweeps
  models x threads x batch x providers with optional ORT profiling and
  optimized-graph dumps. Build with the repo's Gradle wrapper and a JDK 17
  (`JAVA_HOME` to Android Studio's `jbr`). Models go to
  `/sdcard/Android/data/org.birdnet.ortbench/files/`; drive it with `bench.sh`.
- `make_variants.py` - fp32 / static-shape / cast-stripped / split variants.
- `make_fft_variant.py` - STFT -> 32x64 Cooley-Tukey DFT as MatMuls.
- `make_mixed_variant.py` - fp16 convs inside an fp32 graph (input: the fp32 variant).
- `make_webgpu_variant.py` - `Pow` rewrite the WebGPU EP needs.
- `make_nofuse_variant.py` - defeats QuickGelu fusion (transpose experiment).
- `quantize_int8.py` - static QDQ quantization with layer-group exclusions.
- `compare_models.py` - top-1 agreement and score deltas on real audio.
- `analyze_profile.py` - per-op summary of an ORT profile JSON.

Push from Git Bash needs `MSYS_NO_PATHCONV=1` and Windows-style source paths.
