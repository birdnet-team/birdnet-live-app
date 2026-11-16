"""Charts for the findings issue. Benchmark numbers from README (Pixel 9 Pro), field results from results/*.csv.

Writes results/fig_*.png
"""
import os

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

SURF, INK, INK2, MUTED, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#898781", "#e1e0d9"
COL = {"CPU": "#2a78d6", "GPU": "#eb6834", "TPU": "#1baf7a"}  # fixed categorical order: slots 1-3
plt.rcParams.update({
    "figure.facecolor": SURF, "axes.facecolor": SURF, "savefig.facecolor": SURF,
    "axes.edgecolor": GRID, "axes.labelcolor": INK2, "xtick.color": MUTED, "ytick.color": INK2,
    "text.color": INK, "font.size": 10, "axes.spines.top": False, "axes.spines.right": False,
    "axes.spines.left": False, "axes.grid": True, "axes.grid.axis": "x", "grid.color": GRID, "grid.linewidth": 0.6,
    "axes.axisbelow": True, "axes.titlesize": 12, "axes.titleweight": "bold", "axes.titlelocation": "left",
})
os.makedirs("results", exist_ok=True)


def legend(ax, loc="lower right"):
    from matplotlib.patches import Patch
    ax.legend(handles=[Patch(color=c, label=k) for k, c in COL.items()], frameon=False, loc=loc, labelcolor=INK2)


def hbars(ax, labels, vals, kinds, fmt, err=None):
    y = np.arange(len(labels))[::-1]
    ax.barh(y, vals, height=0.55, color=[COL[k] for k in kinds], xerr=err,
            error_kw=dict(ecolor=INK, lw=1.2, capsize=3) if err is not None else None)
    ax.set_yticks(y, labels)
    ax.tick_params(axis="y", length=0)
    hi = max(v + (e if err is not None else 0) for v, e in zip(vals, err if err is not None else [0] * len(vals)))
    for yi, v, s in zip(y, vals, fmt):
        ax.text(v + hi * 0.015 + (0 if err is None else err[list(y).index(yi)]), yi, s, va="center", color=INK2, fontsize=9)
    ax.set_xlim(0, hi * 1.25)


def bench():
    # latency per 3-s window, backbone only, batch 1
    L = [("CPU fp32, 1 thread", 127, "CPU"), ("CPU fp32, 4 threads", 58, "CPU"), ("CPU fp16, 4 threads", 31, "CPU"),
         ("GPU fp16", 23, "GPU"), ("TPU low_power", 8.6, "TPU"), ("TPU", 4.1, "TPU")]
    fig, ax = plt.subplots(figsize=(7.5, 3.4))
    hbars(ax, [l[0] for l in L], [l[1] for l in L], [l[2] for l in L],
          [f"{v:g} ms  ·  {3000 / v:.0f}× real-time" for _, v, _ in L])
    ax.set_xlabel("ms per 3-s window (backbone, batch 1, lower is better)")
    ax.set_title("Inference latency on Pixel 9 Pro (Tensor G4)")
    fig.tight_layout(); fig.savefig("results/fig_latency.png", dpi=200); plt.close(fig)

    # energy per window under continuous load
    E = [("CPU fp32, 4 threads", 595, 9913, "CPU"), ("CPU fp16, 4 threads", 275, 8384, "CPU"), ("GPU fp16", 85, 3676, "GPU"),
         ("TPU", 33, 8228, "TPU"), ("TPU low_power", 27, 3319, "TPU")]
    fig, ax = plt.subplots(figsize=(7.5, 3.0))
    hbars(ax, [e[0] for e in E], [e[1] for e in E], [e[3] for e in E], [f"{e[1]} mJ  ({e[2]:,} mW)" for e in E])
    ax.set_xlabel("energy per 3-s window, continuous batch load (mJ, lower is better)")
    ax.set_title("Energy per window under continuous load (preliminary)")
    fig.tight_layout(); fig.savefig("results/fig_energy_batch.png", dpi=200); plt.close(fig)

    # live mode, 1 window per second: total device power (ranges over repeats)
    P = [("CPU fp32, 4 threads", 1594, 1594, "CPU"), ("CPU fp16, 4 threads", 1045, 1154, "CPU"), ("GPU fp16", 961, 1013, "GPU"),
         ("TPU", 1667, 1869, "TPU"), ("TPU low_power", 1148, 1365, "TPU")]
    mid = [(a + b) / 2 for _, a, b, _ in P]
    err = [(b - a) / 2 for _, a, b, _ in P]
    fig, ax = plt.subplots(figsize=(7.5, 3.0))
    hbars(ax, [p[0] for p in P], mid, [p[3] for p in P],
          [f"{a:,}–{b:,} mW" if a != b else f"{a:,} mW" for _, a, b, _ in P], err=err)
    ax.axvspan(820, 920, color=GRID, alpha=0.8, zorder=0)
    ax.set_xlabel("total device power, screen on (mW, lower is better); grey band = idle 820–920 mW")
    ax.set_title("Total device power at 1 window per second (preliminary)")
    fig.tight_layout(); fig.savefig("results/fig_power_live.png", dpi=200); plt.close(fig)


