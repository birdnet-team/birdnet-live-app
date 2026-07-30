// =============================================================================
// LiveScreenPresence Tests
// =============================================================================
//
// The Quick Listen home-screen widget uses this to reuse an existing Live Mode
// route without resetting its recording lifecycle.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:birdnet_live/features/live/live_screen.dart';

void main() {
  group('LiveScreenPresence', () {
    tearDown(() {
      while (LiveScreenPresence.isMounted) {
        final route = LiveScreenPresence.mountedRoute;
        if (route == null) break;
        LiveScreenPresence.unregister(route);
      }
    });

    test('reports absent until a screen registers', () {
      final route = _route();
      expect(LiveScreenPresence.isMounted, isFalse);

      LiveScreenPresence.register(route, onStartListening: () {});
      expect(LiveScreenPresence.isMounted, isTrue);
      expect(LiveScreenPresence.mountedRoute, same(route));

      LiveScreenPresence.unregister(route);
      expect(LiveScreenPresence.isMounted, isFalse);
    });

    test('stays present while one Live Mode route replaces another', () {
      final outgoing = _route();
      final incoming = _route();
      LiveScreenPresence.register(outgoing, onStartListening: () {});

      LiveScreenPresence.register(incoming, onStartListening: () {});
      LiveScreenPresence.unregister(outgoing);

      expect(LiveScreenPresence.isMounted, isTrue);
      expect(LiveScreenPresence.mountedRoute, same(incoming));

      LiveScreenPresence.unregister(incoming);
      expect(LiveScreenPresence.isMounted, isFalse);
    });

    test('sends start requests only to the selected mounted route', () {
      final first = _route();
      final second = _route();
      var firstRequests = 0;
      var secondRequests = 0;
      LiveScreenPresence.register(
        first,
        onStartListening: () => firstRequests++,
      );
      LiveScreenPresence.register(
        second,
        onStartListening: () => secondRequests++,
      );

      LiveScreenPresence.requestStartListening(second);

      expect(firstRequests, 0);
      expect(secondRequests, 1);
    });

    test('ignores an unregister for an unknown route', () {
      final registered = _route();
      LiveScreenPresence.register(registered, onStartListening: () {});

      LiveScreenPresence.unregister(_route());

      expect(LiveScreenPresence.isMounted, isTrue);
      expect(LiveScreenPresence.mountedRoute, same(registered));
    });

    testWidgets('prefers the visible route over the last registered one', (
      tester,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        WidgetsApp(
          navigatorKey: navigatorKey,
          color: const Color(0xFF000000),
          onGenerateRoute: (_) => _route(),
        ),
      );

      final under = _route();
      final visible = _route();
      navigatorKey.currentState!.push(under);
      navigatorKey.currentState!.push(visible);
      await tester.pumpAndSettle();

      // Registered in the order that makes insertion order disagree with what
      // the user is looking at: Quick Listen must reveal the visible screen.
      LiveScreenPresence.register(visible, onStartListening: () {});
      LiveScreenPresence.register(under, onStartListening: () {});

      expect(LiveScreenPresence.mountedRoute, same(visible));
    });
  });
}

Route<void> _route() {
  return PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox());
}
