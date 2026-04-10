import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../about/about_screen.dart';
import '../explore/explore_screen.dart';
import '../history/session_library_screen.dart';
import '../live/live_screen.dart';
import '../file_analysis/file_analysis_screen.dart';
import '../settings/settings_screen.dart';

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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // ── Logo + Title ─────────────────────────────────
              _LogoHeader(l10n: l10n, theme: theme),

              const Spacer(),

              // ── Mode Grid ────────────────────────────────────
              _ModeGrid(l10n: l10n, theme: theme),

              const Spacer(),

              // ── Footer ───────────────────────────────────────
              _Footer(l10n: l10n, theme: theme),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo Header
// ─────────────────────────────────────────────────────────────────────────────

class _LogoHeader extends StatelessWidget {
  const _LogoHeader({required this.l10n, required this.theme});
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Circular logo with subtle glow.
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(60),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo-birdnet-circle.png',
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 20),
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
  const _ModeGrid({required this.l10n, required this.theme});
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.0,
        children: [
          _ModeCard(
            icon: Icons.mic_rounded,
            label: l10n.liveMode,
            description: l10n.liveModeDescription,
            color: theme.colorScheme.primary,
            onTap: () => _openLive(context),
          ),
          _ModeCard(
            icon: Icons.location_on_rounded,
            label: l10n.pointCountMode,
            description: l10n.pointCountModeDescription,
            color: theme.colorScheme.secondary,
            comingSoon: true,
          ),
          _ModeCard(
            icon: Icons.route_rounded,
            label: l10n.surveyMode,
            description: l10n.surveyModeDescription,
            color: theme.colorScheme.tertiary,
            comingSoon: true,
          ),
          _ModeCard(
            icon: Icons.audio_file_rounded,
            label: l10n.fileAnalysisMode,
            description: l10n.fileAnalysisModeDescription,
            color: theme.colorScheme.secondary,
            onTap: () => _openFileAnalysis(context),
          ),
        ],
      ),
    );
  }

  void _openLive(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LiveScreen(),
      ),
    );
  }

  void _openFileAnalysis(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const FileAnalysisScreen(),
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
    required this.color,
    this.comingSoon = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final bool comingSoon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest.withAlpha(120)
          : theme.colorScheme.surfaceContainerHighest.withAlpha(180),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: comingSoon ? null : onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon in a tinted circle.
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withAlpha(isDark ? 50 : 30),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: comingSoon
                          ? theme.colorScheme.onSurface.withAlpha(100)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // "Coming Soon" badge.
            if (comingSoon)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.comingSoon,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer — Settings & About
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.l10n, required this.theme});
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.tune_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
            label: Text(
              l10n.settings,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ExploreScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.search_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
            label: Text(
              l10n.exploreMode,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SessionLibraryScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.library_music_outlined,
              size: 18,
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
            label: Text(
              l10n.sessionLibraryTitle,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AboutScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
            label: Text(
              l10n.about,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
