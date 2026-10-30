"""Summarize an ONNX Runtime profile JSON (per op type, top nodes, inserted casts).

Usage: python -I analyze_profile.py <profile.json> [top_nodes=15]
"""
import sys, json, collections

ev = json.load(open(sys.argv[1], encoding="utf-8"))
top_n = int(sys.argv[2]) if len(sys.argv) > 2 else 15
by_op = collections.Counter()
by_node = collections.Counter()
node_op = {}
runs = 0
run_total = 0
for e in ev:
    if e.get("cat") == "Node" and e["name"].endswith("_kernel_time"):
        op = e["args"]["op_name"]
        by_op[op] += e["dur"]
        by_node[e["name"]] += e["dur"]
        node_op[e["name"]] = (op, e["args"].get("provider", ""), e["args"].get("input_type_shape", ""))
    if e.get("cat") == "Session" and e["name"] == "model_run":
        runs += 1
        run_total += e["dur"]
tot = sum(by_op.values())
print(f"runs={runs} avg model_run {run_total/max(runs,1)/1000:.1f} ms; kernel sum {tot/max(runs,1)/1000:.1f} ms/run")
for op, d in by_op.most_common(20):
    print(f"  {op:14s} {100*d/tot:5.1f}%  {d/runs/1000:7.2f} ms")
print("top nodes:")
for name, d in by_node.most_common(top_n):
    op, prov, shp = node_op[name]
    print(f"  {op:12s} {d/runs/1000:7.2f} ms  {name[:60]}  {str(shp)[:90]}")
inserted = [(n, d) for n, d in by_node.items() if "Inserted" in n]
if inserted:
    print(f"inserted casts: {len(inserted)} nodes, {sum(d for _, d in inserted)/runs/1000:.2f} ms/run")
