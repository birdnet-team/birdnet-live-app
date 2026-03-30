// =============================================================================
// Inference Isolate — Background ONNX inference via Dart Isolate
// =============================================================================
//
// The `onnxruntime` package uses dart:ffi, which means it CAN run in a Dart
// isolate (unlike platform-channel-based plugins).  This class manages a
// long-lived background isolate that:
//
//   1. Loads the ONNX model once on start-up (using the supplied config).
//   2. Accepts audio chunks via [SendPort] messages.
//   3. Returns detection results back to the main isolate.
//
// ### Why an isolate?
//
// Even though the native ONNX Runtime engine runs inference off-thread, the
// Dart-side pre-/post-processing (sigmoid over N values, sensitivity scaling,
// sorting) can take several milliseconds.  Running this work in a separate
// isolate prevents any chance of UI jank during rapid inference cycles.
//
// ### Message protocol
//
// Main → Worker:
//   - [InferenceRequest] — audio samples + configuration
//   - `null` — shutdown signal
//
// Worker → Main:
//   - [InferenceResult] — list of [Detection]s
//   - [InferenceError] — exception description
//
// ### Usage
//
// ```dart
// final isolate = InferenceIsolate();
// await isolate.start(
//   modelFilePath: '/path/to/model.onnx',
//   labelsCsv: '...',
//   config: modelConfig,
// );
// final detections = await isolate.infer(audioSamples);
// await isolate.stop();
// ```
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'inference_service.dart';
import 'model_config.dart';
import 'models/detection.dart';

// =============================================================================
// Public API
// =============================================================================

/// Manages a background isolate for ONNX model inference.
///
/// Start the isolate with [start], send work with [infer], and clean up
/// with [stop].
class InferenceIsolate {
  Isolate? _isolate;
  SendPort? _sendPort;
  final _responseCompleter = <int, Completer<List<Detection>>>{};
  int _nextRequestId = 0;
  StreamSubscription<dynamic>? _responseSubscription;

  /// Whether the background isolate is running and ready.
  bool get isRunning => _isolate != null && _sendPort != null;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Spawn the background isolate and load the model from a file.
  ///
  /// [modelFilePath] — absolute path to the `.onnx` model file on disk.
  /// [labelsCsv] — full content of the labels file.
  /// [config] — model configuration (tensor names, label format, defaults).
  ///
  /// Loading from a file path instead of raw bytes avoids serialising ~259 MB
  /// through the isolate port, which would triple peak memory usage.
  ///
  /// This method waits until the worker isolate has fully initialized the
  /// ONNX session.  If initialisation fails, the future completes with an
  /// error.
  Future<void> start({
    required String modelFilePath,
    required String labelsCsv,
    required ModelConfig config,
  }) async {
    if (isRunning) return;

    final receivePort = ReceivePort();

    debugPrint('[InferenceIsolate] spawning worker …');
    _isolate = await Isolate.spawn(
      _workerEntryPoint,
      _WorkerInit(
        sendPort: receivePort.sendPort,
        modelFilePath: modelFilePath,
        labelsCsv: labelsCsv,
        configJson: config.toJson(),
      ),
    );
    debugPrint('[InferenceIsolate] worker spawned');

    final sendPortCompleter = Completer<SendPort>();
    final readyCompleter = Completer<void>();

    _responseSubscription = receivePort.listen((message) {
      if (message is SendPort) {
        sendPortCompleter.complete(message);
      } else if (message is _WorkerReady) {
        readyCompleter.complete();
      } else if (message is _WorkerInitError) {
        readyCompleter.completeError(Exception(message.error));
      } else if (message is _WorkerResponse) {
        final c = _responseCompleter.remove(message.requestId);
        if (c != null) {
          if (message.error != null) {
            c.completeError(Exception(message.error));
          } else {
            c.complete(message.detections);
          }
        }
      }
    });

    _sendPort = await sendPortCompleter.future;
    debugPrint('[InferenceIsolate] waiting for model init …');
    await readyCompleter.future;
    debugPrint('[InferenceIsolate] model ready');
  }

  /// Stop the background isolate and free resources.
  Future<void> stop() async {
    _sendPort?.send(null); // Shutdown signal.
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    await _responseSubscription?.cancel();
    _responseSubscription = null;

    // Complete any pending futures with an error.
    for (final c in _responseCompleter.values) {
      c.completeError(StateError('Inference isolate stopped'));
    }
    _responseCompleter.clear();
  }

  // ---------------------------------------------------------------------------
  // Inference
  // ---------------------------------------------------------------------------

  /// Run inference on [audioSamples] in the background isolate.
  ///
  /// Parameters that are not supplied fall back to the active [ModelConfig]
  /// defaults inside the worker.  Returns a list of [Detection] sorted by
  /// descending confidence.
  Future<List<Detection>> infer(
    Float32List audioSamples, {
    int? windowSeconds,
    double? sensitivity,
    double? confidenceThreshold,
    int? topK,
    bool useTemporalPooling = true,
  }) {
    if (!isRunning) {
      throw StateError('Inference isolate not started. Call start() first.');
    }

    final requestId = _nextRequestId++;
    final completer = Completer<List<Detection>>();
    _responseCompleter[requestId] = completer;

    _sendPort!.send(_WorkerRequest(
      requestId: requestId,
      audioSamples: audioSamples,
      windowSeconds: windowSeconds,
      sensitivity: sensitivity,
      confidenceThreshold: confidenceThreshold,
      topK: topK,
      useTemporalPooling: useTemporalPooling,
    ));

    return completer.future;
  }

