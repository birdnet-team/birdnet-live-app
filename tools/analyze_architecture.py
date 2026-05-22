"""
Deep architecture analysis of BirdNET+ V3.0 ONNX model.
"""
import onnx
import numpy as np
from onnx import numpy_helper
from collections import Counter

MODEL_PATH = r'C:\Users\JB\workspace\birdnet-live-app\assets\models\BirdNET+_V3.0-preview3_Global_5K-pruned_FP16.onnx'

model = onnx.load(MODEL_PATH)
graph = model.graph
nodes = list(graph.node)

# ── Initializer map (works for both FP16 and FP32) ──────────────────────────
initializers = {}
for init in graph.initializer:
    initializers[init.name] = init

def init_dims(name):
    if name in initializers:
        return list(initializers[name].dims)
    return None

def init_value(name):
    if name in initializers:
        try:
            return numpy_helper.to_array(initializers[name])
        except Exception:
            return None
    return None

# ── Value info map for intermediate shapes ───────────────────────────────────
value_info = {}
for vi in list(graph.value_info) + list(graph.input) + list(graph.output):
    try:
        shape = [d.dim_value if d.dim_value > 0 else (d.dim_param or '?')
                 for d in vi.type.tensor_type.shape.dim]
        dtype = onnx.TensorProto.DataType.Name(vi.type.tensor_type.elem_type)
        value_info[vi.name] = (dtype, shape)
    except Exception:
        pass

SEP = "─" * 68

print("\n" + "="*68)
print("  BirdNET+ V3.0-preview3  —  ARCHITECTURE ANALYSIS")
print("="*68)

# ════════════════════════════════════════════════════════════════════════════
print(f"\n{SEP}")
print("  1. GRAPH OVERVIEW")
print(SEP)
opset = [o.version for o in model.opset_import if o.domain == ""]
op_counts = Counter(n.op_type for n in nodes)
print(f"  IR version : {model.ir_version}   Opset : {opset}")
print(f"  Total nodes: {len(nodes)}")
print(f"  Initializers (weights/buffers): {len(initializers)}")
print(f"\n  Op distribution:")
for op, cnt in op_counts.most_common():
    bar = '█' * min(cnt, 35)
    print(f"    {op:<22} {cnt:>5}   {bar}")

# ════════════════════════════════════════════════════════════════════════════
print(f"\n{SEP}")
print("  2. INPUTS / OUTPUTS")
print(SEP)
for inp in graph.input:
    try:
        shape = [d.dim_value if d.dim_value > 0 else (d.dim_param or '?')
                 for d in inp.type.tensor_type.shape.dim]
        dtype = onnx.TensorProto.DataType.Name(inp.type.tensor_type.elem_type)
        print(f"  INPUT  {inp.name}: {dtype}  shape={shape}")
    except Exception:
        print(f"  INPUT  {inp.name}: (no shape info)")
for out in graph.output:
    try:
        shape = [d.dim_value if d.dim_value > 0 else (d.dim_param or '?')
                 for d in out.type.tensor_type.shape.dim]
        dtype = onnx.TensorProto.DataType.Name(out.type.tensor_type.elem_type)
        print(f"  OUTPUT {out.name}: {dtype}  shape={shape}")
    except Exception:
        print(f"  OUTPUT {out.name}: (no shape info)")

# ════════════════════════════════════════════════════════════════════════════
print(f"\n{SEP}")
print("  3. AUDIO PREPROCESSING PIPELINE")
print(SEP)

# STFT details
for node in nodes:
    if node.op_type == 'STFT':
        attrs = {a.name: a for a in node.attribute}
        onesided = attrs['onesided'].i if 'onesided' in attrs else '?'
        # frame_step
        hop_val = init_value(node.input[3]) if len(node.input) > 3 else None
        hop = int(hop_val.flat[0]) if hop_val is not None else '?'
        # window
        win_dims = init_dims(node.input[1]) if len(node.input) > 1 else None
        win_val = init_value(node.input[1]) if len(node.input) > 1 else None
        fft_size = win_dims[0] if win_dims else '?'
        print(f"  STFT:")
        print(f"    onesided       : {onesided}  (real-valued output)")
        print(f"    window size    : {fft_size} samples "
              f"({'%.1f' % (fft_size/32000*1000)} ms @ 32 kHz)" if isinstance(fft_size,int) else f"    window size: {fft_size}")
        print(f"    hop (frame_step): {hop} samples "
              f"({'%.1f' % (hop/32000*1000)} ms)" if isinstance(hop,int) else f"    hop: {hop}")
        if isinstance(fft_size, int) and isinstance(hop, int):
            freq_bins = fft_size // 2 + 1
            print(f"    freq_bins      : {freq_bins}  (fft_size/2 + 1)")
            # time frames for 3s window
            for ws in [3, 5, 10]:
                n_samples = ws * 32000
                n_frames = (n_samples - fft_size) // hop + 1
                print(f"    time_frames    : {n_frames}  (for {ws}s window)")
        print(f"    → output shape : [batch, freq_bins, time_frames, 2]  (real+imag)")

