import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/history/session_library_screen.dart';
import 'package:birdnet_live/features/live/live_providers.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  LiveSession makeSession() => LiveSession(
    id: 'test-session',
    startTime: DateTime(2026, 9, 30, 9),
    endTime: DateTime(2026, 9, 30, 9, 5),
    settings: const SessionSettings(
      windowDuration: 3,
      confidenceThreshold: 25,
      inferenceRate: 1,
      speciesFilterMode: 'off',
    ),
  );

  Future<GlobalKey<NavigatorState>> pumpLibraryStack(
    WidgetTester tester, {
    List<LiveSession> sessions = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionListProvider.overrideWith((ref) async => sessions),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
          effectiveSpeciesLocaleProvider.overrideWith((ref) => 'en'),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('Main menu')),
        ),
      ),
    );

    final navigator = navigatorKey.currentState!;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Previous session')),
      ),
    );
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const SessionLibraryScreen()),
    );
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const SessionLibraryScreen()),
    );
    await tester.pumpAndSettle();
    return navigatorKey;
  }

  testWidgets('back arrow skips earlier sessions and libraries', (
    tester,
  ) async {
    final navigatorKey = await pumpLibraryStack(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Main menu'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('system back skips earlier sessions and libraries', (
    tester,
  ) async {
    final navigatorKey = await pumpLibraryStack(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Main menu'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('system back clears selection before leaving library', (
    tester,
  ) async {
    final navigatorKey = await pumpLibraryStack(
      tester,
      sessions: [makeSession()],
    );

    await tester.longPress(find.byKey(const ValueKey('swipe-test-session')));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsNothing);
    expect(find.byKey(const ValueKey('swipe-test-session')), findsOneWidget);
    expect(find.text('Main menu'), findsNothing);
    expect(navigatorKey.currentState!.canPop(), isTrue);
  });
}