  /// Clear the temporal pooling buffer in the background isolate.
  void resetPooling() {
    _sendPort?.send(const _WorkerResetPooling());
  }
}

// =============================================================================
// Worker isolate entry point
// =============================================================================

/// Top-level function that runs inside the background isolate.
///
/// Receives an [_WorkerInit] with the model path and labels CSV, initializes
/// the [InferenceService], then processes [_WorkerRequest] messages in a loop.
Future<void> _workerEntryPoint(_WorkerInit init) async {
  final receivePort = ReceivePort();

  // Send our SendPort back so the main isolate can talk to us.
  init.sendPort.send(receivePort.sendPort);

  final config = ModelConfig.fromJson(
    Map<String, dynamic>.from(init.configJson),
  );

  // Initialize the model — signal success or failure back to main isolate.
  final InferenceService service;
  try {
    debugPrint(
        '[InferenceIsolate] loading model from file: ${init.modelFilePath}');
    final modelFile = File(init.modelFilePath);
    final modelBytes = await modelFile.readAsBytes();
    debugPrint('[InferenceIsolate] model bytes read: ${modelBytes.length}');

    final svc = InferenceService();
    await svc.initialize(
      modelBytes: modelBytes,
      labelsCsv: init.labelsCsv,
      config: config,
    );
    service = svc;
    debugPrint('[InferenceIsolate] model initialized');
    init.sendPort.send(const _WorkerReady());
  } catch (e) {
    debugPrint('[InferenceIsolate] init error: $e');
    init.sendPort.send(_WorkerInitError(e.toString()));
    receivePort.close();
    return;
  }

  // Process inference requests.
  await for (final message in receivePort) {
    if (message == null) {
      // Shutdown signal.
      service.dispose();
      receivePort.close();
      break;
    }

    if (message is _WorkerResetPooling) {
      service.resetPooling();
      continue;
    }

    if (message is _WorkerRequest) {
      debugPrint('[InferenceIsolate] processing request #${message.requestId} '
          '(${message.audioSamples.length} samples)');
      try {
        final detections = await service.infer(
          message.audioSamples,
          windowSeconds: message.windowSeconds,
          sensitivity: message.sensitivity,
          confidenceThreshold: message.confidenceThreshold,
          topK: message.topK,
          useTemporalPooling: message.useTemporalPooling,
        );
        debugPrint('[InferenceIsolate] request #${message.requestId} → '
            '${detections.length} detections');
        init.sendPort.send(_WorkerResponse(
          requestId: message.requestId,
          detections: detections,
        ));
      } catch (e, st) {
        debugPrint('[InferenceIsolate] request #${message.requestId} ERROR: '
            '$e\n$st');
        init.sendPort.send(_WorkerResponse(
          requestId: message.requestId,
          detections: const [],
          error: e.toString(),
        ));
      }
    }
  }
}

// =============================================================================
// Message types (internal, not exported)
// =============================================================================

/// Initialisation data sent to the worker isolate.
class _WorkerInit {
  const _WorkerInit({
    required this.sendPort,
    required this.modelFilePath,
    required this.labelsCsv,
    required this.configJson,
  });
  final SendPort sendPort;

  /// Absolute path to the `.onnx` model file on the device filesystem.
  ///
  /// The isolate reads the file directly, avoiding the need to serialize
  /// hundreds of megabytes of model bytes through the isolate port.
  final String modelFilePath;
  final String labelsCsv;

  /// Serialized [ModelConfig] as a JSON map.
  ///
  /// We pass a plain map instead of [ModelConfig] because [Isolate.spawn]
  /// can only send primitive/transferable types.
  final Map<String, dynamic> configJson;
}

/// Inference request sent from main → worker.
class _WorkerRequest {
  const _WorkerRequest({
    required this.requestId,
    required this.audioSamples,
    this.windowSeconds,
    this.sensitivity,
    this.confidenceThreshold,
    this.topK,
    required this.useTemporalPooling,
  });
  final int requestId;
  final Float32List audioSamples;
  final int? windowSeconds;
  final double? sensitivity;
  final double? confidenceThreshold;
  final int? topK;
  final bool useTemporalPooling;
}

/// Response sent from worker → main.
class _WorkerResponse {
  const _WorkerResponse({
    required this.requestId,
    required this.detections,
    this.error,
  });
  final int requestId;
  final List<Detection> detections;
  final String? error;
}

/// Signal to reset the temporal pooling buffer.
class _WorkerResetPooling {
  const _WorkerResetPooling();
}

/// Signal that the worker has finished initialising the model.
class _WorkerReady {
  const _WorkerReady();
}

/// Signal that the worker failed to initialize the model.
class _WorkerInitError {
  const _WorkerInitError(this.error);
  final String error;
}
