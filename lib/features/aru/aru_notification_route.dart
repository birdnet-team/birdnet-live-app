import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/session_library_screen.dart';
import 'aru_active_screen.dart';
import 'aru_controller.dart';
import 'aru_providers.dart';

/// Landing route used when Android launches the app from the ARU foreground
/// notification.
class AruNotificationRoute extends ConsumerStatefulWidget {
  const AruNotificationRoute({required this.requestStop, super.key});

  final bool requestStop;

  @override
  ConsumerState<AruNotificationRoute> createState() =>
      _AruNotificationRouteState();
}

class _AruNotificationRouteState extends ConsumerState<AruNotificationRoute> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  void _route() {
    final active = _hasActiveDeployment();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => active
            ? AruActiveScreen(confirmStopOnOpen: widget.requestStop)
            : const SessionLibraryScreen(),
      ),
    );
  }

  bool _hasActiveDeployment() {
    final inMemorySession = ref.read(aruSessionProvider);
    final inMemoryState = ref.read(aruStateProvider);
    return inMemorySession != null &&
        inMemoryState != AruControllerState.completed &&
        inMemoryState != AruControllerState.idle;
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
