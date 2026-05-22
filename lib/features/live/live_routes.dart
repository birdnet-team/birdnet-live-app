// =============================================================================
// Live Routes
// =============================================================================
//
// Centralizes navigation into Live mode so regular in-app entry points and
// platform shortcuts reuse the same route construction.
// =============================================================================

import 'package:flutter/material.dart';

import 'live_screen.dart';

/// Standard route used to enter Live mode.
Route<void> buildLiveScreenRoute() {
  return MaterialPageRoute<void>(builder: (_) => const LiveScreen());
}
