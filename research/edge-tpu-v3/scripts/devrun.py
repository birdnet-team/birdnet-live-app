"""Helpers: run a TFLite model on the phone via benchmark_model with real inputs and fetch raw outputs."""
import os
import re
import subprocess

import numpy as np
from ai_edge_litert.interpreter import Interpreter

D = "/data/local/tmp/bn"


def sh(c):
    return subprocess.run(["adb", "shell", c], capture_output=True, text=True).stdout


def run(local, remote, tag, flags, inputs_nhwc):
    """inputs_nhwc: float32 [N,H,W,C]. Returns (list of {shape: array} per input, log of first run)."""
    it = Interpreter(model_path=local)
    i0 = it.get_input_details()[0]
    outs = it.get_output_details()
    name = i0["name"]
    shape = ",".join(str(int(v)) for v in i0["shape"])
    os.makedirs("results/io", exist_ok=True)
    res = []
    log0 = None
    for x in inputs_nhwc:
        x = x[None]
        if i0["dtype"] != np.float32:
            sc, zp = i0["quantization"]
            info = np.iinfo(i0["dtype"])
            x = np.clip(np.round(x / sc + zp), info.min, info.max)
        x.astype(i0["dtype"]).tofile("results/io/in.bin")
        subprocess.run(["adb", "push", "results/io/in.bin", f"{D}/in.bin"], capture_output=True)
        o = sh(
            f"cd {D} && rm -f out.bin && ./bm --graph={remote} --input_layer='{name}' --input_layer_shape={shape} "
            f"--input_layer_value_files='{name}:in.bin' --output_filepath=out.bin --num_runs=1 --warmup_runs=1 --min_secs=0 "
            f"--delegate_serialize_dir={D}/cache --delegate_serialize_token={tag} {' '.join(flags)} 2>&1"
        )
        if log0 is None:
            log0 = "\n".join(l for l in o.splitlines() if re.search("Replacing|executed by|ERROR", l))
        subprocess.run(["adb", "pull", f"{D}/out.bin", "results/io/out.bin"], capture_output=True)
        raw = open("results/io/out.bin", "rb").read()
        off = 0
        d_out = {}
        for d in outs:
            n = int(np.prod(d["shape"])) * np.dtype(d["dtype"]).itemsize
            a = np.frombuffer(raw[off:off + n], dtype=d["dtype"]).reshape(d["shape"])
            off += n
            if d["dtype"] != np.float32:
                sc, zp = d["quantization"]
                a = (a.astype(np.float32) - zp) * sc
            d_out[tuple(int(v) for v in d["shape"])] = a.astype(np.float32)
        res.append(d_out)
    return res, log0


def report(tag, P, R):
    print(
        f"{tag}: n={len(P)} top1 {(P.argmax(1) == R.argmax(1)).mean():.3f} | max|d| {np.abs(P - R).max():.4f} | "
        f"mean|d| ref>=0.1 {np.abs(P - R)[R >= 0.1].mean():.4f} | det@0.35 ref {(R >= 0.35).sum()} "
        f"cand {(P >= 0.35).sum()} both {((R >= 0.35) & (P >= 0.35)).sum()}"
    )
