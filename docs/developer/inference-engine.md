# Inference Engine

ONNX Runtime integration and model inference.

## Architecture

```
InferenceIsolate (background Dart isolate)
  └─ InferenceService (high-level coordinator)
      └─ ClassifierModel (low-level ONNX session wrapper)
```

## ClassifierModel

Direct ONNX Runtime FFI wrapper:

- `loadModel(bytes)` / `loadModelFromFile(path)` — create `OrtSession`
- `predict(audioSamples, windowSamples)` — run inference, return `ModelOutput`
- Resolves output tensor indices by name (handles any graph ordering)

## InferenceService

High-level coordinator:

- `initialize(modelBytes, labelsCsv, config)` — load model + parse labels
- `infer(audioSamples)` — model → temporal pooling → sensitivity → top-K
- Log-Mean-Exp temporal smoothing across recent windows (α=5.0, max 5 windows)

## InferenceIsolate

Runs `InferenceService` in a background Dart isolate:

- `start(modelFilePath, labelsCsv, config)` — spawn isolate, load model
- `infer(audioSamples)` — send request via `SendPort`, await response
- `stop()` — kill isolate and clean up

The model file path (not bytes) is sent to the isolate to avoid serializing ~259 MB.

## Geo-Model

`GeoModel` runs a smaller ONNX model (~7 MB) on the main thread:

- Input: `[latitude, longitude, week]` (normalized)
- Output: per-species probability scores
- Used for geographic species filtering

## Model Config

All model parameters are in `assets/models/model_config.json`:

- Tensor names, sample rate, window duration
- Label file format (delimiter, columns)
- Inference defaults (sensitivity, threshold, top-K, pooling)
