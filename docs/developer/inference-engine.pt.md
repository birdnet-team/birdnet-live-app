<!-- TRANSLATION TODO (pt) -->

# Inference Engine

ONNX Runtime integration and model inference.

## Architecture

```
InferenceIsolate (compatibility wrapper; root Dart isolate)
  └─ InferenceService (high-level coordinator)
      └─ ClassifierModel (low-level ONNX session wrapper)
```

## ClassifierModel

Low-level `flutter_onnxruntime` session wrapper:

- `loadModelFromFile(path)` — create `OrtSession` from an on-device model file
- `predict(audioSamples, windowSamples)` — run inference, return `ModelOutput`
- Resolves output tensor indices by name (handles any graph ordering)

## InferenceService

High-level coordinator:

- `initialize(modelFilePath, labelsCsv, config)` — load model + parse labels
- `infer(audioSamples)` — model → temporal pooling → sensitivity → top-K
- Log-Mean-Exp temporal smoothing across recent windows (α=5.0, max 5 windows)

## InferenceIsolate

Keeps the historical public API while delegating to `InferenceService` on the root isolate:

- `start(modelFilePath, labelsCsv, config)` — load model from a resolved file path
- `infer(audioSamples)` — serialize the request and run it through the native session
- `stop()` — release the service and close native resources

`flutter_onnxruntime` runs native inference on a platform background queue, so there is no dedicated Dart inference isolate now. Inference calls are serialized before entering the native session.

## Geo-Model

`GeoModel` runs the smaller ONNX geo-model (~6 MB) through the same runtime:

- Input: `[latitude, longitude, week]` (normalized)
- Output: per-species probability scores
- Used for geographic species filtering

## Model Config

All model parameters are in `assets/models/model_config.json`:

- Tensor names, sample rate, window duration
- Label file format (delimiter, columns)
- Inference defaults (sensitivity, threshold, top-K, pooling)
