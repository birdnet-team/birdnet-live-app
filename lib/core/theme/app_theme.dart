import 'package:flutter/material.dart';

import 'app_semantic_colors.dart';
import 'score_colors.dart';

// =============================================================================
// BirdNET Live — Application Theme
// =============================================================================
//
// Brand color: #0D6EFD (vibrant blue).
//
// The palette is built concentrically around this anchor:
//   • Dark theme  — lighter tints of #0D6EFD for legibility on true-black
//   • Light theme — the exact brand hex as primary for punchy contrast
//
// Complementary roles:
//   • Secondary  — desaturated sky-blue for supporting UI surfaces
//   • Tertiary   — warm amber/orange for alerts, warnings, active captures
//   • Error      — standard Material red tones
//
// Both themes target:
//   • 48 dp minimum touch targets (WCAG / Material 3 guidance)
//   • OLED-friendly dark surfaces (0xFF121212)
//   • High-contrast text (>7 : 1 on dark, >4.5 : 1 on light)
// =============================================================================

/// Centralized theme definitions for BirdNET Live.
///
/// Call [AppTheme.dark] or [AppTheme.light] to obtain a fully-configured
/// [ThemeData] with Material 3 enabled, the brand blue palette, and
/// component-level overrides (buttons, cards, switches, sliders, etc.).
///
/// Call [AppTheme.fromColorScheme] to build a theme from an externally
/// provided [ColorScheme] (e.g. from the `dynamic_color` package).
abstract final class AppTheme {
  // ---------------------------------------------------------------------------
  // Brand palette constants (shared between both themes)
  // ---------------------------------------------------------------------------

  /// Brand primary — vibrant blue (#0D6EFD).
  static const Color brandPrimary = Color(0xFF0D6EFD);

  /// Lighter tint used as the dark-theme primary for readability on dark
  /// surfaces.  Approximately HSL(216°, 98%, 68%).
  static const Color brandPrimaryLight = Color(0xFF5B9CFF);

  /// Darker shade used as the light-theme primaryContainer fill.
  /// Approximately HSL(216°, 90%, 90%).
  static const Color brandPrimaryContainer = Color(0xFFD6E4FF);

  /// Dark-theme primary container — deep navy for subtle emphasis on dark
  /// surfaces.
  static const Color brandPrimaryContainerDark = Color(0xFF0043A8);

  // ─── Dark Theme ────────────────────────────────────────────────────────────

