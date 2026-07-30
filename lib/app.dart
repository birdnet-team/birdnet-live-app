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
import 'features/live/live_controller.dart';
import 'features/live/live_providers.dart';
import 'features/live/live_screen.dart';
import 'features/live/live_session.dart';
import 'shared/providers/app_providers.dart';
import 'shared/services/quick_action_service.dart';
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
  const App({super.key});

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
          home: const _AruNotificationActionListener(
            child: _QuickActionListener(child: _AppGate()),
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
  const _QuickActionListener({required this.child});

  final Widget child;

  @override
  ConsumerState<_QuickActionListener> createState() =>
      _QuickActionListenerState();
}

class _QuickActionListenerState extends ConsumerState<_QuickActionListener> {
  bool _handlingQuickAction = false;

  /// The Live Mode route this handler last pushed. Self-invalidating: once the
  /// user leaves that screen the route is no longer `isActive`.
  Route<void>? _pushedLiveRoute;

  /// Set once a storage scan has confirmed there is no unfinished ARU
  /// deployment on disk. Only the cold-start case needs that scan — nothing
  /// outside this process can start a deployment — and it parses every session
  /// file, which is too slow to repeat on a widget tap whose whole point is
  /// landing in Live Mode immediately. A positive result is never cached: the
  /// user can resolve the deployment and tap again.
  bool _aruStorageScanCleared = false;

  @override
  void initState() {
    super.initState();
    QuickActionService.setNativeActionHandler(_onNativeAction);
    unawaited(_takePendingNativeAction());
  }

  @override
  void dispose() {
    QuickActionService.setNativeActionHandler(null);
    super.dispose();
  }

  Future<void> _takePendingNativeAction() async {
    try {
      final action = await QuickActionService.takePendingNativeAction();
      if (!mounted || action == null) return;
      await _handleQuickAction(action);
    } catch (error, stackTrace) {
      debugPrint(
        'Quick Listen could not read the pending native action: '
        '$error\n$stackTrace',
      );
    }
  }

  void _onNativeAction(String action) {
    if (!mounted) return;
    unawaited(_handleQuickAction(action));
  }

  Future<void> _handleQuickAction(String action) async {
    if (action != QuickActionService.startListeningAction ||
        _handlingQuickAction) {
      return;
    }
    _handlingQuickAction = true;

    try {
      // A fresh install must still complete onboarding and accept the terms;
      // a widget is not a path around either gate.
      final onboardingComplete = ref.read(onboardingCompleteProvider);
      final termsAccepted = ref.read(termsAcceptedProvider);
      if (!onboardingComplete || !termsAccepted) return;

      final blockingMode = await _findBlockingMode();
      if (!mounted) return;

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;

      if (blockingMode != null) {
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
      final route = MaterialPageRoute<void>(
        builder: (_) => const LiveScreen(forceAutoStart: true),
      );
      _pushedLiveRoute = route;
      unawaited(navigator.push(route));
    } catch (error, stackTrace) {
      debugPrint('Quick Listen action failed: $error\n$stackTrace');
    } finally {
      _handlingQuickAction = false;
    }
  }

  Future<_QuickListenBlockingMode?> _findBlockingMode() async {
    final screenOwner = QuickListenSafety.activeSessionOwner;
    if (screenOwner == QuickListenSessionOwner.pointCount) {
      return _QuickListenBlockingMode.pointCount;
    }
    if (screenOwner == QuickListenSessionOwner.survey) {
      return _QuickListenBlockingMode.survey;
    }
    if (screenOwner == QuickListenSessionOwner.fileAnalysis) {
      return _QuickListenBlockingMode.fileAnalysis;
    }

    final aruState = ref.read(aruStateProvider);
    final aruOwnsAudio =
        aruState != AruControllerState.idle &&
        aruState != AruControllerState.completed &&
        aruState != AruControllerState.error;
    if (aruOwnsAudio) return _QuickListenBlockingMode.aru;

    // Point Count and Live Mode share LiveController. If it is running
    // without a mounted Live screen, fail closed: the owner is Point Count,
    // and opening Live Mode would adopt/finalize the wrong session.
    final liveController = ref.read(liveControllerProvider);
    final sharedControllerIsRunning =
        liveController.state == LiveState.active ||
        liveController.state == LiveState.paused;
    if (sharedControllerIsRunning && !LiveScreenPresence.isMounted) {
      return _QuickListenBlockingMode.pointCount;
    }

    // A capture stream with no Live screen or registered Point Count screen
    // belongs to Survey/ARU. This also closes the brief startup race before
    // those controllers publish their active state.
    if (ref.read(captureStateProvider) == CaptureState.capturing &&
        !LiveScreenPresence.isMounted) {
      return _QuickListenBlockingMode.survey;
    }

    // After Android restarts the process, ARU's provider begins at `idle`
    // until its persisted deployment is restored. Check storage before
    // treating that cold-start state as permission to take the controller.
    if (!_aruStorageScanCleared) {
      try {
        final sessions = await ref.read(sessionRepositoryProvider).listAll();
        final hasUnfinishedAru = sessions.any(
          (session) =>
              session.type == SessionType.aru &&
              session.endTime == null &&
              session.aruMetadata != null,
        );
        if (hasUnfinishedAru) return _QuickListenBlockingMode.aru;
        _aruStorageScanCleared = true;
      } catch (error, stackTrace) {
        // Fail closed. Starting another recorder is less safe than asking the
        // user to resolve a possibly active ARU deployment.
        debugPrint(
          'Quick Listen could not check active ARU deployments: '
          '$error\n$stackTrace',
        );
        return _QuickListenBlockingMode.aru;
      }
    }

    return null;
  }

  Future<void> _showBlockedDialog(
    NavigatorState navigator,
    _QuickListenBlockingMode mode,
  ) async {
    final l10n = AppLocalizations.of(navigator.context)!;
    final modeLabel = switch (mode) {
      _QuickListenBlockingMode.pointCount => l10n.pointCountMode,
      _QuickListenBlockingMode.survey => l10n.surveyMode,
      _QuickListenBlockingMode.fileAnalysis => l10n.fileAnalysisMode,
      _QuickListenBlockingMode.aru => l10n.aruMode,
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

enum _QuickListenBlockingMode { pointCount, survey, fileAnalysis, aru }

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
