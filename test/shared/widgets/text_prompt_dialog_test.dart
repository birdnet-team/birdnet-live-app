import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/widgets/text_prompt_dialog.dart';

void main() {
  testWidgets('returns the text on Save and survives the exit animation', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showTextPromptDialog(
                  context,
                  title: 'Rename',
                  initialText: 'Old',
                  labelText: 'Name',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'New name');
    await tester.tap(find.text('Save'));
    // Pump the exit animation frame by frame: the field is still built
    // while the dialog fades out and must not touch a disposed controller.
    await tester.pumpAndSettle();

    expect(result, 'New name');
    expect(tester.takeException(), isNull);
    expect(find.byType(TextPromptDialog), findsNothing);
  });

  testWidgets('returns null on Cancel', (tester) async {
    String? result = 'untouched';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showTextPromptDialog(context, title: 'T');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
