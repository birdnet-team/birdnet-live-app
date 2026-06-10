// =============================================================================
// Session Type Visuals — Centralized icon + color mapping per app mode
// =============================================================================
//
// The app has four modes — Live, Point Count, Survey, and File Analysis —
// and each is shown with a distinct icon throughout the UI: the home menu,
// the help screen, the session library, the session review header, etc.
//
// To keep mode visuals recognizable under both the brand theme and dynamic
// color, each mode starts from a stable base hue (red, blue, green, orange)
// and is then harmonized with the active theme's primary color. This keeps
// the four modes visually distinct without fighting the current palette.
//
// Centralizing the mapping here avoids drift between the home screen,
// help screen, and history views.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';

import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/live/live_session.dart';

/// Theme-derived palette for a specific [SessionType].
@immutable
class SessionTypePalette {
  const SessionTypePalette({
    required this.accent,
    required this.onAccent,
    required this.container,
    required this.onContainer,
  });

  final Color accent;
  final Color onAccent;
  final Color container;
  final Color onContainer;
}

/// Returns the icon used to represent the given [SessionType] across the
/// app (home menu, help, session library, review header, etc.).
IconData sessionTypeIcon(SessionType type) {
  switch (type) {
    case SessionType.live:
      return AppIcons.micRounded;
    case SessionType.pointCount:
      return AppIcons.locationOnRounded;
    case SessionType.survey:
      return AppIcons.routeRounded;
    case SessionType.fileUpload:
      return AppIcons.audioFileRounded;
    case SessionType.batchAnalysis:
      return AppIcons.sdStorage;
    case SessionType.aru:
      return AppIcons.timerRounded;
  }
}

/// Theme-derived colors for the given [SessionType].
SessionTypePalette sessionTypePalette(ThemeData theme, SessionType type) {
  final colorScheme = theme.colorScheme;
  final semantic = AppSemanticColors.fromTheme(theme);
  final accent = _accentForType(semantic, type);
  final onAccent =
      isBrandThemeColorScheme(colorScheme)
          ? Colors.white
          : (ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
              ? Colors.white
              : Colors.black);
  final container =
      isBrandThemeColorScheme(colorScheme)
          ? accent.withAlpha(40)
          : Color.alphaBlend(
            accent.withAlpha(theme.brightness == Brightness.dark ? 32 : 14),
            colorScheme.surfaceContainerHigh,
          );

  return SessionTypePalette(
    accent: accent,
    onAccent: onAccent,
    container: container,
    onContainer: colorScheme.onSurface,
  );
}

bool isBrandThemeColorScheme(ColorScheme colorScheme) {
  return (colorScheme.primary == AppTheme.brandPrimary &&
          colorScheme.primaryContainer == AppTheme.brandPrimaryContainer) ||
      (colorScheme.primary == AppTheme.brandPrimaryLight &&
          colorScheme.primaryContainer == AppTheme.brandPrimaryContainerDark);
}

Color _accentForType(AppSemanticColors colors, SessionType type) {
  switch (type) {
    case SessionType.live:
      return colors.sessionLive;
    case SessionType.pointCount:
      return colors.sessionPointCount;
    case SessionType.survey:
      return colors.sessionSurvey;
    case SessionType.fileUpload:
      return colors.sessionFileAnalysis;
    case SessionType.batchAnalysis:
      return colors.sessionBatchAnalysis;
    case SessionType.aru:
      return colors.sessionAru;
  }
}

Color sessionTypeAccentColor(ThemeData theme, SessionType type) =>
    sessionTypePalette(theme, type).accent;

Color sessionTypeOnAccentColor(ThemeData theme, SessionType type) =>
    sessionTypePalette(theme, type).onAccent;

Color sessionTypeContainerColor(ThemeData theme, SessionType type) =>
    sessionTypePalette(theme, type).container;

Color sessionTypeOnContainerColor(ThemeData theme, SessionType type) =>
    sessionTypePalette(theme, type).onContainer;
