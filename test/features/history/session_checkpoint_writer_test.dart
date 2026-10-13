import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/history/session_checkpoint_writer.dart';
import 'package:birdnet_live/features/history/session_repository.dart';
import 'package:birdnet_live/features/live/live_session.dart';

class _BlockingRepository extends SessionRepository {
  final firstWrite = Completer<void>();
  final savedNames = <String?>[];

  @override
  Future<void> saveCheckpoint(LiveSession session) async {
    savedNames.add(session.customName);
    if (savedNames.length == 1) await firstWrite.future;
  }
}

void main() {
  test(
    'a lifecycle checkpoint follows an in-progress periodic write',
    () async {
      final repository = _BlockingRepository();
      final session = LiveSession(
        id: 'checkpoint-writer',
        startTime: DateTime.now(),
        settings: const SessionSettings(
          windowDuration: 3,
          confidenceThreshold: 25,
          inferenceRate: 1,
          speciesFilterMode: 'off',
        ),
        customName: 'before',
      );
      final writer = SessionCheckpointWriter(
        repository: repository,
        session: () => session,
        shouldSave: () => true,
      );

      final first = writer.saveNow();
      session.customName = 'after';
      final second = writer.saveNow();
      repository.firstWrite.complete();
      await Future.wait([first, second]);
      await writer.stop();

      expect(repository.savedNames, ['before', 'after']);
    },
  );
}
