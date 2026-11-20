import sys
import os
a = os.environ.get("FROM", "serving_default_node_div_1_output_cast_0:0").encode(); b = a.replace(b":", b"_")
for f in sys.argv[1:]:
    d = open(f, "rb").read(); n = d.count(a); open(f, "wb").write(d.replace(a, b)); print(f, "replaced", n)
