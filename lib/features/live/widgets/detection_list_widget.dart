// =============================================================================
// Detection List Widget — Real-time species detection display
// =============================================================================
//
// Shows the accumulated detections from the current live session.  Each
// detection is displayed as a card with:
//
//   • Thumbnail image (3:2)
//   • Common name (full row, not truncated)
//   • Scientific name + confidence bar
//
// Tapping a detection opens the species info overlay.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/score_colors.dart';
import '../../../shared/providers/settings_providers.dart';
import '../../../shared/services/taxonomy_service.dart';
import '../../explore/explore_providers.dart';
import '../../history/widgets/detection_actions.dart';
import '../live_session.dart';
import 'live_tips.dart';

/// Displays a scrollable list of species detections.
///
/// Pass an empty list to show an appropriate empty-state message.
class DetectionList extends StatelessWidget {
  const DetectionList({
    super.key,
    required this.detections,
    required this.isActive,
    this.onDetectionTap,
    this.actionsBuilder,
    this.showTips = false,
  });

  /// Detections to display (newest first).
  final List<DetectionRecord> detections;

  /// Whether the session is actively running.
  final bool isActive;

  /// Called when a detection tile is tapped.
  final void Function(DetectionRecord detection)? onDetectionTap;

  /// Whether the empty detection panel may show rotating Live-mode tips.
  final bool showTips;

  /// Optional per-detection action contract. When non-null and
  /// non-empty, each tile gets an inline confirm checkmark (if
  /// [DetectionActions.onToggleConfirm] is set) and a more_vert overflow
  /// for the remaining actions (share / delete / replace). Live screens
  /// pass null to keep the streaming view chrome-free; the survey live
  /// screen wires confirm + share so reviewers can validate as they go.
  final DetectionActions? Function(DetectionRecord detection)? actionsBuilder;

  @override
  Widget build(BuildContext context) {
    if (detections.isEmpty) {
      return _EmptyState(isActive: isActive, showTips: showTips);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: detections.length,
      itemBuilder: (context, index) {
        final det = detections[index];
        final actions = actionsBuilder?.call(det);
        final tile = DetectionTile(
          detection: det,
          onTap: onDetectionTap != null ? () => onDetectionTap!(det) : null,
          actions: actions,
        );
        // When the host wires a delete action, also expose it as a
        // horizontal swipe shortcut. The host's undo SnackBar covers
        // misfires, so no modal confirm is needed. Keyed by the
        // detection's identity (sci-name + microsecond timestamp) so
        // dismiss/rebuild stays stable as new detections stream in.
        final onDelete = actions?.onDelete;
        if (onDelete == null) return tile;
        return Dismissible(
          key: ValueKey(
            '${det.scientificName}-${det.timestamp.microsecondsSinceEpoch}',
          ),
          direction: DismissDirection.horizontal,
          background: _swipeDeleteBackground(context, alignLeft: true),
          secondaryBackground: _swipeDeleteBackground(
            context,
            alignLeft: false,
          ),
          onDismissed: (_) => onDelete(),
          child: tile,
        );
      },
    );
  }

  Widget _swipeDeleteBackground(
    BuildContext context, {
    required bool alignLeft,
  }) {
    final theme = Theme.of(context);
    return Container(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: theme.colorScheme.error.withAlpha(40),
      child: Icon(AppIcons.deleteOutline, color: theme.colorScheme.error),
    );
  }
}

/// A single detection entry in the list.
class DetectionTile extends ConsumerWidget {
  const DetectionTile({
    super.key,
    required this.detection,
    this.onTap,
    this.actions,
  });

  final DetectionRecord detection;
  final VoidCallback? onTap;

  /// Per-detection action contract. When provided, the tile renders an
  /// inline confirm icon (if [DetectionActions.onToggleConfirm] is set)
  /// followed by a [DetectionActionsOverflow] for the remaining actions,
  /// in place of the chevron.
  final DetectionActions? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomyAsync = ref.watch(taxonomyServiceProvider);
    final showSciNames = ref.watch(showSciNamesProvider);

