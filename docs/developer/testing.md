# Testing

Testing strategy and running tests.

## Running Tests

```bash
# Run all unit tests
flutter test

# Run a specific test file
flutter test test/features/inference/classifier_model_test.dart

# Run with coverage
flutter test --coverage
```

## Test Coverage

There are 426 unit tests across 24 test files, plus 3 integration tests. All tests are pure Dart (no widget tests requiring `testWidgets`).

## Integration Tests

Integration tests require a connected device or emulator, with the test fixtures pushed to it first:

```bash
adb shell rm -rf /data/local/tmp/test_fixtures
adb push assets/test_fixtures /data/local/tmp/test_fixtures
flutter test integration_test/model_output_test.dart -d <device_id>
```

Remove the old directory first; pushing onto an existing one nests the new
files inside it. From Git Bash on Windows, prefix the `adb` commands with
`MSYS_NO_PATHCONV=1` so the device paths are not rewritten.

| Test | Purpose |
|------|---------|
| `model_output_test.dart` | Validates ONNX model output against reference detections, checks the output size against the model config, and compares batched with single-window inference |
| `geo_soundscape_test.dart` | Geo-model predictions and the audio model on a soundscape, end to end |
| `memory_stress_test.dart` | Long-running session memory profiling |
| `inference_rate_benchmark_test.dart` | Inference rate the device sustains |
| `native_mp3_file_analysis_test.dart` | Native MP3 decoding for File Analysis |
| `aru_deployment_test.dart` | ARU deployment storage |

The reference detections belong to one model. After a model change, regenerate
them with `python dev/run_onnx_reference.py`, which rewrites
`assets/test_fixtures/test_windows.bin` and `test_windows_meta.json`, and push
the fixtures again. `model_output_test.dart` fails with a clear message when
the pushed fixtures were made for a different model.

The developer's phones carry real Sessions. Run these tests on an emulator, or
on a phone only with a build signed like the installed app (see
`AGENTS.md`, Device Testing).

## Test Structure

Tests mirror the `lib/` directory structure:

```
test/
  features/
    inference/
      classifier_model_test.dart
      geo_model_test.dart
      inference_service_test.dart
      ...
    spectrogram/
      fft_processor_test.dart
      color_maps_test.dart
      spectrogram_painter_test.dart
    live/
      live_session_test.dart
      ...
  shared/
    ...
```

## Integration Tests

ONNX model integration tests that require the actual model file:

```bash
flutter test integration_test/
```

These are slow and require the model asset to be present.

## Test Fixtures

Test data is in `assets/test_fixtures/` and `build/test_cache/`. Reference detection outputs for regression testing are in `dev/reference_detections.json`.
