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
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isTablet = shortestSide >= 600;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal:
                    isLandscape ? (isTablet ? 64 : 48) : (isTablet ? 40 : 24),
                vertical: isLandscape ? 12 : 0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child:
                      isLandscape
                          ? _LandscapeHomeLayout(
                            l10n: l10n,
                            theme: theme,
                            isTablet: isTablet,
                          )
                          : _PortraitHomeLayout(
                            l10n: l10n,
                            theme: theme,
                            isTablet: isTablet,
                          ),
                ),
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
  const _PortraitHomeLayout({
    required this.l10n,
    required this.theme,
    this.isTablet = false,
  });
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const SizedBox(height: 32),
        _LogoHeader(l10n: l10n, theme: theme, isTablet: isTablet),
        const SizedBox(height: 24),
        _ModeCarousel(l10n: l10n, theme: theme, isTablet: isTablet),
        const SizedBox(height: 24),
        _Footer(l10n: l10n, theme: theme, isTablet: isTablet),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Landscape Layout — Logo + title left, grid + footer right
// ─────────────────────────────────────────────────────────────────────────────

class _LandscapeHomeLayout extends ConsumerWidget {
  const _LandscapeHomeLayout({
    required this.l10n,
    required this.theme,
    this.isTablet = false,
  });
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Left: compact logo + title ────────────────────────
        Expanded(
          flex: isTablet ? 3 : 2,
          child: _LogoHeader(
            l10n: l10n,
            theme: theme,
            compact: true,
            isTablet: isTablet,
          ),
        ),
        const SizedBox(width: 32),
        // ── Right: mode grid + footer ─────────────────────────
        Expanded(
          flex: isTablet ? 4 : 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModeCarousel(
                l10n: l10n,
                theme: theme,
                landscape: true,
                isTablet: isTablet,
              ),
              const SizedBox(height: 16),
              _Footer(l10n: l10n, theme: theme, isTablet: isTablet),
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
    this.isTablet = false,
  });
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool compact;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoSize =
        compact ? (isTablet ? 96.0 : 72.0) : (isTablet ? 160.0 : 120.0);
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
        SizedBox(height: compact ? (isTablet ? 16 : 12) : (isTablet ? 28 : 20)),
        Text(
          l10n.appTitle,
          style: (compact
                  ? theme.textTheme.headlineSmall
                  : theme.textTheme.headlineMedium)
              ?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                fontSize: !compact && isTablet ? 32 : null,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.homeSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(153),
            fontSize: isTablet ? 16 : null,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode Carousel — 2 pages of 2×2 cards with indicators
// ─────────────────────────────────────────────────────────────────────────────

class _ModeCarousel extends StatefulWidget {
  const _ModeCarousel({
    required this.l10n,
    required this.theme,
    this.landscape = false,
    this.isTablet = false,
  });
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool landscape;
  final bool isTablet;

  @override
  State<_ModeCarousel> createState() => _ModeCarouselState();
}

class _ModeCarouselState extends State<_ModeCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double maxWidth =
        widget.isTablet
            ? (widget.landscape ? 650 : 550)
            : (widget.landscape ? 500 : 400);
    final double aspectRatio =
        widget.landscape
            ? (widget.isTablet ? 1.3 : 1.6)
            : (widget.isTablet ? 1.2 : 1.0);
    final double spacing = widget.landscape ? 12 : 16;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gridWidth = constraints.maxWidth.clamp(0.0, maxWidth);
          final cellWidth = (gridWidth - spacing) / 2;
          final cellHeight = cellWidth / aspectRatio;
          final gridHeight = cellHeight * 2 + spacing;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: gridHeight,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    // Page 1 — Active Modes
                    GridView.count(
                      padding: EdgeInsets.zero,
                      crossAxisCount: 2,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: aspectRatio,
                      children: [
                        _ModeCard(
                          icon: sessionTypeIcon(SessionType.live),
                          label: widget.l10n.liveMode,
                          description: widget.l10n.liveModeDescription,
                          accentColor: sessionTypeAccentColor(
                            widget.theme,
                            SessionType.live,
                          ),
                          isTablet: widget.isTablet,
                          onTap: () => _openLive(context),
                        ),
                        _ModeCard(
                          icon: sessionTypeIcon(SessionType.pointCount),
                          label: widget.l10n.pointCountMode,
                          description: widget.l10n.pointCountModeDescription,
                          accentColor: sessionTypeAccentColor(
                            widget.theme,
                            SessionType.pointCount,
                          ),
                          isTablet: widget.isTablet,
                          onTap: () => _openPointCount(context),
                        ),
                        _ModeCard(
                          icon: sessionTypeIcon(SessionType.survey),
                          label: widget.l10n.surveyMode,
                          description: widget.l10n.surveyModeDescription,
                          accentColor: sessionTypeAccentColor(
                            widget.theme,
                            SessionType.survey,
                          ),
                          isTablet: widget.isTablet,
                          onTap: () => _openSurvey(context),
                        ),
                        _ModeCard(
                          icon: sessionTypeIcon(SessionType.fileUpload),
                          label: widget.l10n.fileAnalysisMode,
                          description: widget.l10n.fileAnalysisModeDescription,
                          accentColor: sessionTypeAccentColor(
                            widget.theme,
                            SessionType.fileUpload,
                          ),
                          isTablet: widget.isTablet,
                          onTap: () => _openFileAnalysis(context),
                        ),
                      ],
                    ),
                    // Page 2 — Coming Soon Modes & Placeholders
                    GridView.count(
                      padding: EdgeInsets.zero,
                      crossAxisCount: 2,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: aspectRatio,
                      children: [
                        _ModeCard(
                          icon: sessionTypeIcon(SessionType.batchAnalysis),
                          label: widget.l10n.batchAnalysisMode,
                          description: widget.l10n.batchAnalysisModeDescription,
                          accentColor: sessionTypeAccentColor(
                            widget.theme,
                            SessionType.batchAnalysis,
                          ),
                          isTablet: widget.isTablet,
                          comingSoon: true,
                          onTap:
                              () => _showComingSoonSnackBar(
                                context,
                                widget.l10n.batchAnalysisMode,
                              ),
                        ),
                        _ModeCard(
                          icon: sessionTypeIcon(SessionType.aru),
                          label: widget.l10n.aruMode,
                          description: widget.l10n.aruModeDescription,
                          accentColor: sessionTypeAccentColor(
                            widget.theme,
                            SessionType.aru,
                          ),
                          isTablet: widget.isTablet,
                          comingSoon: true,
                          onTap:
                              () => _showComingSoonSnackBar(
                                context,
                                widget.l10n.aruMode,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Page Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (index) {
                  final isSelected = _currentPage == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: isSelected ? 18 : 8,
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? widget.theme.colorScheme.primary
                              : widget.theme.colorScheme.onSurface.withAlpha(
                                50,
                              ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          );
        },
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

  void _showComingSoonSnackBar(BuildContext context, String modeLabel) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$modeLabel: ${widget.l10n.comingSoon}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
    this.isTablet = false,
    this.comingSoon = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color accentColor;
  final bool isTablet;
  final bool comingSoon;
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
      borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
      side:
          isBrandTheme
              ? BorderSide.none
              : BorderSide(
                color: theme.colorScheme.outlineVariant.withAlpha(140),
              ),
    );

    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: cardColor,
      elevation: isBrandTheme ? 0 : 1,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon & "Coming Soon" badge row.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: isTablet ? 52 : 44,
                    height: isTablet ? 52 : 44,
                    decoration: BoxDecoration(
                      color:
                          isBrandTheme
                              ? accentColor.withAlpha(isDark ? 50 : 30)
                              : accentColor.withAlpha(36),
                      borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                    ),
                    child: Icon(
                      icon,
                      color: accentColor,
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  if (comingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.comingSoon,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 11 : 9,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withAlpha(
                    comingSoon ? 150 : 255,
                  ),
                  fontSize: isTablet ? 14 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(
                      comingSoon ? 80 : 100,
                    ),
                    fontSize: isTablet ? 12 : 11,
                  ),
                  maxLines: isTablet ? 3 : 2,
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
  const _Footer({
    required this.l10n,
    required this.theme,
    this.isTablet = false,
  });
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final color = theme.colorScheme.onSurface.withAlpha(153);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: isTablet ? 24 : 12,
      runSpacing: isTablet ? 12 : 8,
      children: [
        // Sessions first — it's the more frequently used destination
        // (every recording produces one) so it deserves the leftmost
        // slot. Settings sits near the end where infrequent prefs
        // belong (#33).
        _FooterButton(
          icon: AppIcons.libraryMusic,
          label: l10n.sessionLibraryTitle,
          color: color,
          isTablet: isTablet,
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
          isTablet: isTablet,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ExploreScreen()),
              ),
        ),
        _FooterButton(
          icon: AppIcons.tuneRounded,
          label: l10n.settings,
          color: color,
          isTablet: isTablet,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
        ),
        _FooterButton(
          icon: AppIcons.helpOutlineRounded,
          label: l10n.helpTitle,
          color: color,
          isTablet: isTablet,
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
              ),
        ),
        _FooterButton(
          icon: AppIcons.infoOutline,
          label: l10n.about,
          color: color,
          isTablet: isTablet,
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
    this.isTablet = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isTablet ? 24 : 20, color: color),
      label: Text(
        label,
        style: TextStyle(color: color, fontSize: isTablet ? 16 : 14),
      ),
      style: TextButton.styleFrom(
        padding:
            isTablet
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                : null,
      ),
    );
  }
}
