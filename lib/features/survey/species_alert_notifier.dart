// =============================================================================
// Species Alert Notifier — Heads-up notifications for survey species alerts
// =============================================================================
//
// Wraps `flutter_local_notifications` to deliver one-shot alerts on a
// dedicated high-importance Android channel `birdnet_species_alert`.
//
// This channel is intentionally separate from the silent ongoing
// `birdnet_survey_fg` foreground-service channel so users can independently
// mute/unmute species alerts in Android system settings without losing the
// persistent survey-recording notification.
//
// Sound and vibration are controlled per-call by the caller (typically
// reading the `surveyAlertSound` / `surveyAlertVibrate` user prefs at
// survey-start time).  When sound is off the channel falls back to a
// silent-but-still-heads-up presentation.
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'alert_throttler.dart';
import 'survey_alert_engine.dart';

/// Localized strings used to format alert notifications. Constructed from
/// AppLocalizations on the main isolate (where `BuildContext` is
/// available) and passed in by the caller — this keeps the notifier free
/// of localization plumbing.
class SpeciesAlertStrings {
  const SpeciesAlertStrings({
    required this.channelName,
    required this.channelDescription,
    required this.firstInSessionBody,
    required this.firstEverBody,
    required this.rareBody,
    required this.watchlistBody,
    required this.liferBody,
    required this.summaryTitle,
    required this.summaryBody,
  });

  final String channelName;
  final String channelDescription;

  /// "First detection of this survey"
  final String firstInSessionBody;

  /// "First detection ever in this app"
  final String firstEverBody;

  /// Body for rare alerts. Receives the geo-model score as an integer
  /// percentage. Use `{pct}` as the placeholder (replaced via `replaceAll`).
  final String rareBody;

  /// "On your watchlist"
  final String watchlistBody;

  /// "New for your life list"
  final String liferBody;

  /// Title for coalesced alerts. Use `{count}` placeholder.
  final String summaryTitle;

  /// Summary body for coalesced alerts. Use `{count}` and `{names}`
  /// placeholders. Example: "{count} more new species: {names}".
  final String summaryBody;
}

/// Delivers heads-up species-alert notifications.
///
/// Construct one instance per app run (or per survey — both work), call
/// [init] once before any [notifyOne] / [notifySummary] call. The plugin
/// itself is a process-wide singleton so calling [init] multiple times is
/// safe and only the latest channel/sound configuration takes effect.
class SpeciesAlertNotifier {
  SpeciesAlertNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const String _channelId = 'birdnet_species_alert';
  bool _initialized = false;
  int _nextId = 100000;

  // Live channel configuration — recreated on every [init] call so toggling
  // sound/vibration in settings takes effect for the next survey.
  bool _sound = true;
  bool _vibrate = true;

  /// Initialize the plugin and (re)create the Android notification channel.
  ///
  /// Safe to call multiple times; the channel is replaced if any of the
  /// audio/vibration parameters change.
  Future<void> init({
    required SpeciesAlertStrings strings,
    bool sound = true,
    bool vibrate = true,
  }) async {
    _sound = sound;
    _vibrate = vibrate;

    const initSettingsAndroid = AndroidInitializationSettings(
      // Monochrome notification icon (white-on-transparent blue jay).
      // Required by Android — launcher icon would render as a white square.
      'ic_notification',
    );
    const initSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsDarwin,
      macOS: initSettingsDarwin,
    );
    try {
      await _plugin.initialize(settings: initSettings);
    } catch (e) {
      debugPrint('[SpeciesAlertNotifier] init failed: $e');
      _initialized = false;
      return;
    }

    if (Platform.isAndroid) {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android != null) {
        // Importance HIGH gives heads-up presentation. The system enforces
        // user overrides — if they've muted the channel manually we can't
        // fight that, which is the desired behavior.
        final channel = AndroidNotificationChannel(
          _channelId,
          strings.channelName,
          description: strings.channelDescription,
          importance: Importance.high,
          playSound: sound,
          enableVibration: vibrate,
        );
        await android.createNotificationChannel(channel);
      }
    }
    _initialized = true;
  }

  /// Whether the plugin has been successfully initialized.
  bool get isInitialized => _initialized;

  /// Request the Android 13+ POST_NOTIFICATIONS runtime permission.
  ///
  /// Returns `true` when the user has granted (or had previously granted)
  /// notification permission for the app, `false` when denied or when the
  /// platform does not require a runtime prompt. Safe to call before
  /// [init] — initializes the plugin lazily.
  Future<bool> requestPermission({SpeciesAlertStrings? strings}) async {
    if (!Platform.isAndroid) return true;
    if (!_initialized && strings != null) {
      await init(strings: strings, sound: _sound, vibrate: _vibrate);
    } else if (!_initialized) {
      // Initialize plugin alone (channel can be created later in init()).
      const initSettingsAndroid = AndroidInitializationSettings(
        'ic_notification',
      );
      const initSettingsDarwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      try {
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: initSettingsAndroid,
            iOS: initSettingsDarwin,
            macOS: initSettingsDarwin,
          ),
        );
      } catch (e) {
        debugPrint('[SpeciesAlertNotifier] lazy init failed: $e');
        return false;
      }
    }
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (android == null) return false;
    try {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    } catch (e) {
      debugPrint('[SpeciesAlertNotifier] requestPermission failed: $e');
      return false;
    }
  }

  /// Fire a one-shot alert for a single species detection.
  Future<void> notifyOne(
    AlertCandidate alert, {
    required SpeciesAlertStrings strings,
    String? title,
  }) async {
    if (!_initialized) return;
    final body = _bodyFor(alert, strings);
    await _show(title: title ?? alert.commonName, body: body);
  }

  /// Fire a summary alert covering multiple coalesced species.
  Future<void> notifySummary(
    SummaryAlert summary, {
    required SpeciesAlertStrings strings,
  }) async {
    if (!_initialized) return;
    final names = summary.alerts.map((a) => a.commonName).join(', ');
    final title = strings.summaryTitle.replaceAll(
      '{count}',
      summary.count.toString(),
    );
    final body = strings.summaryBody
        .replaceAll('{count}', summary.count.toString())
        .replaceAll('{names}', names);
    await _show(title: title, body: body);
  }

  /// Cancels every pending or already-shown species alert. Useful when a
  /// survey ends so the lock screen doesn't keep stale entries around.
  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[SpeciesAlertNotifier] cancelAll failed: $e');
    }
  }

  // ── Internals ────────────────────────────────────────────────────────

  String _bodyFor(AlertCandidate a, SpeciesAlertStrings strings) {
    switch (a.reason) {
      case AlertReason.firstInSession:
        return strings.firstInSessionBody;
      case AlertReason.firstEver:
        return strings.firstEverBody;
      case AlertReason.rare:
        final pct = ((a.geoScore ?? 0) * 100).round();
        return strings.rareBody.replaceAll('{pct}', pct.toString());
      case AlertReason.watchlist:
        return strings.watchlistBody;
      case AlertReason.lifer:
        return strings.liferBody;
    }
  }

  Future<void> _show({required String title, required String body}) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      'Species alerts',
      channelDescription: 'Heads-up alerts for new species during a survey.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: _sound,
      enableVibration: _vibrate,
      styleInformation: BigTextStyleInformation(body),
      ticker: title,
    );
    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: _sound,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      // Notification permission denied or platform unavailable — never let
      // this take down the survey.
      debugPrint('[SpeciesAlertNotifier] show failed: $e');
    }
  }
}
