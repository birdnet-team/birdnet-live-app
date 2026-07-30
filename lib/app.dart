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
import 'features/live/live_controller.dart';
import 'features/live/live_providers.dart';
import 'features/live/live_screen.dart';
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
    final action = await QuickActionService.takePendingNativeAction();
    if (!mounted || action == null) return;
    _handleQuickAction(action);
  }

  void _onNativeAction(String action) {
    if (!mounted) return;
    _handleQuickAction(action);
  }

  void _handleQuickAction(String action) {
    if (action != QuickActionService.startListeningAction) return;

    // Guard against a fresh install: if the user taps the widget before
    // ever opening the app (onboarding/terms not yet completed), fall
    // through to the normal onboarding flow instead of skipping straight
    // to Live Mode.
    final onboardingComplete = ref.read(onboardingCompleteProvider);
    final termsAccepted = ref.read(termsAcceptedProvider);
    if (!onboardingComplete || !termsAccepted) return;

    // LiveController is a single app-wide instance shared with the
    // autonomous ARU background runner (see aru_runner.dart). If ARU
    // currently owns it, do not navigate into Live Mode at all — doing so
    // would let the user pause/finalize an unattended ARU deployment via
    // ordinary Live Mode interactions (backgrounding, tapping Stop).
    final aruState = ref.read(aruStateProvider);
    final aruOwnsController =
        aruState != AruControllerState.idle &&
        aruState != AruControllerState.completed &&
        aruState != AruControllerState.error;
    if (aruOwnsController) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    // If a session is already active or paused, don't tear down and
    // rebuild an already-visible LiveScreen — that discarded its
    // session-duration-warning timer on every tap. Only navigate if the
    // user isn't already looking at it (e.g. a paused session while
    // they're elsewhere in the app).
    final controller = ref.read(liveControllerProvider);
    final alreadyRecording =
        controller.state == LiveState.active ||
        controller.state == LiveState.paused;
    if (alreadyRecording && LiveScreenPresence.isMounted) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        // Always true: LiveScreen's own auto-start guard already requires
        // LiveState.ready, so this safely no-ops whenever alreadyRecording
        // is true (active/paused fails that check regardless).
        builder: (_) => const LiveScreen(forceAutoStart: true),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
