"""Record per-tensor activation ranges of the fp32 backbone on real spectrograms; flag fp16 trouble."""
import numpy as np, onnx, onnxruntime as ort
m = onnx.load("models/v3_backbone_3s.onnx"); g = m.graph
names = [o for n in g.node for o in n.output]; prod = {o: n for n in g.node for o in n.output}
del g.output[:]
for n in names: g.output.append(onnx.helper.make_tensor_value_info(n, onnx.TensorProto.FLOAT, None))
so = ort.SessionOptions(); so.graph_optimization_level = ort.GraphOptimizationLevel.ORT_DISABLE_ALL
s = ort.InferenceSession(m.SerializeToString(), so, providers=["CPUExecutionProvider"])
specs = np.load("models/specs_test.npy")
mx = {n: 0.0 for n in names}; mn = {n: 0.0 for n in names}
for k in range(0, len(specs), 8):
    for n, v in zip(names, s.run(names, {"node_div_1_output_cast_0": specs[k:k+1]})):
        mx[n] = max(mx[n], float(np.abs(v).max())); mn[n] = min(mn[n], float(v.min()))
np.save("models/act_absmax.npy", np.array([(n, mx[n]) for n in names], dtype=object), allow_pickle=True)
order = sorted(names, key=lambda n: -mx[n])
print("top |activation| tensors (fp16 max = 65504):")
for n in order[:25]: print(f"  {mx[n]:12.1f}  min {mn[n]:12.1f}  {prod[n].op_type:8s} {n}")
print("tensors > 65504:", sum(mx[n] > 65504 for n in names), "| > 1e4:", sum(mx[n] > 1e4 for n in names), "| > 1e3:", sum(mx[n] > 1e3 for n in names), "of", len(names))
print("--- tail of graph")
for nd in g.node[-16:]: print(f"  {nd.op_type:10s} {nd.output[0]:50s} absmax {mx[nd.output[0]]:.4g}")
