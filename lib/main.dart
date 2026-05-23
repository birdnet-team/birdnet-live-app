import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/survey/survey_notification.dart';
import 'shared/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ONNX Runtime environment (singleton, must run before any session).
  OrtEnv.instance.init();

  // Initialize foreground task communication for survey background service.
  FlutterForegroundTask.initCommunicationPort();
  await SurveyNotificationService.init();

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

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const App(),
    ),
  );
}
