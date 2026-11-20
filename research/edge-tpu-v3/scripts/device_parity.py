"""Run real spectrograms through benchmark_model on the phone with a given delegate and compare
the exported outputs against the desktop reference (shipped ONNX model)."""
import sys, subprocess, numpy as np, os
from ai_edge_litert.interpreter import Interpreter
local, remote, tag = sys.argv[1], sys.argv[2], sys.argv[3]; flags = sys.argv[4:]
D = "/data/local/tmp/bn"
it = Interpreter(model_path=local); i0 = it.get_input_details()[0]; outs = it.get_output_details()
name = i0["name"]; specs = np.load("models/specs_test.npy"); ref = np.load("models/ref_preds.npy")
idx = list(range(0, len(specs), 6))
os.makedirs("results/io", exist_ok=True); res = []
sh = lambda c: subprocess.run(["adb", "shell", c], capture_output=True, text=True).stdout
for k in idx:
    x = specs[k:k+1].transpose(0, 2, 3, 1)
    if i0["dtype"] != np.float32:
        sc, zp = i0["quantization"]; x = np.clip(np.round(x / sc + zp), -128, 127).astype(i0["dtype"])
    x.tofile("results/io/in.bin")
    subprocess.run(["adb", "push", "results/io/in.bin", f"{D}/in.bin"], capture_output=True)
    o = sh(f"cd {D} && rm -f out.bin && ./bm --graph={remote} --input_layer='{name}' --input_layer_shape=1,224,281,3 --input_layer_value_files='{name}:in.bin' "
           f"--output_filepath=out.bin --num_runs=1 --warmup_runs=1 --min_secs=0 --delegate_serialize_dir={D}/cache --delegate_serialize_token={tag} {' '.join(flags)} 2>&1")
    subprocess.run(["adb", "pull", f"{D}/out.bin", "results/io/out.bin"], capture_output=True)
    raw = open("results/io/out.bin", "rb").read()
    # outputs are concatenated in model output order
    off = 0; pred = None
    for d in outs:
        n = int(np.prod(d["shape"])) * np.dtype(d["dtype"]).itemsize
        a = np.frombuffer(raw[off:off+n], dtype=d["dtype"]); off += n
        if d["shape"][-1] == 10064:
            pred = a.astype(np.float32)
            if d["dtype"] != np.float32:
                sc, zp = d["quantization"]; pred = (pred - zp) * sc
    res.append((k, pred))
    if k == idx[0]: print([l for l in o.splitlines() if "Replacing" in l or "executed" in l][:3], "bytes", len(raw))
P = np.stack([p for _, p in res]); R = ref[idx]
print(f"{tag}: n={len(idx)} top1 {(P.argmax(1)==R.argmax(1)).mean():.3f} | max|d| {np.abs(P-R).max():.4f} | mean|d| ref>=0.1 {np.abs(P-R)[R>=0.1].mean():.4f} | "
      f"det@0.35 ref {(R>=0.35).sum()} cand {(P>=0.35).sum()} both {((R>=0.35)&(P>=0.35)).sum()} | nan {np.isnan(P).sum()}")
