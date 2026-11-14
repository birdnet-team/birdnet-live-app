import 'package:birdnet_live/features/about/about_screen.dart';
import 'package:birdnet_live/features/audio/audio_providers.dart';
import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/settings/settings_screen.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _announcementsSwitch = 'Speak detections aloud';

Future<void> _pumpSettings(
  WidgetTester tester, {
  SettingsContext settingsContext = SettingsContext.all,
  bool keepPrefs = false,
}) async {
  if (!keepPrefs) SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ignoredSpeciesCountProvider.overrideWith((ref) async => 0),
        // Keeps the Audio tile from creating the real capture service.
        inputDevicesProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(settingsContext: settingsContext),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Types [query] into the search field, opening it from the app bar first.
Future<void> _search(WidgetTester tester, String query) async {
  if (find.byType(TextField).evaluate().isEmpty) {
    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
  }
  await tester.enterText(find.byType(TextField), query);
}

/// Top edge of the tappable title row of the section named [title].
double _titleRowTop(WidgetTester tester, String title) => tester
    .getTopLeft(
      find.ancestor(of: find.text(title), matching: find.byType(InkWell)).first,
    )
    .dy;

Future<void> _tapSection(WidgetTester tester, String title) async {
  // Sections below the fold are built but not painted.
  await tester.ensureVisible(find.text(title, skipOffstage: false));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens with every section collapsed', (tester) async {
    await _pumpSettings(tester);

    for (final title in [
      'General',
      'Appearance',
      'Audio & Recording',
      'Inference',
      'Spectrogram',
      'Playback & Announcements',
      'Location & Species Filter',
      'Export & Sync',
      'Privacy',
      'Danger Zone',
    ]) {
      expect(
        find.text(title, skipOffstage: false),
        findsOneWidget,
        reason: title,
      );
    }
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Reset All Settings'), findsNothing);
  });

  testWidgets('a header expands its section and collapses it again', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await _tapSection(tester, 'Audio & Recording');
    expect(find.text('Gain'), findsOneWidget);

    await _tapSection(tester, 'Audio & Recording');
    expect(find.text('Gain'), findsNothing);
  });

  testWidgets('sections expand independently of each other', (tester) async {
    await _pumpSettings(tester);

    await _tapSection(tester, 'Audio & Recording');
    await _tapSection(tester, 'Inference');

    expect(find.text('Gain', skipOffstage: false), findsOneWidget);
    expect(find.text('Window duration'), findsOneWidget);
  });

  testWidgets('theme settings are under Appearance, not General', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await _tapSection(tester, 'General');
    expect(find.text('Theme'), findsNothing);
    expect(find.text('Show scientific names'), findsOneWidget);

    await _tapSection(tester, 'Appearance');
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('High Contrast Theme'), findsOneWidget);
  });

  testWidgets('the first header sits directly below the app bar', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 120);
    addTearDown(tester.view.resetPadding);
    await _pumpSettings(tester);

    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    expect(_titleRowTop(tester, 'General'), appBarBottom);
  });

  testWidgets('a side display cutout insets the tiles only once', (
    tester,
  ) async {
    const inset = 48.0;
    final ratio = tester.view.devicePixelRatio;
    tester.view.padding = FakeViewPadding(
      left: inset * ratio,
      right: inset * ratio,
    );
    addTearDown(tester.view.resetPadding);
    await _pumpSettings(tester);
    await _tapSection(tester, 'General');

    final listLeft = tester.getTopLeft(find.byType(CustomScrollView)).dx;
    final tileLeft = tester.getTopLeft(find.byType(SwitchListTile).first).dx;
    final titleLeft = tester.getTopLeft(find.text('Show scientific names')).dx;
    expect(tileLeft, listLeft);
    // ListTile's own 16 dp content padding, not the cutout a second time.
    expect(titleLeft - tileLeft, 16);
  });

  testWidgets('Audio and Recording share one section above Inference', (
    tester,
  ) async {
    await _pumpSettings(tester);
    expect(find.text('Recording'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Audio & Recording')).dy,
      lessThan(tester.getTopLeft(find.text('Inference')).dy),
    );

    await _tapSection(tester, 'Audio & Recording');
    expect(find.text('Gain'), findsOneWidget);
    expect(find.text('Recording format'), findsOneWidget);
  });

  testWidgets('Playback and Announcements share one section', (tester) async {
    await _pumpSettings(tester);
    expect(find.text('Playback'), findsNothing);
    expect(find.text('Announcements'), findsNothing);

    await _tapSection(tester, 'Playback & Announcements');
    expect(find.text('Auto-play voice memos'), findsOneWidget);
    expect(find.text(_announcementsSwitch), findsOneWidget);
  });

  testWidgets('File Analysis shows Playback without announcements', (
    tester,
  ) async {
    await _pumpSettings(tester, settingsContext: SettingsContext.fileAnalysis);
    expect(find.text('Playback & Announcements'), findsNothing);

    await _tapSection(tester, 'Playback');
    expect(find.text('Auto-play voice memos'), findsOneWidget);
    expect(find.text(_announcementsSwitch), findsNothing);
  });

  testWidgets('search opens from the app bar icon and closes again', (
    tester,
  ) async {
    await _pumpSettings(tester);
    expect(find.byType(TextField), findsNothing);

    await _search(tester, 'gain');
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Gain'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
  });

  testWidgets('search finds a setting and opens its section', (tester) async {
    await _pumpSettings(tester);

    await _search(tester, 'gain');
    await tester.pumpAndSettle();
    expect(find.text('General'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Audio & Recording'), findsOneWidget);

    await tester.tap(find.text('Gain'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('General', skipOffstage: false), findsOneWidget);
    expect(find.text('Gain').hitTestable(), findsOneWidget);
    expect(find.byType(Slider), findsWidgets);
  });

  testWidgets('search scrolls to a setting far down the list', (tester) async {
    await _pumpSettings(tester);

    await _search(tester, 'weather');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow weather lookup'));
    await tester.pumpAndSettle();

    expect(find.text('Allow weather lookup').hitTestable(), findsOneWidget);
  });

  testWidgets('search finds About and opens the About screen', (tester) async {
    await _pumpSettings(tester);

    await _search(tester, 'about');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'About'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsOneWidget);
  });

  testWidgets('the hidden list cannot take keyboard focus during search', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await _tapSection(tester, 'General');
    bool listExcluded() => tester
        .widget<ExcludeFocus>(
          find
              .ancestor(
                of: find.byType(CustomScrollView, skipOffstage: false),
                matching: find.byType(ExcludeFocus, skipOffstage: false),
              )
              .first,
        )
        .excluding;
    expect(listExcluded(), isFalse);

    await _search(tester, 'gain');
    await tester.pumpAndSettle();
    expect(listExcluded(), isTrue);
  });

  testWidgets('the settings list is the primary scroll view, also in search', (
    tester,
  ) async {
    await _pumpSettings(tester);
    // What a tap on the iOS status bar scrolls to the top.
    ScrollController primary() =>
        PrimaryScrollController.of(tester.element(find.byType(Scaffold)));
    expect(primary().positions, hasLength(1));

    await _search(tester, 'e');
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget);
    expect(primary().positions, hasLength(1));
  });

  testWidgets('a section name lists its settings; no match says so', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await _search(tester, 'appearance');
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('High Contrast Theme'), findsOneWidget);

    await _search(tester, 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No settings found'), findsOneWidget);
  });

  testWidgets('settings matching by name rank above section-name matches', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await _search(tester, 'infer');
    await tester.pumpAndSettle();
    final titles = [
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        (tile.title! as Text).data!,
    ];
    expect(titles.first, 'Inference rate');
    expect(titles, contains('Window duration'));
    expect(titles.toSet().length, titles.length);
  });

  testWidgets('search lists a dependent setting only while it is on screen', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await _search(tester, 'verbosity');
    await tester.pumpAndSettle();
    expect(find.text('No settings found'), findsOneWidget);

    // Turn announcements on, then search again.
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await _tapSection(tester, 'Playback & Announcements');
    await Scrollable.ensureVisible(
      tester.element(find.text(_announcementsSwitch)),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(_announcementsSwitch));
    await tester.pumpAndSettle();

    await _search(tester, 'verbosity');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Verbosity'), findsOneWidget);
  });

  testWidgets('closing search returns to the same place in the list', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await _tapSection(tester, 'Spectrogram');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final before = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    expect(before, greaterThan(0));

    await _search(tester, 'gain');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    final after = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    expect(after, before);
  });

  testWidgets('back closes search before it leaves Settings', (tester) async {
    await _pumpSettings(tester);
    await _search(tester, 'gain');
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('only the title row is pinned; the description scrolls away', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await _tapSection(tester, 'Spectrogram');
    final description = find.textContaining('finer frequency resolution');
    expect(description, findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Spectrogram quality'),
      find.byType(CustomScrollView),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();

    expect(find.text('Spectrogram').hitTestable(), findsOneWidget);
    expect(description.hitTestable(), findsNothing);
  });

  testWidgets('search only offers settings of the current context', (
    tester,
  ) async {
    await _pumpSettings(tester, settingsContext: SettingsContext.fileAnalysis);

    await _search(tester, 'gain');
    await tester.pumpAndSettle();
    expect(find.text('No settings found'), findsOneWidget);
  });

  testWidgets('every search entry is the title of a tile in its section', (
    tester,
  ) async {
    await _pumpSettings(tester);

    // Tall enough that every result and every expanded section is built.
    tester.view.physicalSize = const Size(800, 20000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pump();

    const sections = [
      'General',
      'Appearance',
      'Audio & Recording',
      'Inference',
      'Spectrogram',
      'Playback & Announcements',
      'Location & Species Filter',
      'Export & Sync',
      'Privacy',
      'Danger Zone',
    ];
    var checked = 0;
    final missing = <String>{};
    for (final section in sections) {
      // A section name lists all of that section's entries.
      await _search(tester, section);
      await tester.pump();
      final titles = [
        for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
          if ((tile.subtitle! as Text).data == section)
            (tile.title! as Text).data!,
      ];
      expect(titles, isNotEmpty, reason: section);

      await _search(tester, '');
      await tester.pump();
      await tester.tap(find.text(section));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (final title in titles) {
        checked++;
        if (find.text(title).evaluate().isEmpty) missing.add(title);
      }
      await tester.tap(find.text(section));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(checked, greaterThan(40));
    expect(missing, isEmpty);
  });

  testWidgets('the header of an expanded section stays pinned until the next '
      'section pushes it out', (tester) async {
    await _pumpSettings(tester);
    await _tapSection(tester, 'Spectrogram');
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    final scrollable = find.byType(CustomScrollView);

    // Deep inside the section: its header sits at the top.
    await tester.dragUntilVisible(
      find.text('Spectrogram quality'),
      scrollable,
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    expect(_titleRowTop(tester, 'Spectrogram'), appBarBottom);
    expect(find.text('Spectrogram').hitTestable(), findsOneWidget);

    // Collapsing from there keeps the header on screen.
    await tester.tap(find.text('Spectrogram'));
    await tester.pumpAndSettle();
    expect(find.text('Spectrogram quality'), findsNothing);
    expect(find.text('Spectrogram').hitTestable(), findsOneWidget);

    // Past the section, the header leaves with it.
    await tester.tap(find.text('Spectrogram'));
    await tester.pumpAndSettle();
    await _tapSection(tester, 'Privacy');
    await tester.drag(scrollable, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Spectrogram').hitTestable(), findsNothing);
  });

  testWidgets('reopening the screen starts collapsed again', (tester) async {
    await _pumpSettings(tester);
    await _tapSection(tester, 'Audio & Recording');
    expect(find.text('Gain'), findsOneWidget);

    // Same stored preferences as before, so a persisted state would show.
    await tester.pumpWidget(const SizedBox());
    await _pumpSettings(tester, keepPrefs: true);
    expect(find.text('Gain'), findsNothing);
  });

  testWidgets('only the sections of the current context are listed', (
    tester,
  ) async {
    await _pumpSettings(tester, settingsContext: SettingsContext.fileAnalysis);
    expect(find.text('Inference'), findsOneWidget);
    expect(find.text('Audio & Recording'), findsNothing);
    expect(find.text('Spectrogram'), findsNothing);
  });
}