NICE = {
    "onnx_cpu (app ref)": ("ONNX CPU (app today)", "CPU"),
    "cpu16_orig": ("CPU fp16, original head", "CPU"),
    "cpu16_fixed": ("CPU fp16, fp16-safe head (v1)", "CPU"),
    "gpu16_orig": ("GPU fp16, original head", "GPU"),
    "gpu16_v2": ("GPU fp16, fp16-safe head", "GPU"),
    "tpu_orig": ("TPU, original head", "TPU"),
    "tpu_v2": ("TPU, fp16-safe head", "TPU"),
}


def field():
    F = "models/field"
    if not os.path.exists("results/field_metrics.csv"):
        return
    m = pd.read_csv("results/field_metrics.csv").set_index("variant")
    keep = [k for k in NICE if k in m.index]
    fig, ax = plt.subplots(figsize=(7.5, 0.5 * len(keep) + 1.2))
    hbars(ax, [NICE[k][0] for k in keep], [m.cmAP[k] for k in keep], [NICE[k][1] for k in keep],
          [f"{m.cmAP[k]:.3f}" for k in keep])
    ax.set_xlim(0, 0.8)
    ax.set_xlabel("class-mean average precision vs. expert annotations (higher is better)")
    ax.set_title(f"Detection quality, {m.n.iloc[0]} field windows (6 sites, 47 species)", loc="left", x=-0.45)
    fig.tight_layout(); fig.savefig("results/fig_field_cmap.png", dpi=200); plt.close(fig)

    # score scatter: candidate vs app reference, small multiples
    R = np.load(f"{F}/ref_onnx.npy")
    panels = [k for k in ["tpu_orig", "gpu16_orig", "tpu_v2", "gpu16_v2"] if os.path.exists(f"{F}/pred_{k}.npy")]
    if not panels:
        return
    fig, axs = plt.subplots(1, len(panels), figsize=(3.0 * len(panels), 3.6), sharey=True)
    axs = np.atleast_1d(axs)
    mask = R >= 0.02  # only scores that matter; the rest is ~0 everywhere
    for ax, k in zip(axs, panels):
        P = np.load(f"{F}/pred_{k}.npy")
        ok = ~np.isnan(P).any(1)
        mk = mask & ok[:, None]
        hi = (P >= 0.35) & ~(R >= 0.35) & ok[:, None]
        ax.scatter(R[mk], P[mk], s=4, color=COL[NICE[k][1]], alpha=0.35, lw=0)
        ax.plot([0, 1], [0, 1], color=MUTED, lw=0.8)
        ax.axhline(0.35, color=GRID, lw=0.8); ax.axvline(0.35, color=GRID, lw=0.8)
        ax.set_xlim(0, 1); ax.set_ylim(0, 1); ax.set_aspect("equal")
        ax.grid(False)
        ax.set_title(NICE[k][0], fontsize=10)
        ax.text(0.03, 0.97, f"top-1 agree {m.top1_agree[k]:.1%}\nfalse new det. {int(hi.sum()):,}", transform=ax.transAxes,
                va="top", fontsize=8, color=INK2)
        ax.set_xlabel("app reference score")
    axs[0].set_ylabel("on-device score")
    fig.suptitle("Per-class scores vs. the shipped ONNX model (scores ≥ 0.02)", x=0.01, ha="left", fontweight="bold")
    fig.tight_layout(); fig.savefig("results/fig_field_scatter.png", dpi=200); plt.close(fig)


def app():
    """In-app results of integration_test/litert_backend_test.dart (batch of 16, real windows)."""
    import json
    p = "results/app_integration_test.jsonl"
    if not os.path.exists(p):
        return
    rows = [json.loads(l.split(" ", 1)[1]) for l in open(p) if l.startswith("LITERT_BENCH")]
    order = {"ONNX": 0, "LiteRT cpu": 1, "LiteRT gpu": 2, "LiteRT tpu": 3}
    rows.sort(key=lambda r: next(v for k, v in order.items() if r["label"].startswith(k)))
    lab = {"ONNX": ("ONNX Runtime, CPU (app today)", "CPU"), "LiteRT cpu": ("LiteRT, CPU fp32", "CPU"),
           "LiteRT gpu": ("LiteRT, GPU fp16", "GPU"), "LiteRT tpu": ("LiteRT, Edge TPU", "TPU")}
    names, vals, kinds, txt = [], [], [], []
    for r in rows:
        k = next(k for k in order if r["label"].startswith(k))
        names.append(lab[k][0]); kinds.append(lab[k][1]); v = r["batchMsPerWindow"]; vals.append(v)
        txt.append(f"{v:.0f} ms  ·  {3000 / v:.0f}× real-time" + (f"  ·  top-1 {r['top1Agree']:.0%}" if "top1Agree" in r else ""))
    fig, ax = plt.subplots(figsize=(8.5, 2.8))
    hbars(ax, names, vals, kinds, txt)
    ax.set_xlabel("ms per 3-s window in the app (batches of 16, incl. spectrogram; lower is better)")
    ax.set_xlim(0, max(vals) * 1.85)
    ax.set_title("In the app: Edge TPU analyses 3× faster than ONNX")
    fig.tight_layout(); fig.savefig("results/fig_app_latency.png", dpi=200); plt.close(fig)


if __name__ == "__main__":
    bench()
    field()
    app()
