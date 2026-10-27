import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

// =============================================================================
// AppSemanticColors — theme extension for non-score semantic UI colors
// =============================================================================
//
// Holds semantic tokens that are not part of Flutter's built-in ColorScheme,
// such as success-state greens and distinct session-mode accent
// colors. The default BirdNET theme uses the app's existing brand hues,
// while dynamic-color mode harmonizes the same roles against the active
// Android palette so widgets can stay theme-driven.
// =============================================================================

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.sessionLive,
    required this.sessionPointCount,
    required this.sessionSurvey,
    required this.sessionFileAnalysis,
    required this.sessionBatchAnalysis,
    required this.sessionAru,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color sessionLive;
  final Color sessionPointCount;
  final Color sessionSurvey;
  final Color sessionFileAnalysis;
  final Color sessionBatchAnalysis;
  final Color sessionAru;

  static const Color _successBase = Color(0xFF43A047);
  static const Color _successHighContrastLight = Color(0xFF005C1A);
  static const Color _successHighContrastDark = Color(0xFF6DDE76);
  static const Color _successContainerLight = Color(0xFFD7F0DA);
  static const Color _successContainerForegroundLight = Color(0xFF1B5E20);
  static const Color _liveBase = Color(0xFFE53935);
  static const Color _pointCountBase = Color(0xFF1E88E5);
  static const Color _surveyBase = Color(0xFF43A047);
  static const Color _fileAnalysisBase = Color(0xFFFB8C00);
  static const Color _batchAnalysisBase = Color(0xFFD4AF37);
  static const Color _aruBase = Color(0xFF8E24AA);

  // High-contrast session-mode accents. Standard themes reuse the base hues,
  // but the black/white high-contrast palettes need deeper tones on the white
  // surface and brighter tones on the black surface so the modes stay legible
  // and clearly distinct while keeping their identity (red, blue, green,
  // orange, yellow, purple). "Light" = for the white high-contrast surface,
  // "Dark" = for the black one.
  static const Color _liveHighContrastLight = Color(0xFFC62828);
  static const Color _liveHighContrastDark = Color(0xFFFF8A80);
  static const Color _pointCountHighContrastLight = Color(0xFF1565C0);
  static const Color _pointCountHighContrastDark = Color(0xFF64B5F6);
  static const Color _surveyHighContrastLight = Color(0xFF2E7D32);
  static const Color _surveyHighContrastDark = Color(0xFF66BB6A);
  static const Color _fileAnalysisHighContrastLight = Color(0xFFE65100);
  static const Color _fileAnalysisHighContrastDark = Color(0xFFFFA726);
  static const Color _batchAnalysisHighContrastLight = Color(0xFFA67C00);
  static const Color _batchAnalysisHighContrastDark = Color(0xFFFFEE58);
  static const Color _aruHighContrastLight = Color(0xFF6A1B9A);
  static const Color _aruHighContrastDark = Color(0xFFCE93D8);

  static const AppSemanticColors light = AppSemanticColors(
    success: _successBase,
    onSuccess: Colors.white,
    successContainer: _successContainerLight,
    onSuccessContainer: _successContainerForegroundLight,
    sessionLive: _liveBase,
    sessionPointCount: _pointCountBase,
    sessionSurvey: _surveyBase,
    sessionFileAnalysis: _fileAnalysisBase,
    sessionBatchAnalysis: _batchAnalysisBase,
    sessionAru: _aruBase,
  );

  static AppSemanticColors dark(ColorScheme colorScheme) {
    return AppSemanticColors(
      success: _successBase,
      onSuccess: Colors.white,
      successContainer: Color.alphaBlend(
        _successBase.withAlpha(48),
        colorScheme.surfaceContainerHigh,
      ),
      onSuccessContainer: Colors.white,
      sessionLive: _liveBase,
      sessionPointCount: _pointCountBase,
      sessionSurvey: _surveyBase,
      sessionFileAnalysis: _fileAnalysisBase,
      sessionBatchAnalysis: _batchAnalysisBase,
      sessionAru: _aruBase,
    );
  }

  /// Dedicated high-contrast semantic roles. These follow Material semantic
  /// slots where possible so mode accents remain legible against the stronger
  /// light/dark palettes.
  static AppSemanticColors highContrast(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final success = isDark
        ? _successHighContrastDark
        : _successHighContrastLight;
    return AppSemanticColors(
      success: success,
      onSuccess: _onColorFor(success),
      successContainer: success,
      onSuccessContainer: _onColorFor(success),
      sessionLive: isDark ? _liveHighContrastDark : _liveHighContrastLight,
      sessionPointCount: isDark
          ? _pointCountHighContrastDark
          : _pointCountHighContrastLight,
      sessionSurvey: isDark
          ? _surveyHighContrastDark
          : _surveyHighContrastLight,
      sessionFileAnalysis: isDark
          ? _fileAnalysisHighContrastDark
          : _fileAnalysisHighContrastLight,
      sessionBatchAnalysis: isDark
          ? _batchAnalysisHighContrastDark
          : _batchAnalysisHighContrastLight,
      sessionAru: isDark ? _aruHighContrastDark : _aruHighContrastLight,
    );
  }

  /// Harmonized variant for dynamic-color themes — the brand semantic hues
  /// are blended toward the active OS palette's primary so they coexist
  /// with Material You without losing their meaning (success still reads
  /// as green-ish, mode accents stay distinguishable, etc.).
  static AppSemanticColors harmonized(ColorScheme colorScheme) {
    final success = _successBase.harmonizeWith(colorScheme.primary);
    final isDark = colorScheme.brightness == Brightness.dark;
    final successContainer = Color.alphaBlend(
      success.withAlpha(isDark ? 44 : 20),
      colorScheme.surfaceContainerHigh,
    );
    // Pick a foreground that always survives against the success-tinted
    // container: white on dark, the deepened success hue on light. Using
    // the raw success color here would collapse contrast in light mode.
    final onSuccessContainer = isDark
        ? Colors.white
        : Color.alphaBlend(Colors.black.withAlpha(120), success);

    return AppSemanticColors(
      success: success,
      onSuccess: _onColorFor(success),
      successContainer: successContainer,
      onSuccessContainer: onSuccessContainer,
      sessionLive: _liveBase.harmonizeWith(colorScheme.primary),
      sessionPointCount: _pointCountBase.harmonizeWith(colorScheme.primary),
      sessionSurvey: _surveyBase.harmonizeWith(colorScheme.primary),
      sessionFileAnalysis: _fileAnalysisBase.harmonizeWith(colorScheme.primary),
      sessionBatchAnalysis: _batchAnalysisBase.harmonizeWith(
        colorScheme.primary,
      ),
      sessionAru: _aruBase.harmonizeWith(colorScheme.primary),
    );
  }

  static AppSemanticColors of(BuildContext context) =>
      fromTheme(Theme.of(context));

  /// [ThemeData]-based companion to [of] for callers (utility functions,
  /// painters) that already hold a [ThemeData] but no [BuildContext].
  /// Falls back to the brightness-appropriate brand defaults so the result
  /// stays sensible even when the extension is missing (tests, previews).
  static AppSemanticColors fromTheme(ThemeData theme) {
    final ext = theme.extension<AppSemanticColors>();
    if (ext != null) return ext;
    return theme.brightness == Brightness.dark
        ? dark(theme.colorScheme)
        : light;
  }

  static Color _onColorFor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? sessionLive,
    Color? sessionPointCount,
    Color? sessionSurvey,
    Color? sessionFileAnalysis,
    Color? sessionBatchAnalysis,
    Color? sessionAru,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      sessionLive: sessionLive ?? this.sessionLive,
      sessionPointCount: sessionPointCount ?? this.sessionPointCount,
      sessionSurvey: sessionSurvey ?? this.sessionSurvey,
      sessionFileAnalysis: sessionFileAnalysis ?? this.sessionFileAnalysis,
      sessionBatchAnalysis: sessionBatchAnalysis ?? this.sessionBatchAnalysis,
      sessionAru: sessionAru ?? this.sessionAru,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t) ?? success,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t) ?? onSuccess,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t) ??
          successContainer,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t) ??
          onSuccessContainer,
      sessionLive: Color.lerp(sessionLive, other.sessionLive, t) ?? sessionLive,
      sessionPointCount:
          Color.lerp(sessionPointCount, other.sessionPointCount, t) ??
          sessionPointCount,
      sessionSurvey:
          Color.lerp(sessionSurvey, other.sessionSurvey, t) ?? sessionSurvey,
      sessionFileAnalysis:
          Color.lerp(sessionFileAnalysis, other.sessionFileAnalysis, t) ??
          sessionFileAnalysis,
      sessionBatchAnalysis:
          Color.lerp(sessionBatchAnalysis, other.sessionBatchAnalysis, t) ??
          sessionBatchAnalysis,
      sessionAru: Color.lerp(sessionAru, other.sessionAru, t) ?? sessionAru,
    );
  }
}
