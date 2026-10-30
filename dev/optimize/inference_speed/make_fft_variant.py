"""Replace the ONNX STFT node (and the |X|^2 that follows it) with a two-stage
Cooley-Tukey DFT built from plain MatMul/Mul/Add ops.

ORT's CPU STFT kernel is a scalar, single-threaded DFT and costs ~7.8 ms per
3 s window on a Pixel 10 Pro. The factorized version (2048 = 32 x 64) runs on
MLAS sgemm, is multithreaded, and needs ~6x fewer MACs than a dense DFT.

Usage: python -I make_fft_variant.py <src.onnx> <out.onnx>
"""
import sys
import numpy as np
import onnx
from onnx import helper, numpy_helper, TensorProto

src, out = sys.argv[1], sys.argv[2]
m = onnx.load(src)
g = m.graph
inits = {t.name: t for t in g.initializer}
prod = {o: n for n in g.node for o in n.output}

stft = next(n for n in g.node if n.op_type == "STFT")
signal_name = stft.input[0]           # [B, Lpad] float32, already reflect-padded
window = numpy_helper.to_array(inits[stft.input[2]]) if stft.input[2] in inits else None
if window is None:
    # window may come through a Cast of an initializer
    cast = prod[stft.input[2]]
    window = numpy_helper.to_array(inits[cast.input[0]]).astype(np.float32)
N = int(numpy_helper.to_array(inits[stft.input[3]]).flatten()[0])
hop = int(numpy_helper.to_array(inits[stft.input[1]]).flatten()[0])
assert N == 2048 and hop == 512 and window.shape == (N,), (N, hop, window.shape)
N1, N2 = 32, 64
assert N1 * N2 == N

# Walk forward: STFT -> Transpose -> Reshape -> ReduceL2 -> Pow -> Transpose(perm 0,2,1)
# The Transpose output is the power spectrogram [B, T, 1025] we will produce directly.
chain = [stft]
cur = stft
for expected in ("Transpose", "Reshape", "ReduceL2", "Pow", "Transpose"):
    nxt = [n for n in g.node if cur.output[0] in n.input]
    assert len(nxt) == 1 and nxt[0].op_type == expected, (expected, [n.op_type for n in nxt])
    cur = nxt[0]
    chain.append(cur)
power_out = cur.output[0]  # [B, T, 1025]
print("replacing", [n.op_type for n in chain], "->", power_out)