    // Resolve localized common name, falling back to English inference name.
    final displayName =
        taxonomyAsync.value
            ?.lookup(detection.scientificName)
            ?.commonNameForLocale(speciesLocale) ??
        detection.commonName;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Thumbnail (3:2, matching the 360×240 bundled photos) ──
            SizedBox(
              width: 60,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _buildSpeciesImage(taxonomyAsync),
              ),
            ),

            const SizedBox(width: 10),

            // ── Name + sci name + confidence ──────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Common name — full width, wraps if needed
                  Text(
                    displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Scientific name + confidence on one row
                  Row(
                    children: [
                      // Manual-entry badge (small icon + label) takes the
                      // place of the scientific-name field for manual
                      // detections, since manuals carry confidence 1.0 and
                      // the user explicitly chose the species — the
                      // scientific name is less important than making it
                      // obvious this didn't come from inference.
                      if (detection.source == DetectionSource.manual ||
                          detection.source == DetectionSource.manualGlobal ||
                          detection.source ==
                              DetectionSource.userSpecified) ...[
                        Icon(
                          AppIcons.editNote,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          AppLocalizations.of(context)!.detectionSourceManual,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (showSciNames)
                        Expanded(
                          child: Text(
                            detection.scientificName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (!showSciNames) const Spacer(),
                      const SizedBox(width: 8),
                      Semantics(
                        label: AppLocalizations.of(
                          context,
                        )!.a11yConfidencePercent(
                          (detection.confidence * 100).round(),
                        ),
                        excludeSemantics: true,
                        child: Text(
                          detection.confidencePercent,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _confidenceColor(
                              detection.confidence,
                              theme,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Confidence bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: detection.confidence,
                      minHeight: 3,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _confidenceColor(detection.confidence, theme),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Trailing chrome ────────────────────────────────
            // When per-detection actions are wired, replace the
            // navigational chevron with inline confirm + overflow so the
            // tile matches the cluster row in session review. Otherwise
            // keep the lightweight chevron to signal tap-for-info.
            if (actions != null)
              ..._trailingActions(context, theme, actions!)
            else
              Icon(
                AppIcons.chevronRight,
                size: 20,
                color: theme.colorScheme.onSurface.withAlpha(80),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _trailingActions(
    BuildContext context,
    ThemeData theme,
    DetectionActions actions,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return [
      if (actions.onToggleConfirm != null)
        Tooltip(
          message:
              actions.isConfirmed
                  ? l10n.detectionUnconfirmTooltip
                  : l10n.detectionConfirmTooltip,
          child: InkWell(
            onTap: actions.onToggleConfirm,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                actions.isConfirmed
                    ? AppIcons.checkCircle
                    : AppIcons.checkCircleOutline,
                size: 24,
                color:
                    actions.isConfirmed
                        ? AppSemanticColors.of(context).success
                        : theme.colorScheme.onSurface.withAlpha(120),
              ),
            ),
          ),
        ),
      if (actions.hasOverflow)
        DetectionActionsOverflow(
          actions: actions,
          iconColor: theme.colorScheme.onSurface.withAlpha(120),
        ),
    ];
  }

  /// Map confidence to a color via the [ScoreColors] theme extension.
  Color _confidenceColor(double confidence, ThemeData theme) {
    final scoreColors = theme.extension<ScoreColors>() ?? ScoreColors.light;
    return scoreColors.forScore(confidence);
  }

  Widget _buildSpeciesImage(AsyncValue<TaxonomyService> taxonomyAsync) {
    final path =
        taxonomyAsync.value?.assetImagePath(detection.scientificName) ??
        'assets/images/dummy_species.png';
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder:
          (a, b, c) =>
              Image.asset('assets/images/dummy_species.png', fit: BoxFit.cover),
    );
  }
}

/// Empty state shown when no detections are available.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isActive, required this.showTips});

  final bool isActive;
  final bool showTips;

  @override
  Widget build(BuildContext context) {
    if (showTips && !isActive) {
      return const Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: LiveTipsCarousel(),
        ),
      );
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? AppIcons.hearing : AppIcons.micOff,
              size: 40,
              color: theme.colorScheme.onSurface.withAlpha(77),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.liveListening,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(128),
              ),
            ),
            Text(
              l10n.liveSpeciesWillAppear,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(77),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
