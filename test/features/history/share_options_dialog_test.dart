import 'package:birdnet_live/features/history/services/share_export_config.dart';
import 'package:birdnet_live/features/history/widgets/share_options_dialog.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Pumps a host page with one button that opens the dialog and records
  /// the value it pops with.
  Future<ShareExportConfig? Function()> pumpDialog(
    WidgetTester tester, {
    required ShareExportConfig initial,
    bool audioAvailable = true,
  }) async {
    ShareExportConfig? result;
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<ShareExportConfig>(
                  context: context,
                  builder: (_) => ShareOptionsDialog(
                    initial: initial,
                    audioAvailable: audioAvailable,
                  ),
                );
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () {
      expect(popped, isTrue, reason: 'dialog has not closed yet');
      return result;
    };
  }

  Checkbox checkboxAt(WidgetTester tester, int index) =>
      tester.widget<Checkbox>(find.byType(Checkbox).at(index));

  FilledButton shareButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  const full = ShareExportConfig(
    formats: {'raven', 'csv'},
    includeAudio: true,
    includeHtmlReport: true,
  );

  testWidgets('boxes mirror the saved preferences and the subtitles name '
      'what each box adds', (tester) async {
    await pumpDialog(tester, initial: full);

    expect(checkboxAt(tester, 0).value, isTrue, reason: 'Audio');
    expect(checkboxAt(tester, 1).value, isTrue, reason: 'Metadata');
    expect(find.text('Original recording format'), findsOneWidget);
    expect(
      find.text('Raven Selection Table, CSV, HTML report'),
      findsOneWidget,
    );
    expect(shareButton(tester).onPressed, isNotNull);
  });

  testWidgets('Metadata starts unticked when nothing is enabled and ticking '
      'it falls back to Raven', (tester) async {
    const audioOnly = ShareExportConfig(
      formats: {},
      includeAudio: true,
      shareAudioAsWav: true,
    );
    final result = await pumpDialog(tester, initial: audioOnly);

    expect(checkboxAt(tester, 1).value, isFalse);
    expect(find.text('Converted to WAV'), findsOneWidget);
    expect(find.text('Raven Selection Table'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final config = result()!;
    expect(config.includeAudio, isTrue);
    expect(config.shareAudioAsWav, isTrue);
    expect(config.formats, {'raven'});
  });

  testWidgets('unticking Metadata yields an audio-only share', (tester) async {
    final result = await pumpDialog(tester, initial: full);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final config = result()!;
    expect(config.includeAudio, isTrue);
    expect(config.formats, isEmpty);
    expect(config.includeHtmlReport, isFalse);
    expect(config.includeAppMetadata, isFalse);
  });

  testWidgets('Share is disabled while both boxes are off', (tester) async {
    await pumpDialog(tester, initial: full);

    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();

    expect(shareButton(tester).onPressed, isNull);
  });

  testWidgets('Cancel returns null without changing anything', (tester) async {
    final result = await pumpDialog(tester, initial: full);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result(), isNull);
  });

  testWidgets('Audio is greyed out when there is nothing to share', (
    tester,
  ) async {
    final result = await pumpDialog(
      tester,
      initial: full,
      audioAvailable: false,
    );

    final audio = checkboxAt(tester, 0);
    expect(audio.value, isFalse);
    expect(audio.onChanged, isNull);
    expect(find.text('No saved audio to share'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(result()!.includeAudio, isFalse);
  });

  testWidgets('the title ? explains where the defaults come from', (
    tester,
  ) async {
    await pumpDialog(tester, initial: full);

    // Title help comes first, then one per box.
    expect(find.byTooltip('About this setting'), findsNWidgets(3));
    await tester.tap(find.byTooltip('About this setting').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Export & Sync'), findsOneWidget);
    expect(find.textContaining('this share only'), findsOneWidget);
  });

  testWidgets('the ? button opens the help sheet for that box', (tester) async {
    await pumpDialog(tester, initial: full);

    await tester.tap(find.byTooltip('About this setting').at(1));
    await tester.pumpAndSettle();

    expect(find.textContaining('Adds the saved audio'), findsOneWidget);
  });
}
