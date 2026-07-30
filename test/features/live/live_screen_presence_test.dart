// =============================================================================
// LiveScreenPresence Tests
// =============================================================================
//
// The Quick Listen home-screen widget uses this to decide whether tapping it
// should navigate (rebuilding Live Mode, which restarts the session-duration
// warning timer) or leave the visible session alone.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/features/live/live_screen.dart';

void main() {
  group('LiveScreenPresence', () {
    tearDown(() {
      // Drain any leftover registrations so one test can't leak into the next.
      while (LiveScreenPresence.isMounted) {
        LiveScreenPresence.unregister();
      }
    });

    test('reports absent until a screen registers', () {
      expect(LiveScreenPresence.isMounted, isFalse);

      LiveScreenPresence.register();
      expect(LiveScreenPresence.isMounted, isTrue);

      LiveScreenPresence.unregister();
      expect(LiveScreenPresence.isMounted, isFalse);
    });

    test('stays present while one Live Mode route replaces another', () {
      // pushAndRemoveUntil mounts the incoming screen before disposing the
      // outgoing one, so the overlap must not read as "no Live Mode on
      // screen" — that would let a second widget tap rebuild the session.
      LiveScreenPresence.register();

      LiveScreenPresence.register(); // incoming screen's initState
      LiveScreenPresence.unregister(); // outgoing screen's dispose

      expect(LiveScreenPresence.isMounted, isTrue);

      LiveScreenPresence.unregister();
      expect(LiveScreenPresence.isMounted, isFalse);
    });

    test('ignores an unbalanced unregister', () {
      LiveScreenPresence.unregister();
      expect(LiveScreenPresence.isMounted, isFalse);

      LiveScreenPresence.register();
      expect(LiveScreenPresence.isMounted, isTrue);
    });
  });
}
