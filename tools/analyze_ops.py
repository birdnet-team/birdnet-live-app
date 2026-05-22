import onnx

model = onnx.load(r'C:\Users\JB\workspace\birdnet-live-app\assets\models\BirdNET+_V3.0-preview3_Global_5K-pruned_FP16.onnx')
graph = model.graph

# STFT details
print("=== STFT Node ===")
for node in graph.node:
    if node.op_type == 'STFT':
        print(f"  inputs : {list(node.input)}")
        print(f"  outputs: {list(node.output)}")
        for a in node.attribute:
            print(f"  attr   : {a.name} = {a.i or a.f or a.s}")

# Cast chain
cast_to = {}
for node in graph.node:
    if node.op_type == 'Cast':
        to = next((a.i for a in node.attribute if a.name == 'to'), None)
        cast_to[to] = cast_to.get(to, 0) + 1

dtype_names = {1: 'FLOAT(fp32)', 10: 'FLOAT16', 6: 'INT32', 7: 'INT64', 9: 'BOOL'}
print("\n=== Cast targets ===")
for k, v in sorted(cast_to.items()):
    print(f"  to {dtype_names.get(k, k)}: {v}x")

# TFLite-unsupported ops check
TFLITE_UNSUPPORTED = {'STFT', 'STFTGrad', 'CumSum', 'Det', 'EinsumFused'}
unsupported = set(n.op_type for n in graph.node) & TFLITE_UNSUPPORTED
print(f"\n=== Ops not in standard TFLite ===")
if unsupported:
    for op in unsupported:
        print(f"  !! {op}")
else:
    print("  (none found in known list)")

# First 5 nodes (preprocessing)
print("\n=== First 10 nodes (input pipeline) ===")
for node in list(graph.node)[:10]:
    print(f"  {node.op_type:20} in={list(node.input)[:2]}  out={list(node.output)[:1]}")
