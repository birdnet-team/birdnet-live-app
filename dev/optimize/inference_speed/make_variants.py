"""Generate model variants of the shipped BirdNET+ FP16 ONNX for on-device speed tests.

Usage: python -I make_variants.py <src.onnx> <out_dir>
"""
import sys, os, collections
import numpy as np
import onnx
from onnx import numpy_helper, helper, TensorProto, shape_inference

src, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(out_dir, exist_ok=True)
base = onnx.load(src)

FRONTEND_OUT = "div_1"  # fp16 [B,3,224,W] image fed into the first Conv


def save(m, name):
    path = os.path.join(out_dir, name)
    onnx.save(m, path)
    print("wrote", name, round(os.path.getsize(path) / 1e6, 1), "MB")


def remove_casts(m):
    """Rewire every Cast node away and upcast all fp16 initializers to fp32."""
    g = m.graph
    rename = {}
    keep = []
    for n in g.node:
        if n.op_type == "Cast":
            rename[n.output[0]] = n.input[0]
        else:
            keep.append(n)

    def resolve(name):
        while name in rename:
            name = rename[name]
        return name

    del g.node[:]
    g.node.extend(keep)
    for n in g.node:
        for i, name in enumerate(n.input):
            n.input[i] = resolve(name)
    # graph outputs that were produced by a Cast need an Identity
    for o in g.output:
        if o.name in rename:
            g.node.append(helper.make_node("Identity", [resolve(o.name)], [o.name]))
    for t in g.initializer:
        if t.data_type == TensorProto.FLOAT16:
            arr = numpy_helper.to_array(t).astype(np.float32)
            t.CopyFrom(numpy_helper.from_array(arr, t.name))
    for vi in list(g.value_info):
        if vi.type.tensor_type.elem_type == TensorProto.FLOAT16:
            vi.type.tensor_type.elem_type = TensorProto.FLOAT
    return m


def fix_samples(m, samples=96000):
    m.graph.input[0].type.tensor_type.shape.dim[1].dim_value = samples
    return m


def strip_se_casts(m):
    """Drop the fp16->fp32->ReduceMean->fp16 bracket around the SE pooling.

    ORT will reinsert casts itself if the fp16 ReduceMean kernel is missing on
    the target, so this is lossless in the worst case.
    """
    g = m.graph
    prod = {o: n for n in g.node for o in n.output}
    rename = {}
    drop = set()
    fixed = set()
    for n in g.node:
        if n.op_type != "ReduceMean":
            continue
        src_cast = prod.get(n.input[0])
        if src_cast is None or src_cast.op_type != "Cast":
            continue
        consumers = [c for c in g.node if n.output[0] in c.input]
        if len(consumers) != 1 or consumers[0].op_type != "Cast":
            continue
        dst_cast = consumers[0]
        rename[src_cast.output[0]] = src_cast.input[0]
        rename[dst_cast.output[0]] = n.output[0]
        drop.add(id(src_cast)); drop.add(id(dst_cast)); fixed.add(n.output[0])
    keep = [n for n in g.node if id(n) not in drop]
    del g.node[:]
    g.node.extend(keep)
    for n in g.node:
        for i, name in enumerate(n.input):
            if name in rename:
                n.input[i] = rename[name]
    for vi in g.value_info:
        if vi.name in fixed and vi.type.tensor_type.elem_type == TensorProto.FLOAT:
            vi.type.tensor_type.elem_type = TensorProto.FLOAT16
    print("  stripped", len(drop), "SE casts")
    return m


def split(m, name_front, name_back):
    import onnx.utils
    tmp = os.path.join(out_dir, "_tmp.onnx")
    onnx.save(m, tmp)
    onnx.utils.extract_model(tmp, os.path.join(out_dir, name_front), ["input"], [FRONTEND_OUT], check_model=False)
    onnx.utils.extract_model(tmp, os.path.join(out_dir, name_back), [FRONTEND_OUT], ["predictions", "embeddings_out"], check_model=False)
    os.remove(tmp)
    # give the backbone a concrete input shape for 3 s windows
    bb = onnx.load(os.path.join(out_dir, name_back))
    inp = bb.graph.input[0]
    inp.type.tensor_type.elem_type = TensorProto.FLOAT16
    del inp.type.tensor_type.shape.dim[:]
    for d in ("batch_size", 3, 224, 281):
        dim = inp.type.tensor_type.shape.dim.add()
        if isinstance(d, str): dim.dim_param = d
        else: dim.dim_value = d
    save(bb, name_back)
    print("wrote", name_front)


import copy
save(copy.deepcopy(base), "v0_fp16.onnx")
save(fix_samples(copy.deepcopy(base)), "v2_fp16_static96k.onnx")
save(strip_se_casts(copy.deepcopy(base)), "v6_fp16_nosecast.onnx")
fp32 = remove_casts(copy.deepcopy(base))
onnx.checker.check_model(fp32)
save(fp32, "v1_fp32.onnx")
split(copy.deepcopy(base), "v3_frontend_fp16.onnx", "v3_backbone_fp16.onnx")
