"""Trunk on device (any delegate) -> fp32 tail on desktop CPU -> compare with shipped-model predictions.

usage: trunk_parity.py <local.tflite> <remote name> <tag> [benchmark_model flags...]
"""
import sys

import numpy as np
import onnxruntime as ort

import devrun

local, remote, tag = sys.argv[1], sys.argv[2], sys.argv[3]
flags = sys.argv[4:]
specs = np.load("models/specs_test.npy")
ref = np.load("models/ref_preds.npy")
import os
idx = list(range(0, len(specs), int(os.environ.get("STEP", "6"))))
res, log = devrun.run(local, remote, tag, flags, specs[idx].transpose(0, 2, 3, 1))
print(log)
F = np.concatenate([list(r.values())[0] for r in res]).transpose(0, 3, 1, 2)  # NHWC -> NCHW
trunk = ort.InferenceSession("models/v3_trunk_3s.onnx", providers=["CPUExecutionProvider"])
Fr = np.concatenate([trunk.run(None, {"node_div_1_output_cast_0": specs[k:k + 1]})[0] for k in idx])
cos = [float((a.ravel() @ b.ravel()) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-12)) for a, b in zip(F, Fr)]
print(
    f"feature map: cos min {min(cos):.5f} mean {np.mean(cos):.5f} | max|d| {np.abs(F - Fr).max():.4f} "
    f"(ref absmax {np.abs(Fr).max():.3f}) | nan {np.isnan(F).sum()}"
)
tail = ort.InferenceSession("models/v3_tail.onnx", providers=["CPUExecutionProvider"])
P = np.concatenate([tail.run(["predictions"], {"silu_101": f[None]})[0] for f in F])
devrun.report(tag, P, ref[idx])
