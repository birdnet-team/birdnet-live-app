// =============================================================================
// Survey Live Screen — Dashboard shown during an active survey
// =============================================================================
//
// Tabbed UI for an active survey with three tabs: Map, Spectrogram, Summary.
// Map is the default tab and shows 50% of screen height.
//
// Layout (top → bottom):
//   1. Status bar with elapsed time, stop button, settings
//   2. Tab bar: Map | Spectrogram | Summary
//   3. Tab content (50% of screen)
//   4. Stats bar (distance, detections, species, audio level)
//   5. Recent detections list (remaining space)
//
// The survey runs primarily in the background.  When the user opens this
// screen, the map and stats update live.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/score_colors.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/quick_action_service.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/utils/share_sheet.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/confirm_destructive.dart';
import '../audio/audio_capture_service.dart';
import '../audio/audio_providers.dart';
import '../audio/ring_buffer.dart';
import '../explore/explore_providers.dart';
import '../explore/explore_screen.dart';
import '../explore/widgets/species_info_overlay.dart';
import '../history/session_library_screen.dart';
import '../history/session_review_screen.dart';
import '../history/services/detection_sharing_service.dart';
import '../history/widgets/clip_player_sheet.dart';
import '../history/widgets/detection_actions.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../live/widgets/detection_list_widget.dart';
import '../recording/recording_service.dart';
import '../settings/settings_screen.dart';
import '../spectrogram/spectrogram_widget.dart';
import 'detection_sampler.dart';
import 'alert_throttler.dart';
import 'species_alert_notifier.dart';
import 'survey_alert_coordinator.dart';
import 'survey_alert_engine.dart';
import 'survey_controller.dart';
import 'survey_providers.dart';
import '../history/global_species_history.dart';
import '../inference/advanced_pooling_params.dart';
import '../inference/custom_species_list.dart';
import 'widgets/survey_map_widget.dart';
import 'widgets/survey_stats_bar.dart';

/// Dashboard shown during an active survey.
class SurveyLiveScreen extends ConsumerStatefulWidget {
  const SurveyLiveScreen({
    super.key,
    this.customName,
    this.transectId,
    this.observerName,
    this.startLatitude,
    this.startLongitude,
    this.backgroundGps = true,
    this.resumeSession,
  });

  final String? customName;
  final String? transectId;
  final String? observerName;
  final double? startLatitude;
  final double? startLongitude;
  final bool backgroundGps;

  /// If non-null, resume this unfinished session instead of starting fresh.
  final LiveSession? resumeSession;

  @override
  ConsumerState<SurveyLiveScreen> createState() => _SurveyLiveScreenState();
}

