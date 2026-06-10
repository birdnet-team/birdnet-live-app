// =============================================================================
// Help Screen — Comprehensive app help clustered by mode
// =============================================================================
//
// A dedicated help screen accessible from the home screen footer. Explains
// each app mode and general tips for best results, organized into expandable
// sections.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/services/link_launcher.dart';
import '../../shared/utils/session_type_visuals.dart';
import '../../shared/widgets/content_width_constraint.dart';
import '../live/live_session.dart';

/// Comprehensive help screen with mode-by-mode explanations.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isBrandTheme = isBrandThemeColorScheme(theme.colorScheme);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: ContentWidthConstraint(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── 1. Introduction ─────────────────────────────────
            // Sets context for everything that follows: what kind of app
            // this is and how the help page is organized.
            Text(
              l10n.helpIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(200),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // ── 2. What you can do (the four core capture modes) ──
            // The user's primary intent on opening the app is to record
            // and identify something — so the four capture modes come
            // first, in order of increasing structure / commitment:
            //   Live  → Point Count → Survey → File Analysis
            _SectionHeader(
              icon: AppIcons.micNoneOutlined,
              title: l10n.helpModesTitle,
            ),
            const SizedBox(height: 12),
            _HelpSection(
              icon: sessionTypeIcon(SessionType.live),
              color: sessionTypeAccentColor(theme, SessionType.live),
              containerColor:
                  isBrandTheme
                      ? sessionTypeAccentColor(
                        theme,
                        SessionType.live,
                      ).withAlpha(30)
                      : sessionTypeContainerColor(theme, SessionType.live),
              title: l10n.helpLiveTitle,
              body: l10n.helpLiveBody,
            ),
            _HelpSection(
              icon: sessionTypeIcon(SessionType.pointCount),
              color: sessionTypeAccentColor(theme, SessionType.pointCount),
              containerColor:
                  isBrandTheme
                      ? sessionTypeAccentColor(
                        theme,
                        SessionType.pointCount,
                      ).withAlpha(30)
                      : sessionTypeContainerColor(
                        theme,
                        SessionType.pointCount,
                      ),
              title: l10n.helpPointCountTitle,
              body: l10n.helpPointCountBody,
            ),
            _HelpSection(
              icon: sessionTypeIcon(SessionType.survey),
              color: sessionTypeAccentColor(theme, SessionType.survey),
              containerColor:
                  isBrandTheme
                      ? sessionTypeAccentColor(
                        theme,
                        SessionType.survey,
                      ).withAlpha(30)
                      : sessionTypeContainerColor(theme, SessionType.survey),
              title: l10n.helpSurveyTitle,
              body: l10n.helpSurveyBody,
            ),
            _HelpSection(
              icon: sessionTypeIcon(SessionType.fileUpload),
              color: sessionTypeAccentColor(theme, SessionType.fileUpload),
              containerColor:
                  isBrandTheme
                      ? sessionTypeAccentColor(
                        theme,
                        SessionType.fileUpload,
                      ).withAlpha(30)
                      : sessionTypeContainerColor(
                        theme,
                        SessionType.fileUpload,
                      ),
              title: l10n.helpFileAnalysisTitle,
              body: l10n.helpFileAnalysisBody,
            ),
            _HelpSection(
              icon: sessionTypeIcon(SessionType.batchAnalysis),
              color: sessionTypeAccentColor(theme, SessionType.batchAnalysis),
              containerColor:
                  isBrandTheme
                      ? sessionTypeAccentColor(
                        theme,
                        SessionType.batchAnalysis,
                      ).withAlpha(30)
                      : sessionTypeContainerColor(
                        theme,
                        SessionType.batchAnalysis,
                      ),
              title: l10n.helpBatchAnalysisTitle,
              body: l10n.helpBatchAnalysisBody,
            ),
            _HelpSection(
              icon: sessionTypeIcon(SessionType.aru),
              color: sessionTypeAccentColor(theme, SessionType.aru),
              containerColor:
                  isBrandTheme
                      ? sessionTypeAccentColor(theme, SessionType.aru).withAlpha(
                        30,
                      )
                      : sessionTypeContainerColor(theme, SessionType.aru),
              title: l10n.helpAruTitle,
              body: l10n.helpAruBody,
            ),
            const SizedBox(height: 20),

            // ── 3. Discover & revisit (Explore + Session Library) ──
            // Once the user has captured something — or wants to know
            // *what to expect* before recording — these two screens are
            // where they go.
            _SectionHeader(
              icon: AppIcons.travelExplore,
              title: l10n.helpToolsTitle,
            ),
            const SizedBox(height: 12),
            _HelpSection(
              icon: AppIcons.searchRounded,
              color: theme.colorScheme.primary,
              containerColor: theme.colorScheme.primaryContainer,
              title: l10n.helpExploreTitle,
              body: l10n.helpExploreBody,
            ),
            _HelpSection(
              icon: AppIcons.libraryBooks,
              color: theme.colorScheme.secondary,
              containerColor: theme.colorScheme.secondaryContainer,
              title: l10n.helpSessionsTitle,
              body: l10n.helpSessionsBody,
            ),
            const SizedBox(height: 20),

            // ── 4. Common controls (settings & meta navigation) ──
            // These are the small AppBar / footer affordances common to
            // every screen. They follow the modes because users typically
            // discover them only after they've started using the app.
            _SectionHeader(
              icon: AppIcons.gridViewRounded,
              title: l10n.helpControlsTitle,
            ),
            const SizedBox(height: 12),
            _ControlCard(
              icon: AppIcons.tuneRounded,
              title: l10n.settings,
              body: l10n.helpControlSettings,
            ),
            _ControlCard(
              icon: AppIcons.helpOutlineRounded,
              title: l10n.helpTitle,
              body: l10n.helpControlHelp,
            ),
            _ControlCard(
              icon: AppIcons.infoOutline,
              title: l10n.about,
              body: l10n.helpControlAbout,
            ),

            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),

            // ── 5. Tips for best results ─────────────────────────
            _SectionHeader(
              icon: AppIcons.lightbulbOutline,
              title: l10n.helpTipsTitle,
            ),
            const SizedBox(height: 12),
            _TipRow(text: l10n.helpTipQuiet),
            _TipRow(text: l10n.helpTipMic),
            _TipRow(text: l10n.helpTipBasics),
            _TipRow(text: l10n.helpTipThreshold),
            _TipRow(text: l10n.helpTipGeoFilter),
            _TipRow(text: l10n.helpTipGuide),
            const SizedBox(height: 12),

            // ── 6. Deeper dive — link out to the online user guide ──
            Card(
              color: theme.colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          AppIcons.menuBook,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.aboutUserGuide,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.helpTipGuide,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(180),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _launchUserGuide(context),
                      icon: const Icon(AppIcons.openInNew),
                      label: Text(l10n.aboutUserGuide),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header — small icon + title row used between top-level help
// groups. Kept inline here (rather than promoted to a shared widget)
// because the layout is intentionally tied to this screen's rhythm.
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Help Section — Expandable card for a single mode
// ─────────────────────────────────────────────────────────────────────────────

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.icon,
    required this.color,
    required this.containerColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final Color containerColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(200),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(180),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tip Row — Bullet-style tip
// ─────────────────────────────────────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  const _TipRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              AppIcons.chevronRight,
              size: 16,
              color: theme.colorScheme.primary.withAlpha(180),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(180),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _launchUserGuide(BuildContext context) async {
  final localeCode = Localizations.localeOf(context).languageCode;
  final basePath = localeCode == 'en' ? '' : '/$localeCode';
  await openExternalUrl(context, '${AppConstants.docsUrl}$basePath/user/');
}
