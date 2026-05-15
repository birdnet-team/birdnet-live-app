// =============================================================================
// AnnouncementsAccessibilityDefaultApplier
// =============================================================================
//
// Implements decision §10.7 of dev/announcements.md: when the user has
// a screen reader active (TalkBack on Android, VoiceOver on iOS) and
// has never explicitly set the announcements master toggle, default
// the toggle to ON so spoken detections are part of the first-run
// experience for accessibility users.
//
// This widget is a no-op visually — it only listens to MediaQuery and
// flips the prefs once. Two safeguards keep it from fighting the
// user:
//
//   • The applier writes a separate
//     `announcementsAccessibilityDefaultApplied` pref the first time
//     it acts. If that pref is already `true`, the applier never
//     touches the master toggle again — so a user who turns
//     announcements off after being defaulted-on will not see them
//     come back on if they later toggle TalkBack on/off.
//
//   • If the master toggle has already been written (prefs key
//     present, regardless of value) we treat that as an explicit user
//     choice and respect it.
//
// Insert near the top of the widget tree (e.g. wrap `MaterialApp`'s
// `home` builder), so MediaQuery has the platform's accessibility
// state by the time this widget builds.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';
import 'announcements_providers.dart';

class AnnouncementsAccessibilityDefaultApplier extends ConsumerStatefulWidget {
  final Widget child;

  const AnnouncementsAccessibilityDefaultApplier({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AnnouncementsAccessibilityDefaultApplier> createState() =>
      _AnnouncementsAccessibilityDefaultApplierState();
}

class _AnnouncementsAccessibilityDefaultApplierState
    extends ConsumerState<AnnouncementsAccessibilityDefaultApplier> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    final accessibleNav = MediaQuery.accessibleNavigationOf(context);
    if (!accessibleNav) return;
    _checked = true;
    final prefs = ref.read(sharedPreferencesProvider);
    final alreadyApplied =
        prefs.getBool(PrefKeys.announcementsAccessibilityDefaultApplied) ??
        false;
    if (alreadyApplied) return;
    final userTouchedToggle = prefs.containsKey(PrefKeys.announcementsEnabled);
    if (userTouchedToggle) {
      // Respect existing user choice; just stamp the marker so we
      // never re-apply.
      prefs.setBool(PrefKeys.announcementsAccessibilityDefaultApplied, true);
      return;
    }
    // Default ON for screen-reader users.
    ref.read(announcementsEnabledProvider.notifier).set(true);
    prefs.setBool(PrefKeys.announcementsAccessibilityDefaultApplied, true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
