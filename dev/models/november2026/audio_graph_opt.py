#!/usr/bin/env python3
"""
Graph-level speed rewrites for the BirdNET+ audio classifier.

Both rewrites come from the #76 inference-speed investigation
(`dev/optimize/inference_speed/` on the `inference-speed` branch, summarized in
`docs/developer/model-export-checklist.md`). They change how the graph is
expressed, not what it computes:

1. `replace_stft_with_matmul_dft` - ONNX Runtime's CPU `STFT` kernel is a
   scalar, single-threaded DFT. The node (plus the magnitude/power ops behind
   it) is replaced by a two-stage Cooley-Tukey DFT (2048 = 32 x 64) expressed
   as `MatMul` with constant matrices, which runs on the multithreaded sgemm
   path.

2. `to_mixed_precision` - arm64 ORT has fast fp16 convolution kernels but no
   vectorized fp16 kernels for elementwise ops, so the `x * sigmoid(x)` SiLU in
   fp16 costs more than the convolutions. The graph is rewritten so that
   activations are fp32 and only the large convolutions run in fp16 (explicit
   `Cast` on each side). Weights of every other op are stored as fp32.

The module is imported by `build_november2026.py`; it can also be run on its
own to rewrite a single file:

    python dev/models/november2026/audio_graph_opt.py <src.onnx> <out.onnx>
"""

from __future__ import annotations

import sys

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper, shape_inference

_FLOAT_TYPES = (TensorProto.FLOAT, TensorProto.FLOAT16)


def _producers(graph) -> dict[str, onnx.NodeProto]:
    return {out: node for node in graph.node for out in node.output}


def _consumers(graph, name: str) -> list[onnx.NodeProto]:
    return [node for node in graph.node if name in node.input]


# ---------------------------------------------------------------------------
# 1. STFT -> factorized DFT
# ---------------------------------------------------------------------------

