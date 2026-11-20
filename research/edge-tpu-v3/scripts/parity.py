"""Compare TFLite backbone(s) against the shipped ONNX model on real audio windows."""
import collections, os, sys
import numpy as np, onnxruntime as ort
from ai_edge_litert.interpreter import Interpreter
REF = os.environ.get("BN_ONNX", "../../assets/models/BirdNET+_V3.0_Global_10K_FP16_BNL.onnx")
specs = np.load("models/specs_test.npy"); audio = np.load("models/specs_test_audio.npy")
N = min(len(specs), int(sys.argv[1])); 
s = ort.InferenceSession(REF, providers=["CPUExecutionProvider"])
ref = np.concatenate([s.run(["predictions"], {"input": audio[i:i+1]})[0] for i in range(N)])
np.save("models/ref_preds.npy", ref)
for f in sys.argv[2:]:
    it = Interpreter(model_path=f, num_threads=8); it.allocate_tensors()
    i0 = it.get_input_details()[0]; outs = it.get_output_details()
    o = [d for d in outs if d["shape"][-1] == 10064][0]
    if len(sys.argv) and f == sys.argv[2]:
        ops = collections.Counter(op["op_name"] for op in it._get_ops_details()); print(dict(ops.most_common()))
        print("in", i0["shape"], i0["dtype"].__name__, "outs", [(d["name"], list(d["shape"])) for d in outs])
    p = []
    for k in range(N):
        x = specs[k:k+1].transpose(0, 2, 3, 1)
        if i0["dtype"] != np.float32:
            sc, zp = i0["quantization"]; x = np.clip(np.round(x / sc + zp), -128, 127).astype(i0["dtype"])
        it.set_tensor(i0["index"], x); it.invoke(); y = it.get_tensor(o["index"])
        if o["dtype"] != np.float32:
            sc, zp = o["quantization"]; y = (y.astype(np.float32) - zp) * sc
        p.append(y)
    p = np.concatenate(p)
    top1 = (p.argmax(1) == ref.argmax(1)).mean()
    # detection agreement at the app threshold
    d_ref, d_p = ref >= 0.35, p >= 0.35
    inter = (d_ref & d_p).sum(); 
    print(f"{f.split('/')[-1]}: top1 {top1:.3f} | max|d| {np.abs(p-ref).max():.4f} | mean|d| on ref>=0.1 {np.abs(p-ref)[ref>=0.1].mean():.4f} | det@0.35 ref {d_ref.sum()} cand {d_p.sum()} both {inter}")
