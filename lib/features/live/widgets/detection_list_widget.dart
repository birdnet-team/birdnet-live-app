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
import '../../../shared/widgets/detection_evidence_badge.dart';
import '../../ebird/ebird_life_list.dart';
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
    this.emptyIcon,
    this.emptyTitle,
    this.emptySubtitle,
    this.emptyAlignment = Alignment.center,
    this.activeDetections,
    this.speciesDetectionCounts,
  });

  /// Detections to display (newest first).
  final List<DetectionRecord> detections;

  /// Whether the session is actively running.
  final bool isActive;

  /// Called when a detection tile is tapped.
  final void Function(DetectionRecord detection)? onDetectionTap;

  /// Whether the empty detection panel may show rotating Live-mode tips.
  final bool showTips;

  /// Optional empty-state icon override.
  final IconData? emptyIcon;

  /// Optional empty-state title override.
  final String? emptyTitle;

  /// Optional empty-state subtitle override.
  final String? emptySubtitle;

  /// Alignment for the empty-state prompt within the available list area.
  final Alignment emptyAlignment;

  /// Detection rows currently present in active inference results.
  ///
  /// When null, every row is treated as active. Live and Point Count pass this
  /// only for the all-species display so retained, inactive rows can hide
  /// current-confidence visuals.
  final Set<DetectionRecord>? activeDetections;

  /// Optional cumulative detection counts by scientific name.
  ///
  /// Live and Point Count pass this only when all-species display floats
  /// current detections to the top.
  final Map<String, int>? speciesDetectionCounts;

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
      return _EmptyState(
        isActive: isActive,
        showTips: showTips,
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
        alignment: emptyAlignment,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: detections.length,
      itemBuilder: (context, index) {
        final det = detections[index];
        final actions = actionsBuilder?.call(det);
        final isActivelyDetected = activeDetections?.contains(det) ?? true;
        final tile = DetectionTile(
          detection: det,
          onTap: onDetectionTap != null ? () => onDetectionTap!(det) : null,
          actions: actions,
          showConfidence: isActivelyDetected,
          detectionCount: speciesDetectionCounts?[det.scientificName],
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
    this.showConfidence = true,
    this.detectionCount,
  });

  final DetectionRecord detection;
  final VoidCallback? onTap;

  /// Per-detection action contract. When provided, the tile renders an
  /// inline confirm icon (if [DetectionActions.onToggleConfirm] is set)
  /// followed by a [DetectionActionsOverflow] for the remaining actions,
  /// in place of the chevron.
  final DetectionActions? actions;

  /// Whether to render current-confidence visuals for this row.
  final bool showConfidence;

  /// Cumulative number of session detection events for this species.
  final int? detectionCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomyAsync = ref.watch(taxonomyServiceProvider);
    final showSciNames = ref.watch(showSciNamesProvider);
    final l10n = AppLocalizations.of(context)!;

    // Resolve localized common name, falling back to English inference name.
    final displayName =
        taxonomyAsync.value
            ?.lookup(detection.scientificName)
            ?.commonNameForLocale(speciesLocale) ??
        detection.commonName;

    final lifeList = ref.watch(ebirdLifeListProvider);
    final isLifer =
        !detection.isUnknown &&
        !lifeList.isEmpty &&
        !lifeList.contains(detection.scientificName);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // Retained (no-longer-vocalizing) rows in the all-species view are
        // dimmed so the currently vocalizing detections read as the live ones.
        child: Opacity(
          opacity: showConfidence ? 1.0 : 0.75,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Thumbnail (3:2, matching the 360×240 bundled photos) ──
              _buildThumbnail(taxonomyAsync, isLifer, theme, l10n),

              const SizedBox(width: 10),

              // ── Name + sci name + confidence ──────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Common name — full width, wraps if needed
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (detectionCount != null && detectionCount! > 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Tooltip(
                              message: l10n.sessionDetectionCount(
                                detectionCount!,
                              ),
                              child: Semantics(
                                label: l10n.sessionDetectionCount(
                                  detectionCount!,
                                ),
                                child: _DetectionCountChip(
                                  count: detectionCount!,
                                ),
                              ),
                            ),
                          ),
                      ],
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
                            l10n.detectionSourceManual,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (detection.evidence != null) ...[
                            const SizedBox(width: 4),
                            DetectionEvidenceBadge(
                              evidence: detection.evidence,
                            ),
                          ],
                          const SizedBox(width: 6),
                        ],
                        if (showSciNames)
                          Expanded(
                            child: Text(
                              taxonomyAsync.value?.displayScientificName(
                                    detection.scientificName,
                                  ) ??
                                  detection.scientificName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurface.withAlpha(
                                  153,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (!showSciNames) const Spacer(),
                        if (showConfidence) ...[
                          const SizedBox(width: 8),
                          Semantics(
                            label: l10n.a11yConfidencePercent(
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
                      ],
                    ),
                    if (showConfidence) ...[
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

  /// Thumbnail with a small flag badge overlaid on the top-left corner when
  /// [isLifer] — the species isn't on the user's imported eBird life list.
  /// Anchored opposite the trailing chrome so it never collides with the
  /// detection-count chip in the name row. Mirrors the corner-badge style
  /// used for confirmed detections on the survey map.
  Widget _buildThumbnail(
    AsyncValue<TaxonomyService> taxonomyAsync,
    bool isLifer,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final image = SizedBox(
      width: 60,
      height: 40,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _buildSpeciesImage(taxonomyAsync),
      ),
    );
    if (!isLifer) return image;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        image,
        Positioned(
          top: -5,
          left: -5,
          child: Tooltip(
            message: l10n.ebirdLifeListBadgeTooltip,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withAlpha(80),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                AppIcons.flagRounded,
                size: 11,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
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

class _DetectionCountChip extends StatelessWidget {
  const _DetectionCountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '×$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Empty state shown when no detections are available.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isActive,
    required this.showTips,
    this.icon,
    this.title,
    this.subtitle,
    required this.alignment,
  });

  final bool isActive;
  final bool showTips;
  final IconData? icon;
  final String? title;
  final String? subtitle;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (showTips && !isActive) {
      return Align(
        alignment: alignment,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: const LiveTipsCarousel(),
        ),
      );
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Align(
      alignment: alignment,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? (isActive ? AppIcons.hearing : AppIcons.micOff),
              size: 40,
              color: theme.colorScheme.onSurface.withAlpha(77),
            ),
            const SizedBox(height: 8),
            Text(
              title ?? l10n.liveListening,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(128),
              ),
            ),
            Text(
              subtitle ?? l10n.liveSpeciesWillAppear,
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
