import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:birdnet_live/features/upload/join_destination_screen.dart';
import 'package:birdnet_live/features/upload/join_link.dart';
import 'package:birdnet_live/features/upload/secret_store.dart';
import 'package:birdnet_live/features/upload/upload_destination.dart';
import 'package:birdnet_live/features/upload/upload_destination_store.dart';
import 'package:birdnet_live/features/upload/upload_providers.dart';
import 'package:birdnet_live/features/upload/webdav_probe.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';

class _AcceptingProbe extends WebDavProbe {
  @override
  Future<ProbeResult> run(
    JoinRequest request, {
    required String folder,
    required Map<String, Object?> registration,
    bool knownFlatLayout = false,
  }) async => ProbeResult.success(resolvedUrl: request.url);
}

class _MemoryDestinationStore extends UploadDestinationStore {
  List<UploadDestination> saved = const [];

  @override
  Future<List<UploadDestination>> load() async => saved;

  @override
  Future<void> save(List<UploadDestination> destinations) async {
    saved = destinations;
  }
}

void main() {
  const link =
      'birdnetlive://join?v=1&kind=webdav&name=ARU%20Sessions'
      '&url=https%3A%2F%2Fdav.example.org%2Fdrop%2F&user=u&secret=s';

  late _MemoryDestinationStore store;
  late SharedPreferences prefs;

  setUp(() async {
    store = _MemoryDestinationStore();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    PackageInfo.setMockInitialValues(
      appName: 'BirdNET Live',
      packageName: 'test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<void> openScreen(WidgetTester tester, {Widget? nextScreen}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          uploadDestinationStoreProvider.overrideWithValue(store),
          webDavProbeProvider.overrideWithValue(_AcceptingProbe()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => JoinDestinationScreen(
                    initialInput: link,
                    nextScreen: nextScreen,
                  ),
                ),
              ),
              child: const Text('Previous screen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Previous screen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
  }

  Future<void> tapInList(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('offers the ARU switch and saves its value', (tester) async {
    await openScreen(tester);

    await tapInList(tester, 'Upload ARU sessions automatically');
    await tapInList(tester, 'Save destination');

    expect(store.saved.single.autoUploadAru, isTrue);
    expect(store.saved.single.name, 'ARU Sessions');
  });

  testWidgets('leaves ARU uploads off unless the user turns them on', (
    tester,
  ) async {
    await openScreen(tester);

    await tapInList(tester, 'Save destination');

    expect(store.saved.single.autoUploadAru, isFalse);
  });

  testWidgets('does not offer the all-sessions switch', (tester) async {
    await openScreen(tester);

    await tester.scrollUntilVisible(
      find.text('Save destination'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Upload ARU sessions automatically'), findsOneWidget);
    expect(find.text('Upload all sessions automatically'), findsNothing);
  });

  testWidgets('pops to the previous screen without a next screen', (
    tester,
  ) async {
    await openScreen(tester);

    await tapInList(tester, 'Save destination');

    expect(find.byType(JoinDestinationScreen), findsNothing);
    expect(find.text('Previous screen'), findsOneWidget);
  });

  testWidgets('saving moves on to the next screen when one is given', (
    tester,
  ) async {
    await openScreen(tester, nextScreen: const Text('Destination overview'));

    await tapInList(tester, 'Save destination');

    expect(find.byType(JoinDestinationScreen), findsNothing);
    expect(find.text('Destination overview'), findsOneWidget);
    expect(find.text('Previous screen'), findsNothing);

    // The join screen is gone from the stack, so back skips it.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Previous screen'), findsOneWidget);
    expect(find.byType(JoinDestinationScreen), findsNothing);
  });
}
