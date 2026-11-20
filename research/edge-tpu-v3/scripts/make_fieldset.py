"""Build a labelled field test set from the Zenodo soundscape collections.

Per site: 3 random annotated recordings, a random 2-min excerpt each -> 3-s windows (no overlap).
Writes models/field/: specs.npy (NHWC float32), audio.npy, meta.parquet, labels.npy (multi-hot over
BirdNET V3 classes), ref_onnx.npy (shipped FP16_BNL ONNX on CPU = app reference).
"""
import os
import sys

import numpy as np
import onnxruntime as ort
import pandas as pd
import soundfile as sf

# Workspace layout of the original run; point DATA_ROOT/LABELS at your copies.
ROOT = os.environ.get("DATA_ROOT", "../..")
OUT = "models/field"
SR, WIN, PER_REC_S, N_REC = 32000, 96000, 120, 3
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(int(os.environ.get("SEED", "7")))

lab = pd.read_csv(os.environ.get("LABELS", "../../assets/models/BirdNET+_V3.0_Global_10K_FP16_BNL_Labels.csv"), sep=";")
sci2idx = {s: i for i, s in zip(lab.idx, lab.sci_name)}
rec = pd.read_parquet(f"{ROOT}/data/field/zenodo/annotations/recordings.parquet")
box = pd.read_parquet(f"{ROOT}/data/field/zenodo/annotations/boxes.parquet")
rec["site"] = rec.xc_id.str.split("_").str[1]

code2sci = {}
for z in sorted(os.listdir(f"{ROOT}/data/external/zenodo")):
    p = f"{ROOT}/data/external/zenodo/{z}/species.csv"
    if os.path.exists(p):
        s = pd.read_csv(p)
        code2sci.update(dict(zip(s.iloc[:, 0], s.iloc[:, 1])))

front = ort.InferenceSession("models/v3_frontend_3s.onnx", providers=["CPUExecutionProvider"])
full = ort.InferenceSession(sys.argv[1], providers=["CPUExecutionProvider"])
fin = full.get_inputs()[0].name

specs, audio, meta, labels, ref = [], [], [], [], []
unmapped = set()
for site, g in rec[rec.n_boxes > 0].groupby("site"):
    pick = g.sample(N_REC, random_state=int(rng.integers(1 << 30)))
    for _, r in pick.iterrows():
        path = f"{ROOT}/data/field/zenodo/raw/{r.xc_id}.flac"
        info = sf.info(path)
        assert info.samplerate == SR, (path, info.samplerate)
        b = box[box.xc_id == r.xc_id]
        # start inside the annotated span so the excerpt is labelled
        lo, hi = max(0.0, b.t0.min() - 10), max(0.0, min(info.duration, b.t1.max() + 10) - PER_REC_S)
        t_start = float(rng.uniform(lo, max(lo, hi)))
        t_start = min(t_start, info.duration - PER_REC_S)
        x, _ = sf.read(path, start=int(t_start * SR), frames=PER_REC_S * SR, dtype="float32", always_2d=True)
        x = x.mean(1)
        for k in range(len(x) // WIN):
            c = x[k * WIN:(k + 1) * WIN][None]
            if c.std() == 0:
                continue
            a, e = t_start + k * 3, t_start + k * 3 + 3
            y = np.zeros(len(lab), np.uint8)
            ov = b[(b.t1 > a + 0.1) & (b.t0 < e - 0.1)]  # >= ~0.1 s overlap
            for code in ov.scientific_name.unique():
                sci = code2sci.get(code)
                if sci in sci2idx:
                    y[sci2idx[sci]] = 1
                else:
                    unmapped.add(code)
            specs.append(front.run(None, {"input": c})[0][0].transpose(1, 2, 0))
            audio.append(c[0])
            ref.append(full.run(None, {fin: c})[0][0])
            labels.append(y)
            meta.append(dict(site=site, xc_id=r.xc_id, t0=a, n_lab=int(y.sum())))
        print(site, r.xc_id, f"{t_start:.0f}s", len(meta), flush=True)

np.save(f"{OUT}/specs.npy", np.stack(specs).astype(np.float32))
np.save(f"{OUT}/audio.npy", np.stack(audio))
np.save(f"{OUT}/labels.npy", np.stack(labels))
np.save(f"{OUT}/ref_onnx.npy", np.stack(ref).astype(np.float32))
m = pd.DataFrame(meta)
m.to_parquet(f"{OUT}/meta.parquet")
print(m.groupby("site").agg(windows=("t0", "size"), labelled=("n_lab", lambda v: (v > 0).sum())))
print("unmapped codes:", sorted(unmapped))
