"""Run the fp32 frontend over real audio -> spectrogram images (NCHW) for calibration / testing."""
import sys, numpy as np, soundfile as sf, onnxruntime as ort
wav, out, hop_s, maxn = sys.argv[1], sys.argv[2], float(sys.argv[3]), int(sys.argv[4])
x, sr = sf.read(wav, dtype="float32", always_2d=True); x = x.mean(1)
if sr != 32000:
    from scipy.signal import resample_poly; from math import gcd; g = gcd(32000, sr); x = resample_poly(x, 32000 // g, sr // g).astype("float32"); sr = 32000
s = ort.InferenceSession("models/v3_frontend_3s.onnx", providers=["CPUExecutionProvider"])
hop = int(hop_s * sr); specs = []; chunks = []
for a in range(0, len(x) - 96000 + 1, hop):
    c = x[a:a + 96000][None]
    if c.std() == 0: continue
    specs.append(s.run(None, {"input": c})[0][0]); chunks.append(c[0])
    if len(specs) >= maxn: break
specs = np.stack(specs); np.save(out, specs); np.save(out.replace(".npy", "_audio.npy"), np.stack(chunks))
print(len(x) / sr, "s ->", specs.shape, specs.dtype, float(specs.min()), float(specs.max()))
