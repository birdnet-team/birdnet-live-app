# Model Export Checklist

What the app needs from the next ONNX model export, and why. Measured on a
Pixel 10 Pro with ONNX Runtime 1.28 during the #76 follow-up (October 2026);
the scripts and raw numbers live in `dev/optimize/inference_speed/` on the
`inference-speed` branch.

The current preview model (`BirdNET+_V3.0-preview3.1_Global_10K-pruned_FP16.onnx`)
runs Batch Analysis at about 53x real-time on that phone. Two graph-level
changes, applied with scripts to the shipped file, reach 84x with identical
top-1 results. Both should be baked into the export of the final V3.0 model
instead of patched in afterwards.

## 1. No `STFT` node

ONNX Runtime's CPU `STFT` kernel is a scalar, single-threaded DFT. For
3 s windows at batch 4 it costs 31 ms of a 242 ms run, more than any single
convolution.

Replace it with a factorized DFT built from standard ops: frame the padded
signal with `Gather`, multiply by the window, reshape each 2048-sample frame to
32 x 64, and apply two complex DFT stages as `MatMul` with constant matrices
plus a twiddle `Mul`. This is a textbook Cooley-Tukey split, runs on the
multithreaded sgemm path, and is bit-exact against the `STFT` output. Cost at
batch 4: about 9 ms. Reference implementation: `make_fft_variant.py`.

A separate "preprocessing" model with a spectrogram input would also work, but
it pushes the framing problem into every platform of the app (Android, iOS,
Windows). One self-contained ONNX file is preferred.

## 2. fp16 only inside convolutions

ONNX Runtime on arm64 has fast fp16 NHWC convolution kernels, 2.3x faster than
fp32 for this backbone. It has **no** vectorized fp16 kernels for the
elementwise ops: the `x * sigmoid(x)` SiLU in fp16 runs at about 1 Gelem/s and,
together with the casts ORT inserts, costs more than the convolutions
themselves.

Export the graph with fp32 activations and fp16 convolution weights, with an
explicit `Cast` to fp16 on each convolution input and a `Cast` back to fp32 on
its output. ORT then fuses the fp32 SiLU into a vectorized `QuickGelu` and keeps
the convolutions on the fp16 kernels. Reference: `make_mixed_variant.py`,
applied to the all-fp32 graph.

Check the fp16 convolution outputs for overflow. The model-converter notes that
some stage-5 expansion convolutions exceed the fp16 range before BatchNorm
folding; the exporter already folds those for its TorchScript fp16 path and the
same folding must be applied here. The test clip used so far showed no
overflow, but it is one clip.

## 3. Still open: INT8

INT8 convolutions are 2x faster than fp16 again. An INT8 graph with the two
changes above and the depthwise convolutions and classifier head kept in float
runs at 108x on the Pixel 10 Pro. Post-training quantization of the shipped
model only reaches 0.77 to 0.89 top-1 agreement, so this needs
quantization-aware training on the model side. Tracked in the model-converter
repository.

## Verifying a new export

1. `python dev/optimize/inference_speed/compare_models.py <reference.onnx> <audio.wav> <candidate.onnx>` reports top-1 agreement and score deltas on 100 windows.
2. The standalone bench app in `dev/optimize/inference_speed/bench_app/` sweeps threads, batch sizes and execution providers on a device and can dump ORT profiles.
3. Six intra-op threads and batch 4 were the best settings for the mixed-precision graph; the shipped model prefers 5 threads.
