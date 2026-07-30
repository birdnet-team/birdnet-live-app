import 'package:birdnet_live/features/survey/widgets/survey_map_widget.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

AppLocalizations _l10n(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
}

void main() {
  group('Survey map accessibility widgets', () {
    testWidgets(
      'marker semantics expose species, confidence, audio, and confirmation',
      (tester) async {
        const label = 'Great Tit';
        await tester.pumpWidget(
          _host(
            SurveyMapMarkerSemantics(
              label: label,
              confidence: 0.87,
              hasAudio: true,
              isConfirmed: true,
              onTap: () {},
              child: const SizedBox(width: 48, height: 48),
            ),
          ),
        );

        final semantics = tester.ensureSemantics();
        try {
          final l10n = _l10n(tester);
          final markerFinder = find.bySemanticsLabel(label);

          expect(
            tester.getSemantics(markerFinder),
            matchesSemantics(
              label: label,
              value: buildSurveyMapMarkerSemanticsValue(
                l10n: l10n,
                confidence: 0.87,
                hasAudio: true,
                isConfirmed: true,
              ),
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasSelectedState: true,
              hasTapAction: true,
            ),
          );
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets('cluster bubble exposes localized detection count semantics', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const SurveyMapClusterBubble(count: 2)));

      final semantics = tester.ensureSemantics();
      try {
        final l10n = _l10n(tester);
        expect(
          find.bySemanticsLabel(l10n.sessionDetectionCount(2)),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('cluster bubble grows for larger counts', (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SurveyMapClusterBubble(count: 3),
              SurveyMapClusterBubble(count: 300),
            ],
          ),
        ),
      );

      final smallBubble = tester.getSize(
        find.byType(SurveyMapClusterBubble).at(0),
      );
      final largeBubble = tester.getSize(
        find.byType(SurveyMapClusterBubble).at(1),
      );

      expect(largeBubble.width, greaterThan(smallBubble.width));
      expect(largeBubble.height, greaterThan(smallBubble.height));
    });
  });
}
