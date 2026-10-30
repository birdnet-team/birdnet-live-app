"""Rewrite Pow nodes so the ORT WebGPU EP can run the graph.

Pow(x, 2) -> Mul(x, x); Pow(x, c) -> Exp(Log(x) * c) (bases are non-negative
power/mean values in this model; verify numerically with compare_models.py).

Usage: python -I make_webgpu_variant.py <src.onnx> <out.onnx>
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


def const_value(name):
    if name in inits:
        return numpy_helper.to_array(inits[name])
    n = prod.get(name)
    if n is not None and n.op_type == "Cast" and n.input[0] in inits:
        return numpy_helper.to_array(inits[n.input[0]])
    return None


new_nodes = []
for n in g.node:
    if n.op_type != "Pow":
        new_nodes.append(n)
        continue
    c = const_value(n.input[1])
    assert c is not None and c.size == 1, n.name
    c = float(c.flatten()[0])
    x, y = n.input[0], n.output[0]
    if c == 2.0:
        new_nodes.append(helper.make_node("Mul", [x, x], [y], name=n.name + "_sq"))
    else:
        cname = n.name + "_exp_c"
        g.initializer.append(numpy_helper.from_array(np.array([c], dtype=np.float32), cname))
        lg = n.name + "_log"
        new_nodes.append(helper.make_node("Log", [x], [lg], name=n.name + "_log"))
        ml = n.name + "_mul"
        new_nodes.append(helper.make_node("Mul", [lg, cname], [ml], name=n.name + "_mulc"))
        new_nodes.append(helper.make_node("Exp", [ml], [y], name=n.name + "_exp"))
    print("rewrote", n.name, "exponent", c)

del g.node[:]
g.node.extend(new_nodes)
onnx.checker.check_model(m)
onnx.save(m, out)
print("wrote", out)