# ---- constants -------------------------------------------------------------
n1 = np.arange(N1); k1 = np.arange(N1); n2 = np.arange(N2); k2 = np.arange(N2)
W1 = np.exp(-2j * np.pi * np.outer(k1, n1) / N1)          # [k1, n1]
TW = np.exp(-2j * np.pi * np.outer(k1, n2) / N)           # twiddle [k1, n2]
W2 = np.exp(-2j * np.pi * np.outer(n2, k2) / N2)          # [n2, k2]
f32 = lambda a, name: numpy_helper.from_array(np.ascontiguousarray(a, dtype=np.float32), name)
i64 = lambda a, name: numpy_helper.from_array(np.asarray(a, dtype=np.int64), name)
new_inits = [
    f32(W1.real, "fft_W1r"), f32(W1.imag, "fft_W1i"),
    f32(TW.real, "fft_TWr"), f32(TW.imag, "fft_TWi"),
    f32(W2.real, "fft_W2r"), f32(W2.imag, "fft_W2i"),
    f32(window, "fft_window"),
    i64([hop], "fft_hop"), i64([N], "fft_N"), i64([1], "fft_one"), i64([0], "fft_zero"),
    i64([N1, N2], "fft_shape_n1n2"), i64([-1], "fft_minus1"), i64([N], "fft_shape_flat"),
    i64([N // 2 + 1], "fft_bins"), i64([2], "fft_axis2"),
    i64([0, 0, 0], "fft_pad_zero3"),
]
g.initializer.extend(new_inits)

nodes = []
def node(op, ins, outs, **attrs):
    nodes.append(helper.make_node(op, ins, outs, **attrs))
    return outs[0]

# T = (Lpad - N) // hop + 1
shape = node("Shape", [signal_name], ["fft_sig_shape"])
Lpad = node("Gather", [shape, "fft_one"], ["fft_Lpad"], axis=0)            # scalar
Lm = node("Sub", [Lpad, "fft_N"], ["fft_Lm"])                               # [1]
Td = node("Div", [Lm, "fft_hop"], ["fft_Td"])
T = node("Add", [Td, "fft_one"], ["fft_T"])                                  # [1]
Tsc = node("Squeeze", [T, "fft_zero"], ["fft_Tsc"])                          # scalar
hop_sc = node("Squeeze", ["fft_hop", "fft_zero"], ["fft_hop_sc"])
N_sc = node("Squeeze", ["fft_N", "fft_zero"], ["fft_N_sc"])
zero_sc = node("Squeeze", ["fft_zero", "fft_zero"], ["fft_zero_sc"])
one_sc = node("Squeeze", ["fft_one", "fft_zero"], ["fft_one_sc"])
# frame start offsets [T,1] and in-frame offsets [1,N]
starts = node("Range", [zero_sc, Tsc, one_sc], ["fft_t_range"])
starts = node("Mul", [starts, "fft_hop"], ["fft_starts"])
starts = node("Unsqueeze", [starts, "fft_one"], ["fft_starts_2d"])          # [T,1]
offs = node("Range", [zero_sc, N_sc, one_sc], ["fft_offs"])
offs = node("Unsqueeze", [offs, "fft_zero"], ["fft_offs_2d"])               # [1,N]
idx = node("Add", [starts, offs], ["fft_idx"])                               # [T,N]
frames = node("Gather", [signal_name, idx], ["fft_frames"], axis=1)         # [B,T,N]
frames = node("Mul", [frames, "fft_window"], ["fft_frames_w"])
# reshape to [B,T,N1,N2] (n = N2*n1 + n2)
bt = node("Shape", [frames], ["fft_frames_shape"])
bt = node("Slice", [bt, "fft_zero", "fft_axis2"], ["fft_bt"])               # [B,T]
shp4 = node("Concat", [bt, "fft_shape_n1n2"], ["fft_shape4"], axis=0)
A = node("Reshape", [frames, shp4], ["fft_A"])                               # [B,T,N1(n1),N2(n2)]
# stage 1: Y[k1,n2] = sum_n1 W1[k1,n1] A[n1,n2]
Yr = node("MatMul", ["fft_W1r", A], ["fft_Yr"])
Yi = node("MatMul", ["fft_W1i", A], ["fft_Yi"])
# twiddle
Zr = node("Sub", [node("Mul", [Yr, "fft_TWr"], ["fft_t1"]), node("Mul", [Yi, "fft_TWi"], ["fft_t2"])], ["fft_Zr"])
Zi = node("Add", [node("Mul", [Yr, "fft_TWi"], ["fft_t3"]), node("Mul", [Yi, "fft_TWr"], ["fft_t4"])], ["fft_Zi"])
# stage 2: X[k1,k2] = sum_n2 Z[k1,n2] W2[n2,k2]
Xr = node("Sub", [node("MatMul", [Zr, "fft_W2r"], ["fft_x1"]), node("MatMul", [Zi, "fft_W2i"], ["fft_x2"])], ["fft_Xr"])
Xi = node("Add", [node("MatMul", [Zr, "fft_W2i"], ["fft_x3"]), node("MatMul", [Zi, "fft_W2r"], ["fft_x4"])], ["fft_Xi"])
P = node("Add", [node("Mul", [Xr, Xr], ["fft_p1"]), node("Mul", [Xi, Xi], ["fft_p2"])], ["fft_P"])  # [B,T,k1,k2]
# k = k1 + N1*k2 -> order [k2,k1] then flatten
Pt = node("Transpose", [P], ["fft_Pt"], perm=[0, 1, 3, 2])                 # [B,T,k2,k1]
shp3 = node("Concat", [bt, "fft_shape_flat"], ["fft_shape3"], axis=0)
Pf = node("Reshape", [Pt, shp3], ["fft_Pf"])                                 # [B,T,N]
node("Slice", [Pf, "fft_zero", "fft_bins", "fft_axis2"], [power_out])       # [B,T,1025]

# splice: drop the old chain, insert the new nodes where the STFT was
pos = list(g.node).index(stft)
drop = {id(n) for n in chain}
kept = [n for n in g.node if id(n) not in drop]
# insert new nodes right before the first consumer position (keep topo order)
insert_at = min(pos, len(kept))
new_list = kept[:insert_at] + nodes + kept[insert_at:]
del g.node[:]
g.node.extend(new_list)
# the old ReduceL2 etc. may have had value_info entries; harmless to keep.
onnx.checker.check_model(m)
onnx.save(m, out)
import os
print("wrote", out, round(os.path.getsize(out) / 1e6, 1), "MB; nodes", len(g.node))