# Normalization
print(f"\n  Normalization (learned):")
for name in ['preprocess.mean', 'preprocess.std']:
    dims = init_dims(name)
    if dims:
        print(f"    {name}: shape={dims}")

print(f"""
  Full preprocessing flow:
    raw audio [1, N]
      → Sub/Div (normalize with preprocess.mean / preprocess.std)
      → STFT    (spectrogram [1, freq_bins, time_frames, 2])
      → Pow+Add+Sqrt  (magnitude)
      → Log           (log-compression)
      → Cast FP16→FP32
      → backbone input""")

# ════════════════════════════════════════════════════════════════════════════
print(f"\n{SEP}")
print("  4. BACKBONE — CONV LAYER ANALYSIS")
print(SEP)

# Collect all Conv nodes with their weight shapes
conv_info = []
for node in nodes:
    if node.op_type == 'Conv':
        groups = next((a.i for a in node.attribute if a.name == 'groups'), 1)
        dilations = next((list(a.ints) for a in node.attribute if a.name == 'dilations'), [1,1])
        kernel = next((list(a.ints) for a in node.attribute if a.name == 'kernel_shape'), None)
        strides = next((list(a.ints) for a in node.attribute if a.name == 'strides'), [1,1])
        weight_dims = init_dims(node.input[1]) if len(node.input) > 1 and node.input[1] in initializers else None
        if weight_dims is None and len(node.input) > 1:
            # Try to find shape from value_info
            for vi in graph.value_info:
                if vi.name == node.input[1]:
                    weight_dims = [d.dim_value for d in vi.type.tensor_type.shape.dim]
        conv_info.append({
            'groups': groups,
            'kernel': kernel,
            'strides': strides,
            'weight': weight_dims,
            'dilations': dilations,
        })

total_conv = len(conv_info)
dw = [c for c in conv_info if c['groups'] > 1]
pw = [c for c in conv_info if c['kernel'] == [1,1] and c['groups'] == 1]
std = [c for c in conv_info if c not in dw and c not in pw]

print(f"  Total Conv nodes: {total_conv}")
print(f"    Depthwise  (groups>1)  : {len(dw)}")
print(f"    Pointwise  (1×1)       : {len(pw)}")
print(f"    Standard               : {len(std)}")

# Kernel shapes
kernel_counts = Counter(str(c['kernel']) for c in conv_info if c['kernel'])
print(f"\n  Kernel shape distribution:")
for k, cnt in kernel_counts.most_common():
    print(f"    {k:<20} × {cnt}")

# Stride distribution
stride_counts = Counter(str(c['strides']) for c in conv_info)
print(f"\n  Stride distribution:")
for s, cnt in stride_counts.most_common():
    print(f"    stride={s:<12} × {cnt}")

# Channel widths from weight dims
out_ch = [c['weight'][0] for c in conv_info if c['weight'] and len(c['weight']) >= 1]
if out_ch:
    ch_counts = Counter(out_ch)
    print(f"\n  Output channel widths:")
    for ch, cnt in sorted(ch_counts.items()):
        bar = '█' * min(cnt, 30)
        print(f"    {ch:>6} ch  ×{cnt:>3}  {bar}")

# ════════════════════════════════════════════════════════════════════════════
print(f"\n{SEP}")
print("  5. ACTIVATION FUNCTIONS")
print(SEP)
# SiLU = x * sigmoid(x)
silu_count = 0
for i, node in enumerate(nodes):
    if node.op_type == 'Sigmoid':
        sig_out = node.output[0] if node.output else None
        for node2 in nodes[i:i+4]:
            if node2.op_type == 'Mul' and sig_out in node2.input:
                silu_count += 1
                break

