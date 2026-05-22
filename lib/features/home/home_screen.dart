import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';

import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../history/session_library_screen.dart';
import '../live/live_routes.dart';
import '../file_analysis/file_analysis_screen.dart';
import '../live/live_session.dart';
import '../point_count/point_count_setup_screen.dart';
import '../settings/settings_screen.dart';
import '../survey/survey_setup_screen.dart';
import '../../shared/utils/session_type_visuals.dart';
import 'help_screen.dart';

// =============================================================================
// Home Screen — Main Menu
// =============================================================================
//
// Clean, full-screen landing with:
//   • App logo + title
//   • 4 mode cards in a 2×2 grid
//   • Settings & About in the footer
//
// Only "Live" mode is active; the other three show a "Coming Soon" badge.
// Tapping Live pushes a full-screen [LiveScreen] for maximum real estate.
// =============================================================================

/// Main menu screen — entry point after onboarding.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 48 : 24,
                vertical: isLandscape ? 12 : 0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child:
                    isLandscape
                        ? _LandscapeHomeLayout(l10n: l10n, theme: theme)
                        : _PortraitHomeLayout(l10n: l10n, theme: theme),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Portrait Layout — Original vertical arrangement
// ─────────────────────────────────────────────────────────────────────────────

class _PortraitHomeLayout extends ConsumerWidget {
  const _PortraitHomeLayout({required this.l10n, required this.theme});
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const SizedBox(height: 32),
        _LogoHeader(l10n: l10n, theme: theme),
        const SizedBox(height: 24),
        _ModeGrid(l10n: l10n, theme: theme),
        const SizedBox(height: 24),
        _Footer(l10n: l10n, theme: theme),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Landscape Layout — Logo + title left, grid + footer right
// ─────────────────────────────────────────────────────────────────────────────

class _LandscapeHomeLayout extends ConsumerWidget {
  const _LandscapeHomeLayout({required this.l10n, required this.theme});
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Left: compact logo + title ────────────────────────
        Expanded(
          flex: 2,
          child: _LogoHeader(l10n: l10n, theme: theme, compact: true),
        ),
        const SizedBox(width: 32),
        // ── Right: mode grid + footer ─────────────────────────
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModeGrid(l10n: l10n, theme: theme, landscape: true),
              const SizedBox(height: 16),
              _Footer(l10n: l10n, theme: theme),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo Header
// ─────────────────────────────────────────────────────────────────────────────

class _LogoHeader extends ConsumerWidget {
  const _LogoHeader({
    required this.l10n,
    required this.theme,
    this.compact = false,
  });
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoSize = compact ? 72.0 : 120.0;
    return Column(
      children: [
        // Circular logo with subtle glow.
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(60),
                blurRadius: compact ? 16 : 32,
                spreadRadius: compact ? 2 : 4,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/app-icon.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(height: compact ? 12 : 20),
        Text(
          l10n.appTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.homeSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(153),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode Grid — 2×2 cards
// ─────────────────────────────────────────────────────────────────────────────

class _ModeGrid extends StatelessWidget {
  const _ModeGrid({
    required this.l10n,
    required this.theme,
    this.landscape = false,
  });
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: landscape ? 500 : 400),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: landscape ? 12 : 16,
        mainAxisSpacing: landscape ? 12 : 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: landscape ? 1.6 : 1.0,
        children: [
          _ModeCard(
            icon: sessionTypeIcon(SessionType.live),
            label: l10n.liveMode,
            description: l10n.liveModeDescription,
            accentColor: sessionTypeAccentColor(theme, SessionType.live),
            onTap: () => _openLive(context),
          ),
          _ModeCard(
            icon: sessionTypeIcon(SessionType.pointCount),
            label: l10n.pointCountMode,
            description: l10n.pointCountModeDescription,
            accentColor: sessionTypeAccentColor(theme, SessionType.pointCount),
            onTap: () => _openPointCount(context),
          ),
          _ModeCard(
            icon: sessionTypeIcon(SessionType.survey),
            label: l10n.surveyMode,
            description: l10n.surveyModeDescription,
            accentColor: sessionTypeAccentColor(theme, SessionType.survey),
            onTap: () => _openSurvey(context),
          ),
          _ModeCard(
            icon: sessionTypeIcon(SessionType.fileUpload),
            label: l10n.fileAnalysisMode,
            description: l10n.fileAnalysisModeDescription,
            accentColor: sessionTypeAccentColor(theme, SessionType.fileUpload),
            onTap: () => _openFileAnalysis(context),
          ),
        ],
      ),
    );
  }

  void _openLive(BuildContext context) {
    Navigator.of(context).push(buildLiveScreenRoute());
  }

  void _openPointCount(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PointCountSetupScreen()),
    );
  }

  void _openSurvey(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SurveySetupScreen()));
  }

  void _openFileAnalysis(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FileAnalysisScreen()));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual mode card
// ─────────────────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.accentColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isBrandTheme = isBrandThemeColorScheme(theme.colorScheme);
    final cardColor =
        isBrandTheme
            ? (theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHighest.withAlpha(120)
                : theme.colorScheme.surfaceContainerHighest.withAlpha(180))
            : (theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surfaceContainerHigh);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side:
          isBrandTheme
              ? BorderSide.none
              : BorderSide(
                color: theme.colorScheme.outlineVariant.withAlpha(140),
              ),
    );

    return Material(
      color: cardColor,
      elevation: isBrandTheme ? 0 : 1,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon in a tinted circle.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      isBrandTheme
                          ? accentColor.withAlpha(isDark ? 50 : 30)
                          : accentColor.withAlpha(36),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const Spacer(),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(100),
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer — 5 items that wrap naturally
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.l10n, required this.theme});
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = theme.colorScheme.onSurface.withAlpha(153);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      children: [
        // Sessions first — it's the more frequently used destination
        // (every recording produces one) so it deserves the leftmost
        // slot. Settings sits near the end where infrequent prefs
        // belong (#33).
        _FooterButton(
          icon: AppIcons.libraryMusic,
          label: l10n.sessionLibraryTitle,
          color: color,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SessionLibraryScreen(),
                ),
              ),
        ),
        _FooterButton(
          icon: AppIcons.searchRounded,
          label: l10n.exploreMode,
          color: color,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ExploreScreen()),
              ),
        ),
        _FooterButton(
          icon: AppIcons.tuneRounded,
          label: l10n.settings,
          color: color,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
        ),
        _FooterButton(
          icon: AppIcons.helpOutlineRounded,
          label: l10n.helpTitle,
          color: color,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
              ),
        ),
        _FooterButton(
          icon: AppIcons.infoOutline,
          label: l10n.about,
          color: color,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
        ),
      ],
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
    );
  }
}
