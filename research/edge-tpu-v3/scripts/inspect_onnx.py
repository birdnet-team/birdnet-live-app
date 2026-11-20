import sys, collections, onnx
from onnx import numpy_helper
m = onnx.load(sys.argv[1]); g = m.graph
print("opset", [(o.domain, o.version) for o in m.opset_import], "nodes", len(g.node), "inits", len(g.initializer))
for i in g.input: print("IN ", i.name, [d.dim_param or d.dim_value for d in i.type.tensor_type.shape.dim], i.type.tensor_type.elem_type)
for o in g.output: print("OUT", o.name, [d.dim_param or d.dim_value for d in o.type.tensor_type.shape.dim], o.type.tensor_type.elem_type)
c = collections.Counter(n.op_type for n in g.node)
print(dict(c.most_common()))
dt = collections.Counter(i.data_type for i in g.initializer); print("init dtypes", dict(dt))
n = int(sys.argv[2]) if len(sys.argv) > 2 else 45
print("--- first", n, "nodes")
for nd in g.node[:n]:
    print(nd.op_type, list(nd.input), "->", list(nd.output), {a.name: (a.i if a.type==2 else a.ints if a.type==7 else '') for a in nd.attribute})
print("--- last 14 nodes")
for nd in g.node[-14:]:
    print(nd.op_type, list(nd.input), "->", list(nd.output))
