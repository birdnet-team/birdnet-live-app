// =============================================================================
// Detection Actions — Shared per-detection action contract + overflow menu
// =============================================================================
//
// Defines a single value object [DetectionActions] that bundles the
// per-detection callbacks (confirm / share / delete / replace) and a
// matching [DetectionActionsOverflow] widget that renders them as a
// `more_vert` popup menu, omitting any entry whose callback is null.
//
// The contract for the wider app (per TODO 9b in `dev/issue_33.md`):
//
//   • Confirm    — always inline (highest-frequency action, deserves
//                  one tap). NOT housed in the overflow menu.
//   • Share      — overflow entry (medium frequency, doesn't earn
//                  permanent chrome).
//   • Delete     — overflow entry; row-level surfaces also expose a
//                  Dismissible swipe shortcut with SnackBar undo.
//   • Replace    — overflow entry, review-only (manual correction of a
//                  misidentified species).
//
// Every surface that shows a single detection (session review cluster
// row, clip player sheet header, live survey detection list, live
// survey map marker tap) takes a [DetectionActions] and renders the
// overflow + (optional) inline confirm the same way, so users learn
// one mental model regardless of where they encounter the detection.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';

/// Bundle of optional per-detection action callbacks.
///
/// Pass to surfaces that show a single detection (or a cluster of
/// detections of the same species) to opt them into the unified
/// confirm / share / delete / replace UI. A `null` callback hides the
/// corresponding affordance, so callers can scope each surface to the
/// subset of actions it supports without forking the widget.
@immutable
class DetectionActions {
  const DetectionActions({
    this.onToggleConfirm,
    this.isConfirmed = false,
    this.onShare,
    this.onDelete,
    this.onDeleteSpecies,
    this.onReplace,
    this.onEditNote,
    this.hasNote = false,
    this.onEditVoiceMemo,
    this.onDeleteVoiceMemo,
    this.hasVoiceMemo = false,
  });

  /// Toggles the confirmed state of the detection (or every record in
  /// the cluster). Hosts own the actual mutation and persistence; this
  /// widget only reports user intent.
  final VoidCallback? onToggleConfirm;

  /// Current confirmed state, used by inline confirm renderings to
  /// pick the filled vs outlined check icon.
  final bool isConfirmed;

  /// Shares the detection's representative payload via the platform
  /// share sheet. Wired to [shareDetection] at every call site so the
  /// emitted text and attached audio clip stay consistent.
  final VoidCallback? onShare;

  /// Removes the detection. Row-level callers should pair this with a
  /// `Dismissible` swipe + SnackBar undo so misfires are recoverable
  /// without a modal confirm dialog.
  final VoidCallback? onDelete;

  /// Removes every detection of this species from the session in one
  /// shot. Surfaced from cluster-row contexts where the user has
  /// already decided the species itself is a false positive (mis-IDed
  /// noise, etc.) and individual delete would be tedious. Hosts should
  /// pair this with the same SnackBar undo as [onDelete].
  final VoidCallback? onDeleteSpecies;

  /// Replaces the inferred species with a manually-picked one. Review
  /// surfaces only — live capture has nothing to replace yet.
  final VoidCallback? onReplace;

  /// Opens an editor for the detection's free-form text note. Hosts
  /// own the dialog/sheet and persistence; this widget only reports
  /// user intent. The menu label switches between "Add note" and
  /// "Edit note" based on [hasNote].
  final VoidCallback? onEditNote;

  /// Current note state, used by the overflow menu to label the entry
  /// "Edit note" (true) vs "Add note" (false) and to decorate the
  /// trailing chrome with a small note glyph at row level.
  final bool hasNote;

  /// Opens the voice-memo recorder dialog for this detection. The host
  /// is responsible for persisting the resulting `voiceMemoPath` on
  /// the [DetectionRecord]. The menu label switches between "Record
  /// voice memo" (no memo yet) and "Replace voice memo" based on
  /// [hasVoiceMemo].
  final VoidCallback? onEditVoiceMemo;

  /// Removes the voice memo attached to this detection (deletes the
  /// underlying file and clears `voiceMemoPath`). Only surfaced when a
  /// memo currently exists.
  final VoidCallback? onDeleteVoiceMemo;

  /// Current voice-memo state. Drives the overflow label and the
  /// row-level mic glyph.
  final bool hasVoiceMemo;

  /// True when at least one overflow entry would be rendered. Hosts
  /// can use this to skip drawing the overflow button entirely when
  /// none of share / delete / replace / note is wired up.
  bool get hasOverflow =>
      onShare != null ||
      onDelete != null ||
      onDeleteSpecies != null ||
      onReplace != null ||
      onEditNote != null ||
      onEditVoiceMemo != null ||
      onDeleteVoiceMemo != null;
}

