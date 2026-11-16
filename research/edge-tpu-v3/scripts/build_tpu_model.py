"""Compose trunk (onnx2tf SavedModel) + fp16-stable head into one TFLite model for the Edge TPU.

Input: spectrogram image NHWC [1, 224, 281, 3] (output of frontend_3s.tflite).
Outputs: predictions [1, 10064], embeddings [1, 1280].
"""
import os

import numpy as np
import onnxruntime as ort
import tensorflow as tf

import build_tail_logdomain as tl

trunk = tf.saved_model.load("models/tf_trunk")
fn = trunk.signatures["serving_default"]
in_name = list(fn.structured_input_signature[1].keys())[0]
out_name = list(fn.structured_outputs.keys())[0]
print("trunk signature", in_name, "->", out_name)


@tf.function(input_signature=[tf.TensorSpec([1, 224, 281, 3], tf.float32, name="spec")])
def model(x):
    f = fn(**{in_name: x})[out_name]  # NHWC [1, 7, 9, 1280]
    return tl.tail(f)


if __name__ == "__main__":
    conv = tf.lite.TFLiteConverter.from_concrete_functions([model.get_concrete_function()], trunk)
    if os.environ.get("FP16W"):  # store weights as fp16 (half the file size), compute stays fp32/fp16 per delegate
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        conv.target_spec.supported_types = [tf.float16]
    OUT = os.environ.get("OUT", "models/v3_tpu_3s.tflite")
    open(OUT, "wb").write(conv.convert())
    from ai_edge_litert.interpreter import Interpreter

    it = Interpreter(model_path=OUT)
    it.allocate_tensors()
    i0 = it.get_input_details()[0]
    po = [d for d in it.get_output_details() if d["shape"][-1] == 10064][0]
    print("in", i0["name"], i0["shape"])
    specs = np.load("models/specs_test.npy")
    ref = np.load("models/ref_preds.npy")
    P = []
    for k in range(0, len(specs), 6):
        it.set_tensor(i0["index"], specs[k:k + 1].transpose(0, 2, 3, 1))
        it.invoke()
        P.append(it.get_tensor(po["index"]))
    P = np.concatenate(P)
    R = ref[::6]
    print("desktop fp32 check: top1", (P.argmax(1) == R.argmax(1)).mean(), "max|d|", np.abs(P - R).max())
