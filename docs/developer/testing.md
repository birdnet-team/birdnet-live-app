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

426 unit tests across 24 test files, plus 3 integration tests. All tests are pure Dart (no widget tests requiring `testWidgets`).

## Integration Tests

Integration tests require a connected device and test fixtures pushed to the device:

```bash
adb push assets/test_fixtures /data/local/tmp/test_fixtures
flutter test integration_test/model_output_test.dart -d <device_id>
```

| Test | Purpose |
|------|---------|
| `model_output_test.dart` | Validates ONNX model output against reference detections |
| `memory_stress_test.dart` | Long-running session memory profiling |
| `geo_soundscape_test.dart` | Geo-model + explore screen end-to-end |

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
