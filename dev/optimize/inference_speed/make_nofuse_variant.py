"""Break the QuickGelu fusion pattern (x * Sigmoid(x)) by feeding Sigmoid through
Add(x, 0). QuickGelu is opaque to ORT's transpose optimizer, so every SiLU keeps
an NHWC->NCHW->NHWC Transpose pair around it; plain Sigmoid/Mul let the pair cancel.
Usage: python -I make_nofuse_variant.py <src.onnx> <out.onnx>
"""
import sys, numpy as np, onnx
from onnx import helper, numpy_helper
src, out = sys.argv[1], sys.argv[2]
m = onnx.load(src); g = m.graph
prod = {o: n for n in g.node for o in n.output}
g.initializer.append(numpy_helper.from_array(np.zeros([1], dtype=np.float32), "silu_zero"))
new = []; count = 0
for n in g.node:
    if n.op_type == "Mul":
        a, b = n.input
        sig = prod.get(a) if prod.get(a) is not None and prod[a].op_type == "Sigmoid" else (prod.get(b) if prod.get(b) is not None and prod[b].op_type == "Sigmoid" else None)
        other = b if sig is not None and sig.output[0] == a else a
        if sig is not None and sig.input[0] == other:
            tmp = sig.input[0] + "_plus0_" + str(count)
            new.append(helper.make_node("Add", [sig.input[0], "silu_zero"], [tmp], name=f"silu_add0_{count}"))
            sig.input[0] = tmp
            count += 1
    new.append(n)
# Sigmoid nodes were mutated in place; rebuild list with Add inserted before each Sigmoid user
del g.node[:]
# ensure the Add precedes the Sigmoid: place Adds right before their Sigmoid
adds = {n.output[0]: n for n in new if n.name.startswith("silu_add0_")}
final = []
for n in new:
    if n.name.startswith("silu_add0_"): continue
    if n.op_type == "Sigmoid" and n.input[0] in adds: final.append(adds[n.input[0]])
    final.append(n)
g.node.extend(final)
onnx.checker.check_model(m); onnx.save(m, out)
print("rewrote", count, "SiLU patterns ->", out)
