"""Rebuild the BirdNET+ V3.0 audio frontend (3 s, 32 kHz -> 224x281x3 image) in TensorFlow and export TFLite.

Constants (window, mel matrix, mean/std) come from the shipped ONNX model (models/frontend_consts.npz).
Verifies against the ONNX frontend on real audio.
"""
import numpy as np
import onnxruntime as ort
import tensorflow as tf

c = np.load("models/frontend_consts.npz")
WINDOW = tf.constant(c["window"], tf.float32)  # [2048]
MEL = tf.constant(c["mel"], tf.float32)  # [1025, 128]
MEAN = tf.constant(c["mean"].reshape(1, 1, 1, 3), tf.float32)
STD = tf.constant(c["std"].reshape(1, 1, 1, 3), tf.float32)
LN10 = 2.3027344  # value baked into the export (fp16-rounded ln 10)


@tf.function(input_signature=[tf.TensorSpec([1, 96000], tf.float32, name="audio")])
def frontend(x):
    x = tf.pad(x, [[0, 0], [1024, 1024]], mode="REFLECT")
    frames = tf.signal.frame(x, 2048, 512)  # [1, 188, 2048]
    spec = tf.signal.rfft(frames * WINDOW, [2048])  # [1, 188, 1025]
    power = tf.math.real(spec) ** 2 + tf.math.imag(spec) ** 2
    mel = tf.matmul(tf.reshape(power, [188, 1025]), MEL)  # [188, 128]
    mel = tf.transpose(mel)  # [128, 188]
    db = tf.math.log(tf.maximum(mel, 1.1920929e-07)) / LN10 * 10.0
    db = tf.maximum(db, tf.reduce_max(db) - 100.0)
    db = db[1:-2][::-1]  # 125 mel rows, flipped
    mx, mn = tf.reduce_max(db), tf.reduce_min(db)
    img = (mx - db) / (mx - mn)
    img = tf.image.resize(img[None, :, :, None], [224, 281], method="bilinear")  # half-pixel centers
    return (tf.tile(img, [1, 1, 1, 3]) - MEAN) / STD  # NHWC [1, 224, 281, 3]


conv = tf.lite.TFLiteConverter.from_concrete_functions([frontend.get_concrete_function()])
open("models/frontend_3s.tflite", "wb").write(conv.convert())

from ai_edge_litert.interpreter import Interpreter  # noqa: E402
import collections  # noqa: E402

it = Interpreter(model_path="models/frontend_3s.tflite")
it.allocate_tensors()
print(dict(collections.Counter(op["op_name"] for op in it._get_ops_details()).most_common()))
i0, o0 = it.get_input_details()[0], it.get_output_details()[0]
print("in", i0["name"], i0["shape"], "out", o0["shape"])
audio = np.load("models/specs_test_audio.npy")
ref = ort.InferenceSession("models/v3_frontend_3s.onnx", providers=["CPUExecutionProvider"])
worst = 0.0
for k in range(0, len(audio), 4):
    it.set_tensor(i0["index"], audio[k:k + 1])
    it.invoke()
    y = it.get_tensor(o0["index"]).transpose(0, 3, 1, 2)
    worst = max(worst, float(np.abs(y - ref.run(None, {"input": audio[k:k + 1]})[0]).max()))
print("max |tflite - onnx| over test windows:", worst, "(value range about -3..7)")
