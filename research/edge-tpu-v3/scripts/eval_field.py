"""Evaluate device predictions on the field set against (a) the shipped ONNX model and (b) ground truth.

Reads models/field/{labels,ref_onnx,meta}, pred_<variant>.npy, emb_<variant>.npy.
Writes results/field_metrics.csv, results/field_site_ap.csv and prints a markdown table.
"""
import glob
import os

import numpy as np
import pandas as pd
from sklearn.metrics import average_precision_score

F = "models/field"
TH = 0.35


def host_preds(path, out):
    """fp32 reference of a .tflite model on the desktop CPU."""
    if os.path.exists(out):
        return np.load(out)
    from ai_edge_litert.interpreter import Interpreter

    it = Interpreter(model_path=path, num_threads=8)
    it.allocate_tensors()
    i0 = it.get_input_details()[0]
    po = [d for d in it.get_output_details() if d["shape"][-1] == 10064][0]
    P = []
    for x in np.load(f"{F}/specs.npy", mmap_mode="r"):
        it.set_tensor(i0["index"], np.ascontiguousarray(x[None]))
        it.invoke()
        P.append(it.get_tensor(po["index"])[0].copy())
    P = np.stack(P)
    np.save(out, P)
    return P


def cmap(Y, P, cls):
    aps = [average_precision_score(Y[:, c], P[:, c]) for c in cls]
    return float(np.mean(aps))


def main():
    Y = np.load(f"{F}/labels.npy").astype(int)
    R = np.load(f"{F}/ref_onnx.npy")
    meta = pd.read_parquet(f"{F}/meta.parquet")
    cls = np.where(Y.sum(0) > 0)[0]
    V = {"onnx_cpu (app ref)": R,
         "host_fp32_orig": host_preds("models/tf_backbone/v3_backbone_3s_float32.tflite", f"{F}/host_fp32_orig.npy"),
         "host_fp32_fixed": host_preds("models/v3_tpu_3s.tflite", f"{F}/host_fp32_fixed.npy")}
    for p in sorted(glob.glob(f"{F}/pred_*.npy")):
        V[os.path.basename(p)[5:-4]] = np.load(p)
    rows, site_rows = [], []
    for name, P in V.items():
        ok = ~np.isnan(P).any(1)
        Pk, Rk, Yk = P[ok], R[ok], Y[ok]
        d = np.abs(Pk - Rk)
        det_r, det_p = Rk >= TH, Pk >= TH
        tp, fp, fn = (Yk & det_p).sum(), (det_p & ~Yk.astype(bool)).sum(), (Yk.astype(bool) & ~det_p).sum()
        rows.append(dict(
            variant=name, n=int(ok.sum()),
            top1_agree=float((Pk.argmax(1) == Rk.argmax(1)).mean()),
            max_abs_diff=float(d.max()), mean_abs_diff_ref01=float(d[Rk >= 0.1].mean()),
            det_ref=int(det_r.sum()), det_cand=int(det_p.sum()), det_both=int((det_r & det_p).sum()),
            cmAP=cmap(Yk, Pk, cls),
            P_at_035=float(tp / max(1, tp + fp)), R_at_035=float(tp / max(1, tp + fn)),
        ))
        for site, g in meta[ok].groupby("site"):
            ix = g.index.values
            ok_c = [c for c in cls if Y[ix, c].sum() > 0]
            site_rows.append(dict(variant=name, site=site, cmAP=cmap(Y[ix], P[ix], ok_c), n_cls=len(ok_c)))
    m = pd.DataFrame(rows)
    m.to_csv("results/field_metrics.csv", index=False)
    pd.DataFrame(site_rows).to_csv("results/field_site_ap.csv", index=False)
    print(f"windows {len(Y)}, labelled {(Y.sum(1) > 0).sum()}, species in GT {len(cls)}, sites {meta.site.nunique()}")
    print(m.to_markdown(index=False, floatfmt=".3f"))


if __name__ == "__main__":
    main()
