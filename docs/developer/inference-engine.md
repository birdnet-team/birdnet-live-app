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
- `infer(audioSamples)` — model → sensitivity → temporal pooling → top-K
- Log-Mean-Exp temporal smoothing across recent windows (α=5.0, max 5 windows)

## InferenceIsolate

Keeps the historical public API while delegating to `InferenceService` on the root isolate:

- `start(modelFilePath, labelsCsv, config)` — load model from a resolved file path
- `infer(audioSamples)` — serialize the request and run it through the native session
- `stop()` — release the service and close native resources

`flutter_onnxruntime` runs native inference on a platform background queue, so there is no longer a dedicated Dart inference isolate. Inference calls are serialized before entering the native session.

## Geo-Model

`GeoModel` runs the smaller ONNX geo-model (~8 MB) through the same runtime:

- Input: `[latitude, longitude, week]`, in degrees and week 1-48
- Output: per-species probability scores
- Used for geographic species filtering

The geo-model covers exactly the animal species of the audio model. Its labels
file names output `i` on line `i`, so `GeoModel` rejects a line it cannot
parse and an output whose length differs from the label count instead of
continuing with misaligned scores.

## Labels and sound classes

`LabelParser` reads the audio labels CSV (`idx;birdnet_id;sci_name;com_name;class`)
with the delimiter and column names from the model config. It requires the
indices to be exactly `0..N-1` and the scientific names to be unique, and
`InferenceService` refuses a model output whose length differs from the label
count.

Most labels are animal species. A label whose `class` is not Aves, Mammalia,
Amphibia, or Insecta is a non-animal sound class (`Species.isSoundClass`).
Sound classes are masked to zero unless the user turns on **Non-animal
sounds** (`SpeciesIgnoreSettings.includeSoundClasses`). When reported, they
skip the geo filters and the "both models know it" restriction
(`SpeciesFilter`), because the geo-model has no output for them.

## Model Config

All model parameters are in `assets/models/model_config.json`:

- Tensor names, sample rate, window duration
- Label file format (delimiter, columns)
- Inference defaults (sensitivity, threshold, top-K, pooling)
- Display names and counts of both models and the taxonomy version; the About
  screen, the Help screen, and export metadata read them from here

How the files in `assets/models/` are produced is described in
[Updating the Models](model-update.md).