def replace_stft_with_matmul_dft(model: onnx.ModelProto) -> None:
    """Replace `STFT -> Transpose -> Reshape -> ReduceL2 -> Pow -> Transpose`
    with a MatMul-based DFT that writes the same power spectrogram tensor.

    Raises if the graph does not have exactly the expected front end, so a
    changed export fails loudly instead of being rewritten wrongly.
    """
    g = model.graph
    inits = {t.name: t for t in g.initializer}
    prod = _producers(g)

    stfts = [n for n in g.node if n.op_type == "STFT"]
    if len(stfts) != 1:
        raise ValueError(f"expected exactly one STFT node, found {len(stfts)}")
    stft = stfts[0]
    onesided = next((a.i for a in stft.attribute if a.name == "onesided"), 1)
    if onesided != 1:
        raise ValueError("STFT rewrite only supports onesided=1")

    signal_name = stft.input[0]  # [B, Lpad] float32, already padded

    def const_of(name: str) -> np.ndarray:
        if name in inits:
            return numpy_helper.to_array(inits[name])
        node = prod.get(name)
        if node is not None and node.op_type == "Cast" and node.input[0] in inits:
            return numpy_helper.to_array(inits[node.input[0]])
        raise ValueError(f"STFT input '{name}' is not a constant")

    hop = int(const_of(stft.input[1]).flatten()[0])
    window = const_of(stft.input[2]).astype(np.float32)
    n_fft = int(const_of(stft.input[3]).flatten()[0])
    n1, n2 = 32, 64
    if n_fft != n1 * n2 or window.shape != (n_fft,):
        raise ValueError(f"unexpected STFT config: n_fft={n_fft}, window={window.shape}")

    # Walk the magnitude/power chain. Its last output is the power
    # spectrogram [B, T, n_fft/2+1] that the new nodes produce directly.
    chain = [stft]
    cur = stft
    for expected in ("Transpose", "Reshape", "ReduceL2", "Pow", "Transpose"):
        nxt = _consumers(g, cur.output[0])
        if len(nxt) != 1 or nxt[0].op_type != expected:
            raise ValueError(
                f"unexpected node after {cur.op_type}: wanted {expected}, "
                f"got {[n.op_type for n in nxt]}"
            )
        cur = nxt[0]
        chain.append(cur)
    pow_node = chain[4]
    exponent = float(const_of(pow_node.input[1]).flatten()[0])
    if exponent != 2.0:
        raise ValueError(f"expected a power spectrogram (Pow 2), got exponent {exponent}")
    power_out = cur.output[0]

    # Constants: X[k1 + n1*k2] = sum_{n2} W2[n2,k2] * TW[k1,n2] * sum_{j} W1[k1,j] * x[n2 + N2*j]
    a1 = np.arange(n1)
    a2 = np.arange(n2)
    w1 = np.exp(-2j * np.pi * np.outer(a1, a1) / n1)      # [k1, j]
    tw = np.exp(-2j * np.pi * np.outer(a1, a2) / n_fft)   # [k1, n2]
    w2 = np.exp(-2j * np.pi * np.outer(a2, a2) / n2)      # [n2, k2]

    def f32(arr, name):
        return numpy_helper.from_array(np.ascontiguousarray(arr, dtype=np.float32), name)

    def i64(arr, name):
        return numpy_helper.from_array(np.asarray(arr, dtype=np.int64), name)

    g.initializer.extend([
        f32(w1.real, "fft_W1r"), f32(w1.imag, "fft_W1i"),
        f32(tw.real, "fft_TWr"), f32(tw.imag, "fft_TWi"),
        f32(w2.real, "fft_W2r"), f32(w2.imag, "fft_W2i"),
        f32(window, "fft_window"),
        i64([hop], "fft_hop"), i64([n_fft], "fft_N"), i64([1], "fft_one"),
        i64([0], "fft_zero"), i64([n1, n2], "fft_shape_n1n2"),
        i64([n_fft], "fft_shape_flat"), i64([n_fft // 2 + 1], "fft_bins"),
        i64([2], "fft_axis2"),
    ])

    nodes: list[onnx.NodeProto] = []

    def node(op, ins, out, **attrs):
        nodes.append(helper.make_node(op, ins, [out], name=f"fft/{out}", **attrs))
        return out

    # Frame count T = (Lpad - N) // hop + 1
    shape = node("Shape", [signal_name], "fft_sig_shape")
    lpad = node("Gather", [shape, "fft_one"], "fft_Lpad", axis=0)
    t = node("Add", [node("Div", [node("Sub", [lpad, "fft_N"], "fft_Lm"), "fft_hop"], "fft_Td"), "fft_one"], "fft_T")
    t_sc = node("Squeeze", [t, "fft_zero"], "fft_T_sc")
    n_sc = node("Squeeze", ["fft_N", "fft_zero"], "fft_N_sc")
    zero_sc = node("Squeeze", ["fft_zero", "fft_zero"], "fft_zero_sc")
    one_sc = node("Squeeze", ["fft_one", "fft_zero"], "fft_one_sc")
    # Sample index of every frame element: [T, 1] starts + [1, N] offsets
    starts = node("Mul", [node("Range", [zero_sc, t_sc, one_sc], "fft_t_range"), "fft_hop"], "fft_starts")
    starts = node("Unsqueeze", [starts, "fft_one"], "fft_starts_2d")
    offs = node("Unsqueeze", [node("Range", [zero_sc, n_sc, one_sc], "fft_offs"), "fft_zero"], "fft_offs_2d")
    idx = node("Add", [starts, offs], "fft_idx")
    frames = node("Gather", [signal_name, idx], "fft_frames", axis=1)            # [B, T, N]
    frames = node("Mul", [frames, "fft_window"], "fft_frames_w")
    bt = node("Slice", [node("Shape", [frames], "fft_frames_shape"), "fft_zero", "fft_axis2"], "fft_bt")
    a = node("Reshape", [frames, node("Concat", [bt, "fft_shape_n1n2"], "fft_shape4", axis=0)], "fft_A")
    # Stage 1 over the coarse index, twiddle, stage 2 over the fine index.
    yr = node("MatMul", ["fft_W1r", a], "fft_Yr")
    yi = node("MatMul", ["fft_W1i", a], "fft_Yi")
    zr = node("Sub", [node("Mul", [yr, "fft_TWr"], "fft_t1"), node("Mul", [yi, "fft_TWi"], "fft_t2")], "fft_Zr")
    zi = node("Add", [node("Mul", [yr, "fft_TWi"], "fft_t3"), node("Mul", [yi, "fft_TWr"], "fft_t4")], "fft_Zi")
    xr = node("Sub", [node("MatMul", [zr, "fft_W2r"], "fft_x1"), node("MatMul", [zi, "fft_W2i"], "fft_x2")], "fft_Xr")
    xi = node("Add", [node("MatMul", [zr, "fft_W2i"], "fft_x3"), node("MatMul", [zi, "fft_W2r"], "fft_x4")], "fft_Xi")
    p = node("Add", [node("Mul", [xr, xr], "fft_p1"), node("Mul", [xi, xi], "fft_p2")], "fft_P")  # [B,T,k1,k2]
    # Bin k = k1 + n1*k2, so order as [k2, k1] before flattening.
    pt = node("Transpose", [p], "fft_Pt", perm=[0, 1, 3, 2])
    pf = node("Reshape", [pt, node("Concat", [bt, "fft_shape_flat"], "fft_shape3", axis=0)], "fft_Pf")
    nodes.append(helper.make_node(
        "Slice", [pf, "fft_zero", "fft_bins", "fft_axis2"], [power_out], name="fft/power"))

    drop = {id(n) for n in chain}
    pos = list(g.node).index(stft)
    kept = [n for n in g.node if id(n) not in drop]
    insert_at = sum(1 for n in list(g.node)[:pos] if id(n) not in drop)
    new_list = kept[:insert_at] + nodes + kept[insert_at:]
    del g.node[:]
    g.node.extend(new_list)

    # Remove value_info of tensors that no longer exist.
    gone = {o for n in chain for o in n.output} - {power_out}
    stale = [vi for vi in g.value_info if vi.name in gone]
    for vi in stale:
        g.value_info.remove(vi)
    _drop_unused_initializers(g)


# ---------------------------------------------------------------------------
# 2. fp16 convolutions inside an fp32 graph
# ---------------------------------------------------------------------------

def _is_small_conv(weight: onnx.TensorProto) -> bool:
    """Squeeze/excite 1x1 convs and the stem are tiny; a cast pair around them
    costs more than the fp16 kernel saves, so they stay fp32."""
    cout, cin, kh, kw = weight.dims
    return (kh == 1 and kw == 1 and (cout <= 64 or cin <= 64)) or cin == 3


def to_mixed_precision(model: onnx.ModelProto) -> int:
    """Rewrite an fp16 graph to fp32 activations with fp16 large convolutions.

    Returns the number of convolutions kept in fp16.
    """
    g = model.graph

    # Every Cast in the exported graph must be an fp16<->fp32 precision cast;
    # anything else (integer casts for shape math) must not be rewired away.
    inferred = shape_inference.infer_shapes(model)
    types = {vi.name: vi.type.tensor_type.elem_type
             for vi in list(inferred.graph.value_info) + list(inferred.graph.input) + list(inferred.graph.output)}
    for init in g.initializer:
        types[init.name] = init.data_type
    for n in g.node:
        if n.op_type != "Cast":
            continue
        to = next(a.i for a in n.attribute if a.name == "to")
        src = types.get(n.input[0])
        if to not in _FLOAT_TYPES or src not in _FLOAT_TYPES:
            raise ValueError(
                f"Cast '{n.name}' is not an fp16<->fp32 cast "
                f"({src} -> {to}); refusing to rewrite")

    # Step 1: drop every precision cast and make the whole graph fp32.
    rename: dict[str, str] = {}
    keep = []
    for n in g.node:
        if n.op_type == "Cast":
            rename[n.output[0]] = n.input[0]
        else:
            keep.append(n)

    def resolve(name: str) -> str:
        while name in rename:
            name = rename[name]
        return name

    del g.node[:]
    g.node.extend(keep)
    for n in g.node:
        for i, name in enumerate(n.input):
            n.input[i] = resolve(name)
    for out in g.output:
        if out.name in rename:
            g.node.append(helper.make_node(
                "Identity", [resolve(out.name)], [out.name], name=f"{out.name}_identity"))
    for init in g.initializer:
        if init.data_type == TensorProto.FLOAT16:
            arr = numpy_helper.to_array(init).astype(np.float32)
            init.CopyFrom(numpy_helper.from_array(arr, init.name))
    # Intermediate type annotations are stale now; ORT re-infers them at load.
    del g.value_info[:]

    # Step 2: put the large convolutions back into fp16.
    inits = {t.name: t for t in g.initializer}
    use_count: dict[str, int] = {}
    for n in g.node:
        for name in n.input:
            use_count[name] = use_count.get(name, 0) + 1

    new_nodes = []
    converted = 0
    for n in g.node:
        if n.op_type != "Conv" or n.input[1] not in inits or _is_small_conv(inits[n.input[1]]):
            new_nodes.append(n)
            continue
        for name in n.input[1:]:
            if name not in inits or use_count[name] != 1:
                raise ValueError(f"Conv '{n.name}' weight '{name}' is shared or not constant")
            t = inits[name]
            arr = numpy_helper.to_array(t)
            half = arr.astype(np.float16)
            if not np.isfinite(half).all():
                raise ValueError(f"Conv '{n.name}' weight '{name}' overflows fp16")
            t.CopyFrom(numpy_helper.from_array(half, t.name))
        converted += 1
        base = n.name or n.output[0]
        x16, y16 = f"{base}_in_fp16", f"{base}_out_fp16"
        new_nodes.append(helper.make_node(
            "Cast", [n.input[0]], [x16], to=TensorProto.FLOAT16, name=f"{base}_cast_in"))
        conv = helper.make_node("Conv", [x16] + list(n.input[1:]), [y16], name=n.name)
        conv.attribute.extend(n.attribute)
        new_nodes.append(conv)
        new_nodes.append(helper.make_node(
            "Cast", [y16], [n.output[0]], to=TensorProto.FLOAT, name=f"{base}_cast_out"))

    del g.node[:]
    g.node.extend(new_nodes)
    return converted


def _drop_unused_initializers(graph) -> None:
    used = {name for n in graph.node for name in n.input}
    used |= {o.name for o in graph.output}
    for init in [t for t in graph.initializer if t.name not in used]:
        graph.initializer.remove(init)


def optimize_audio_graph(model: onnx.ModelProto) -> int:
    """Apply both rewrites in place. Returns the fp16 convolution count."""
    replace_stft_with_matmul_dft(model)
    converted = to_mixed_precision(model)
    _drop_unused_initializers(model.graph)
    onnx.checker.check_model(model)
    return converted


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    model = onnx.load(sys.argv[1])
    converted = optimize_audio_graph(model)
    onnx.save(model, sys.argv[2])
    print(f"wrote {sys.argv[2]} (fp16 convolutions: {converted})")


if __name__ == "__main__":
    main()
