import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/features/settings/settings_screen.dart';
import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('appears below Inference rate and opens the modal overlay', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ignoredSpeciesCountProvider.overrideWith((ref) async => 2),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(settingsContext: SettingsContext.fileAnalysis),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ignore species'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      tester.getCenter(find.text('Inference rate')).dy,
      lessThan(tester.getCenter(find.text('Ignore species')).dy),
    );

    await tester.tap(find.text('Ignore species'));
    await tester.pumpAndSettle();
    expect(find.text('Birds'), findsOneWidget);
  });

  testWidgets('non-animal sounds are off by default and the switch persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ignoredSpeciesCountProvider.overrideWith((ref) async => 0),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(settingsContext: SettingsContext.fileAnalysis),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Non-animal sounds'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final tile = find.widgetWithText(SwitchListTile, 'Non-animal sounds');
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(
      tester.getCenter(find.text('Ignore species')).dy,
      lessThan(tester.getCenter(find.text('Non-animal sounds')).dy),
    );

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    expect(prefs.getBool(PrefKeys.includeSoundClasses), isTrue);
  });

  testWidgets('shows all ignore controls and persists checkbox changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ignoredSpeciesCountProvider.overrideWith((ref) async => 2),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _OverlayLauncher(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Ignore species'), findsOneWidget);
    expect(find.text('Birds'), findsOneWidget);
    expect(find.text('Mammals'), findsOneWidget);
    expect(find.text('Amphibians'), findsOneWidget);
    expect(find.text('Insects'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('2 species ignored'), findsOneWidget);

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 0.8);
    expect(slider.max, 1.0);

    await tester.tap(find.text('Mammals'));
    await tester.pump();

    expect(prefs.getBool(PrefKeys.ignoreMammals), isTrue);
  });
}

class _OverlayLauncher extends ConsumerWidget {
  const _OverlayLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => showIgnoreSpeciesSettingsSheet(context, ref),
          child: const Text('Open'),
        ),
      ),
    );
  }
}
