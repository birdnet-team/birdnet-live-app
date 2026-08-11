import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/aru/aru_controller.dart';
import 'features/aru/aru_notification.dart';
import 'features/aru/aru_notification_route.dart';
import 'features/aru/aru_providers.dart';
import 'features/audio/audio_capture_service.dart';
import 'features/audio/audio_providers.dart';
import 'features/file_analysis/file_analysis_controller.dart';
import 'features/file_analysis/file_analysis_providers.dart';
import 'features/file_analysis/file_analysis_screen.dart';
import 'features/live/live_controller.dart';
import 'features/live/live_providers.dart';
import 'features/live/live_screen.dart';
import 'features/live/live_session.dart';
import 'shared/providers/app_providers.dart';
import 'shared/services/quick_action_service.dart';
import 'shared/services/shared_media_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Resolve the UI locale from the platform/app preference list.
///
/// Flutter's generated locale list is alphabetized, so relying on the default
/// fallback can land unsupported languages on Czech because `cs` is first.
/// Prefer an exact language match from the user's locale list, otherwise fall
/// back to English explicitly.
Locale resolveAppLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  final supported = supportedLocales.toList();
  for (final preferred in preferredLocales ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == preferred.languageCode) return candidate;
    }
  }

  return supported.firstWhere(
    (locale) => locale.languageCode == 'en',
    orElse: () => supported.first,
  );
}

/// Root application widget.
///
/// Configures theme, localization, and the initial route based on
/// whether onboarding and policy acceptance have been completed.
class App extends ConsumerWidget {
  const App({super.key, this.launchSharedFile, this.launchQuickAction});

  /// An audio file another app shared with us that was already waiting when the
  /// app started. Read before the first frame so the app can open on File
  /// Analysis rather than painting Home and then navigating off it.
  final SharedAudioFile? launchSharedFile;

  /// A Quick Listen widget tap that started the app, read before the first
  /// frame for the same reason.
  final String? launchQuickAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final useDynamicColor = ref.watch(dynamicColorProvider);
    final useHighContrastTheme = ref.watch(highContrastThemeProvider);
    final locale = ref.watch(localeProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Use the platform's dynamic palette when the user has opted in
        // and the OS provides one. Otherwise fall back to the brand theme.
        final ThemeData lightTheme;
        final ThemeData darkTheme;

        if (useHighContrastTheme) {
          lightTheme = AppTheme.highContrastLight();
          darkTheme = AppTheme.highContrastDark();
        } else if (useDynamicColor &&
            lightDynamic != null &&
            darkDynamic != null) {
          lightTheme = AppTheme.fromColorScheme(lightDynamic.harmonized());
          darkTheme = AppTheme.fromColorScheme(darkDynamic.harmonized());
        } else {
          lightTheme = AppTheme.light();
          darkTheme = AppTheme.dark();
        }

        return MaterialApp(
          navigatorKey: appNavigatorKey,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,

          // Theme
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,

          // Localization
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppLocale,
          localeResolutionCallback:
              (locale, supportedLocales) => resolveAppLocale(
                locale == null ? null : <Locale>[locale],
                supportedLocales,
              ),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case AruNotificationService.openRoute:
                return MaterialPageRoute<void>(
                  builder:
                      (_) => const AruNotificationRoute(requestStop: false),
                  settings: settings,
                );
              case AruNotificationService.stopRoute:
                return MaterialPageRoute<void>(
                  builder: (_) => const AruNotificationRoute(requestStop: true),
                  settings: settings,
                );
            }
            return null;
          },

