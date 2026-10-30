"""Static INT8 (QDQ) quantization of the fp32 variant for ARM64 speed tests.

Usage: python -I quantize_int8.py <v1_fp32.onnx> <calib.wav> <out.onnx> [per_channel=1]
"""
import sys, wave, numpy as np, onnx
from onnx import numpy_helper
from onnxruntime.quantization import quantize_static, QuantFormat, QuantType, CalibrationDataReader, CalibrationMethod
from onnxruntime.quantization.shape_inference import quant_pre_process

src, wav_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
per_channel = True
method = sys.argv[4] if len(sys.argv) > 4 else "minmax"
extra_ops = sys.argv[5].split(",") if len(sys.argv) > 5 and sys.argv[5] else []
n_win = int(sys.argv[6]) if len(sys.argv) > 6 else 48
group = sys.argv[7] if len(sys.argv) > 7 else ""

with wave.open(wav_path) as w:
    assert w.getframerate() == 32000 and w.getnchannels() == 1 and w.getsampwidth() == 2, (w.getframerate(), w.getnchannels())
    pcm = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
starts = np.linspace(0, len(pcm) - 96000, n_win).astype(int)
windows = [pcm[s:s + 96000][None] for s in starts]


class Reader(CalibrationDataReader):
    def __init__(self):
        self.it = iter(windows)
    def get_next(self):
        x = next(self.it, None)
        return None if x is None else {"input": x}


m = onnx.load(src)
inits = {t.name: t for t in m.graph.initializer}
exclude = []
for n in m.graph.node:
    if n.op_type == "MatMul":
        w = inits.get(n.input[1])
        if w is not None and list(w.dims) == [1025, 128]:
            exclude.append(n.name)
convs = [n for n in m.graph.node if n.op_type == "Conv"]
for i, n in enumerate(convs):
    w = inits[n.input[1]]; cout, cin, kh, kw = w.dims
    is_stem = cin == 3
    is_dw = cin == 1 and kh == 3
    is_se = kh == 1 and (cout <= 64 or cin <= 64) and not is_stem
    is_early = i < 12
    if (group == "stem" and is_stem) or (group == "dw" and is_dw) or (group == "se" and is_se) or (group == "early" and is_early) or (group == "stem_early_se" and (is_stem or is_early or is_se)) or (group == "dw_head" and is_dw) or (group == "dw_head_se" and (is_dw or is_se)):
        exclude.append(n.name)
if group in ("head", "stem_early_se", "dw_head", "dw_head_se"):
    exclude += [n.name for n in m.graph.node if n.op_type == "Gemm"]
print("group", group, "excluding", len(exclude), "nodes")

pre = out.replace(".onnx", "_pre.onnx")
quant_pre_process(src, pre, skip_symbolic_shape=True)
quantize_static(
    pre, out, Reader(),
    quant_format=QuantFormat.QDQ,
    op_types_to_quantize=["Conv", "Gemm", "MatMul"] + extra_ops,
    per_channel=per_channel,
    reduce_range=False,
    activation_type=QuantType.QUInt8,
    weight_type=QuantType.QInt8,
    nodes_to_exclude=exclude,
    calibrate_method={"minmax": CalibrationMethod.MinMax, "percentile": CalibrationMethod.Percentile, "entropy": CalibrationMethod.Entropy}[method],
    extra_options={"ActivationSymmetric": False, "WeightSymmetric": True, "CalibMovingAverage": method == "minmax", "CalibPercentile": 99.99},
)
import os
print("wrote", out, round(os.path.getsize(out) / 1e6, 1), "MB")
