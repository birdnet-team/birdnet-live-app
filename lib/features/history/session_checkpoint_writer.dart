import 'dart:async';

import 'package:flutter/foundation.dart';

import '../live/live_session.dart';
import 'session_repository.dart';

/// Persists partial Live Mode and Point Count sessions during recording.
/// The writer is owned by the active screen and drained before final save.
class SessionCheckpointWriter {
  SessionCheckpointWriter({
    required this.repository,
    required this.session,
    required this.shouldSave,
    this.prepare,
  });

  static const interval = Duration(seconds: 30);

  final SessionRepository repository;
  final LiveSession? Function() session;
  final bool Function() shouldSave;
  final void Function(LiveSession)? prepare;
  Timer? _timer;
  Future<void>? _pending;
  bool _writeAgain = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(saveNow()));
    unawaited(saveNow());
  }

  Future<void> saveNow() {
    if (_pending != null) {
      _writeAgain = true;
      return _pending!;
    }
    final work = _drain();
    _pending = work;
    return work.whenComplete(() {
      if (identical(_pending, work)) _pending = null;
    });
  }

  Future<void> _drain() async {
    do {
      _writeAgain = false;
      try {
        final current = session();
        if (current == null) return;
        prepare?.call(current);
        if (shouldSave()) {
          await repository.saveCheckpoint(current);
        } else {
          await repository.deleteMetadataOnly(current.id);
        }
      } catch (error, stack) {
        debugPrint('Session checkpoint failed: $error\n$stack');
      }
    } while (_writeAgain);
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _pending;
  }

  void dispose() => _timer?.cancel();
}
