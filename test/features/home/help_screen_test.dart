import 'dart:convert';

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/core/theme/app_theme.dart';
import 'package:birdnet_live/features/home/help_screen.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:birdnet_live/shared/utils/session_type_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppLocalizations> showHelp(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1,
  ThemeData? theme,
}) async {
  // Asset I/O needs the real event loop before entering the widget's fake clock.
  await tester.runAsync(
    () => rootBundle.loadString(AppConstants.modelConfigAssetPath),
  );
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const HelpScreen(),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(HelpScreen)))!;
}

Finder topic(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(ExpansionTile));

Future<void> openTopic(WidgetTester tester, String title) async {
  await tester.ensureVisible(topic(title));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('jump links and floating button return to the introduction', (
    tester,
  ) async {
    final l10n = await showHelp(tester);
    expect(
      find.widgetWithText(FilledButton, l10n.aboutUserGuide),
      findsOneWidget,
    );
    expect(find.byTooltip(l10n.helpBackToTop), findsNothing);

    await tester.ensureVisible(
      find.widgetWithText(ActionChip, l10n.helpModelsTitle),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, l10n.helpModelsTitle));
    await tester.pumpAndSettle();
    expect(find.byTooltip(l10n.helpBackToTop), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, greaterThan(300));
    final header = find.text(l10n.helpModelsTitle).last;
    expect(tester.getTopLeft(header).dy, greaterThanOrEqualTo(0));
    expect(tester.getTopLeft(header).dy, lessThan(150));

    await tester.tap(find.byTooltip(l10n.helpBackToTop));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, 0);
    expect(find.byTooltip(l10n.helpBackToTop), findsNothing);
    expect(
      tester.getTopLeft(find.text(AppConstants.appName)).dy,
      lessThan(150),
    );
  });

  testWidgets(
    'mode purpose, availability, and configured models are explained',
    (tester) async {
      final l10n = await showHelp(tester);
      for (final type in SessionType.values) {
        expect(find.byIcon(sessionTypeIcon(type)), findsWidgets);
      }
      expect(find.byIcon(AppIcons.libraryMusic), findsOneWidget);
      expect(find.text(l10n.helpSurveySummary), findsOneWidget);
      await openTopic(tester, l10n.surveyMode);
      expect(find.text(l10n.helpSurveyBody), findsOneWidget);

      await openTopic(tester, l10n.batchAnalysisMode);
      expect(find.text(l10n.comingSoon), findsOneWidget);
      expect(find.text(l10n.helpBatchAnalysisBody), findsOneWidget);

      final config = jsonDecode(
        (await tester.runAsync(
          () => rootBundle.loadString(AppConstants.modelConfigAssetPath),
        ))!,
      );
      await openTopic(tester, l10n.helpAudioModelTitle);
      expect(find.text(config['audioModel']['name']), findsOneWidget);
      expect(find.text(l10n.helpAudioModelBody), findsOneWidget);
      await openTopic(tester, l10n.helpGeomodelTitle);
      expect(find.text('Geomodel'), findsOneWidget);
      expect(find.text(config['geoModel']['name']), findsOneWidget);
      expect(find.text(l10n.helpGeomodelBody), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      '${locale.languageCode}: expanded help fits a narrow screen with large text',
      (tester) async {
        await showHelp(
          tester,
          locale: locale,
          size: const Size(360, 800),
          textScale: 2,
          theme: AppTheme.highContrastDark(),
        );
        final tiles = find.byType(ExpansionTile);
        for (var i = 0; i < tiles.evaluate().length; i++) {
          final tile = tester.widget<ExpansionTile>(tiles.at(i));
          final title = find
              .descendant(
                of: find.byWidget(tile.title),
                matching: find.byType(Text),
              )
              .first;
          await tester.ensureVisible(title);
          await tester.pumpAndSettle();
          await tester.tap(title);
          await tester.pumpAndSettle();
          expect(find.byWidget(tile.children.first), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'Topic $i in ${locale.languageCode}',
          );
        }
      },
    );
  }

  for (final size in [const Size(844, 390), const Size(1024, 768)]) {
    testWidgets('help fits $size with a dynamic palette', (tester) async {
      final l10n = await showHelp(
        tester,
        size: size,
        locale: const Locale('de'),
        textScale: 2,
        theme: AppTheme.fromColorScheme(
          ColorScheme.fromSeed(seedColor: Colors.purple),
        ),
      );
      await openTopic(tester, l10n.helpGeomodelTitle);
      expect(
        tester.getSize(find.byType(SingleChildScrollView)).width,
        lessThanOrEqualTo(600),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