class _SurveyLiveScreenState extends ConsumerState<SurveyLiveScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final Object _quickListenSafetyOwner = Object();

  bool _started = false;
  bool _finalizing = false;
  bool _stopDialogShowing = false;
  bool _foregroundGpsStream = false;

  /// Whether the app has genuinely been backgrounded since the last resume.
  ///
  /// A bare `resumed` does not mean the user went away and came back: the
  /// rotation transition under auto-rotate delivers `inactive` → `resumed`
  /// without ever reaching `paused`. Work that belongs to "the user returned"
  /// is keyed off this instead of off `resumed` alone.
  bool _wasBackgrounded = false;

  StreamSubscription<bool>? _micContestedSub;
  late final TabController _tabController;
  late final SurveyController _surveyController;

  @override
  void initState() {
    super.initState();
    QuickListenSafety.registerIncompatibleSessionOwner(
      _quickListenSafetyOwner,
      QuickListenSessionOwner.survey,
    );
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addObserver(this);

    _surveyController = ref.read(surveyControllerProvider);
    _surveyController.onStateChanged = _onControllerStateChanged;
    _surveyController.onAutoStop = _onAutoStop;

    // Listen for "Stop" button pressed in the foreground notification.
    FlutterForegroundTask.addTaskDataCallback(_onNotificationData);

    // Forward microphone-contention status from the audio capture
    // service to the survey controller so the foreground notification
    // can show "Microphone in use by another app — audio paused"
    // (issue #29 — keeps users from thinking the app has frozen when
    // an audiobook or voice recorder grabs the mic).
    final captureService = ref.read(audioCaptureServiceProvider);
    _micContestedSub = captureService.micContestedStream.listen((contested) {
      if (!mounted) return;
      ref.read(surveyControllerProvider).setMicContested(contested);
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startSurvey();
    });
  }

  /// Handle data from the foreground service TaskHandler (e.g. Stop button).
  void _onNotificationData(Object data) {
    if (data is Map && data['action'] == 'stop') {
      _confirmStop();
    }
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    final controller = ref.read(surveyControllerProvider);
    ref.read(surveyStateProvider.notifier).state = controller.state;
    ref.read(surveyDetectionsProvider.notifier).state =
        controller.currentLiveDetections;
    ref.read(surveySessionProvider.notifier).state = controller.session;
  }

  /// Delete [detection] from the live session and surface a SnackBar
  /// with an UNDO action. Live deletes mutate `controller.session`
  /// directly so derived stats (count/species) and map markers refresh
  /// on the next rebuild. The undo restores the record at its original
  /// list position so chronological order is preserved.
  void _deleteLiveDetectionWithUndo(DetectionRecord detection) {
    final controller = ref.read(surveyControllerProvider);
    final session = controller.session;
    if (session == null) return;
    final index = session.detections.indexOf(detection);
    if (index < 0) return;
    setState(() => session.detections.removeAt(index));
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    const lifetime = Duration(seconds: 4);
    final snackBarController = messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.sessionDetectionRemoved),
        duration: lifetime,
        action: SnackBarAction(
          label: l10n.sessionUndo,
          onPressed: () {
            if (!mounted) return;
            setState(() {
              final clamped = index.clamp(0, session.detections.length);
              session.detections.insert(clamped, detection);
            });
          },
        ),
      ),
    );
    Future.delayed(lifetime, () {
      try {
        snackBarController.close();
      } catch (_) {}
    });
  }

  /// Center used before the first GPS fix lands, so the map isn't stranded
  /// over the default world view while the survey warms up.
  LatLng? get _mapFallbackCenter =>
      widget.startLatitude != null && widget.startLongitude != null
          ? LatLng(widget.startLatitude!, widget.startLongitude!)
          : null;

  /// Open the clip player for a live detection marker. Shared by the inline
  /// map tab and the fullscreen map so both surfaces behave identically.
  /// Returns the sheet's future so callers can refresh once it closes.
  Future<void> _openLiveClipPlayer(DetectionRecord detection) {
    return showClipPlayerSheet(
      context,
      detection: detection,
      session: ref.read(surveySessionProvider),
      onConfirmChanged: () {
        if (mounted) setState(() {});
      },
      onDelete: () => _deleteLiveDetectionWithUndo(detection),
    );
  }

  /// Push the fullscreen live map. Unlike the inline map it does not
  /// auto-follow the GPS position — the user pans and zooms freely for
  /// navigation and taps the recenter button to jump back.
  void _openFullscreenLiveMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => _FullscreenLiveSurveyMapScreen(
              fallbackCenter: _mapFallbackCenter,
              onMarkerTap: _openLiveClipPlayer,
            ),
      ),
    );
  }

  /// Open the species picker and, on confirm, log a manual observation.
  ///
  /// Manual entries get [DetectionSource.manual], a 1.0 confidence, the
  /// current GPS fix (if available), "now" as their timestamp, and whichever
  /// heard / seen evidence the user ticked in the picker. They surface
  /// immediately in the live detection list and on the map, and are visually
  /// distinguished by a small `edit_note` chip + "manual" badge (plus the
  /// hearing / visibility glyphs) everywhere a [DetectionRecord] is rendered.
  Future<void> _addManualObservation() async {
    if (!mounted) return;
    final controller = ref.read(surveyControllerProvider);
    final session = controller.session;
    if (session == null) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final positionSec =
        DateTime.now().difference(session.startTime).inMilliseconds / 1000.0;
    final result = await Navigator.of(context).push<AddSpeciesResult>(
      MaterialPageRoute(
        builder:
            (_) => AddSpeciesOverlay(
              sessionStart: session.startTime,
              positionSec: positionSec,
              existingDetections: session.detections,
              initialMode: AddSpeciesInsertMode.atTimestamp,
              lockMode: true,
              titleOverride: l10n.surveyAddObservationTitle,
            ),
        fullscreenDialog: true,
      ),
    );
    if (result == null || !mounted) return;

    final record = await controller.addManualDetection(
      scientificName: result.scientificName,
      commonName: result.commonName,
      evidence: result.evidence,
      userSpecified: result.userSpecified,
    );
    if (record == null || !mounted) return;
    setState(() {});
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.surveyAddObservationSnackbar(record.commonName)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Bottom-sheet entry point for the survey-live FAB. Mirrors the
  /// "Add ___" menu in Session Review but only exposes the actions that
  /// are safe during an active capture: a manual species observation
  /// and a session-level text note. Voice memos require the mic, which
  /// is busy with the survey's own capture, so they are intentionally
  /// omitted here — users can still attach memos in Session Review
  /// after the survey ends.
  Future<void> _showAddMenu() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final value = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.addCircleOutline),
                  title: Text(l10n.sessionAddSpecies),
                  onTap: () => Navigator.of(ctx).pop('species'),
                ),
                ListTile(
                  leading: const Icon(AppIcons.noteAdd),
                  title: Text(l10n.sessionAddAnnotationOption),
                  onTap: () => Navigator.of(ctx).pop('annotation'),
                ),
              ],
            ),
          ),
    );
    if (!mounted || value == null) return;
    if (value == 'species') {
      await _addManualObservation();
    } else if (value == 'annotation') {
      await _addNote();
    }
  }

  /// Capture a session-level text note (title + body) and append it to
  /// the active survey via [SurveyController.addAnnotation]. Notes here
  /// are always session-global — there is no playhead to anchor a
  /// timestamp to during a live survey.
  Future<void> _addNote() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(surveyControllerProvider);
    final session = controller.session;
    if (session == null) return;
    final messenger = ScaffoldMessenger.of(context);

    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            title: Text(l10n.sessionAddAnnotationOption),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: l10n.sessionAnnotationName,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bodyController,
                    decoration: InputDecoration(
                      hintText: l10n.sessionAddAnnotation,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 5,
                    minLines: 2,
                    autofocus: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final text = bodyController.text.trim();
                  final title = titleController.text.trim();
                  if (text.isEmpty && title.isEmpty) return;
                  Navigator.of(ctx).pop(true);
                },
                child: Text(l10n.sessionSave),
              ),
            ],
          ),
    );
    final noteTitle = titleController.text.trim();
    final noteBody = bodyController.text.trim();
    titleController.dispose();
    bodyController.dispose();
    if (!mounted || saved != true) return;

    final annotation = SessionAnnotation(
      title: noteTitle,
      text: noteBody,
      createdAt: DateTime.now(),
    );
    await controller.addAnnotation(annotation);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.surveyAddNoteSnackbar),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onAutoStop(String reason) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.surveyAutoStopped(reason)),
        duration: const Duration(seconds: 3),
      ),
    );
    _finalizeAndReview();
  }

  /// Construct and attach the [SurveyAlertCoordinator] honoring all
  /// `surveyAlert*` user prefs. Skips entirely when alerts are off.
  ///
  /// Called from [_startSurvey] for both fresh starts AND resumes (before
  /// `controller.resumeSurvey(...)`), so the resumed session always picks
  /// up the *current* notification settings — not whatever was configured
  /// when the survey was first started. Each call replaces (and shuts
  /// down) any previously-attached coordinator via `setAlertCoordinator`,
  /// ensuring the foreground notification pipeline never holds a stale
  /// snapshot of the user's preferences.
  Future<void> _maybeBuildAlertCoordinator({
    required SurveyController controller,
  }) async {
    final modeIdx = ref.read(surveyAlertModeProvider);
    final mode = AlertMode.fromPrefValue(modeIdx);
    if (mode == AlertMode.off) {
      await controller.setAlertCoordinator(null);
      return;
    }
    final l10n = AppLocalizations.of(context)!;

    final notifier = ref.read(speciesAlertNotifierProvider);
    final sound = ref.read(surveyAlertSoundProvider);
    final vibrate = ref.read(surveyAlertVibrateProvider);
    final strings = SpeciesAlertStrings(
      channelName: l10n.surveyAlertChannelName,
      channelDescription: l10n.surveyAlertChannelDescription,
      firstInSessionBody: l10n.surveyAlertBodyFirstInSession,
      firstEverBody: l10n.surveyAlertBodyFirstEver,
      // l10n.surveyAlertBodyRare requires a String pct placeholder; the
      // notifier substitutes `{pct}` at delivery time so we pass the raw
      // template through.
      rareBody: l10n.surveyAlertBodyRare('{pct}'),
      watchlistBody: l10n.surveyAlertBodyWatchlist,
      summaryTitle: l10n.surveyAlertSummaryTitle(0).replaceAll('0', '{count}'),
      summaryBody: l10n
          .surveyAlertSummaryBody(0, '{names}')
          .replaceAll('0', '{count}'),
    );
    await notifier.init(strings: strings, sound: sound, vibrate: vibrate);

    final history = ref.read(globalSpeciesHistoryProvider);
    history.load();
    final geoScores = await ref.read(geoScoresProvider.future);

    Set<String>? watchlist;
    final wlName = ref.read(surveyAlertWatchlistNameProvider);
    if (mode == AlertMode.watchlist && wlName.isNotEmpty) {
      try {
        watchlist = await CustomSpeciesList.load(wlName);
      } catch (_) {
        watchlist = const <String>{};
      }
    }

    final coord = SurveyAlertCoordinator(
      mode: mode,
      notifier: notifier,
      notifierStrings: strings,
      globalHistory: history,
      geoScores: geoScores,
      watchlist: watchlist,
      minConfidence: ref.read(surveyAlertMinConfidenceProvider),
      rareThreshold: ref.read(surveyAlertRareThresholdProvider),
      startupGraceSeconds: ref.read(surveyAlertStartupGraceSecondsProvider),
      minIntervalSeconds: ref.read(surveyAlertMinIntervalSecondsProvider),
      maxPerMinute: ref.read(surveyAlertMaxPerMinuteProvider),
      coalesce: ref.read(surveyAlertCoalesceProvider),
      inAppToast: ref.read(surveyAlertInAppToastProvider),
      onDelivered: _onAlertDelivered,
      nameLocalizer: _buildNameLocalizer(),
    );
    await controller.setAlertCoordinator(coord);
  }

  /// Build a closure that maps a scientific name to the user's preferred
  /// localized common name. Used by the foreground notification, which
  /// always shows common names (in the user's species locale) regardless
  /// of the in-app "show scientific names" toggle — Latin binomials are
  /// hard to read on a lock screen and don't help users at-a-glance.
  /// Reads the taxonomy lazily on each call so names start translating
  /// as soon as the taxonomy service finishes loading (which can happen
  /// *after* survey start).
  String Function(String, String) _buildNameLocalizer() {
    return (sciName, fallback) {
      final taxonomy = ref.read(taxonomyServiceProvider).value;
      final speciesLocale = ref.read(effectiveSpeciesLocaleProvider);
      return taxonomy?.lookup(sciName)?.commonNameForLocale(speciesLocale) ??
          fallback;
    };
  }

  void _onAlertDelivered(AlertCandidate? one, SummaryAlert? summary) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final String text;
    if (one != null) {
      text = one.commonName;
    } else if (summary != null) {
      text = summary.alerts.map((a) => a.commonName).join(', ');
    } else {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              AppIcons.notificationsActiveRounded,
              color: Theme.of(context).colorScheme.onInverseSurface,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startSurvey() async {
    if (_started) return;
    final controller = ref.read(surveyControllerProvider);
    final captureNotifier = ref.read(captureStateProvider.notifier);
    final captureService = ref.read(audioCaptureServiceProvider);
    final audioSource = ref.read(audioSourceProvider);
    // Capture localizations now — the rest of this method awaits multiple
    // futures and we want to wire foreground-notification strings without
    // crossing BuildContext async gaps.
    final l10n = AppLocalizations.of(context)!;

    // Apply user-tunable DSP (gain + high-pass) before capture starts.
    captureService.setGain(ref.read(audioGainProvider));
    captureService.setHighPassCutoff(ref.read(highPassFilterProvider));

    // Start audio capture.
    await captureNotifier.start(source: audioSource);
    if (captureService.state != CaptureState.capturing) {
      _showStartError(
        captureService.lastError == 'Microphone permission not granted'
            ? l10n.errorMicrophoneRequired
            : captureService.lastError ?? l10n.statusError,
      );
      return;
    }

    // Read settings.
    final windowDuration = ref.read(windowDurationProvider);
    final inferenceRate = ref.read(surveyInferenceRateProvider);
    final confidenceThreshold = ref.read(confidenceThresholdProvider);
    final filterMode = ref.read(speciesFilterModeProvider);
    // When resuming, keep the session's *original* recording mode and format
    // rather than the current global setting. This preserves continuity (a
    // clip-subsampling session stays clips) and guarantees a resumed session
    // never switches into full-audio recording — which can't be safely
    // concatenated across a resume, and is why the Continue button is hidden
    // for full-audio sessions in the first place.
    final resumeSettings = widget.resumeSession?.settings;
    var recordingModeStr = ref.read(surveyRecordingModeProvider);
    var recordingFormat = ref.read(recordingFormatProvider);
    if (widget.resumeSession != null) {
      // Legacy resumable sessions have no recording snapshot and no audio
      // path. Keep them audio-free instead of inheriting a newer global
      // setting that could create a partial full-session recording.
      recordingModeStr = resumeSettings?.recordingMode ?? 'off';
      recordingFormat = resumeSettings?.recordingFormat ?? recordingFormat;
    }
    final recordingMode = recordingModeFromString(recordingModeStr);
    final geoThreshold = ref.read(geoThresholdProvider);
    final gpsInterval = ref.read(surveyGpsIntervalProvider);
    final maxDuration = ref.read(surveyMaxDurationProvider);
    final samplingStr = ref.read(surveyDetectionSamplingProvider);
    final samplingMode = samplingModeFromString(samplingStr);
    final topN = ref.read(surveyTopNPerSpeciesProvider);
    final autoStopBattery = ref.read(surveyAutoStopBatteryProvider);
    final clipContext = ref.read(surveyClipContextProvider);

    final geoScores = await ref.read(geoScoresProvider.future);
    final geoSpeciesNames = await ref.read(geoModelSpeciesNamesProvider.future);
    final ignoredSpeciesNames = await ref.read(
      ignoredSpeciesNamesProvider.future,
    );

    // Build the species-alert pipeline before starting the controller so
    // the very first detection can fire a notification. If the user
    // chose `off` we skip everything — no plugin init, no history load.
    await _maybeBuildAlertCoordinator(controller: controller);

    // Wire localization helpers used by the foreground notification's
    // recent-detections list (species names + relative timestamps).
    controller.setNameLocalizer(_buildNameLocalizer());
    controller.setNotificationStrings(
      title: l10n.surveyNotificationTitle,
      justNow: l10n.surveyJustNow,
      secondsAgo: (s) => l10n.surveySecondsAgo(s),
      minutesAgo: (m) => l10n.surveyMinutesAgo(m),
      hoursAgo: (h) => l10n.surveyHoursAgo(h),
      stats:
          (elapsed, det, spp, km) =>
              l10n.surveyNotificationStats(elapsed, det, spp, km),
      micContested: l10n.surveyNotificationMicContested,
    );

    // With whileInUse permission, use the GPS stream while in the foreground.
    // The screen's lifecycle handler will stop/restart it as the app is
    // backgrounded and foregrounded.
    if (!widget.backgroundGps && ref.read(useGpsProvider)) {
      final permission = await Geolocator.checkPermission();
      _foregroundGpsStream =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    }

    if (widget.resumeSession != null) {
      await controller.resumeSurvey(
        existingSession: widget.resumeSession!,
        windowDuration: windowDuration,
        inferenceRate: inferenceRate,
        confidenceThreshold: confidenceThreshold,
        speciesFilterMode: filterMode,
        recordingMode: recordingMode,
        recordingFormat: recordingFormat,
        geoScores: geoScores,
        geoThreshold: geoThreshold,
        geoModelSpeciesNames: geoSpeciesNames,
        gpsIntervalSeconds: gpsInterval,
        maxDurationHours: maxDuration,
        samplingMode: samplingMode,
        topNPerSpecies: topN,
        backgroundGps: widget.backgroundGps,
        foregroundGps: _foregroundGpsStream,
        autoStopBattery: autoStopBattery,
        poolingWindows: ref.read(scorePoolingWindowsProvider),
        poolingMode: ref.read(scorePoolingProvider),
        poolingMaxAgeSeconds: ref.read(scorePoolingMaxAgeSecondsProvider),
        advancedPooling: ref.read(advancedPoolingParamsProvider),
        sensitivity: ref.read(sensitivityProvider),
        ignoreSettings: ref.read(speciesIgnoreSettingsProvider),
        ignoredSpeciesNames: ignoredSpeciesNames,
      );
    } else {
      await controller.startSurvey(
        windowDuration: windowDuration,
        inferenceRate: inferenceRate,
        confidenceThreshold: confidenceThreshold,
        speciesFilterMode: filterMode,
        recordingMode: recordingMode,
        recordingFormat: recordingFormat,
        geoScores: geoScores,
        geoThreshold: geoThreshold,
        geoModelSpeciesNames: geoSpeciesNames,
        gpsIntervalSeconds: gpsInterval,
        maxDurationHours: maxDuration,
        samplingMode: samplingMode,
        topNPerSpecies: topN,
        clipContextSeconds: clipContext,
        transectId: widget.transectId,
        observerName: widget.observerName,
        customName: widget.customName,
        startLatitude: widget.startLatitude,
        startLongitude: widget.startLongitude,
        backgroundGps: widget.backgroundGps,
        foregroundGps: _foregroundGpsStream,
        autoStopBattery: autoStopBattery,
        poolingWindows: ref.read(scorePoolingWindowsProvider),
        poolingMode: ref.read(scorePoolingProvider),
        poolingMaxAgeSeconds: ref.read(scorePoolingMaxAgeSecondsProvider),
        advancedPooling: ref.read(advancedPoolingParamsProvider),
        sensitivity: ref.read(sensitivityProvider),
        ignoreSettings: ref.read(speciesIgnoreSettingsProvider),
        ignoredSpeciesNames: ignoredSpeciesNames,
        gainLinear: ref.read(audioGainProvider),
        highPassHz: ref.read(highPassFilterProvider).toDouble(),
      );
    }

    if (controller.state == SurveyState.error) {
      await captureNotifier.stop();
      _showStartError(controller.errorMessage ?? l10n.statusError);
      _onControllerStateChanged();
      return;
    }

    _started = true;
    _onControllerStateChanged();
  }

  void _showStartError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
      );
  }

  Future<void> _confirmStop() async {
    // Guard against duplicate confirmation dialogs. The notification "Stop"
    // button can be tapped multiple times while the app is in the
    // background; without this guard each tap pushes another dialog
    // onto the route stack ("Exit Survey" modal pile-up — issue #29).
    if (_stopDialogShowing || _finalizing) return;
    _stopDialogShowing = true;
    final l10n = AppLocalizations.of(context)!;
    try {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.surveyStopTitle,
        body: l10n.surveyStopMessage,
        confirmLabel: l10n.surveyStopConfirm,
        cancelLabel: l10n.cancel,
      );
      if (!confirmed || !mounted) return;
      await _finalizeAndReview();
    } finally {
      _stopDialogShowing = false;
    }
  }

  Future<void> _finalizeAndReview() async {
    if (_finalizing) return;
    _finalizing = true;

    try {
      final controller = ref.read(surveyControllerProvider);
      final captureNotifier = ref.read(captureStateProvider.notifier);

      await captureNotifier.stop();
      final session = await controller.stopSurvey();
      _onControllerStateChanged();

      if (session != null && mounted) {
        final repo = ref.read(sessionRepositoryProvider);
        session.sessionNumber = await repo.nextSessionNumber(session.type);
        await repo.save(session);
        ref.invalidate(sessionListProvider);

        if (mounted) {
          final navigator = Navigator.of(context);
          navigator.pushReplacement(
            PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (a, b, c) => const SessionLibraryScreen(),
            ),
          );
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => SessionReviewScreen(session: session),
            ),
          );
        }
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      debugPrint('[SurveyLiveScreen] finalize error: $e\n$st');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.statusError}: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      _finalizing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(surveyControllerProvider);

    // Read before the flag is updated below, so a `resumed` still sees whether
    // it is closing a real backgrounding or just a rotation.
    final returnedFromBackground =
        state == AppLifecycleState.resumed && _wasBackgrounded;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed) {
      _wasBackgrounded = false;
    }

    if (_foregroundGpsStream && !widget.backgroundGps) {
      // Foreground-only GPS: stop the stream when backgrounded so the OS
      // doesn't revoke whileInUse location access, and restart it when the
      // user brings the app back to the front. Safe to call on a rotation's
      // `resumed` too — [SurveyGpsTracker.startTracking] is a no-op while the
      // stream is still running.
      if (state == AppLifecycleState.paused) {
        controller.stopGpsTracking();
      } else if (state == AppLifecycleState.resumed) {
        controller.startGpsTracking();
      }
    } else if (returnedFromBackground &&
        !widget.backgroundGps &&
        ref.read(useGpsProvider)) {
      // Manual GPS mode: capture a single fix when the user returns. Gated on
      // an actual backgrounding rather than a bare `resumed` — otherwise every
      // rotation of the phone spins the GPS radio up for a fix nobody asked
      // for, which adds up over a multi-hour survey.
      controller.captureGpsFix();
    }
  }

  @override
  void dispose() {
    QuickListenSafety.unregisterIncompatibleSessionOwner(
      _quickListenSafetyOwner,
    );
    if (_surveyController.onStateChanged == _onControllerStateChanged) {
      _surveyController.onStateChanged = null;
    }
    if (_surveyController.onAutoStop == _onAutoStop) {
      _surveyController.onAutoStop = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onNotificationData);
    _micContestedSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surveyState = ref.watch(surveyStateProvider);
    // The active survey session is mutated in place, so watching the
    // per-cycle live detections provides a reliable rebuild signal for the
    // map/list shell even when the session object identity stays unchanged.
    final _ = ref.watch(surveyDetectionsProvider);
    final session = ref.watch(surveySessionProvider);
    final controller = ref.read(surveyControllerProvider);
    final ringBuffer = ref.read(ringBufferProvider);
    final isActive = surveyState == SurveyState.active;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Hot-apply tunable settings to the running survey: when the user
    // tweaks the confidence threshold or pooling window count from the
    // Settings screen mid-survey, push the new value straight to the
    // controller so the next inference cycle picks it up — no need to
    // restart the survey.
    ref.listen<int>(confidenceThresholdProvider, (_, next) {
      ref.read(surveyControllerProvider).setConfidenceThreshold(next);
    });
    ref.listen<int>(scorePoolingWindowsProvider, (_, next) {
      ref.read(surveyControllerProvider).setPoolingWindows(next);
    });
    ref.listen<double>(scorePoolingMaxAgeSecondsProvider, (_, next) {
      ref.read(surveyControllerProvider).setPoolingMaxAgeSeconds(next);
    });
    ref.listen<String>(scorePoolingProvider, (_, next) {
      ref.read(surveyControllerProvider).setPoolingMode(next);
    });
    ref.listen<AdvancedPoolingParams>(advancedPoolingParamsProvider, (_, next) {
      ref.read(surveyControllerProvider).setAdvancedPoolingParams(next);
    });
    ref.listen<double>(sensitivityProvider, (_, next) {
      ref.read(surveyControllerProvider).setSensitivity(next);
    });
    ref.listen(speciesIgnoreSettingsProvider, (_, _) async {
      final names = await ref.read(ignoredSpeciesNamesProvider.future);
      final geoScores = await ref.read(geoScoresProvider.future);
      ref
          .read(surveyControllerProvider)
          .setSpeciesIgnoreFilter(scientificNames: names, geoScores: geoScores);
    });
    ref.listen<double>(audioGainProvider, (_, next) {
      ref.read(audioCaptureServiceProvider).setGain(next);
    });
    ref.listen<double>(highPassFilterProvider, (_, next) {
      ref.read(audioCaptureServiceProvider).setHighPassCutoff(next);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (isActive) {
          await _confirmStop();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: _buildBody(
            context,
            theme: theme,
            l10n: l10n,
            isActive: isActive,
            session: session,
            controller: controller,
            ringBuffer: ringBuffer,
          ),
        ),
        // Add-menu entry point. Sized .small + endFloat so it doesn't
        // compete visually with the Stop button in the status bar.
        // Hidden when the survey isn't active so it can't fire mid-finalize.
        floatingActionButton:
            isActive
                ? FloatingActionButton.small(
                  onPressed: _showAddMenu,
                  tooltip: l10n.surveyAddMenuTitle,
                  child: const Icon(AppIcons.add),
                )
                : null,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required ThemeData theme,
    required AppLocalizations l10n,
    required bool isActive,
    required dynamic session,
    required dynamic controller,
    required dynamic ringBuffer,
  }) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final statusBar = _SurveyStatusBar(
      isActive: isActive,
      alertMode: AlertMode.fromPrefValue(ref.watch(surveyAlertModeProvider)),
      onStop: _confirmStop,
    );
    final tabBar = TabBar(
      controller: _tabController,
      tabs: [
        Tab(icon: const Icon(AppIcons.map, size: 18), text: l10n.surveyTabMap),
        Tab(
          icon: const Icon(AppIcons.graphicEq, size: 18),
          text: l10n.surveyTabSpectrogram,
        ),
        Tab(
          icon: Icon(AppIcons.summaryChart, size: 18),
          text: l10n.surveyTabSummary,
        ),
        Tab(
          icon: const Icon(AppIcons.search, size: 18),
          text: l10n.exploreTitle,
        ),
      ],
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      indicatorWeight: 2,
      labelStyle: theme.textTheme.labelSmall,
    );
    final tabContent = TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Stack(
          children: [
            Positioned.fill(
              child: SurveyMapWidget(
                gpsTrack: controller.gpsTracker?.track ?? [],
                detections: session?.detections ?? [],
                initialCenter: _mapFallbackCenter,
                // Tapping a marker that has a kept clip opens the same
                // player sheet as the post-session map - so the live and
                // review surfaces feel like one continuous experience.
                onMarkerTap: (detection) => _openLiveClipPlayer(detection),
              ),
            ),
            // Expand affordance mirroring Session Review's inline map: the
            // minimized map keeps auto-following the current position, the
            // fullscreen one hands panning and zooming to the user.
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openFullscreenLiveMap,
                  child: Tooltip(
                    message: l10n.surveyMapFullscreen,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        AppIcons.fullscreen,
                        size: 20,
                        color: theme.colorScheme.onSurface,
                        semanticLabel: l10n.surveyMapFullscreen,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        _SurveySpectrogram(ringBuffer: ringBuffer, isActive: isActive),
        _SurveySummaryTab(session: session),
        const ExploreScreen(isEmbedded: true),
      ],
    );
    final statsBar = _LiveSurveyStatsBar(isActive: isActive);
    final detectionList = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: DetectionList(
          detections: _recentDetections(session),
          isActive: isActive,
          onDetectionTap: (detection) {
            SpeciesInfoOverlay.show(
              context,
              ref,
              scientificName: detection.scientificName,
              commonName: detection.commonName,
            );
          },
          // Per-detection actions during a live survey: inline confirm
          // (so reviewers can validate calls as they hear them), share
          // and delete in the overflow. Replace stays a review-only
          // action because picking an alternative species needs the
          // full search overlay.
          actionsBuilder:
              (detection) => DetectionActions(
                isConfirmed: detection.isConfirmed,
                onToggleConfirm: () {
                  setState(() {
                    detection.confirmedAt =
                        detection.isConfirmed ? null : DateTime.now().toUtc();
                  });
                },
                onShare:
                    (origin) => unawaited(
                      reportShareFailure(
                        context,
                        shareDetection(
                          detection,
                          session: session,
                          formats: ref.read(exportSelectionProvider),
                          includeAudio: ref.read(includeAudioProvider),
                          shareAudioAsWav: ref.read(shareAudioAsWavProvider),
                          includeHtmlReport: ref.read(exportHtmlReportProvider),
                          includeAppMetadata: ref.read(
                            includeAppMetadataProvider,
                          ),
                          taxonomy: ref.read(taxonomyServiceProvider).value,
                          speciesLocale: ref.read(
                            effectiveSpeciesLocaleProvider,
                          ),
                          useAbsoluteSurveyTime:
                              ref.read(timestampDisplayModeProvider) ==
                              'absolute',
                          sharePositionOrigin: origin,
                        ),
                      ),
                    ),
                onDelete: () => _deleteLiveDetectionWithUndo(detection),
              ),
        ),
      ),
    );

    final showFullPageTab =
        _tabController.index == 2 || _tabController.index == 3;

    if (isLandscape) {
      return Column(
        children: [
          statusBar,
          Expanded(
            child: Row(
              children: [
                // Left: tabs (map/spectrogram/summary) + stats
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      tabBar,
                      Expanded(child: tabContent),
                      if (!showFullPageTab) statsBar,
                    ],
                  ),
                ),
                // Right: detection list
                if (!showFullPageTab) Expanded(flex: 1, child: detectionList),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    // Portrait: original vertical stack.
    return Column(
      children: [
        statusBar,
        tabBar,
        Expanded(flex: showFullPageTab ? 1 : 2, child: tabContent),
        if (!showFullPageTab) ...[
          statsBar,
          Expanded(flex: 3, child: detectionList),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fullscreen Live Survey Map
// ─────────────────────────────────────────────────────────────────────────────

/// Fullscreen version of the live survey map.
///
/// The inline map tab keeps the camera pinned to the latest GPS fix, which is
/// what you want in a glanceable strip but makes the map useless for looking
/// ahead. This screen turns auto-follow off so the map behaves like a normal
/// navigation map — pan and zoom stay exactly where the user put them, no
/// matter how many GPS points arrive — with a recenter button to jump back to
/// the current position on demand.
class _FullscreenLiveSurveyMapScreen extends ConsumerStatefulWidget {
  const _FullscreenLiveSurveyMapScreen({
    required this.onMarkerTap,
    this.fallbackCenter,
  });

  /// Opens the clip player for a tapped detection. Owned by the live screen
  /// so deletes and confirmations mutate the one running session.
  final Future<void> Function(DetectionRecord detection) onMarkerTap;

  /// Where to center before the first GPS fix arrives.
  final LatLng? fallbackCenter;

  @override
  ConsumerState<_FullscreenLiveSurveyMapScreen> createState() =>
      _FullscreenLiveSurveyMapScreenState();
}

class _FullscreenLiveSurveyMapScreenState
    extends ConsumerState<_FullscreenLiveSurveyMapScreen> {
  /// Owned here (rather than inside [SurveyMapWidget]) so the recenter
  /// button can drive the camera.
  final MapController _mapController = MapController();

  /// Set once the map has been laid out at least once — [MapController]
  /// throws when used before that.
  bool _mapReady = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenter() {
    if (!_mapReady) return;
    final track = ref.read(surveyControllerProvider).gpsTracker?.track;
    final target =
        track != null && track.isNotEmpty
            ? LatLng(track.last.latitude, track.last.longitude)
            : widget.fallbackCenter;
    if (target == null) return;
    // Keep the user's zoom when they're already close in; only pull in when
    // they've zoomed out far enough that the position marker would be lost.
    final zoom = _mapController.camera.zoom;
    _mapController.move(target, zoom < 16 ? 17 : zoom);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Same rebuild signal the live dashboard uses: the session object is
    // mutated in place, so the per-cycle detections provider is what tells us
    // new markers and GPS points have landed.
    ref.watch(surveyDetectionsProvider);
    final session = ref.watch(surveySessionProvider);
    final controller = ref.read(surveyControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.surveyTrackMap)),
      body: SurveyMapWidget(
        mapController: _mapController,
        gpsTrack: controller.gpsTracker?.track ?? const [],
        detections: session?.detections ?? const [],
        // Free navigation: never yank the camera back to the latest fix.
        autoFollow: false,
        initialCenter: widget.fallbackCenter,
        onMarkerTap: (detection) async {
          await widget.onMarkerTap(detection);
          // The sheet can delete the detection; rebuild so its marker goes.
          if (mounted) setState(() {});
        },
        onCameraMove: (_) {
          if (!_mapReady) _mapReady = true;
        },
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _recenter,
        tooltip: l10n.surveyMapRecenter,
        child: const Icon(AppIcons.myLocation),
      ),
      // Bottom-left: the OpenStreetMap attribution badge owns the
      // bottom-right corner of every map in the app.
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Survey App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _SurveyStatusBar extends ConsumerStatefulWidget {
  const _SurveyStatusBar({
    required this.isActive,
    required this.alertMode,
    required this.onStop,
  });

  final bool isActive;
  final AlertMode alertMode;
  final VoidCallback onStop;

  @override
  ConsumerState<_SurveyStatusBar> createState() => _SurveyStatusBarState();
}

class _SurveyStatusBarState extends ConsumerState<_SurveyStatusBar> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = ref.read(surveyControllerProvider).elapsed;
    if (widget.isActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _SurveyStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && _timer == null) {
      _startTimer();
    } else if (!widget.isActive && _timer != null) {
      _stopTimer();
    }
  }

  void _startTimer() {
    // Reflect the current elapsed immediately so a resumed session shows its
    // accumulated total right away instead of flashing 00:00:00 until the
    // first tick fires. Assigning without setState is safe here: _startTimer
    // is only called from initState / didUpdateWidget, both already inside a
    // build cycle that will render this value.
    _elapsed = ref.read(surveyControllerProvider).elapsed;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = ref.read(surveyControllerProvider).elapsed;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final hours = _elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Row(
        children: [
          // Stop button (matches point count).
          IconButton(
            icon: const Icon(AppIcons.stopRounded, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed:
                widget.isActive
                    ? widget.onStop
                    : () => Navigator.of(context).pop(),
            tooltip: l10n.surveyStop,
            color: widget.isActive ? theme.colorScheme.error : null,
          ),

          // Elapsed timer (center).
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.timerRounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$hours:$minutes:$seconds',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Help button.
          IconButton(
            icon: Icon(
              AppIcons.helpOutlineRounded,
              size: 20,
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () => _showSurveyHelp(context),
            tooltip: l10n.surveyLiveHelpTitle,
          ),

          // Alert mode indicator.
          if (widget.alertMode != AlertMode.off)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tooltip(
                message: l10n.surveyAlertsTitle,
                child: Icon(
                  AppIcons.notificationsActiveRounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

          // Settings gear (matches point count).
          IconButton(
            icon: Icon(
              AppIcons.tuneRounded,
              size: 20,
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => const SettingsScreen(
                        settingsContext: SettingsContext.survey,
                      ),
                ),
              );
            },
            tooltip: l10n.settings,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Survey Live Stats Bar Wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _LiveSurveyStatsBar extends ConsumerStatefulWidget {
  const _LiveSurveyStatsBar({required this.isActive});

  final bool isActive;

  @override
  ConsumerState<_LiveSurveyStatsBar> createState() =>
      _LiveSurveyStatsBarState();
}

class _LiveSurveyStatsBarState extends ConsumerState<_LiveSurveyStatsBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _LiveSurveyStatsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && _timer == null) {
      _startTimer();
    } else if (!widget.isActive && _timer != null) {
      _stopTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(surveyControllerProvider);
    final session = ref.watch(surveySessionProvider);
    final ringBuffer = ref.read(ringBufferProvider);
    // Polled on the 1 s stats-bar timer — no stream subscription needed here;
    // the audio service flips this the moment the mic is lost or regained.
    final micLost = ref.read(audioCaptureServiceProvider).isMicContested;

    return SurveyStatsBar(
      distanceMeters: controller.gpsTracker?.distanceMeters ?? 0,
      detectionCount: session?.detections.length ?? 0,
      speciesCount: session?.uniqueSpeciesCount ?? 0,
      audioLevel: ringBuffer.rmsLevel(),
      peakLevel: ringBuffer.peakLevel(),
      micLost: micLost,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Survey Spectrogram Tab
// ─────────────────────────────────────────────────────────────────────────────

class _SurveySpectrogram extends ConsumerWidget {
  const _SurveySpectrogram({required this.ringBuffer, required this.isActive});

  final RingBuffer ringBuffer;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fftSize = ref.watch(fftSizeProvider);
    final colorMap = ref.watch(colorMapProvider);
    final dbFloor = ref.watch(dbFloorProvider);
    final dbCeiling = ref.watch(dbCeilingProvider);
    final durationSec = ref.watch(spectrogramDurationProvider);
    final maxFreq = ref.watch(spectrogramMaxFreqProvider);
    final logAmplitude = ref.watch(logAmplitudeProvider);
    final quality = ref.watch(spectrogramQualityProvider);

    return SpectrogramWidget(
      ringBuffer: ringBuffer,
      isActive: isActive,
      fftSize: fftSize,
      colorMapName: colorMap,
      dbFloor: dbFloor,
      dbCeiling: dbCeiling,
      displaySeconds: durationSec.toDouble(),
      showFrequencyAxis: false,
      showTimeAxis: false,
      maxDisplayFrequency: maxFreq,
      logAmplitude: logAmplitude,
      filterQuality: spectrogramFilterQualityFromString(quality),
      quality: quality,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Survey Summary Tab
// ─────────────────────────────────────────────────────────────────────────────

class _SurveySummaryTab extends ConsumerWidget {
  const _SurveySummaryTab({required this.session});

  final LiveSession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final showSciNames = ref.watch(showSciNamesProvider);

    if (session == null) {
      return Center(
        child: Text(
          l10n.surveyStarting,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
        ),
      );
    }

    final detections = session!.detections;
    final speciesCounts = <String, _SpeciesSummary>{};
    for (final d in detections) {
      final existing = speciesCounts[d.scientificName];
      if (existing == null) {
        speciesCounts[d.scientificName] = _SpeciesSummary(
          scientificName: d.scientificName,
          commonName: d.commonName,
          count: 1,
          bestConfidence: d.confidence,
        );
      } else {
        existing.count++;
        if (d.confidence > existing.bestConfidence) {
          existing.bestConfidence = d.confidence;
        }
      }
    }

    final sorted =
        speciesCounts.values.toList()..sort((a, b) {
          final cmp = b.count.compareTo(a.count);
          if (cmp != 0) return cmp;
          return b.bestConfidence.compareTo(a.bestConfidence);
        });

    // Rate is per minute of *active recording* time, not wall-clock since
    // start — otherwise a resumed session dilutes the rate with the entire
    // stopped gap. [LiveSession.duration] already excludes pause/resume gaps
    // and matches the on-screen elapsed timer.
    final elapsed = session!.duration;
    final activeMinutes = elapsed.inMilliseconds / 60000.0;
    final rate =
        activeMinutes > 0
            ? (detections.length / activeMinutes).toStringAsFixed(1)
            : '0';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Quick stats row.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SummaryChip(
              label: l10n.surveyTabSummarySpecies,
              value: '${speciesCounts.length}',
              theme: theme,
            ),
            _SummaryChip(
              label: l10n.surveyTabSummaryDetections,
              value: '${detections.length}',
              theme: theme,
            ),
            _SummaryChip(
              label: l10n.surveyTabSummaryRate,
              value: '$rate/min',
              theme: theme,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Species list.
        for (final (i, sp) in sorted.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${sp.count}×',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        taxonomy
                                ?.lookup(sp.scientificName)
                                ?.commonNameForLocale(speciesLocale) ??
                            sp.commonName,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showSciNames)
                        Text(
                          taxonomy?.displayScientificName(sp.scientificName) ??
                              sp.scientificName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withAlpha(140),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Text(
                  '${(sp.bestConfidence * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: (theme.extension<ScoreColors>() ?? ScoreColors.light)
                        .forScore(sp.bestConfidence),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SpeciesSummary {
  _SpeciesSummary({
    required this.scientificName,
    required this.commonName,
    required this.count,
    required this.bestConfidence,
  });

  final String scientificName;
  final String commonName;
  int count;
  double bestConfidence;
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(150),
          ),
        ),
      ],
    );
  }
}

/// Extract the last 10 detections (newest first) for display.
List<DetectionRecord> _recentDetections(LiveSession? session) {
  final all = session?.detections ?? [];
  if (all.length > 10) {
    return all.sublist(all.length - 10).reversed.toList();
  }
  return all.reversed.toList();
}

void _showSurveyHelp(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _SurveyLiveHelpSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Survey Help Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SurveyLiveHelpSheet extends StatelessWidget {
  const _SurveyLiveHelpSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppHelpBottomSheet(
      title: l10n.surveyLiveHelpTitle,
      sections: [
        AppHelpSection(
          icon: AppIcons.infoOutline,
          body: l10n.surveyLiveHelpOverview,
        ),
        AppHelpSection(
          icon: AppIcons.helpOutlineRounded,
          body: l10n.surveyLiveHelpTopBar,
        ),
        AppHelpSection(icon: AppIcons.map, body: l10n.surveyLiveHelpTabs),
        AppHelpSection(icon: AppIcons.mic, body: l10n.surveyLiveHelpSignal),
        AppHelpSection(
          icon: AppIcons.species,
          body: l10n.surveyLiveHelpDetections,
        ),
      ],
    );
  }
}
