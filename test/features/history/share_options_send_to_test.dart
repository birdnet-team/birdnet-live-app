import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

import 'package:birdnet_live/features/history/services/share_export_config.dart';
import 'package:birdnet_live/features/history/widgets/share_options_dialog.dart';
import 'package:birdnet_live/features/upload/upload_destination.dart';
import 'package:birdnet_live/features/upload/webdav_probe.dart';

void main() {
  const initial = ShareExportConfig(formats: {'raven'}, includeAudio: true);

  UploadDestination destination(String id, String name) => UploadDestination(
    id: id,
    name: name,
    url: 'https://cloud.example.org/public.php/webdav/',
    username: 'token',
    createdAt: DateTime.utc(2026, 10, 28),
  );

  Future<ShareExportConfig? Function()> open(
    WidgetTester tester, {
    required bool showSendTo,
    List<UploadDestination> destinations = const [],
    Set<String> initialDestinationIds = const {},
    Map<String, DateTime> uploadedTo = const {},
    VoidCallback? onAddDestination,
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
                    showSendTo: showSendTo,
                    destinations: destinations,
                    initialDestinationIds: initialDestinationIds,
                    uploadedTo: uploadedTo,
                    onAddDestination: onAddDestination,
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

  FilledButton primary(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('detection shares show no Send to group', (tester) async {
    await open(
      tester,
      showSendTo: false,
      destinations: [destination('a', 'A')],
    );
    expect(find.text('Send to'), findsNothing);
    expect(find.text('A'), findsNothing);
    expect(find.byType(Checkbox), findsNWidgets(2));
  });

  testWidgets('remembered destinations start ticked and go into the result', (
    tester,
  ) async {
    final read = await open(
      tester,
      showSendTo: true,
      destinations: [destination('a', 'Project A'), destination('b', 'B')],
      initialDestinationIds: {'b'},
      uploadedTo: {'a': DateTime.utc(2026, 10, 27)},
    );
    expect(find.text('Send to'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
    await tester.tap(find.text('Send to'));
    await tester.pumpAndSettle();
    expect(find.text('Share sheet'), findsOneWidget);
    expect(find.text('Project A'), findsOneWidget);
    expect(find.textContaining('Uploaded'), findsOneWidget);
    expect(find.textContaining('Tick to upload again'), findsOneWidget);
    expect(find.text('Share and upload'), findsOneWidget);

    await tester.tap(find.text('Share and upload'));
    await tester.pumpAndSettle();
    final result = read()!;
    expect(result.shareLocally, isTrue);
    expect(result.uploadDestinationIds, {'b'});
    expect(result.formats, {'raven'});
  });

  testWidgets('an already uploaded destination starts unticked even when '
      'remembered', (tester) async {
    final read = await open(
      tester,
      showSendTo: true,
      destinations: [destination('a', 'Project A'), destination('b', 'B')],
      initialDestinationIds: {'a', 'b'},
      uploadedTo: {'a': DateTime.utc(2026, 10, 27)},
    );
    await tester.tap(find.text('Send to'));
    await tester.pumpAndSettle();
    final boxes = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    // Share sheet, Project A (uploaded, unticked), B (remembered, ticked).
    expect(boxes.map((b) => b.value), [true, false, true]);

    // Ticking it again is allowed and lands in the result.
    await tester.tap(find.text('Project A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share and upload'));
    await tester.pumpAndSettle();
    expect(read()!.uploadDestinationIds, {'a', 'b'});
  });

  testWidgets('a destination the server would refuse is marked', (
    tester,
  ) async {
    ShareExportConfig? result;
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
                    showSendTo: true,
                    destinations: [
                      destination('gone', 'Old project'),
                      destination('ok', 'Live project'),
                    ],
                    checkReachable: (d) async =>
                        d.id == 'gone' ? ProbeFailure.unauthorized : null,
                  ),
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
    await tester.tap(find.text('Send to'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Upload would fail'), findsOneWidget);
    expect(find.textContaining('cloud.example.org'), findsNWidgets(2));
    expect(result, isNull);
  });

  testWidgets('unticking the share sheet turns the button into Upload', (
    tester,
  ) async {
    final read = await open(
      tester,
      showSendTo: true,
      destinations: [destination('a', 'Project A')],
    );
    expect(find.widgetWithText(FilledButton, 'Share'), findsOneWidget);
    await tester.tap(find.text('Send to'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share sheet'));
    await tester.pumpAndSettle();
    // Nothing to send to: the primary button is disabled.
    expect(primary(tester).onPressed, isNull);

    await tester.tap(find.text('Project A'));
    await tester.pumpAndSettle();
    expect(find.text('Upload'), findsOneWidget);
    expect(primary(tester).onPressed, isNotNull);

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    final result = read()!;
    expect(result.shareLocally, isFalse);
    expect(result.uploadDestinationIds, {'a'});
  });

  testWidgets('with no destination the group offers to add one', (
    tester,
  ) async {
    var added = false;
    final read = await open(
      tester,
      showSendTo: true,
      onAddDestination: () => added = true,
    );
    await tester.tap(find.text('Send to'));
    await tester.pumpAndSettle();
    expect(find.text('Add destination'), findsOneWidget);

    await tester.tap(find.text('Add destination'));
    await tester.pumpAndSettle();
    expect(added, isTrue);
    expect(read(), isNull);
  });

  testWidgets('thirty destinations do not grow the dialog', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await open(
      tester,
      showSendTo: true,
      destinations: [
        for (var i = 0; i < 30; i++) destination('d$i', 'Destination $i'),
      ],
      initialDestinationIds: {'d3', 'd17'},
    );
    await tester.tap(find.text('Send to'));
    await tester.pumpAndSettle();

    final pane = tester.getSize(find.byType(TabBarView));
    expect(pane.height, lessThanOrEqualTo(360));
    // The actions stay on screen (logical view height is 800).
    expect(
      tester.getBottomRight(find.byType(FilledButton)).dy,
      lessThanOrEqualTo(800),
    );
    // The badge counts the remembered ticks before the list is scrolled.
    expect(find.text('2'), findsOneWidget);
    // Far-down destinations are reachable by scrolling the list.
    expect(find.text('Destination 29'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Destination 29'),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Destination 29'), findsOneWidget);
  });
}