enum _OverflowAction {
  share,
  replace,
  editNote,
  editVoiceMemo,
  deleteVoiceMemo,
  delete,
  deleteSpecies,
}

/// `more_vert` popup menu that lists the non-null entries of a
/// [DetectionActions]. Renders nothing when `actions.hasOverflow` is
/// false so it's safe to drop into a row unconditionally.
///
/// The button styling matches the inline icons used elsewhere in the
/// detection surfaces (subtle on-surface tint, 24 px glyph) so it
/// blends into a row of trailing icons rather than competing with
/// them.
class DetectionActionsOverflow extends StatelessWidget {
  const DetectionActionsOverflow({
    super.key,
    required this.actions,
    this.iconSize = 24,
    this.iconColor,
    this.padding = const EdgeInsets.all(12),
  });

  final DetectionActions actions;
  final double iconSize;
  final Color? iconColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!actions.hasOverflow) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final tint = iconColor ?? theme.colorScheme.onSurface.withAlpha(140);
    return PopupMenuButton<_OverflowAction>(
      tooltip: l10n.detectionActionsTooltip,
      padding: EdgeInsets.zero,
      icon: Padding(
        padding: padding,
        child: Icon(AppIcons.moreVert, size: iconSize, color: tint),
      ),
      onSelected: (a) {
        switch (a) {
          case _OverflowAction.share:
            actions.onShare?.call();
          case _OverflowAction.replace:
            actions.onReplace?.call();
          case _OverflowAction.editNote:
            actions.onEditNote?.call();
          case _OverflowAction.editVoiceMemo:
            actions.onEditVoiceMemo?.call();
          case _OverflowAction.deleteVoiceMemo:
            actions.onDeleteVoiceMemo?.call();
          case _OverflowAction.delete:
            actions.onDelete?.call();
          case _OverflowAction.deleteSpecies:
            actions.onDeleteSpecies?.call();
        }
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<_OverflowAction>>[];
        if (actions.onShare != null) {
          items.add(
            PopupMenuItem<_OverflowAction>(
              value: _OverflowAction.share,
              child: _OverflowRow(
                icon: AppIcons.share,
                label: l10n.detectionShareTooltip,
              ),
            ),
          );
        }
        if (actions.onReplace != null) {
          items.add(
            PopupMenuItem<_OverflowAction>(
              value: _OverflowAction.replace,
              child: _OverflowRow(
                icon: AppIcons.swapHoriz,
                label: l10n.sessionReplaceDetection,
              ),
            ),
          );
        }
        if (actions.onEditNote != null) {
          items.add(
            PopupMenuItem<_OverflowAction>(
              value: _OverflowAction.editNote,
              child: _OverflowRow(
                icon: AppIcons.stickyNote2,
                label:
                    actions.hasNote
                        ? l10n.detectionEditNote
                        : l10n.detectionAddNote,
              ),
            ),
          );
        }
        if (actions.onEditVoiceMemo != null) {
          items.add(
            PopupMenuItem<_OverflowAction>(
              value: _OverflowAction.editVoiceMemo,
              child: _OverflowRow(
                icon: AppIcons.mic,
                label:
                    actions.hasVoiceMemo
                        ? l10n.detectionReplaceVoiceMemo
                        : l10n.detectionRecordVoiceMemo,
              ),
            ),
          );
        }
        if (actions.onDeleteVoiceMemo != null && actions.hasVoiceMemo) {
          items.add(
            PopupMenuItem<_OverflowAction>(
              value: _OverflowAction.deleteVoiceMemo,
              child: _OverflowRow(
                icon: AppIcons.micOff,
                label: l10n.detectionDeleteVoiceMemo,
                color: theme.colorScheme.error,
              ),
            ),
          );
        }
        if (actions.onDelete != null) {
          items.add(
            PopupMenuItem<_OverflowAction>(
              value: _OverflowAction.delete,
              child: _OverflowRow(
                icon: AppIcons.deleteOutline,
                label: l10n.detectionDeleteTooltip,
                color: theme.colorScheme.error,
              ),
            ),
          );
        }
        if (actions.onDeleteSpecies != null) {
          items.add(
            PopupMenuItem<_OverflowAction>(
              value: _OverflowAction.deleteSpecies,
              child: _OverflowRow(
                icon: AppIcons.deleteSweep,
                label: l10n.detectionDeleteSpecies,
                color: theme.colorScheme.error,
              ),
            ),
          );
        }
        return items;
      },
    );
  }
}

class _OverflowRow extends StatelessWidget {
  const _OverflowRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 20, color: c),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: c)),
      ],
    );
  }
}
