// =============================================================================
// App Launch Target Coordinator
// =============================================================================
//
// Listens for external launcher requests (for example, the Android home-screen
// widget) and opens the requested destination once the app has passed its
// onboarding / terms gates.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/history/services/widget_stats_snapshot_service.dart';
import '../../features/live/live_routes.dart';
import '../providers/app_providers.dart';
import '../services/app_launch_target_service.dart';

/// Coordinates app launches initiated by external shortcuts or widgets.
class AppLaunchTargetCoordinator extends ConsumerStatefulWidget {
  const AppLaunchTargetCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLaunchTargetCoordinator> createState() =>
      _AppLaunchTargetCoordinatorState();
}

class _AppLaunchTargetCoordinatorState
    extends ConsumerState<AppLaunchTargetCoordinator> {
  StreamSubscription<AppLaunchRequest>? _subscription;
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();
    _primeInitialTarget();
    unawaited(WidgetStatsSnapshotService.sync(ref));
    _subscription = ref
        .read(appLaunchTargetServiceProvider)
        .watchTargets()
        .listen(_queueTarget);
  }

  Future<void> _primeInitialTarget() async {
    final target =
        await ref.read(appLaunchTargetServiceProvider).takeInitialTarget();
    if (!mounted || target == null) return;
    _queueTarget(target);
  }

  void _queueTarget(AppLaunchRequest request) {
    ref.read(pendingLaunchTargetProvider.notifier).state = request;
  }

  Future<void> _openPendingTarget() async {
    if (!mounted) return;

    final pending = ref.read(pendingLaunchTargetProvider);
    final onboardingComplete = ref.read(onboardingCompleteProvider);
    final termsAccepted = ref.read(termsAcceptedProvider);

    if (pending == null || !onboardingComplete || !termsAccepted) {
      _navigationScheduled = false;
      return;
    }

    ref.read(pendingLaunchTargetProvider.notifier).state = null;

    final navigator = Navigator.of(context, rootNavigator: true);
    switch (pending.target) {
      case AppLaunchTarget.live:
        navigator.pushAndRemoveUntil(
          buildLiveScreenRoute(autoStartOnReady: pending.autoStartLive),
          (_) => false,
        );
    }

    _navigationScheduled = false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboardingComplete = ref.watch(onboardingCompleteProvider);
    final termsAccepted = ref.watch(termsAcceptedProvider);
    final pendingTarget = ref.watch(pendingLaunchTargetProvider);

    if (onboardingComplete &&
        termsAccepted &&
        pendingTarget != null &&
        !_navigationScheduled) {
      _navigationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPendingTarget();
      });
    }

    return widget.child;
  }
}
