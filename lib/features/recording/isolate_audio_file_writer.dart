// =============================================================================
// Isolate Audio File Writer — encoding and file I/O on a worker isolate
// =============================================================================
//
// The FLAC encoder is pure Dart, and the UI isolate is also the platform
// thread on Android and iOS. Encoding there puts every second of a continuous
// recording on the thread that handles input, and a clip round for several
// species is hundreds of milliseconds of it. This writer keeps the real
// [FlacEncoder] / [WavWriter] on a worker isolate and forwards the same calls,
// so [RecordingService] uses it exactly like the writer it wraps.
//
// Each call completes when the worker has finished it, which keeps the
// recording service's natural back-pressure: a flush that falls behind is
// still a flush that has not returned. Samples are copied into the worker —
// one Float32List per call, 128 KB per second of 32 kHz audio.
// =============================================================================

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'audio_file_writer.dart';
import 'flac_encoder.dart';
import 'wav_writer.dart';

/// An error raised by the worker while encoding or writing.
class AudioWriterException implements Exception {
  const AudioWriterException(this.message);

  final String message;

  @override
  String toString() => 'AudioWriterException: $message';
}

/// Streams samples to a FLAC or WAV file through a worker isolate.
class IsolateAudioFileWriter implements AudioFileWriter {
  IsolateAudioFileWriter({
    required this.filePath,
    required this.format,
    this.sampleRate = 32000,
  }) : assert(format == 'flac' || format == 'wav');

  @override
  final String filePath;

  /// `'flac'` or `'wav'`.
  final String format;

  /// Audio sample rate in Hz.
  final int sampleRate;

  Isolate? _isolate;
  SendPort? _commands;
  ReceivePort? _replies;
  StreamSubscription<Object?>? _repliesSub;
  final Map<int, Completer<Object?>> _pending = {};
  int _nextId = 0;
  bool _open = false;
  bool _closed = false;
  String? _failure;
  int _samplesWritten = 0;

  @override
  bool get isOpen => _open && !_closed;

  /// Why the worker went away, when it did: the writer is closed from that
  /// point, and the file holds whatever the worker had written by then.
  String? get failure => _failure;

  /// Samples handed to the worker so far; the final count after [close].
  int get samplesWritten => _samplesWritten;

  @override
  Future<void> open() async {
    if (_open || _closed) return;
    final replies = ReceivePort();
    final ready = Completer<SendPort>();
    _replies = replies;
    _repliesSub = replies.listen((message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      _onReply(message);
    });
    try {
      _isolate = await Isolate.spawn(
        _workerMain,
        _WorkerInit(
          replyPort: replies.sendPort,
          filePath: filePath,
          format: format,
          sampleRate: sampleRate,
        ),
        onExit: replies.sendPort,
        onError: replies.sendPort,
        debugName: 'audio-file-writer',
      );
      _commands = await ready.future;
      await _send('open');
      _open = true;
    } catch (_) {
      await _shutdown();
      rethrow;
    }
  }

  @override
  Future<void> writeSamples(Float32List samples) async {
    if (!isOpen) {
      final failure = _failure;
      if (failure != null) throw AudioWriterException(failure);
      throw StateError(
        'IsolateAudioFileWriter is not open. Call open() first.',
      );
    }
    await _send('write', samples);
    _samplesWritten += samples.length;
  }

  @override
  Future<void> close() async {
    if (!_open || _closed) return;
    _closed = true;
    try {
      final written = await _send('close');
      if (written is int) _samplesWritten = written;
    } finally {
      await _shutdown();
    }
  }

  Future<Object?> _send(String op, [Object? payload]) {
    final commands = _commands;
    if (commands == null) {
      return Future.error(const AudioWriterException('Worker is not running'));
    }
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    commands.send([id, op, payload]);
    return completer.future;
  }

  void _onReply(Object? message) {
    if (message is List && message.length >= 2 && message[0] is int) {
      final completer = _pending.remove(message[0] as int);
      if (completer == null) return;
      if (message[1] == 'error') {
        completer.completeError(AudioWriterException(message[2].toString()));
      } else {
        completer.complete(message.length > 2 ? message[2] : null);
      }
      return;
    }
    // Anything else is the worker's exit or an uncaught error in it. After a
    // close that exit is expected; otherwise every call still waiting can no
    // longer be answered, and nothing more can be written. The writer closes
    // itself here so the recording service stops flushing into it instead of
    // failing on every tick, and [close] has nothing left to send.
    if (_closed) return;
    final reason = message == null
        ? 'Worker exited'
        : 'Worker failed: ${message is List ? message.first : message}';
    _failure ??= reason;
    _closed = true;
    _failPending(reason);
    unawaited(_shutdown());
  }

  /// Kill the worker as if it had crashed; the exit lands as a message.
  @visibleForTesting
  void killWorkerForTesting() {
    _isolate?.kill(priority: Isolate.immediate);
  }

  void _failPending(String reason) {
    final waiting = _pending.values.toList();
    _pending.clear();
    for (final completer in waiting) {
      if (!completer.isCompleted) {
        completer.completeError(AudioWriterException(reason));
      }
    }
    _commands = null;
  }

  Future<void> _shutdown() async {
    _failPending('Worker shut down');
    await _repliesSub?.cancel();
    _repliesSub = null;
    _replies?.close();
    _replies = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commands = null;
  }
}

class _WorkerInit {
  const _WorkerInit({
    required this.replyPort,
    required this.filePath,
    required this.format,
    required this.sampleRate,
  });

  final SendPort replyPort;
  final String filePath;
  final String format;
  final int sampleRate;
}

Future<void> _workerMain(_WorkerInit init) async {
  final commands = ReceivePort();
  init.replyPort.send(commands.sendPort);

  AudioFileWriter? writer;
  await for (final message in commands) {
    final list = message as List;
    final id = list[0] as int;
    final op = list[1] as String;
    try {
      switch (op) {
        case 'open':
          writer = init.format == 'flac'
              ? FlacEncoder(
                  filePath: init.filePath,
                  sampleRate: init.sampleRate,
                )
              : WavWriter(filePath: init.filePath, sampleRate: init.sampleRate);
          await writer.open();
          init.replyPort.send([id, 'ok']);
        case 'write':
          final target = writer;
          if (target == null) throw StateError('Writer is not open');
          await target.writeSamples(list[2] as Float32List);
          init.replyPort.send([id, 'ok']);
        case 'close':
          final target = writer;
          var written = 0;
          if (target != null) {
            await target.close();
            written = target is FlacEncoder
                ? target.totalSamples
                : (target as WavWriter).samplesWritten;
          }
          init.replyPort.send([id, 'ok', written]);
          commands.close();
          return;
        default:
          throw ArgumentError.value(op, 'op', 'Unknown writer command');
      }
    } catch (error) {
      init.replyPort.send([id, 'error', error.toString()]);
      if (op == 'close') {
        commands.close();
        return;
      }
    }
  }
}
