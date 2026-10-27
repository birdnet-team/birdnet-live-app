// =============================================================================
// Detection List Widget Tests
// =============================================================================

import 'package:birdnet_live/features/live/widgets/detection_list_widget.dart';
import 'package:birdnet_live/features/live/widgets/live_tips.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const countChipText = '\u00d73';
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  DetectionRecord record(String scientificName) {
    return DetectionRecord(
      scientificName: scientificName,
      commonName: scientificName,
      confidence: 0.8,
      timestamp: DateTime(2026, 7, 5, 10),
    );
  }

  Widget buildSubject({
    required bool showTips,
    bool isActive = false,
    List<DetectionRecord> detections = const [],
    Set<DetectionRecord>? activeDetections,
    Map<String, int>? speciesDetectionCounts,
    int columns = 1,
    double? height,
  }) {
    final list = DetectionList(
      detections: detections,
      isActive: isActive,
      showTips: showTips,
      activeDetections: activeDetections,
      speciesDetectionCounts: speciesDetectionCounts,
      columns: columns,
    );
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: height == null ? list : SizedBox(height: height, child: list),
        ),
      ),
    );
  }

  Offset tileTopLeft(WidgetTester tester, String name) {
    return tester.getTopLeft(
      find
          .ancestor(of: find.text(name), matching: find.byType(DetectionTile))
          .first,
    );
  }

  testWidgets('two columns fill the left column first', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        showTips: false,
        columns: 2,
        detections: [
          record('Turdus merula'),
          record('Erithacus rubecula'),
          record('Parus major'),
        ],
      ),
    );

    expect(find.byType(DetectionTile), findsNWidgets(3));
    final first = tileTopLeft(tester, 'Turdus merula');
    final second = tileTopLeft(tester, 'Erithacus rubecula');
    final third = tileTopLeft(tester, 'Parus major');
    // Plenty of height: everything stacks in the left column.
    expect(second.dx, first.dx);
    expect(second.dy, greaterThan(first.dy));
    expect(third.dx, first.dx);
    expect(third.dy, greaterThan(second.dy));
  });

  testWidgets('two columns continue on the right once the left is full', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        showTips: false,
        columns: 2,
        // Room for two one-line tiles per column.
        height: 150,
        detections: [
          record('Turdus merula'),
          record('Erithacus rubecula'),
          record('Parus major'),
        ],
      ),
    );

    expect(find.byType(DetectionTile), findsNWidgets(3));
    final first = tileTopLeft(tester, 'Turdus merula');
    final second = tileTopLeft(tester, 'Erithacus rubecula');
    final third = tileTopLeft(tester, 'Parus major');
    expect(second.dx, first.dx);
    expect(second.dy, greaterThan(first.dy));
    // The third tile starts the right column at the top.
    expect(third.dy, first.dy);
    expect(third.dx, greaterThan(first.dx));
  });

  testWidgets('shows live tips only when the host opts in', (tester) async {
    await tester.pumpWidget(buildSubject(showTips: true));

    expect(find.byType(LiveTipsCarousel), findsOneWidget);
  });

  testWidgets('hides live tips by default for shared mode screens', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(showTips: false));

    expect(find.byType(LiveTipsCarousel), findsNothing);
  });

  testWidgets('hides live tips while a session is active', (tester) async {
    await tester.pumpWidget(buildSubject(showTips: true, isActive: true));

    expect(find.byType(LiveTipsCarousel), findsNothing);
  });

  testWidgets('shows species detection count chip when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        showTips: false,
        isActive: true,
        detections: [record('A')],
        speciesDetectionCounts: const {'A': 3},
      ),
    );

    expect(find.text(countChipText), findsOneWidget);
    // Active rows (no activeDetections override) are shown at full opacity.
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity != 1.0),
      findsNothing,
    );
  });

  testWidgets('keeps count chip on inactive retained species rows', (
    tester,
  ) async {
    final detection = record('A');

    await tester.pumpWidget(
      buildSubject(
        showTips: false,
        isActive: true,
        detections: [detection],
        activeDetections: Set<DetectionRecord>.identity(),
        speciesDetectionCounts: const {'A': 3},
      ),
    );

    expect(find.text(countChipText), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    // Retained (inactive) rows are dimmed to read as no-longer-live.
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.75),
      findsOneWidget,
    );
  });
}
