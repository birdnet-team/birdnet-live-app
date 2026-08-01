// =============================================================================
// DetectionEvidenceBadge — heard / seen indicator for manual detections
// =============================================================================
//
// Manual detections carry an optional [DetectionEvidence] recording whether
// the user heard the bird, saw it, or both. This file owns the single visual
// vocabulary for that field so every surface renders it identically:
//
//   • :hearing:    — heard
//   • :visibility: — seen
//   • both icons   — heard and seen
//
// Two entry points:
//
//   • DetectionEvidenceBadge — inline icon(s) for detection rows and headers.
//   • evidenceLabel()        — the localized text, for tooltips, semantics,
//                              snackbars, and share payloads.
//
// Records with `evidence == null` (model detections, legacy manual records,
// and manual entries where the user ticked neither box) render nothing —
// "not specified" must never read as "neither heard nor seen".
// =============================================================================

import 'package:flutter/material.dart';

import '../../features/live/live_session.dart';
import '../../l10n/app_localizations.dart';
import '../utils/app_icons.dart';

/// Union of the evidence across [records], for rows that stand in for more
/// than one detection (a species header, a clustered timestamp row).
///
/// A species heard in one entry and seen in another was, for the group as a
/// whole, both — so the flags are OR-ed rather than requiring agreement.
/// Returns null when no record carries evidence.
DetectionEvidence? aggregateEvidence(Iterable<DetectionRecord> records) {
  var heard = false;
  var seen = false;
  for (final r in records) {
    heard |= r.wasHeard;
    seen |= r.wasSeen;
  }
  return DetectionEvidence.fromFlags(heard: heard, seen: seen);
}

/// Localized label for [evidence] — "Heard", "Seen", or "Heard and seen".
String evidenceLabel(AppLocalizations l10n, DetectionEvidence evidence) =>
    switch (evidence) {
      DetectionEvidence.heard => l10n.detectionEvidenceHeard,
      DetectionEvidence.seen => l10n.detectionEvidenceSeen,
      DetectionEvidence.heardAndSeen => l10n.detectionEvidenceHeardAndSeen,
    };

/// Compact heard / seen indicator for a manually-entered detection.
///
/// Renders `SizedBox.shrink()` when [evidence] is null, so callers can drop
/// it into a row unconditionally.
class DetectionEvidenceBadge extends StatelessWidget {
  const DetectionEvidenceBadge({
    super.key,
    required this.evidence,
    this.size = 14,
    this.color,
    this.spacing = 2,
  });

  /// The record's evidence. Null renders nothing.
  final DetectionEvidence? evidence;

  /// Icon size in logical pixels. Callers match the neighbouring glyphs.
  final double size;

  /// Icon color; defaults to the theme primary, matching the manual badge
  /// the evidence icons always sit next to.
  final Color? color;

  /// Gap between the two icons when both are shown.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final value = evidence;
    if (value == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final iconColor = color ?? Theme.of(context).colorScheme.primary;
    final label = evidenceLabel(l10n, value);

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value.includesHeard)
              Icon(AppIcons.hearing, size: size, color: iconColor),
            if (value.includesHeard && value.includesSeen)
              SizedBox(width: spacing),
            if (value.includesSeen)
              Icon(AppIcons.visibility, size: size, color: iconColor),
          ],
        ),
      ),
    );
  }
}
