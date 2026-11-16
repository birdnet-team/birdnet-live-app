"""Run the field test set (models/field/specs.npy) on the phone for several backend/model variants.

usage: field_device.py push            # push inputs once
       field_device.py run <variant>.. # run variants, pull outputs -> models/field/pred_<variant>.npy
"""
import os
import subprocess
import sys
import time

import numpy as np

D = "/data/local/tmp/bn"
F = "models/field"
MODELS = {  # device file, input name
    "fixed": ("v3_tpu.tflite", "serving_default_spec_0"),
    "orig": ("bb_fp32.tflite", "serving_default_node_div_1_output_cast_0_0"),
    "fixgpu": ("v3_tpu_gpu.tflite", "serving_default_spec_0"),  # same head, reshape instead of strided slice
    "v2": ("v3_v2.tflite", "serving_default_spec_0"),  # head v2: clamp in ratio space, no x1024 (TPU + GPU)
}
BACKENDS = {
    "tpu": "--use_nnapi=true --nnapi_accelerator_name=google-edgetpu --nnapi_allow_fp16=true",
    "gpu16": "--use_gpu=true --gpu_precision_loss_allowed=true",
    "gpu32": "--use_gpu=true --gpu_precision_loss_allowed=false",
    "cpu16": "--use_xnnpack=true --xnnpack_force_fp16=true --num_threads=4",
    "cpu32": "--use_xnnpack=true --num_threads=4",
}
NOUT = 10064 + 1280  # PartitionedCall:1 (preds) first, then embeddings (see devrun)


def sh(c, **kw):
    return subprocess.run(["adb", "shell", c], capture_output=True, text=True, **kw).stdout


def push():
    X = np.load(f"{F}/specs.npy")
    os.makedirs(f"{F}/in", exist_ok=True)
    for i, x in enumerate(X):
        x[None].astype(np.float32).tofile(f"{F}/in/{i:04d}.bin")
    sh(f"rm -rf {D}/field && mkdir -p {D}/field/out")
    subprocess.run(["adb", "push", "--sync", f"{F}/in", f"{D}/field/"], check=True)


def run(variant):
    be, mdl = variant.split("_")
    graph, name = MODELS[mdl]
    n = len(np.load(f"{F}/meta.parquet".replace("meta.parquet", "labels.npy"), mmap_mode="r"))
    out = f"{D}/field/out/{variant}"
    script = (
        f"cd {D} && rm -rf {out} && mkdir -p {out} && for f in field/in/*.bin; do b=$(basename $f); "
        f"./bm --graph={graph} --input_layer={name} --input_layer_shape=1,224,281,3 "
        f"--input_layer_value_files={name}:$f --output_filepath={out}/$b --num_runs=1 --warmup_runs=0 --min_secs=0 "
        f"--delegate_serialize_dir={D}/cache --delegate_serialize_token=field_{variant} {BACKENDS[be]} "
        f">/dev/null 2>&1 || echo FAIL $b; done"
    )
    t = time.time()
    log = sh(script)
    print(variant, f"{time.time() - t:.0f}s", log.strip()[:500], flush=True)
    os.makedirs(f"{F}/out", exist_ok=True)
    subprocess.run(["adb", "pull", out, f"{F}/out/"], capture_output=True, check=True)
    P = np.full((n, 10064), np.nan, np.float32)
    E = np.full((n, 1280), np.nan, np.float32)
    for i in range(n):
        p = f"{F}/out/{variant}/{i:04d}.bin"
        if os.path.exists(p) and os.path.getsize(p) == NOUT * 4:
            a = np.fromfile(p, np.float32)
            P[i], E[i] = a[:10064], a[10064:]
    np.save(f"{F}/pred_{variant}.npy", P)
    np.save(f"{F}/emb_{variant}.npy", E)
    print(variant, "missing", int(np.isnan(P[:, 0]).sum()), flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "push":
        push()
    else:
        for v in sys.argv[2:]:
            run(v)