          // Initial screen based on app state
          home: _AruNotificationActionListener(
            child: _QuickActionListener(
              launchAction: launchQuickAction,
              child: _SharedAudioListener(
                launchSharedFile: launchSharedFile,
                child: const _AppGate(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AruNotificationActionListener extends ConsumerStatefulWidget {
  const _AruNotificationActionListener({required this.child});

  final Widget child;

  @override
  ConsumerState<_AruNotificationActionListener> createState() =>
      _AruNotificationActionListenerState();
}

class _AruNotificationActionListenerState
    extends ConsumerState<_AruNotificationActionListener> {
  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    AruNotificationService.setNativeActionHandler(_onNativeAction);
    unawaited(_takePendingNativeAction());
  }

  @override
  void dispose() {
    AruNotificationService.setNativeActionHandler(null);
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  Future<void> _takePendingNativeAction() async {
    final action = await AruNotificationService.takePendingNativeAction();
    if (!mounted || action == null) return;
    _handleAruAction(action);
  }

  void _onNativeAction(String action) {
    if (!mounted) return;
    _handleAruAction(action);
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final action = data['action'];
    if (action is String) {
      _handleAruAction(action);
    }
  }

  void _handleAruAction(String action) {
    if (action == 'aruOpen') {
      _openAruRoute(requestStop: false);
    } else if (action == 'aruStop') {
      _openAruRoute(requestStop: true);
    }
  }

  void _openAruRoute({required bool requestStop}) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => AruNotificationRoute(requestStop: requestStop),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Listens for the Quick Listen home-screen widget's launch action and
/// jumps straight to Live Mode with recording auto-started, on both cold
/// start (app was killed) and warm start (app already running). Mirrors
/// [_AruNotificationActionListener]'s native-action bridge pattern.
class _QuickActionListener extends ConsumerStatefulWidget {
  const _QuickActionListener({required this.child, this.launchAction});

  final Widget child;

  /// A widget tap that was already waiting when the app started, read before
  /// the first frame so this listener can open Live Mode without the user
  /// watching Home appear first.
  final String? launchAction;

  @override
  ConsumerState<_QuickActionListener> createState() =>
      _QuickActionListenerState();
}

class _QuickActionListenerState extends ConsumerState<_QuickActionListener> {
  bool _handlingQuickAction = false;

  /// The Live Mode route this handler last pushed. Self-invalidating: once the
  /// user leaves that screen the route is no longer `isActive`.
  Route<void>? _pushedLiveRoute;

  final _LaunchFrameHold _launchFrame = _LaunchFrameHold();

  /// Quick Listen reuses a mounted Live Mode screen instead of waiting for it,
  /// so Live Mode is the one running workflow that does not block here.
  late final _AudioWorkflowProbe _workflowProbe = _AudioWorkflowProbe(
    ref,
    liveModeBlocks: false,
  );

  @override
  void initState() {
    super.initState();
    QuickActionService.setNativeActionHandler(_onNativeAction);
    if (widget.launchAction != null) _launchFrame.hold();
    unawaited(_takePendingNativeAction());
  }

  @override
  void dispose() {
    _launchFrame.release();
    QuickActionService.setNativeActionHandler(null);
    super.dispose();
  }

  Future<void> _takePendingNativeAction() async {
    try {
      // A tap that launched the app was already drained before the first frame;
      // the native queue only still holds one when that read did not happen or
      // did not find it.
      final launchAction = widget.launchAction;
      if (launchAction != null) {
        await _handleQuickAction(launchAction, fromLaunch: true);
        return;
      }
      final action = await QuickActionService.takePendingNativeAction();
      if (!mounted || action == null) return;
      await _handleQuickAction(action);
    } catch (error, stackTrace) {
      debugPrint(
        'Quick Listen could not read the pending native action: '
        '$error\n$stackTrace',
      );
    } finally {
      // Never keep the launch waiting on a read that threw before it could
      // settle on a destination.
      _launchFrame.release();
    }
  }

  void _onNativeAction(String action) {
    if (!mounted) return;
    unawaited(_handleQuickAction(action));
  }

  Future<void> _handleQuickAction(
    String action, {
    bool fromLaunch = false,
  }) async {
    if (action != QuickActionService.startListeningAction ||
        _handlingQuickAction) {
      // Only the launch delivery owns the hold. A cold start also replays the
      // tap through the channel buffer, and that duplicate lands here while the
      // real one is still deciding — it must not let the app paint early.
      if (fromLaunch) _launchFrame.release();
      return;
    }
    _handlingQuickAction = true;

    try {
      // A fresh install must still complete onboarding and accept the terms;
      // a widget is not a path around either gate.
      final onboardingComplete = ref.read(onboardingCompleteProvider);
      final termsAccepted = ref.read(termsAcceptedProvider);
      if (!onboardingComplete || !termsAccepted) return;

      final blockingMode = await _workflowProbe.find();
      if (!mounted) return;

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;

      if (blockingMode != null) {
        // The dialog stays up until the user dismisses it, and it needs a
        // screen behind it, so stop holding the launch before awaiting.
        _launchFrame.release();
        await _showBlockedDialog(navigator, blockingMode);
        return;
      }

      // Reuse a mounted Live screen. Replacing it would cancel its duration
      // warning timer and disable its wakelock while the app-wide controller
      // kept recording.
      //
      // [_pushedLiveRoute] covers the gap before a screen this handler pushed
      // has built and registered itself: a cold start can deliver the same
      // action twice — once as the drained pending action, once as the channel
      // message the engine buffered before Dart attached a handler — and
      // without it the second delivery would stack a second Live Mode screen.
      final liveRoute = LiveScreenPresence.mountedRoute ?? _pushedLiveRoute;
      // `isActive` and the navigator identity check matter: `popUntil` with a
      // predicate nothing satisfies pops the stack down to the first route, so
      // a route that has already been removed (or never belonged here) must
      // fall through to a fresh push instead.
      if (liveRoute != null &&
          liveRoute.isActive &&
          identical(liveRoute.navigator, navigator)) {
        if (!liveRoute.isCurrent) {
          navigator.popUntil((route) => identical(route, liveRoute));
        }
        // A no-op for a route that has not registered yet — that screen
        // auto-starts on its own via `forceAutoStart`.
        LiveScreenPresence.requestStartListening(liveRoute);
        return;
      }

      // Preserve the current workflow under Live Mode. In particular, never
      // remove a route without giving its normal PopScope/finalization path a
      // chance to run.
      //
      // A tap that launched the app has nothing to animate away from: Home has
      // never been on screen, and is only underneath so Back has somewhere
      // to go.
      final route =
          fromLaunch
              ? _InstantMaterialPageRoute<void>(
                builder: (_) => const LiveScreen(forceAutoStart: true),
              )
              : MaterialPageRoute<void>(
                builder: (_) => const LiveScreen(forceAutoStart: true),
              );
      _pushedLiveRoute = route;
      unawaited(navigator.push(route));
    } catch (error, stackTrace) {
      debugPrint('Quick Listen action failed: $error\n$stackTrace');
    } finally {
      _handlingQuickAction = false;
      // Every path above has settled on what the first frame should show —
      // Live Mode, or the screen the user has to deal with first.
      _launchFrame.release();
    }
  }

  Future<void> _showBlockedDialog(
    NavigatorState navigator,
    _AudioWorkflowOwner mode,
  ) async {
    final l10n = AppLocalizations.of(navigator.context)!;
    final modeLabel = switch (mode) {
      _AudioWorkflowOwner.live => l10n.liveMode,
      _AudioWorkflowOwner.pointCount => l10n.pointCountMode,
      _AudioWorkflowOwner.survey => l10n.surveyMode,
      _AudioWorkflowOwner.fileAnalysis => l10n.fileAnalysisMode,
      _AudioWorkflowOwner.aru => l10n.aruMode,
    };
    await showDialog<void>(
      context: navigator.context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.quickListenBlockedTitle),
            content: Text(l10n.quickListenBlockedMessage(modeLabel)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.done),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Keeps the system launch screen up while a hand-off that started the app
/// works out where to go.
///
/// A widget tap or a shared file has to clear the same readiness check before
/// it can open a screen, and on a cold start that check reads storage. Without
/// this, the user watches Home paint and then get navigated away from. Frames
/// are still built and laid out while held — only compositing waits — so the
/// work that decides the destination proceeds normally.
class _LaunchFrameHold {
  bool _held = false;
  Timer? _timeout;

  /// Starts holding. Only valid before the first frame — that is, from a
  /// listener's [State.initState]. Calling it later stalls a running app
  /// instead of delaying a launch.
  void hold() {
    if (_held) return;
    _held = true;
    WidgetsBinding.instance.deferFirstFrame();
    // Nothing on the path that follows is slow, but none of it is worth a
    // launch that never paints either. Give up after a beat and let the
    // ordinary push-over-Home behavior take over.
    _timeout = Timer(const Duration(seconds: 5), release);
  }

  /// Lets the app paint. Safe to call repeatedly, and when never held.
  void release() {
    if (!_held) return;
    _held = false;
    _timeout?.cancel();
    _timeout = null;
    WidgetsBinding.instance.allowFirstFrame();
  }
}

/// A [MaterialPageRoute] that arrives without a transition, but still leaves on
/// one.
///
/// For a route pushed before the app's first frame: there is no previous screen
/// to animate away from, and animating one in would put the screen we are
/// bypassing on display for the length of the transition. Going back from it is
/// an ordinary navigation, so that keeps the ordinary animation.
class _InstantMaterialPageRoute<T> extends MaterialPageRoute<T> {
  _InstantMaterialPageRoute({required super.builder});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}

/// A workflow that owns the microphone, the model, or a session that another
/// workflow must not disturb.
enum _AudioWorkflowOwner { live, pointCount, survey, fileAnalysis, aru }

/// Answers "is something already running that a native hand-off must not
/// interrupt?" for the Quick Listen widget and for a shared audio file.
///
/// The two callers ask the same question and differ in one respect: Quick
/// Listen *reuses* a mounted Live Mode screen, so Live Mode does not block it,
/// while a shared file has to wait for that Session to end. [liveModeBlocks]
/// carries that difference; everything else is identical, and both callers
/// need it to fail closed the same way.
class _AudioWorkflowProbe {
  _AudioWorkflowProbe(this._ref, {required this.liveModeBlocks});

  final WidgetRef _ref;

  /// Whether a running Live Mode counts as a blocker for this caller.
  final bool liveModeBlocks;

  /// Set once a storage scan has confirmed there is no unfinished ARU
  /// deployment on disk. Only the cold-start case needs that scan — nothing
  /// outside this process can start a deployment — and it parses every session
  /// file, which is too slow to repeat on a widget tap whose whole point is
  /// landing in Live Mode immediately. A positive result is never cached: the
  /// user can resolve the deployment and try again.
  bool _aruStorageScanCleared = false;

  /// The owner blocking this hand-off, or `null` if the way is clear.
  Future<_AudioWorkflowOwner?> find() async {
    final running = _findRunning();
    if (running != null) return running;

    // After Android restarts the process, ARU's provider begins at `idle`
    // until its persisted deployment is restored. Check storage before
    // treating that cold-start state as permission to take the controller.
    if (_aruStorageScanCleared) return null;
    try {
      final sessions = await _ref.read(sessionRepositoryProvider).listAll();
      final hasUnfinishedAru = sessions.any(
        (session) =>
            session.type == SessionType.aru &&
            session.endTime == null &&
            session.aruMetadata != null,
      );
      if (hasUnfinishedAru) return _AudioWorkflowOwner.aru;
      _aruStorageScanCleared = true;
    } catch (error, stackTrace) {
      // Fail closed. Starting another recorder is less safe than asking the
      // user to resolve a possibly active ARU deployment.
      debugPrint(
        'Could not check for active ARU deployments: $error\n$stackTrace',
      );
      return _AudioWorkflowOwner.aru;
    }

    // The storage read yields to the UI; a workflow may have started while it
    // was in flight, so close that race before answering "nothing is running".
    return _findRunning();
  }

  /// The synchronous half of [find] — everything answerable from live state.
  _AudioWorkflowOwner? _findRunning() {
    final screenOwner = QuickListenSafety.activeSessionOwner;
    if (screenOwner == QuickListenSessionOwner.pointCount) {
      return _AudioWorkflowOwner.pointCount;
    }
    if (screenOwner == QuickListenSessionOwner.survey) {
      return _AudioWorkflowOwner.survey;
    }
    if (screenOwner == QuickListenSessionOwner.fileAnalysis) {
      return _AudioWorkflowOwner.fileAnalysis;
    }

    // A fail-safe for a run whose route has already disappeared — the screen is
    // gone but the analysis keeps going. Loading counts as busy too: taking the
    // controller during model startup would let that async launch continue
    // against a disposed ref.
    final fileAnalysisController = _ref.read(fileAnalysisControllerProvider);
    if (fileAnalysisController.state == FileAnalysisState.loading ||
        fileAnalysisController.state == FileAnalysisState.analyzing) {
      return _AudioWorkflowOwner.fileAnalysis;
    }

    final aruState = _ref.read(aruStateProvider);
    final aruOwnsAudio =
        aruState != AruControllerState.idle &&
        aruState != AruControllerState.completed &&
        aruState != AruControllerState.error;
    if (aruOwnsAudio) return _AudioWorkflowOwner.aru;

    // Point Count and Live Mode share LiveController. If it is running without
    // a mounted Live screen, fail closed: the owner is Point Count, and opening
    // Live Mode would adopt/finalize the wrong session.
    final liveController = _ref.read(liveControllerProvider);
    final sharedControllerIsRunning =
        liveController.state == LiveState.active ||
        liveController.state == LiveState.paused;
    if (sharedControllerIsRunning) {
      if (!LiveScreenPresence.isMounted) return _AudioWorkflowOwner.pointCount;
      if (liveModeBlocks) return _AudioWorkflowOwner.live;
    }

    // A capture stream with no Live screen or registered Point Count screen
    // belongs to Survey/ARU. This also closes the brief startup race before
    // those controllers publish their active state. A caller that Live Mode
    // blocks has no reason to make the mounted-Live exception.
    if (_ref.read(captureStateProvider) == CaptureState.capturing &&
        (liveModeBlocks || !LiveScreenPresence.isMounted)) {
      return _AudioWorkflowOwner.survey;
    }

    return null;
  }
}

/// Listens for an audio file shared with the app from another app's share
/// sheet (Android `ACTION_SEND`/`ACTION_VIEW`, iOS "Copy to BirdNET Live") and
/// opens File Analysis on it, on both cold start (app was killed) and warm
/// start (app already running or, on iOS, next activated). Mirrors
/// [_QuickActionListener]'s native-action bridge pattern.
class _SharedAudioListener extends ConsumerStatefulWidget {
  const _SharedAudioListener({required this.child, this.launchSharedFile});

  final Widget child;

  /// A hand-off that was already waiting when the app started, read before the
  /// first frame so this listener can decide where to open without the user
  /// watching Home appear first.
  final SharedAudioFile? launchSharedFile;

  @override
  ConsumerState<_SharedAudioListener> createState() =>
      _SharedAudioListenerState();
}

class _SharedAudioListenerState extends ConsumerState<_SharedAudioListener> {
  bool _handlingSharedFile = false;
  bool _sharedFileReadRequested = false;
  bool _deferredRetryScheduled = false;
  SharedAudioFile? _deferredSharedFile;
  SharedAudioFile? _launchSharedFile;
  Route<void>? _pushedFileAnalysisRoute;
  final _LaunchFrameHold _launchFrame = _LaunchFrameHold();

  /// Unlike Quick Listen, a shared file cannot reuse a running Live Mode — it
  /// needs File Analysis, which would contend for the same model and audio.
  late final _AudioWorkflowProbe _workflowProbe = _AudioWorkflowProbe(
    ref,
    liveModeBlocks: true,
  );

  @override
  void initState() {
    super.initState();
    SharedMediaService.setNativeShareHandler(_onNativeShare);
    _launchSharedFile = widget.launchSharedFile;
    if (_launchSharedFile != null) _launchFrame.hold();
    _requestPendingSharedFile();
  }

  @override
  void dispose() {
    _launchFrame.release();
    SharedMediaService.setNativeShareHandler(null);
    final deferredSharedFile = _deferredSharedFile;
    if (deferredSharedFile != null) {
      _discard(deferredSharedFile);
      _deferredSharedFile = null;
    }
    super.dispose();
  }

  void _onNativeShare() {
    if (!mounted) return;
    _requestPendingSharedFile();
  }

  void _requestPendingSharedFile() {
    _sharedFileReadRequested = true;
    if (!_handlingSharedFile) {
      unawaited(_drainPendingSharedFiles());
    }
  }

  Future<void> _drainPendingSharedFiles() async {
    if (_handlingSharedFile) return;
    _handlingSharedFile = true;
    try {
      do {
        _sharedFileReadRequested = false;
        final next = await _takeNextSharedFile();
        if (!mounted) {
          if (next != null) _discard(next.file);
          return;
        }
        if (next != null) {
          await _openFileAnalysis(next.file, fromLaunch: next.fromLaunch);
        }
      } while (_sharedFileReadRequested);
    } catch (error, stackTrace) {
      debugPrint('Shared audio file could not be opened: $error\n$stackTrace');
    } finally {
      _handlingSharedFile = false;
      // Nothing left to decide, so never keep the launch waiting — including
      // when the read above threw before it could settle on a destination.
      _launchFrame.release();
      // A platform notification can arrive while the method-channel read is
      // in flight. Its request must survive the reentrancy guard.
      if (mounted && _sharedFileReadRequested) {
        unawaited(_drainPendingSharedFiles());
      }
    }
  }

  /// The next hand-off to open: the one that came in with the launch if it has
  /// not been taken yet, otherwise whatever the platform has queued since.
  Future<({SharedAudioFile file, bool fromLaunch})?>
  _takeNextSharedFile() async {
    final launchFile = _launchSharedFile;
    if (launchFile != null) {
      _launchSharedFile = null;
      return (file: launchFile, fromLaunch: true);
    }
    final pending = await SharedMediaService.takePendingSharedFile();
    if (pending == null) return null;
    return (file: pending, fromLaunch: false);
  }

  Future<void> _openFileAnalysis(
    SharedAudioFile sharedFile, {
    bool fromLaunch = false,
  }) async {
    try {
      // A fresh install must still complete onboarding and accept the terms; a
      // share from another app is not a path around either gate.
      final onboardingComplete = ref.read(onboardingCompleteProvider);
      final termsAccepted = ref.read(termsAcceptedProvider);
      if (!onboardingComplete || !termsAccepted) {
        _deferSharedFile(sharedFile);
        return;
      }

      final blockingMode = await _workflowProbe.find();
      if (!mounted) {
        _discard(sharedFile);
        return;
      }

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        _deferSharedFile(sharedFile);
        return;
      }

      if (blockingMode != null) {
        // The dialog asks the user to share again once the Session ends, so
        // this hand-off is over — release the staging copy behind it.
        _discard(sharedFile);
        // The dialog stays up until the user dismisses it, and it needs a
        // screen behind it, so stop holding the launch back before awaiting.
        _launchFrame.release();
        await _showBusyDialog(navigator, blockingMode);
        return;
      }

      // A hand-off that arrived with the launch has nothing to animate away
      // from: Home has never been on screen, and is only underneath so Back
      // has somewhere to go.
      final route =
          fromLaunch
              ? _InstantMaterialPageRoute<void>(
                builder: (_) => FileAnalysisScreen(sharedFile: sharedFile),
              )
              : MaterialPageRoute<void>(
                builder: (_) => FileAnalysisScreen(sharedFile: sharedFile),
              );

      // Reuse the slot of a File Analysis screen the user already has open —
      // sharing a second file should swap the file, not stack another wizard.
      // The navigator identity and `isActive` checks matter: `popUntil` with a
      // predicate nothing satisfies pops the stack down to the first route.
      final existing =
          FileAnalysisScreenPresence.mountedRoute ?? _pushedFileAnalysisRoute;
      if (existing != null &&
          existing.isActive &&
          identical(existing.navigator, navigator)) {
        if (!existing.isCurrent) {
          navigator.popUntil((r) => identical(r, existing));
        }
        _pushedFileAnalysisRoute = route;
        unawaited(navigator.pushReplacement(route));
        return;
      }

      _pushedFileAnalysisRoute = route;
      unawaited(navigator.push(route));
    } finally {
      // Every path above has settled on what the first frame should show —
      // File Analysis, or the screen the user has to deal with first.
      _launchFrame.release();
    }
  }

  void _deferSharedFile(SharedAudioFile sharedFile) {
    // Keep the latest hand-off while onboarding/policy acceptance is visible.
    // The native URI remains valid for this Activity, and iOS keeps its staged
    // App Group copy until import succeeds.
    final previous = _deferredSharedFile;
    if (previous != null && !identical(previous, sharedFile)) {
      _discard(previous);
    }
    _deferredSharedFile = sharedFile;
    _scheduleDeferredRetry();
  }

  /// Releases the platform's staging copy of a hand-off we are giving up on,
  /// so an abandoned share does not sit in the app's storage indefinitely.
  void _discard(SharedAudioFile sharedFile) {
    unawaited(SharedMediaService.discardSharedFile(sharedFile));
  }

  void _scheduleDeferredRetry() {
    if (_deferredRetryScheduled || _deferredSharedFile == null) return;
    _deferredRetryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deferredRetryScheduled = false;
      if (!mounted || _deferredSharedFile == null) return;
      final onboardingComplete = ref.read(onboardingCompleteProvider);
      final termsAccepted = ref.read(termsAcceptedProvider);
      if (!onboardingComplete || !termsAccepted) return;
      final sharedFile = _deferredSharedFile!;
      _deferredSharedFile = null;
      unawaited(_openFileAnalysis(sharedFile));
    });
  }

  Future<void> _showBusyDialog(
    NavigatorState navigator,
    _AudioWorkflowOwner mode,
  ) async {
    final l10n = AppLocalizations.of(navigator.context)!;
    final modeLabel = switch (mode) {
      _AudioWorkflowOwner.live => l10n.liveMode,
      _AudioWorkflowOwner.pointCount => l10n.pointCountMode,
      _AudioWorkflowOwner.survey => l10n.surveyMode,
      _AudioWorkflowOwner.fileAnalysis => l10n.fileAnalysisMode,
      _AudioWorkflowOwner.aru => l10n.aruMode,
    };
    await showDialog<void>(
      context: navigator.context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.sharedAudioBusyTitle),
            content: Text(l10n.sharedAudioBusyMessage(modeLabel)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.done),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canOpenSharedFile =
        ref.watch(onboardingCompleteProvider) &&
        ref.watch(termsAcceptedProvider);
    if (canOpenSharedFile) _scheduleDeferredRetry();
    return widget.child;
  }
}

/// Gate widget that routes to onboarding or the home screen.
class _AppGate extends ConsumerWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingComplete = ref.watch(onboardingCompleteProvider);
    final termsAccepted = ref.watch(termsAcceptedProvider);

    // The onboarding flow now also captures acceptable-use acceptance, so a
    // completed onboarding implies accepted policy. We still gate on both
    // independently so a future settings reset of either flag re-shows the
    // onboarding flow.
    if (!onboardingComplete || !termsAccepted) {
      return const OnboardingScreen();
    }

    return const HomeScreen();
  }
}
