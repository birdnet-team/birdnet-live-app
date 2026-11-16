"""fp16-stable rewrite of the V3.0 head (GeM pooling + classifier) for the Edge TPU.

Original:  e = mean(clamp(x, 1e-6, 3.5) ** p) ** (1/p)        p ~ 6.64
x**p underflows in fp16. Rewrite with a per-window max shift (exact in real arithmetic):
    m = max(x_c)  over H,W per channel ;  e = m * mean((x_c / m) ** p) ** (1/p)
(x_c/m) is in (0, 1], its p-th power still underflows for tiny values, but those terms do not
matter for the mean because the max term contributes 1. Then classifier as in the export.
"""
import os

import numpy as np
import onnx
import onnxruntime as ort
import tensorflow as tf
from onnx import numpy_helper

m = onnx.load("models/v3_tail.onnx")
ini = {i.name: numpy_helper.to_array(i).astype(np.float32) for i in m.graph.initializer}
P = float(ini["clamp_2"].ravel()[0])
LO, HI = float(ini["val_1568"]), float(ini["val_1570"])
W, B = ini["head.weight_fp16"], ini["head.bias_fp16"]  # Gemm: transB?
gemm = [n for n in m.graph.node if n.op_type == "Gemm"][0]
transB = any(a.name == "transB" and a.i == 1 for a in gemm.attribute)
Wm = W.T if transB else W  # [1280, 10064]
SCALE = 5.0 / float(ini["scalar_tensor_default"])  # linear summed 5x, divided by 5
H, Wd = 7, 9


HEAD = os.environ.get("HEAD", "v2")
F16_MIN = 2.0 ** -14  # smallest normal fp16 number


@tf.function(input_signature=[tf.TensorSpec([1, H, Wd, 1280], tf.float32, name="feat")])
def tail(x):
    x = tf.clip_by_value(x, LO, HI)
    mx = tf.reduce_max(x, axis=[1, 2], keepdims=True)
    if HEAD == "v1":
        # v1 (Edge TPU only): GeM is positively homogeneous (GeM(k*x) = k*GeM(x)); scale by 1024 so
        # the clamp floor 1e-6 becomes ~1e-3, a normal fp16 number (the TPU flushes subnormals to 0,
        # 0/0 = NaN). The GPU delegate mis-computes this graph in fp16 once fused with the trunk.
        k = 1024.0
        x, mx = x * k, mx * k
        r = x / mx
    else:
        # v2 (TPU and GPU): keep the max and the ratio away from fp16 subnormals instead of scaling.
        # Clamping r at 2^-14 only touches terms below 2^-14^p ~ 1e-28 of the max term: exact in
        # practice, and log() never sees 0.
        k = 1.0
        mx = tf.maximum(mx, F16_MIN)
        r = tf.clip_by_value(x / mx, F16_MIN, 1.0)
    # explicit exp/log instead of POW (Edge TPU returns NaN for POW with fractional exponents)
    mean = tf.reduce_mean(tf.exp(P * tf.math.log(r)), axis=[1, 2])  # >= 1/63: the max term is 1
    # reshape instead of mx[:, 0, 0, :]: STRIDED_SLICE with shrink_axis is not supported by the GPU delegate
    e = tf.reshape(mx, [1, 1280]) * tf.exp(tf.math.log(mean) / P) / k  # [1, 1280]
    logits = tf.matmul(e, Wm) + B
    return {"predictions": tf.sigmoid(logits * SCALE), "embeddings": e}


if __name__ == "__main__":
    s = ort.InferenceSession("models/v3_trunk_3s.onnx", providers=["CPUExecutionProvider"])
    specs = np.load("models/specs_test.npy")
    f = s.run(None, {"node_div_1_output_cast_0": specs[:1]})[0]
    print("feature shape", f.shape)
    assert f.shape[2:] == (H, Wd), f.shape
    ref = ort.InferenceSession("models/v3_tail.onnx", providers=["CPUExecutionProvider"]).run(["predictions"], {"silu_101": f})[0]
    got = tail(tf.constant(f.transpose(0, 2, 3, 1)))["predictions"].numpy()
    print("fp32 rewrite vs original tail: max|d|", np.abs(got - ref).max())
    conv = tf.lite.TFLiteConverter.from_concrete_functions([tail.get_concrete_function()])
    open("models/tail_logdomain.tflite", "wb").write(conv.convert())
    print("written models/tail_logdomain.tflite")
