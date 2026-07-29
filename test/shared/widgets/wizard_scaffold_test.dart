// Tests for WizardScaffold (Phase 3).

import 'package:birdnet_live/core/theme/app_theme.dart';
import 'package:birdnet_live/shared/widgets/wizard_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required Widget Function(BuildContext) builder}) {
  return MaterialApp(
    theme: AppTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(builder: builder),
  );
}

void main() {
  group('WizardScaffold', () {
    testWidgets('renders title, footer labels, and step semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          builder:
              (_) => WizardScaffold(
                title: 'Setup',
                step: 1,
                totalSteps: 3,
                onBack: () {},
                onNext: () {},
                backLabel: 'Back',
                nextLabel: 'Next',
                child: const Text('content'),
              ),
        ),
      );

      expect(find.text('Setup'), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Back'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
    });

    testWidgets('disables Next button when onNext is null', (tester) async {
      await tester.pumpWidget(
        _host(
          builder:
              (_) => WizardScaffold(
                title: 'Setup',
                step: 0,
                totalSteps: 2,
                onBack: () {},
                onNext: null,
                backLabel: 'Cancel',
                nextLabel: 'Next',
                child: const SizedBox(),
              ),
        ),
      );

      final next = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );
      expect(next.onPressed, isNull);
    });

    testWidgets('uses FilledButton.icon when nextIcon is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          builder:
              (_) => WizardScaffold(
                title: 'Setup',
                step: 1,
                totalSteps: 2,
                onBack: () {},
                onNext: () {},
                backLabel: 'Back',
                nextLabel: 'Start',
                nextIcon: Icons.play_arrow,
                child: const SizedBox(),
              ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('hides footer when showFooter is false', (tester) async {
      await tester.pumpWidget(
        _host(
          builder:
              (_) => WizardScaffold(
                title: 'Setup',
                step: 0,
                totalSteps: 2,
                onBack: () {},
                onNext: () {},
                backLabel: 'Back',
                nextLabel: 'Next',
                showFooter: false,
                child: const SizedBox(),
              ),
        ),
      );

      expect(find.widgetWithText(TextButton, 'Back'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Next'), findsNothing);
    });

    testWidgets('invokes onBack and onNext callbacks', (tester) async {
      var backTaps = 0;
      var nextTaps = 0;
      await tester.pumpWidget(
        _host(
          builder:
              (_) => WizardScaffold(
                title: 'Setup',
                step: 0,
                totalSteps: 2,
                onBack: () => backTaps++,
                onNext: () => nextTaps++,
                backLabel: 'Back',
                nextLabel: 'Next',
                child: const SizedBox(),
              ),
        ),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Back'));
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pump();

      expect(backTaps, 1);
      expect(nextTaps, 1);
    });

    testWidgets('renders leading widget in AppBar', (tester) async {
      await tester.pumpWidget(
        _host(
          builder:
              (_) => WizardScaffold(
                title: 'Setup',
                step: 0,
                totalSteps: 2,
                leading: const Icon(
                  Icons.close,
                  key: ValueKey('leading-close'),
                ),
                onBack: () {},
                onNext: () {},
                backLabel: 'Back',
                nextLabel: 'Next',
                child: const SizedBox(),
              ),
        ),
      );

      expect(find.byKey(const ValueKey('leading-close')), findsOneWidget);
    });
  });
}
