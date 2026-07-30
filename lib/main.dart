import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'features/aru/aru_notification.dart';
import 'features/survey/survey_notification.dart';
import 'shared/providers/app_providers.dart';
import 'shared/widgets/open_street_map_tile_layer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize foreground task communication for survey background service.
  FlutterForegroundTask.initCommunicationPort();
  await SurveyNotificationService.init();
  await AruNotificationService.init();

  // Edge-to-edge: set once at startup so the system bars stay transparent
  // on every screen without triggering flicker on rebuilds.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Initialize SharedPreferences before running the app.
  final prefs = await SharedPreferences.getInstance();

  // One-time privacy-gate migration (0.12.0). Pre-0.12.0 stored a single
  // `mapTileConsent` flag that gated both OSM tiles and reverse
  // geocoding. We now have three independent toggles; if the user had
  // previously consented, inherit that consent into both equivalent
  // gates so they don't have to re-approve. The legacy key is left in
  // place as a one-shot trigger and is otherwise ignored.
  final hasNewMap = prefs.containsKey('privacy_allow_map');
  final hasNewGeo = prefs.containsKey('privacy_allow_reverse_geocoding');
  if (!hasNewMap || !hasNewGeo) {
    final legacyConsent = prefs.getBool('map_tile_consent') ?? false;
    if (!hasNewMap) await prefs.setBool('privacy_allow_map', legacyConsent);
    if (!hasNewGeo) {
      await prefs.setBool('privacy_allow_reverse_geocoding', legacyConsent);
    }
  }

  // One-time hidden pooling-default migration. Pooling controls are not exposed
  // in Settings, so installations that persisted the old default need to move
  // forward explicitly; later explicit internal changes remain respected.
  if (!(prefs.getBool(PrefKeys.scorePoolingDefaultMigration) ?? false)) {
    final currentPooling = prefs.getString(PrefKeys.scorePooling);
    if (currentPooling == null || currentPooling == 'lme') {
      await prefs.setString(PrefKeys.scorePooling, 'adaptive_lme_peak');
    }
    if (!prefs.containsKey(PrefKeys.scorePoolingWindows)) {
      await prefs.setInt(PrefKeys.scorePoolingWindows, 5);
    }
    if (!prefs.containsKey(PrefKeys.scorePoolingMaxAgeSeconds)) {
      await prefs.setDouble(PrefKeys.scorePoolingMaxAgeSeconds, 10.0);
    }
    await prefs.setBool(PrefKeys.scorePoolingDefaultMigration, true);
  }

  // One-time removal of the pre-0.19.4 `flutter_cache_manager` tile store,
  // superseded by flutter_map's built-in tile cache. Deliberately not awaited:
  // it only frees disk space and must never delay first paint.
  if (!(prefs.getBool(PrefKeys.legacyTileCachePurge) ?? false)) {
    unawaited(
      purgeLegacyOsmTileCache().then(
        (_) => prefs.setBool(PrefKeys.legacyTileCachePurge, true),
      ),
    );
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const App(),
    ),
  );
}
