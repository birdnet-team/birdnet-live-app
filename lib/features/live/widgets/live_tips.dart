// =============================================================================
// Live Tips — Rotating hints shown while listening with no detections yet
// =============================================================================
//
// When a live session is recording but the detection list is empty, the
// detection panel has a lot of unused vertical space. Instead of showing a
// static "listening for species" placeholder, this widget cycles through a
// short list of practical tips and feature pointers so newcomers discover
// announcements, wind handling, watchlists, the spectrogram, etc.
//
// Design choices:
//
//   • Pure presentation — tips are localized strings, no state beyond the
//     current index. Easy to extend by adding entries to [buildLiveTips].
//   • Auto-advances every ~10s with a soft fade. Tapping the card jumps to
//     the next tip immediately for users who want to read at their own pace.
//   • Random starting index per build so opening a new session does not
//     always show "tip 1" first.
//   • Compact (icon + bold title + body). Fits in the empty-state column
//     without dominating the screen.
// =============================================================================

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';

/// One tip entry — icon + short title + one-sentence body. All localized.
class LiveTip {
  const LiveTip({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

/// Returns the localized tip list. Order is preserved for the carousel,
/// but the starting index is randomized per build so users don't always
/// see the same tip first.
List<LiveTip> buildLiveTips(AppLocalizations l10n) => <LiveTip>[
  LiveTip(
    icon: Icons.campaign_outlined,
    title: l10n.liveTipAnnouncementsTitle,
    body: l10n.liveTipAnnouncementsBody,
  ),
  LiveTip(
    icon: Icons.air,
    title: l10n.liveTipWindTitle,
    body: l10n.liveTipWindBody,
  ),
  LiveTip(
    icon: Icons.volume_up_outlined,
    title: l10n.liveTipQuietPlaybackTitle,
    body: l10n.liveTipQuietPlaybackBody,
  ),
  LiveTip(
    icon: Icons.public,
    title: l10n.liveTipGeoFilterTitle,
    body: l10n.liveTipGeoFilterBody,
  ),
  LiveTip(
    icon: Icons.save_alt,
    title: l10n.liveTipSaveClipsTitle,
    body: l10n.liveTipSaveClipsBody,
  ),
  LiveTip(
    icon: Icons.edit_note,
    title: l10n.liveTipNotesTitle,
    body: l10n.liveTipNotesBody,
  ),
  LiveTip(
    icon: Icons.graphic_eq,
    title: l10n.liveTipSpectrogramTitle,
    body: l10n.liveTipSpectrogramBody,
  ),
  LiveTip(
    icon: Icons.tune,
    title: l10n.liveTipThresholdTitle,
    body: l10n.liveTipThresholdBody,
  ),
  LiveTip(
    icon: Icons.bookmark_added_outlined,
    title: l10n.liveTipWatchlistTitle,
    body: l10n.liveTipWatchlistBody,
  ),
  LiveTip(
    icon: Icons.audio_file_outlined,
    title: l10n.liveTipFileAnalysisTitle,
    body: l10n.liveTipFileAnalysisBody,
  ),
  LiveTip(
    icon: Icons.bluetooth_audio,
    title: l10n.liveTipBluetoothMicTitle,
    body: l10n.liveTipBluetoothMicBody,
  ),
  LiveTip(
    icon: Icons.notifications_active_outlined,
    title: l10n.liveTipSurveyNotificationsTitle,
    body: l10n.liveTipSurveyNotificationsBody,
  ),
  LiveTip(
    icon: Icons.science_outlined,
    title: l10n.liveTipStudyDesignTitle,
    body: l10n.liveTipStudyDesignBody,
  ),
  LiveTip(
    icon: Icons.report_problem_outlined,
    title: l10n.liveTipAiMistakesTitle,
    body: l10n.liveTipAiMistakesBody,
  ),
  LiveTip(
    icon: Icons.battery_charging_full,
    title: l10n.liveTipBatteryTitle,
    body: l10n.liveTipBatteryBody,
  ),
];

/// Rotating tip card. Auto-advances every [interval] (default 10s) with
/// a fade transition. Tap to skip to the next tip.
class LiveTipsCarousel extends StatefulWidget {
  const LiveTipsCarousel({
    super.key,
    this.interval = const Duration(seconds: 15),
  });

  final Duration interval;

  @override
  State<LiveTipsCarousel> createState() => _LiveTipsCarouselState();
}

class _LiveTipsCarouselState extends State<LiveTipsCarousel> {
  late int _index;
  Timer? _timer;
  int _tipCount = 0;

  @override
  void initState() {
    super.initState();
    _index = Random().nextInt(1 << 16); // resolved against tip count on build
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() => _index++);
    });
  }

  void _next() {
    setState(() => _index++);
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final tips = buildLiveTips(l10n);
    if (tips.isEmpty) return const SizedBox.shrink();
    _tipCount = tips.length;
    final tip = tips[_index % _tipCount];
    // Tips use the same faint tone as the empty-state subtitle so the
    // carousel reads as supporting text and doesn't compete with the
    // "Listening…" headline above it.
    final faint = theme.colorScheme.onSurface.withAlpha(140);
    final fainter = theme.colorScheme.onSurface.withAlpha(115);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.liveTipsHeader,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fainter,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _next,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              // Fixed height so the "Listening…" header above doesn't
              // jump around when tips of different lengths cycle in.
              child: SizedBox(
                height: 110,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder:
                      (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                  child: Padding(
                    key: ValueKey<int>(_index % _tipCount),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(tip.icon, size: 28, color: fainter),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tip.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: faint,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tip.body,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: fainter,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
