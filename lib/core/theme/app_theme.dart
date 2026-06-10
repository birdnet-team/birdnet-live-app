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
      onSurface: Color(0xFF212121),
      surfaceContainerHighest: Color(0xFFEEEEEE),
      outline: Color(0xFFBDBDBD),
    );

    return _buildThemeData(colorScheme, Brightness.light);
  }

  // ─── Dynamic Color ─────────────────────────────────────────────────────────

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
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    final isBrandTheme = _isBrandThemeColorScheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: colorScheme.surface,
      extensions: <ThemeExtension<dynamic>>[
        isDark ? ScoreColors.dark : ScoreColors.light,
        isBrandTheme
            ? (isDark
                ? AppSemanticColors.dark(colorScheme)
                : AppSemanticColors.light)
            : AppSemanticColors.harmonized(colorScheme),
      ],

      // ── Bottom Sheets ──
      bottomSheetTheme: const BottomSheetThemeData(
        constraints: BoxConstraints(maxWidth: 640),
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
        backgroundColor:
            isBrandTheme
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
        color:
            isBrandTheme
                ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                : (isDark
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.surfaceContainerLow),
        elevation: isDark ? 0 : 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── List Tiles ──
      listTileTheme: _sharedListTileTheme(),

      // ── Dialogs ──
      dialogTheme: DialogThemeData(
        backgroundColor:
            isBrandTheme
                ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                : (isDark
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.surfaceContainerLow),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Switches ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // ── Sliders ──
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withAlpha(30),
      ),

      // ── Elevated Buttons (48 dp touch target) ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDark ? colorScheme.primaryContainer : colorScheme.primary,
          foregroundColor:
              isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary,
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
        color:
            isBrandTheme
                ? (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0))
                : colorScheme.outlineVariant,
        thickness: 1,
      ),

      // ── Snack Bars ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isBrandTheme
                ? (isDark ? const Color(0xFF2C2C2C) : const Color(0xFF323232))
                : (isDark
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.inverseSurface),
        contentTextStyle: TextStyle(
          color:
              isBrandTheme
                  ? (isDark ? const Color(0xFFE0E0E0) : Colors.white)
                  : (isDark
                      ? colorScheme.onSurface
                      : colorScheme.onInverseSurface),
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
}