  /// Dark theme — default for field use.
  ///
  /// Optimized for outdoor birding: high-contrast text on true-black,
  /// battery-efficient on OLED, and the blue brand color lightened just
  /// enough to remain legible.
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      // ── Primary (blue) ──
      primary: Color(0xFF5B9CFF), // Light tint of brand for dark bg
      onPrimary: Color(0xFF002F6C), // Dark navy for text on primary
      primaryContainer: Color(0xFF0043A8), // Deep blue container
      onPrimaryContainer: Color(0xFFD6E4FF), // Very light blue text on cont.
      // ── Secondary (sky-blue, desaturated) ──
      secondary: Color(0xFF8AB4F8), // Soft sky-blue
      onSecondary: Color(0xFF003062), // Dark blue on secondary
      secondaryContainer: Color(0xFF1B3A5C), // Muted navy container
      onSecondaryContainer: Color(0xFFD1E4FF), // Pale blue text
      // ── Tertiary (amber — alerts, active indicators) ──
      tertiary: Color(0xFFFFB74D), // Amber accent
      onTertiary: Color(0xFF462A00),
      tertiaryContainer: Color(0xFF633F00),
      onTertiaryContainer: Color(0xFFFFDDB3),
      // ── Error ──
      error: Color(0xFFEF5350),
      onError: Color(0xFF601410),
      // ── Surfaces ──
      surface: Color(0xFF121212), // True-black OLED
      onSurface: Color(0xFFE0E0E0),
      surfaceContainerHighest: Color(0xFF2C2C2C),
      outline: Color(0xFF5C5C5C),
    );

    return _buildThemeData(colorScheme, Brightness.dark);
  }

  // ─── Light Theme ───────────────────────────────────────────────────────────

  /// Light theme — alternative for well-lit conditions.
  ///
  /// Uses the exact brand blue (#0D6EFD) as [primary] for maximum
  /// recognition, with a pale-blue container tint and warm amber tertiary.
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      // ── Primary (brand blue) ──
      primary: Color(0xFF0D6EFD), // Brand #0D6EFD
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD6E4FF), // Very pale blue
      onPrimaryContainer: Color(0xFF001B3D),
      // ── Secondary (muted blue-grey) ──
      secondary: Color(0xFF3D7BF7), // Slightly lighter variant
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFDBE7FF),
      onSecondaryContainer: Color(0xFF001A40),
      // ── Tertiary (warm amber) ──
      tertiary: Color(0xFFF57C00), // Orange 800
      // ── Surfaces ──
      surface: Color(0xFFFAFAFA),
      onSurface: Colors.black,
      onSurfaceVariant: Color(0xFF424242),
      surfaceContainerHighest: Color(0xFFEEEEEE),
      outline: Color(0xFF757575),
      outlineVariant: Color(0xFF9E9E9E),
    );

    return _buildThemeData(colorScheme, Brightness.light);
  }

  // ---------------------------------------------------------------------------
  // High Contrast
  // ---------------------------------------------------------------------------

  /// High-contrast light theme.
  ///
  /// Uses dedicated color definitions rather than dynamic color so contrast
  /// stays predictable. Score colors and spectrogram color maps remain
  /// separate from this palette.
  static ThemeData highContrastLight() {
    const colorScheme = ColorScheme.light(
      primary: Colors.black,
      onPrimary: Colors.white,
      primaryContainer: Colors.black,
      onPrimaryContainer: Colors.white,
      secondary: Colors.black,
      onSecondary: Colors.white,
      secondaryContainer: Colors.black,
      onSecondaryContainer: Colors.white,
      tertiary: Color(0xFF7A4A00),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFC107),
      onTertiaryContainer: Colors.black,
      error: Color(0xFFB00020),
      onError: Colors.white,
      errorContainer: Color(0xFFB00020),
      onErrorContainer: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
      onSurfaceVariant: Colors.black,
      surfaceContainerLow: Colors.white,
      surfaceContainerHigh: Colors.white,
      surfaceContainerHighest: Colors.white,
      outline: Colors.black,
      outlineVariant: Colors.black,
      inverseSurface: Colors.black,
      onInverseSurface: Colors.white,
    );

    return _buildThemeData(colorScheme, Brightness.light, highContrast: true);
  }

  /// High-contrast dark theme.
  ///
  /// Keeps surfaces near black and controls near white for maximum separation
  /// while preserving the existing score and spectrogram palettes.
  static ThemeData highContrastDark() {
    const colorScheme = ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      primaryContainer: Colors.white,
      onPrimaryContainer: Colors.black,
      secondary: Colors.white,
      onSecondary: Colors.black,
      secondaryContainer: Colors.white,
      onSecondaryContainer: Colors.black,
      tertiary: Color(0xFFFFD54F),
      onTertiary: Colors.black,
      tertiaryContainer: Color(0xFFFFD54F),
      onTertiaryContainer: Colors.black,
      error: Color(0xFFFFB4AB),
      onError: Colors.black,
      errorContainer: Color(0xFFFFB4AB),
      onErrorContainer: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
      onSurfaceVariant: Colors.white,
      surfaceContainerLow: Colors.black,
      surfaceContainerHigh: Colors.black,
      surfaceContainerHighest: Colors.black,
      outline: Colors.white,
      outlineVariant: Colors.white,
      inverseSurface: Colors.white,
      onInverseSurface: Colors.black,
    );

    return _buildThemeData(colorScheme, Brightness.dark, highContrast: true);
  }

  // ---------------------------------------------------------------------------
  // Dynamic Color
  // ---------------------------------------------------------------------------

  /// Build a theme from an externally provided [ColorScheme], typically
  /// obtained from the `dynamic_color` package's [DynamicColorBuilder].
  ///
  /// Applies the same component-level overrides (button shapes, card radii,
  /// touch targets, etc.) as the brand themes so the app layout and UX
  /// remain identical — only the palette changes.
  static ThemeData fromColorScheme(ColorScheme colorScheme) {
    return _buildThemeData(colorScheme, colorScheme.brightness);
  }

  // ---------------------------------------------------------------------------
  // Shared theme builder
  // ---------------------------------------------------------------------------

  /// Internal factory that wires a [ColorScheme] into a fully-configured
  /// [ThemeData] with component-level overrides.
  ///
  /// Both the brand themes ([dark], [light]) and dynamic-color themes
  /// ([fromColorScheme]) funnel through here so every variant gets
  /// identical structural styling (shapes, padding, touch targets).
  static ThemeData _buildThemeData(
    ColorScheme colorScheme,
    Brightness brightness, {
    bool highContrast = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final isBrandTheme = _isBrandThemeColorScheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: highContrast
          ? _highContrastTextTheme(colorScheme, brightness)
          : null,
      extensions: <ThemeExtension<dynamic>>[
        isDark ? ScoreColors.dark : ScoreColors.light,
        highContrast
            ? AppSemanticColors.highContrast(colorScheme)
            : isBrandTheme
            ? (isDark
                  ? AppSemanticColors.dark(colorScheme)
                  : AppSemanticColors.light)
            : AppSemanticColors.harmonized(colorScheme),
      ],

      // ── Bottom Sheets ──
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: highContrast ? colorScheme.surface : null,
        constraints: const BoxConstraints(maxWidth: 640),
        shape: highContrast
            ? RoundedRectangleBorder(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                side: BorderSide(color: colorScheme.outline),
              )
            : null,
      ),

      // ── App Bar ──
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),

      // ── Bottom Navigation ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: highContrast
            ? colorScheme.surface
            : isBrandTheme
            ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
            : (isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surfaceContainerLow),
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        color: highContrast
            ? colorScheme.surface
            : isBrandTheme
            ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
            : (isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surfaceContainerLow),
        elevation: highContrast || isDark ? 0 : 1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(highContrast ? 8 : 12),
          side: highContrast
              ? BorderSide(color: colorScheme.outline)
              : BorderSide.none,
        ),
      ),

      // ── List Tiles ──
      listTileTheme: _sharedListTileTheme(),

      // ── Dialogs ──
      dialogTheme: DialogThemeData(
        backgroundColor: highContrast
            ? colorScheme.surface
            : isBrandTheme
            ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
            : (isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surfaceContainerLow),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: highContrast
              ? BorderSide(color: colorScheme.outline)
              : BorderSide.none,
        ),
      ),

      // ── Switches ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return highContrast ? colorScheme.onPrimary : colorScheme.primary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return highContrast
                ? colorScheme.primary
                : colorScheme.primaryContainer;
          }
          return highContrast
              ? colorScheme.surface
              : colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: highContrast
            ? WidgetStateProperty.all(colorScheme.outline)
            : null,
      ),

      // ── Sliders ──
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: highContrast
            ? colorScheme.outlineVariant
            : colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withAlpha(30),
      ),

      // ── Elevated Buttons (48 dp touch target) ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark
              ? colorScheme.primaryContainer
              : colorScheme.primary,
          foregroundColor: isDark
              ? colorScheme.onPrimaryContainer
              : colorScheme.onPrimary,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // ── Text Buttons ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(48, 48),
        ),
      ),

      // ── Dividers ──
      dividerTheme: DividerThemeData(
        color: isBrandTheme
            ? (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0))
            : colorScheme.outlineVariant,
        thickness: 1,
      ),

      // ── Snack Bars ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isBrandTheme
            ? (isDark ? const Color(0xFF2C2C2C) : const Color(0xFF323232))
            : (isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.inverseSurface),
        contentTextStyle: TextStyle(
          color: isBrandTheme
              ? (isDark ? const Color(0xFFE0E0E0) : Colors.white)
              : (isDark ? colorScheme.onSurface : colorScheme.onInverseSurface),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static bool _isBrandThemeColorScheme(ColorScheme colorScheme) {
    return (colorScheme.primary == brandPrimary &&
            colorScheme.primaryContainer == brandPrimaryContainer) ||
        (colorScheme.primary == brandPrimaryLight &&
            colorScheme.primaryContainer == brandPrimaryContainerDark);
  }

  /// Whether [theme] is one of the dedicated high-contrast themes.
  static bool isHighContrastTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    return (scheme.brightness == Brightness.light &&
            scheme.primary == Colors.black &&
            scheme.surface == Colors.white) ||
        (scheme.brightness == Brightness.dark &&
            scheme.primary == Colors.white &&
            scheme.surface == Colors.black);
  }

  // ---------------------------------------------------------------------------
  // Shared component themes
  // ---------------------------------------------------------------------------
  //
  // These structural themes (padding, shape, density) are deliberately
  // factored out so the dark and light themes apply *identical* spacing.
  // Previously only the dark theme set a custom [ListTileThemeData], so
  // toggling to light caused tile padding to fall back to Material 3
  // defaults — visibly shifting layout on the Settings, Session Library,
  // and Session Review screens. Anything that affects layout (not color)
  // belongs here.

  static ListTileThemeData _sharedListTileTheme() {
    return ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      minVerticalPadding: 8,
    );
  }

  static TextTheme _highContrastTextTheme(
    ColorScheme colorScheme,
    Brightness brightness,
  ) {
    final base = ThemeData(brightness: brightness, useMaterial3: true).textTheme
        .apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        );

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w700),
      displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: base.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      bodySmall: base.bodySmall?.copyWith(fontWeight: FontWeight.w500),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
