// =============================================================================
// Detection List Widget Tests
// =============================================================================

import 'package:birdnet_live/core/theme/score_colors.dart';
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
    Map<String, double>? speciesMaxConfidences,
    int columns = 1,
    double? height,
  }) {
    final list = DetectionList(
      detections: detections,
      isActive: isActive,
      showTips: showTips,
      activeDetections: activeDetections,
      speciesDetectionCounts: speciesDetectionCounts,
      speciesMaxConfidences: speciesMaxConfidences,
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

  testWidgets('shows the highest confidence chip in the score color', (
    tester,
  ) async {
    final detection = record('A');

    await tester.pumpWidget(
      buildSubject(
        showTips: false,
        isActive: true,
        detections: [detection],
        // Retained row: the current-confidence text and bar are hidden, so
        // the chip is the only place the score shows.
        activeDetections: Set<DetectionRecord>.identity(),
        speciesDetectionCounts: const {'A': 3},
        speciesMaxConfidences: const {'A': 0.874},
      ),
    );

    expect(find.text('87%'), findsOneWidget);
    // The confidence chip is always the last one in the row.
    expect(
      tester.getTopLeft(find.text('87%')).dx,
      greaterThan(tester.getTopRight(find.text(countChipText)).dx),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    final chip = tester.widget<Container>(
      find.ancestor(of: find.text('87%'), matching: find.byType(Container)),
    );
    expect(
      (chip.decoration! as BoxDecoration).color,
      ScoreColors.light.forScore(0.874),
    );
    expect(find.byTooltip('Highest confidence: 87%'), findsOneWidget);
  });

  testWidgets('labels the highest confidence chip in the readable color', (
    tester,
  ) async {
    // Light-theme score buckets and the label color with the higher contrast.
    // 0.30 and 0.70 are mid-tone fills where white would be hard to read.
    final expected = <double, Color>{
      0.10: Colors.black,
      0.30: Colors.black,
      0.50: Colors.black,
      0.70: Colors.black,
      0.90: Colors.white,
    };

    for (final entry in expected.entries) {
      await tester.pumpWidget(
        buildSubject(
          showTips: false,
          isActive: true,
          detections: [record('A')],
          activeDetections: Set<DetectionRecord>.identity(),
          speciesMaxConfidences: {'A': entry.key},
        ),
      );

      final label = tester.widget<Text>(
        find.text('${(entry.key * 100).round()}%'),
      );
      expect(label.style?.color, entry.value, reason: 'score ${entry.key}');
    }
  });

  testWidgets('hides the highest confidence chip while the species is active', (
    tester,
  ) async {
    final detection = record('A');

    await tester.pumpWidget(
      buildSubject(
        showTips: false,
        isActive: true,
        detections: [detection],
        activeDetections: Set<DetectionRecord>.identity()..add(detection),
        speciesMaxConfidences: const {'A': 0.874},
      ),
    );

    // The row shows its current confidence; the peak would be a second,
    // different percentage on the same row.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('87%'), findsNothing);
    expect(find.byTooltip('Highest confidence: 87%'), findsNothing);
  });

  testWidgets('omits the highest confidence chip when not provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        showTips: false,
        isActive: true,
        detections: [record('A')],
        activeDetections: Set<DetectionRecord>.identity(),
      ),
    );

    expect(find.byTooltip('Highest confidence: 80%'), findsNothing);
    expect(find.text('80%'), findsNothing);
  });
}
