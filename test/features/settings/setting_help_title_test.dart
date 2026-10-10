import 'package:birdnet_live/features/settings/settings_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('setup setting help opens the same sheet as Settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SettingHelpTitle(
              title: 'Recording',
              helpBody: 'Choose full audio or detection clips.',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(AppIcons.helpOutline));
    await tester.pumpAndSettle();

    expect(find.text('Recording'), findsNWidgets(2));
    expect(find.text('Choose full audio or detection clips.'), findsOneWidget);
  });
}
