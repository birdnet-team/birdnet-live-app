import sys, onnx, onnx.utils
src = sys.argv[1]; cut = "node_div_1_output_cast_0"
onnx.utils.extract_model(src, "models/v3_frontend_3s.onnx", ["input"], [cut])
onnx.utils.extract_model(src, "models/v3_backbone_3s.onnx", [cut], ["predictions", "embeddings_out"])
import collections
for f in ("models/v3_frontend_3s.onnx", "models/v3_backbone_3s.onnx"):
    m = onnx.load(f); print(f, len(m.graph.node), dict(collections.Counter(n.op_type for n in m.graph.node).most_common()))
