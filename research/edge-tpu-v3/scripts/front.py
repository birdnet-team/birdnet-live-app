import sys, onnx
from onnx import numpy_helper, shape_inference
m = shape_inference.infer_shapes(onnx.load(sys.argv[1])); g = m.graph
sh = {v.name: [d.dim_value for d in v.type.tensor_type.shape.dim] for v in list(g.value_info)+list(g.output)+list(g.input)}
ini = {i.name: list(i.dims) for i in g.initializer}
a, b = int(sys.argv[2]), int(sys.argv[3])
for k, nd in enumerate(g.node[a:b], a):
    ins = [f"{x}{ini[x]}c" if x in ini else f"{x}{sh.get(x,'?')}" for x in nd.input]
    at = {x.name: (list(x.ints) if x.type == 7 else x.i if x.type == 2 else x.s if x.type == 3 else x.f if x.type == 1 else '') for x in nd.attribute}
    print(k, nd.op_type, ins, "->", [f"{o}{sh.get(o,'?')}" for o in nd.output], at)
