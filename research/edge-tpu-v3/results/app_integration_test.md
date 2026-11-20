| Backend | mean ms | p95 ms | batch-16 ms/window | × real-time | frontend / classifier / channel ms | top-1 vs ONNX | max |Δ| | det ≥0.35 (ONNX → this, both) |
|---|---|---|---|---|---|---|---|---|
| ONNX CPU | 85.1 | 100.0 | 61.6 | 49 | – | – | – | – |
| LiteRT tpu (ran on tpu, load 6285 ms) | 29.3 | 39.4 | 20.4 | 147 | 9.7 / 5.4 / 4.1 | 100.0 % | 0.051 | 55 → 53, 53 |
| LiteRT gpu (ran on gpu, load 1309 ms) | 52.3 | 64.9 | 47.2 | 64 | 12.9 / 30.5 / 4.3 | 100.0 % | 0.020 | 55 → 54, 54 |
| LiteRT cpu (ran on cpu, load 257 ms) | 157.3 | 185.8 | 142.5 | 21 | 5.5 / 132.9 / 4.8 | 100.0 % | 0.017 | 55 → 55, 55 |