print(f"  Relu          : {op_counts.get('Relu', 0)}")
print(f"  Sigmoid       : {op_counts.get('Sigmoid', 0)}")
print(f"  Softmax       : {op_counts.get('Softmax', 0)}")
print(f"  SiLU pattern  : ~{silu_count}  (Sigmoid→Mul, backbone activation)")
print(f"  Clip          : {op_counts.get('Clip', 0)}  (ReLU6-style)")

# ════════════════════════════════════════════════════════════════════════════
print(f"\n{SEP}")
print("  6. CLASSIFICATION HEAD")
print(SEP)
for node in nodes:
    if node.op_type in ('Gemm', 'MatMul'):
        for inp in node.input:
            dims = init_dims(inp)
            if dims:
                print(f"  {node.op_type} weight: {dims}")
for node in nodes:
    if node.op_type == 'AveragePool':
        attrs = {a.name: a for a in node.attribute}
        global_pool = attrs.get('global_pooling')
        kernel = [a.ints for a in node.attribute if a.name == 'kernel_shape']
        print(f"  AveragePool (global pooling → 1×1 feature map)")
for node in nodes:
    if node.op_type == 'Softmax':
        axis = next((a.i for a in node.attribute if a.name == 'axis'), '?')
        print(f"  Softmax (axis={axis}) — Note: app applies sigmoid, not softmax, in post-proc")

# ════════════════════════════════════════════════════════════════════════════
print(f"\n{SEP}")
print("  7. PARAMETER DISTRIBUTION")
print(SEP)
total_params = 0
total_bytes = 0
dtype_size = {1:4, 10:2, 11:8, 6:4, 7:8, 9:1}
section_params = Counter()

for init in graph.initializer:
    n = 1
    for d in init.dims: n *= d
    total_params += n
    total_bytes += n * dtype_size.get(init.data_type, 4)
    name = init.name.lower()
    if any(x in name for x in ['preprocess', 'stft', 'window', 'mean', 'std']):
        section_params['Preprocessing'] += n
    elif any(x in name for x in ['head', 'classifier', 'fc', 'gemm']):
        section_params['Head'] += n
    else:
        section_params['Backbone'] += n

print(f"  Total parameters : {total_params:>15,}")
print(f"  Total weight size: {total_bytes/1e6:>12.1f} MB  (actual stored, FP16)")
print(f"  FP32 equivalent  : {total_params*4/1e6:>12.1f} MB")
print()
for sec, cnt in sorted(section_params.items(), key=lambda x: -x[1]):
    pct = cnt/total_params*100
    bar = '█' * int(pct/3)
    print(f"  {sec:<20} {cnt:>14,}  ({pct:5.1f}%)  {bar}")

# ════════════════════════════════════════════════════════════════════════════
print(f"\n{SEP}")
print("  8. FULL ARCHITECTURE DIAGRAM")
print(SEP)
print("""
  ┌─────────────────────────────────────────────────────────────────┐
  │  INPUT: float32 [1, N]   N = samples (96k/160k/320k for 3/5/10s│
  └────────────────────────────┬────────────────────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Normalize           │
                    │  Sub(μ) / Div(σ)    │
                    │  μ,σ: learned [1,3,1,1]│
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  STFT               │
                    │  → complex spec     │
                    │  → |mag|  → log     │
                    └──────────┬──────────┘
                               │  [1, freq, time, 1]
                    ┌──────────▼──────────┐
                    │  Cast FP16 → FP32   │ ← 381× throughout graph
                    └──────────┬──────────┘
                               │
              ┌────────────────▼────────────────────┐
              │  EfficientNet-style Backbone         │
              │  ┌─────────────────────────────────┐ │
              │  │ Stem Conv (stride 2)             │ │
              │  └────────────────┬────────────────┘ │
              │                   │                   │
              │  ┌────────────────▼────────────────┐ │
              │  │ MBConv Block × N:                │ │
              │  │  DepthwiseConv (3×3 or 5×5)     │ │
              │  │  → SiLU (x * sigmoid(x))        │ │
              │  │  → SE attention (pool→fc→sigmoid)│ │
              │  │  → PointwiseConv (1×1)           │ │
              │  │  → residual Add                 │ │
              │  └────────────────┬────────────────┘ │
              │                   │  (repeated)       │
              └────────────────────────────────────── ┘
                               │
                    ┌──────────▼──────────┐
                    │  Global AveragePool  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Gemm               │
                    │  → embeddings       │
                    │     [1, 1280]       │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  MatMul             │
                    │  → logits [1, 5250] │
                    │  (sigmoid in app    │
                    │   post-processing)  │
                    └─────────────────────┘
""")
print("="*68 + "\n")
