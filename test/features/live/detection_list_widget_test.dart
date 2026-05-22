// =============================================================================
// Detection List Widget Tests
// =============================================================================

import 'package:birdnet_live/features/live/widgets/detection_list_widget.dart';
import 'package:birdnet_live/features/live/widgets/live_tips.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({required bool showTips, bool isActive = false}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DetectionList(
          detections: const [],
          isActive: isActive,
          showTips: showTips,
        ),
      ),
    );
  }

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
}
