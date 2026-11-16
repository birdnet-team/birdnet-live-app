"""Write N field windows (raw float32, N x 96000) for integration_test/litert_backend_test.dart.

usage: export_windows.py <out.f32> [n=64]   (needs models/field from make_fieldset.py)
"""
import sys

import numpy as np

a = np.load("models/field/audio.npy", mmap_mode="r")
n = int(sys.argv[2]) if len(sys.argv) > 2 else 64
idx = np.linspace(0, len(a) - 1, n).round().astype(int)  # spread over all sites
np.ascontiguousarray(a[idx], dtype="<f4").tofile(sys.argv[1])
print(f"{n} windows -> {sys.argv[1]}")
