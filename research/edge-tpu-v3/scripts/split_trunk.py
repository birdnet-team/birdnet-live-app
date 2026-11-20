"""Backbone -> trunk (up to the last SiLU, TPU-safe) and tail (GeM pooling + classifier)."""
import onnx.utils
src, cut = "models/v3_backbone_3s.onnx", "silu_101"
onnx.utils.extract_model(src, "models/v3_trunk_3s.onnx", ["node_div_1_output_cast_0"], [cut])
onnx.utils.extract_model(src, "models/v3_tail.onnx", [cut], ["predictions", "embeddings_out"])
