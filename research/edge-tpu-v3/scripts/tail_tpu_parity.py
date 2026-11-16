"""Trunk features (exact fp32, desktop) -> rewritten head on the phone with a given delegate -> compare.

usage: tail_tpu_parity.py <tag> [benchmark_model flags...]
"""
import os
import sys

import numpy as np
import onnxruntime as ort

import devrun

tag = sys.argv[1]
flags = sys.argv[2:]
specs = np.load("models/specs_test.npy")
ref = np.load("models/ref_preds.npy")
idx = list(range(0, len(specs), int(os.environ.get("STEP", "2"))))
trunk = ort.InferenceSession("models/v3_trunk_3s.onnx", providers=["CPUExecutionProvider"])
F = np.concatenate([trunk.run(None, {"node_div_1_output_cast_0": specs[k:k + 1]})[0] for k in idx]).transpose(0, 2, 3, 1)
res, log = devrun.run("models/tail_logdomain.tflite", "tail_log.tflite", tag, flags, F)
print(log)
P = np.concatenate([r[(1, 10064)] for r in res])
print("nan", int(np.isnan(P).sum()))
devrun.report(tag, P, ref[idx])
