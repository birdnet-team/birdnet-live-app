"""
BirdNET ONNX model inspector.
Usage: python inspect_model.py <path/to/model.onnx>
"""

import sys
import collections
import onnx
import onnxruntime as ort
import numpy as np

def inspect(model_path: str):
    print(f"\n{'='*60}")
    print(f"Model: {model_path}")
    print('='*60)

    # --- Load with onnx for graph analysis ---
    model = onnx.load(model_path)
    graph = model.graph

    # Basic info
    opset = [o.version for o in model.opset_import if o.domain == ""]
    print(f"\n[General]")
    print(f"  IR version  : {model.ir_version}")
    print(f"  Opset       : {opset}")
    print(f"  Doc string  : {model.doc_string or '—'}")

    # Custom metadata
    if model.metadata_props:
        print(f"\n[Metadata]")
        for p in model.metadata_props:
            print(f"  {p.key}: {p.value}")

    # Inputs / Outputs
    print(f"\n[Inputs]")
    for inp in graph.input:
        shape = [d.dim_value if d.dim_value > 0 else d.dim_param
                 for d in inp.type.tensor_type.shape.dim]
        dtype = onnx.TensorProto.DataType.Name(inp.type.tensor_type.elem_type)
        print(f"  {inp.name}: {dtype} {shape}")

    print(f"\n[Outputs]")
    for out in graph.output:
        shape = [d.dim_value if d.dim_value > 0 else d.dim_param
                 for d in out.type.tensor_type.shape.dim]
        dtype = onnx.TensorProto.DataType.Name(out.type.tensor_type.elem_type)
        print(f"  {out.name}: {dtype} {shape}")

    # Op counts
    op_counts = collections.Counter(n.op_type for n in graph.node)
    total_nodes = sum(op_counts.values())
    print(f"\n[Op distribution]  ({total_nodes} nodes total)")
    for op, count in op_counts.most_common():
        bar = '█' * min(count, 40)
        print(f"  {op:<24} {count:>5}  {bar}")

    # Parameter count (initializers)
    param_count = 0
    param_bytes = 0
    for init in graph.initializer:
        n = 1
        for d in init.dims:
            n *= d
        param_count += n
        # dtype size
        elem_size = {1: 4, 10: 2, 11: 8, 6: 4, 7: 8}.get(init.data_type, 4)
        param_bytes += n * elem_size

    print(f"\n[Parameters]")
    print(f"  Count : {param_count:,}")
    print(f"  Size  : {param_bytes / 1e6:.1f} MB (estimated)")

    # --- ORT session for runtime info ---
    print(f"\n[OnnxRuntime session]")
    sess_opts = ort.SessionOptions()
    sess_opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_BASIC
    try:
        sess = ort.InferenceSession(model_path, sess_opts,
                                    providers=['CPUExecutionProvider'])
        print(f"  Providers used: {sess.get_providers()}")
        for inp in sess.get_inputs():
            print(f"  Input  {inp.name}: {inp.type} {inp.shape}")
        for out in sess.get_outputs():
            print(f"  Output {out.name}: {out.type} {out.shape}")

        # Quick dummy inference to confirm it runs
        dummy = np.zeros((1, 96000), dtype=np.float32)  # 3s @ 32kHz
        out = sess.run(None, {sess.get_inputs()[0].name: dummy})
        print(f"  Dummy run OK — output shapes: {[o.shape for o in out]}")
    except Exception as e:
        print(f"  ORT error: {e}")

    print(f"\n{'='*60}\n")


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else (
        r"assets\models\BirdNET+_V3.0-preview3_Global_5K-pruned_FP16.onnx"
    )
    inspect(path)
