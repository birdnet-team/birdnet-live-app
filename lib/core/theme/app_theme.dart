import 'package:flutter/material.dart';

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

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colorScheme.surface,

      // ── App Bar ──
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),

      // ── Bottom Navigation ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ── List Tiles ──
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        minVerticalPadding: 8,
      ),

      // ── Dialogs ──
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
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
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2C2C2C),
        thickness: 1,
      ),

      // ── Snack Bars ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2C2C2C),
        contentTextStyle: const TextStyle(color: Color(0xFFE0E0E0)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
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

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colorScheme.surface,

      // ── App Bar ──
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),

      // ── Bottom Navigation ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ── Elevated Buttons ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
