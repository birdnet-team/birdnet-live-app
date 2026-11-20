"""Localise fp16 errors on the phone's GPU (and TPU) on 20 field windows.

Each check prints top-1 agreement, max |diff| and detections >= 0.35 against the shipped ONNX model.

  full     combined trunk+head graphs on GPU fp16 / GPU fp32 / TPU
  split    trunk and head separately: GPU16 trunk + host fp32 head, host trunk + GPU16 head,
           TPU trunk + host head, and the two-graph chain GPU16 trunk -> GPU16 head
  feat     max relative error of the trunk features (GPU16, TPU) vs host fp32

Findings (2026-11-16): head v1 (x1024) is correct as separate graphs and as a chain on the GPU, but
the fused v1 graph fails on GPU fp16 (top-1 0.5); head v2 fixes it (top-1 1.0 on GPU16 and TPU).

usage: gpu_fp16_probe.py [full|split|feat ...]   (needs models/field from make_fieldset.py and the
       device files listed in GRAPHS under /data/local/tmp/bn)
"""
import subprocess
import sys

import numpy as np
from ai_edge_litert.interpreter import Interpreter

D = "/data/local/tmp/bn"
F = "models/field"
SPEC_IN = ("1,224,281,3",)
TRUNK_IN = "serving_default_node_div_1_output_cast_0_0"
GRAPHS = {  # device file: (input name, local file)
    "bb_fp32.tflite": (TRUNK_IN, "models/tf_backbone/v3_backbone_3s_float32.tflite"),  # original head
    "v3_tpu_gpu.tflite": ("serving_default_spec_0", "models/v3_tpu_gpu_3s.tflite"),  # head v1
    "v3_v2.tflite": ("serving_default_spec_0", "models/v3_litert_v2_3s.tflite"),  # head v2
    "trunk_fp32.tflite": (TRUNK_IN, "models/tf_trunk/v3_trunk_3s_float32.tflite"),
    "tail_log.tflite": ("feat", "models/tail_logdomain.tflite"),  # head v1 alone
}
G16 = "--use_gpu=true --gpu_precision_loss_allowed=true"
G32 = "--use_gpu=true --gpu_precision_loss_allowed=false"
TPU = "--use_nnapi=true --nnapi_accelerator_name=google-edgetpu --nnapi_allow_fp16=true"

S = np.load(f"{F}/specs.npy", mmap_mode="r")
R = np.load(f"{F}/ref_onnx.npy")
IDX = list(range(0, len(S), 36))  # 20 windows across all sites


def dev(graph, shape, arr, flags, tag):
    """Run one input through `graph` on the phone, return the flat float32 output file."""
    name = GRAPHS[graph][0]
    np.ascontiguousarray(arr, dtype=np.float32).tofile("/tmp/probe_in.bin")
    subprocess.run(["adb", "push", "/tmp/probe_in.bin", f"{D}/probe_in.bin"], capture_output=True, check=True)
    subprocess.run(["adb", "shell",
                    f"cd {D} && ./bm --graph={graph} --input_layer={name} --input_layer_shape={shape} "
                    f"--input_layer_value_files={name}:probe_in.bin --output_filepath={D}/probe.bin "
                    f"--num_runs=1 --warmup_runs=0 --min_secs=0 --delegate_serialize_dir={D}/cache "
                    f"--delegate_serialize_token=probe_{tag} {flags} >/dev/null 2>&1"], check=True)
    subprocess.run(["adb", "pull", f"{D}/probe.bin", "/tmp/probe.bin"], capture_output=True, check=True)
    return np.fromfile("/tmp/probe.bin", np.float32)


def host(path):
    it = Interpreter(model_path=path)
    it.allocate_tensors()

    def run(x):
        it.set_tensor(it.get_input_details()[0]["index"], np.ascontiguousarray(x, dtype=np.float32))
        it.invoke()
        return {tuple(d["shape"]): it.get_tensor(d["index"]) for d in it.get_output_details()}
    return run


def report(label, P):
    P, Rr = np.stack(P), R[IDX]
    print(f"{label:38s} top1 {(P.argmax(1) == Rr.argmax(1)).mean():.2f}  max|d| {np.abs(P - Rr).max():.3f}  "
          f"nan {int(np.isnan(P).sum())}  det ref {(Rr >= .35).sum()} cand {(P >= .35).sum()}", flush=True)


def full():
    for graph, label in [("bb_fp32.tflite", "original head"), ("v3_tpu_gpu.tflite", "head v1"),
                         ("v3_v2.tflite", "head v2")]:
        for tag, flags in [("gpu16", G16), ("gpu32", G32), ("tpu", TPU)]:
            report(f"fused {label}, {tag}", [dev(graph, SPEC_IN[0], S[i][None], flags, f"{graph}_{tag}")[:10064]
                                              for i in IDX])


def split():
    trunk, tail = host(GRAPHS["trunk_fp32.tflite"][1]), host(GRAPHS["tail_log.tflite"][1])
    A, B, C, D_ = [], [], [], []
    for i in IDX:
        f = trunk(S[i][None])[(1, 7, 9, 1280)]
        fg = dev("trunk_fp32.tflite", SPEC_IN[0], S[i][None], G16, "tg").reshape(f.shape)
        ft = dev("trunk_fp32.tflite", SPEC_IN[0], S[i][None], TPU, "tt").reshape(f.shape)
        A.append(tail(fg)[(1, 10064)][0])
        C.append(tail(ft)[(1, 10064)][0])
        B.append(dev("tail_log.tflite", "1,7,9,1280", f, G16, "lg")[1280:1280 + 10064])
        D_.append(dev("tail_log.tflite", "1,7,9,1280", fg, G16, "lg")[1280:1280 + 10064])
    report("GPU16 trunk + host fp32 head v1", A)
    report("host trunk + GPU16 head v1", B)
    report("TPU trunk + host fp32 head v1", C)
    report("chain GPU16 trunk -> GPU16 head v1", D_)


def feat():
    trunk = host(GRAPHS["trunk_fp32.tflite"][1])
    for tag, flags in [("GPU16", G16), ("TPU", TPU)]:
        err = []
        for i in IDX:
            f = trunk(S[i][None])[(1, 7, 9, 1280)]
            g = dev("trunk_fp32.tflite", SPEC_IN[0], S[i][None], flags, "f" + tag).reshape(f.shape)
            err.append(np.abs(g - f).max() / np.abs(f).max())
        print(f"trunk features {tag}: rel. error median {np.median(err):.4f}, max {np.max(err):.4f}")


if __name__ == "__main__":
    for step in sys.argv[1:] or ["full", "split", "feat"]:
        {"full": full, "split": split, "feat": feat}[step]()
