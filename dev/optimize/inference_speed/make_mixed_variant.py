"""Mixed precision: convolutions in fp16 (NHWC fp16 MLAS kernels), everything
else in fp32 (vectorized MLAS/Eigen float kernels instead of the scalar
MLFloat16 elementwise path).

Input must be the all-fp32 variant (v1_fp32.onnx). Each Conv gets
Cast(fp16) on its data input, fp16 weights/bias, and Cast(fp32) on its output.
Consecutive casts (Conv -> Cast32 -> Cast16 -> Conv) are left for ORT to fold.

Usage: python -I make_mixed_variant.py <v1_fp32.onnx> <out.onnx> [skip_small=1]
"""
import sys
import numpy as np
import onnx
from onnx import helper, numpy_helper, TensorProto

src, out = sys.argv[1], sys.argv[2]
skip_small = len(sys.argv) < 4 or sys.argv[3] == "1"
m = onnx.load(src)
g = m.graph
inits = {t.name: t for t in g.initializer}

new_nodes = []
converted = 0
for n in g.node:
    if n.op_type != "Conv":
        new_nodes.append(n)
        continue
    w = inits[n.input[1]]
    # SE squeeze/excite 1x1 convs and the stem are tiny; leaving them fp32 avoids
    # cast pairs that cost more than the conv itself.
    cout, cin = w.dims[0], w.dims[1]
    small = (w.dims[2] == 1 and w.dims[3] == 1 and (cout <= 64 or cin <= 64)) or cin == 3
    if skip_small and small:
        new_nodes.append(n)
        continue
    converted += 1
    x16 = n.name + "_in_fp16"
    new_nodes.append(helper.make_node("Cast", [n.input[0]], [x16], to=TensorProto.FLOAT16, name=n.name + "_cast_in"))
    for idx in (1, 2):
        if idx < len(n.input) and n.input[idx] in inits:
            t = inits[n.input[idx]]
            if t.data_type == TensorProto.FLOAT:
                arr = numpy_helper.to_array(t).astype(np.float16)
                t.CopyFrom(numpy_helper.from_array(arr, t.name))
    y16 = n.name + "_out_fp16"
    conv = helper.make_node("Conv", [x16] + list(n.input[1:]), [y16], name=n.name)
    conv.attribute.extend(n.attribute)
    new_nodes.append(conv)
    new_nodes.append(helper.make_node("Cast", [y16], [n.output[0]], to=TensorProto.FLOAT, name=n.name + "_cast_out"))

del g.node[:]
g.node.extend(new_nodes)
# drop stale value_info (types changed for conv outputs are unchanged here; conv internal names are new)
onnx.checker.check_model(m)
onnx.save(m, out)
import os
print(f"wrote {out} {os.path.getsize(out)/1e6:.1f} MB; convs in fp16: {converted}")
