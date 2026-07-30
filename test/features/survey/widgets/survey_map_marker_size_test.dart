// =============================================================================
// Survey Map Marker Sizing Tests
// =============================================================================
//
// flutter_map hands each marker's child *tight* constraints. A bare sized
// Container inflates to fill those, which silently blew silent (no-clip)
// markers up to the full marker box — bigger than the audio markers they are
// meant to sit behind. These tests pin the intended sizing.
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/survey/widgets/survey_map_widget.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;
  late String clipPath;

  setUp(() async {
    SharedPreferences.setMockInitialValues({PrefKeys.privacyAllowMap: true});
    prefs = await SharedPreferences.getInstance();
    tempDir = await Directory.systemTemp.createTemp('survey_map_marker_test');
    clipPath = '${tempDir.path}/clip.wav';
    await File(clipPath).writeAsBytes(const [0, 1, 2, 3]);
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  DetectionRecord record({
    required String scientificName,
    required double latitude,
    String? audioClipPath,
  }) {
    return DetectionRecord(
      scientificName: scientificName,
      commonName: scientificName,
      confidence: 0.8,
      timestamp: DateTime(2026, 7, 5, 10),
      latitude: latitude,
      longitude: 13.405,
      audioClipPath: audioClipPath,
    );
  }

  Widget buildSubject(List<DetectionRecord> detections) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Keep the taxonomy pending: markers fall back to the placeholder
        // image, which is all these layout assertions need.
        taxonomyServiceProvider.overrideWith(
          (ref) => Completer<TaxonomyService>().future,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SurveyMapWidget(
            gpsTrack: const [],
            detections: detections,
            initialCenter: const LatLng(52.52, 13.405),
            onMarkerTap: (_) {},
            tileLayerBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  /// Rendered diameter of the avatar behind [label]'s marker. The avatar's
  /// ClipOval is the photo circle itself, so this is what the eye reads as
  /// "how big is this pin".
  Size avatarSize(WidgetTester tester, String label) {
    return tester.getSize(
      find
          .descendant(
            of: find.bySemanticsLabel(label),
            matching: find.byType(ClipOval),
          )
          .first,
    );
  }

  testWidgets('a silent marker is not inflated to the marker box size', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject([record(scientificName: 'Parus major', latitude: 52.52)]),
    );
    await tester.pump();

    final semantics = tester.ensureSemantics();
    try {
      // The 48 px marker box would render a ~44 px circle once borders are
      // subtracted; the intended silent avatar is far smaller than that.
      final size = avatarSize(tester, 'Parus major');
      expect(size.width, lessThan(40));
      expect(size.width, size.height);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('silent and audio markers read as the same size', (tester) async {
    await tester.pumpWidget(
      buildSubject([
        record(scientificName: 'Parus major', latitude: 52.52),
        record(
          scientificName: 'Turdus merula',
          latitude: 52.5201,
          audioClipPath: clipPath,
        ),
      ]),
    );
    await tester.pump();

    final semantics = tester.ensureSemantics();
    try {
      final silent = avatarSize(tester, 'Parus major').width;
      final audio = avatarSize(tester, 'Turdus merula').width;
      // The audio marker carries a play badge that overhangs its avatar, so
      // its circle is allowed to be a little smaller — never the other way
      // round, and never by more than a few pixels.
      expect(silent, lessThan(audio));
      expect(audio - silent, lessThanOrEqualTo(6));
    } finally {
      semantics.dispose();
    }
  });
}
