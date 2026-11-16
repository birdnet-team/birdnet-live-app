"""Shipped mixed-precision BNL model -> pure fp32, fixed [1, N] input, simplified."""
import sys, numpy as np, onnx
from onnx import numpy_helper, TensorProto as T, helper
import onnxsim
src, dst, n = sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 96000
m = onnx.load(src); g = m.graph
for i, init in enumerate(g.initializer):
    if init.data_type == T.FLOAT16:
        a = numpy_helper.to_array(init).astype(np.float32)
        g.initializer[i].CopyFrom(numpy_helper.from_array(a, init.name))
kept = 0
for nd in g.node:
    if nd.op_type == "Cast":
        to = [a for a in nd.attribute if a.name == "to"][0]
        if to.i in (T.FLOAT16, T.FLOAT):
            to.i = T.FLOAT  # fp16->fp32 becomes a no-op cast that onnxsim removes
            kept += 1
    for a in nd.attribute:  # Constant / ConstantOfShape tensors
        if a.type == onnx.AttributeProto.TENSOR and a.t.data_type == T.FLOAT16:
            a.t.CopyFrom(numpy_helper.from_array(numpy_helper.to_array(a.t).astype(np.float32), a.t.name))
del g.value_info[:]
for o in g.output: o.type.tensor_type.elem_type = T.FLOAT
ms, ok = onnxsim.simplify(m, overwrite_input_shapes={"input": [1, n]})
assert ok
onnx.save(ms, dst)
import collections
print("float casts rewritten", kept, "nodes", len(ms.graph.node), dict(collections.Counter(x.op_type for x in ms.graph.node).most_common()))
