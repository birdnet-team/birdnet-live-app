import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/audio/ring_buffer.dart';
import 'package:birdnet_live/features/live/live_controller.dart';
import 'package:birdnet_live/features/recording/recording_service.dart';

// =============================================================================
// LiveController.loadModel() — concurrency contract
// =============================================================================
//
// The main menu warms the model up in the background so that opening Live Mode
// is fast.  That means loadModel() is now genuinely called concurrently: once
// by the menu, and again by the Live screen if the user gets there before the
// warm-up finishes.  These tests pin the guarantees the Live screen relies on.
//
// The model itself cannot load under `flutter test` (no path_provider, no
// bundled ONNX), so every load here settles into [LiveState.error].  That is
// fine — and deliberate: the contract under test is about *joining* and
// *settling*, and the error path is also the one that used to strand the user.
// =============================================================================

LiveController buildController() {
  final ringBuffer = RingBuffer();
  return LiveController(
    ringBuffer: ringBuffer,
    recordingService: RecordingService(ringBuffer: ringBuffer),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('concurrent callers join one load instead of starting a second', () async {
    final controller = buildController();

    // One load notifies exactly twice: once entering `loading`, once settling.
    // A duplicate load would push this to four.
    var notifications = 0;
    controller.onStateChanged = () => notifications++;

    final fromWarmUp = controller.loadModel();
    final fromLiveScreen = controller.loadModel();

    expect(
      identical(fromWarmUp, fromLiveScreen),
      isTrue,
      reason: 'the second caller should be handed the in-flight load',
    );

    await Future.wait([fromWarmUp, fromLiveScreen]);

    expect(notifications, 2, reason: 'exactly one load should have run');
  });

  test('the returned future never completes while the model is still loading', () async {
    final controller = buildController();

    await controller.loadModel();

    // The whole point: `await loadModel()` is enough to know the load is over,
    // so callers can check `state` afterwards without racing it.
    expect(controller.state, isNot(LiveState.loading));
    expect(controller.state, LiveState.error);
  });

  test('a load that failed can be retried', () async {
    final controller = buildController();

    await controller.loadModel();
    expect(controller.state, LiveState.error);

    // A failed warm-up must not wedge the controller: the Live screen retries
    // on entry, and the error banner offers a retry button. Both must be able
    // to start a genuinely new attempt rather than get the settled future back.
    var notifications = 0;
    controller.onStateChanged = () => notifications++;

    await controller.loadModel();

    expect(notifications, 2, reason: 'the retry should have run a fresh load');
    expect(controller.state, LiveState.error);
  });

  // Not covered here: the guard that stops loadModel() reloading the model
  // while a session is `active`/`paused`. Reaching that state needs real audio
  // hardware and a loaded isolate, neither of which exists under `flutter
  // test`, and a test that cannot actually reach the state would assert
  // nothing while implying otherwise.
}
