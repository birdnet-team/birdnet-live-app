import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/features/settings/export_options_screens.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/providers/settings_providers.dart';

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() => container.dispose());

  Widget app(Widget home) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: home,
    ),
  );

  testWidgets('Formats screen toggles the export selection', (tester) async {
    await tester.pumpWidget(app(const ExportFormatsScreen()));
    await tester.pumpAndSettle();

    final before = container.read(exportSelectionProvider);
    expect(find.text('CSV'), findsOneWidget);
    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();

    final after = container.read(exportSelectionProvider);
    expect(after.contains('csv'), !before.contains('csv'));
  });

  testWidgets('Content screen shows WAV only while audio is on', (
    tester,
  ) async {
    await container.read(includeAudioProvider.notifier).set(false);
    await tester.pumpWidget(app(const ExportContentScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Always share audio as WAV'), findsNothing);

    await tester.tap(find.text('Include audio files'));
    await tester.pumpAndSettle();
    expect(container.read(includeAudioProvider), isTrue);
    expect(find.text('Always share audio as WAV'), findsOneWidget);

    final htmlBefore = container.read(exportHtmlReportProvider);
    await tester.tap(find.text('Include HTML report'));
    await tester.pumpAndSettle();
    expect(container.read(exportHtmlReportProvider), !htmlBefore);
  });

  test('summaries name the choices or say what an empty group means', () async {
    await withEnglishL10n((l10n) {
      expect(
        exportFormatsSummary(l10n, {'csv', 'raven'}),
        'Raven Selection Table, CSV',
      );
      expect(exportFormatsSummary(l10n, {}), 'None');
      expect(
        exportContentSummary(
          l10n,
          includeAudio: true,
          audioAsWav: true,
          htmlReport: true,
          appMetadata: false,
        ),
        'Audio (WAV), HTML report',
      );
      expect(
        exportContentSummary(
          l10n,
          includeAudio: false,
          audioAsWav: false,
          htmlReport: false,
          appMetadata: false,
        ),
        'Tables only',
      );
    });
  });
}

Future<void> withEnglishL10n(void Function(AppLocalizations l10n) body) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  body(l10n);
}
