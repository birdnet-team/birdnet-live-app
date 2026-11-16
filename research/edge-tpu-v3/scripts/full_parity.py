"""Combined trunk+head model on the phone -> compare with the shipped model. usage: full_parity.py <tag> [flags]"""
import os, sys
import numpy as np
import devrun
specs = np.load("models/specs_test.npy"); ref = np.load("models/ref_preds.npy")
idx = list(range(0, len(specs), int(os.environ.get("STEP", "2"))))
res, log = devrun.run("models/v3_tpu_3s.tflite", "v3_tpu.tflite", sys.argv[1], sys.argv[2:], specs[idx].transpose(0, 2, 3, 1))
print(log)
P = np.concatenate([r[(1, 10064)] for r in res]); print("nan", int(np.isnan(P).sum()))
devrun.report(sys.argv[1], P, ref[idx])
