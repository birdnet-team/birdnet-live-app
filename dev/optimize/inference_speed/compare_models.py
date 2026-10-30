"""Compare model variants on real audio windows: top-1 agreement, score deltas, PC timing.
Usage: python -I compare_models.py <ref.onnx> <wav> <cand1.onnx> [cand2.onnx ...]
"""
import sys, wave, time, numpy as np, onnxruntime as ort
ref_path, wav_path, cands = sys.argv[1], sys.argv[2], sys.argv[3:]
with wave.open(wav_path) as w:
    pcm = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
starts = (np.linspace(0, len(pcm) - 96000, 101)[:-1] + 48000).astype(int)  # offset from calibration windows
X = np.stack([pcm[s:s + 96000] for s in starts])
def run(path):
    so = ort.SessionOptions(); so.intra_op_num_threads = 6
    s = ort.InferenceSession(path, so, providers=["CPUExecutionProvider"])
    outs = []; t = 0
    for i in range(0, len(X), 4):
        x = X[i:i+4]; t0 = time.perf_counter(); o = s.run(["predictions"], {"input": x})[0]; t += time.perf_counter() - t0; outs.append(o)
    return np.concatenate(outs), t / len(X) * 1000
ref, ms = run(ref_path)
print(f"ref: {ms:.1f} ms/window (PC b4); windows with max score>0.35: {(ref.max(1) > 0.35).sum()}/{len(ref)}")
for c in cands:
    o, ms = run(c)
    conf = ref.max(1) > 0.35
    top1 = (o.argmax(1) == ref.argmax(1))
    print(f"{c.split('/')[-1]}: {ms:.1f} ms/window | top1 agree all {top1.mean():.3f}, on confident {top1[conf].mean() if conf.any() else float('nan'):.3f} | "
          f"max|d| {np.abs(o-ref).max():.3f} mean|d| {np.abs(o-ref).mean():.5f} | max-score corr {np.corrcoef(o.max(1), ref.max(1))[0,1]:.4f}")
