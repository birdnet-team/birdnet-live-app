import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:birdnet_live/features/upload/join_code_dialog.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

void main() {
  const link =
      'https://birdnet-team.github.io/birdnet-live-app/join#v=1&kind=webdav'
      '&name=TUC%20Nextcloud%20test&url=https%3A%2F%2Ftuc.cloud%2Fpublic.php'
      '%2Fdav%2Ffiles%2FLH7maGsAz2GB6Gt%2F&user=LH7maGsAz2GB6Gt&audio=0&wifi=1';

  testWidgets('lays out inside AlertDialog with semantics on and copies', (
    tester,
  ) async {
    // The bug only showed with accessibility services running: the dialog
    // never got a size and the framework asserted on every frame.
    final semantics = tester.ensureSemantics();
    var copied = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      JoinCodeDialog(link: link, onCopy: () => copied++),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      tester.getSize(find.byType(QrImageView)),
      const Size(JoinCodeDialog.qrSize, JoinCodeDialog.qrSize),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, 1);
    expect(find.byType(JoinCodeDialog), findsNothing);
    semantics.dispose();
  });
}
