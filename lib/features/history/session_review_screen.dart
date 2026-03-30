// =============================================================================
// Session Review Screen — Post-session review and playback
// =============================================================================
//
// Shown after finalising a live session. Lets the user:
//
//   • See a summary (species count, detections, duration).
//   • Browse detections grouped by species.
//   • Play the full session recording and seek to detection timestamps.
//   • Delete individual detections.
//   • Save, share, or discard the session.
//
// The session has already been persisted by the live screen before this
// screen is pushed. "Discard" will delete it from the repository.
// =============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../../shared/providers/settings_providers.dart';
import '../explore/explore_providers.dart';
import '../explore/widgets/species_info_overlay.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import 'session_export.dart';

/// Review screen displayed after a live session ends.
class SessionReviewScreen extends ConsumerStatefulWidget {
  const SessionReviewScreen({super.key, required this.session});

  /// The completed session to review.
  final LiveSession session;

  @override
  ConsumerState<SessionReviewScreen> createState() =>
      _SessionReviewScreenState();
}

class _SessionReviewScreenState extends ConsumerState<SessionReviewScreen> {
  late List<DetectionRecord> _detections;
  late List<_GroupedDetection> _groups;
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _audioAvailable = false;

  @override
  void initState() {
    super.initState();
    _detections = List.of(widget.session.detections);
    _groups = _buildGroups(_detections);
    _initAudio();
  }

  Future<void> _initAudio() async {
    final path = widget.session.recordingPath;
    if (path == null || !File(path).existsSync()) return;

    try {
      final dur = await _player.setFilePath(path);
      if (!mounted) return;
      setState(() {
        _duration = dur ?? Duration.zero;
        _audioAvailable = true;
      });

      _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });
      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
          if (state.processingState == ProcessingState.completed) {
            _player.pause();
            _player.seek(Duration.zero);
          }
        }
      });
    } catch (_) {
      // Audio not available — review still works without playback.
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _discard() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sessionDiscardTitle),
        content: Text(l10n.sessionDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.sessionDiscard),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(sessionRepositoryProvider);
    await repo.delete(widget.session.id);
    ref.invalidate(sessionListProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _share() async {
    final zipPath = await buildSessionZip(widget.session);
    if (zipPath == null) return;
    await Share.shareXFiles([XFile(zipPath)]);
  }

  void _done() {
    Navigator.of(context).pop();
  }

  void _deleteDetection(int groupIndex) {
    final group = _groups[groupIndex];
    setState(() {
      for (final r in group.records) {
        _detections.remove(r);
        widget.session.detections.remove(r);
      }
      _groups = _buildGroups(_detections);
    });
    // Persist updated session.
    ref.read(sessionRepositoryProvider).save(widget.session);
    ref.invalidate(sessionListProvider);
  }

  void _seekToDetection(_GroupedDetection group) {
    if (!_audioAvailable || _duration == Duration.zero) return;
    final offset = group.firstTimestamp.difference(widget.session.startTime);
    if (offset.isNegative || offset > _duration) return;
    _player.seek(offset);
    if (!_isPlaying) _player.play();
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.sessionReviewTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _done,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.sessionDiscard,
              onPressed: _discard,
            ),
            if (_audioAvailable)
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: l10n.sessionShare,
                onPressed: _share,
              ),
          ],
        ),
        body: Column(
          children: [
            // ── Summary header ──────────────────────────────
            _SummaryHeader(
              session: widget.session,
              detectionCount: _detections.length,
            ),

            // ── Audio player ────────────────────────────────
            if (_audioAvailable)
              _AudioPlayerBar(
                player: _player,
                position: _position,
                duration: _duration,
                isPlaying: _isPlaying,
              ),

            const Divider(height: 1),

            // ── Detection list ──────────────────────────────
            Expanded(
              child: _groups.isEmpty
                  ? Center(
                      child: Text(
                        l10n.sessionNoDetections,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(120),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _groups.length,
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        return _ReviewDetectionTile(
                          group: group,
                          sessionStart: widget.session.startTime,
                          isHighlighted: _isGroupActive(group),
                          onSeek: () => _seekToDetection(group),
                          onDelete: () => _deleteDetection(index),
                          onTap: () => SpeciesInfoOverlay.show(
                            context,
                            ref,
                            scientificName: group.scientificName,
                            commonName: group.commonName,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Whether any detection in [group] is near the current playback position.
  bool _isGroupActive(_GroupedDetection group) {
    if (!_isPlaying || _duration == Duration.zero) return false;
    for (final r in group.records) {
      final offset = r.timestamp.difference(widget.session.startTime);
      final diff = (_position - offset).abs();
      if (diff.inSeconds <= 3) return true;
    }
    return false;
  }

  /// Merge consecutive same-species detections into groups.
  static List<_GroupedDetection> _buildGroups(List<DetectionRecord> records) {
    if (records.isEmpty) return const [];
    final groups = <_GroupedDetection>[];
    var current = [records.first];
    for (var i = 1; i < records.length; i++) {
      if (records[i].scientificName == current.first.scientificName) {
        current.add(records[i]);
      } else {
        groups.add(_GroupedDetection(current));
        current = [records[i]];
      }
    }
    groups.add(_GroupedDetection(current));
    return groups;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grouped Detection
// ─────────────────────────────────────────────────────────────────────────────

/// A run of consecutive detections of the same species.
class _GroupedDetection {
  _GroupedDetection(this.records)
      : assert(records.isNotEmpty),
        scientificName = records.first.scientificName,
        commonName = records.first.commonName;

  final List<DetectionRecord> records;
  final String scientificName;
  final String commonName;

  int get count => records.length;
  DetectionRecord get best =>
      records.reduce((a, b) => a.confidence >= b.confidence ? a : b);
  double get bestConfidence => best.confidence;
  DateTime get firstTimestamp => records.first.timestamp;
  DateTime get lastTimestamp => records.last.timestamp;
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Header
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.session,
    required this.detectionCount,
  });

  final LiveSession session;
  final int detectionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final duration = session.duration;
    final species =
        session.detections.map((d) => d.scientificName).toSet().length;
    final dateStr = DateFormat.yMMMd().add_Hm().format(session.startTime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatChip(
                icon: Icons.timer_outlined,
                label: _formatDuration(duration),
              ),
              const SizedBox(width: 16),
              _StatChip(
                icon: Icons.pets,
                label: l10n.sessionSpeciesCount(species),
              ),
              const SizedBox(width: 16),
              _StatChip(
                icon: Icons.graphic_eq,
                label: l10n.sessionDetectionCount(detectionCount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio Player Bar
// ─────────────────────────────────────────────────────────────────────────────

class _AudioPlayerBar extends StatelessWidget {
  const _AudioPlayerBar({
    required this.player,
    required this.position,
    required this.duration,
    required this.isPlaying,
  });

  final AudioPlayer player;
  final Duration position;
  final Duration duration;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Play/Pause button
          IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
            iconSize: 40,
            color: theme.colorScheme.primary,
            onPressed: () {
              if (isPlaying) {
                player.pause();
              } else {
                player.play();
              }
            },
          ),

          // Position label
          SizedBox(
            width: 48,
            child: Text(
              _formatPosition(position),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),

          // Seek bar
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                thumbColor: theme.colorScheme.primary,
              ),
              child: Slider(
                value: duration.inMilliseconds > 0
                    ? position.inMilliseconds
                        .clamp(0, duration.inMilliseconds)
                        .toDouble()
                    : 0,
                max: duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  player.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
          ),

          // Duration label
          SizedBox(
            width: 48,
            child: Text(
              _formatPosition(duration),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPosition(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review Detection Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewDetectionTile extends ConsumerWidget {
  const _ReviewDetectionTile({
    required this.group,
    required this.sessionStart,
    required this.isHighlighted,
    required this.onSeek,
    required this.onDelete,
    required this.onTap,
  });

  final _GroupedDetection group;
  final DateTime sessionStart;
  final bool isHighlighted;
  final VoidCallback onSeek;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomyAsync = ref.watch(taxonomyServiceProvider);

    final displayName = taxonomyAsync.valueOrNull
            ?.lookup(group.scientificName)
            ?.commonNameForLocale(speciesLocale) ??
        group.commonName;

    final offset = group.firstTimestamp.difference(sessionStart);
    final offsetStr = _formatOffset(offset);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: isHighlighted
          ? theme.colorScheme.primaryContainer.withAlpha(80)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // ── Seek button ─────────────────────────────────
              InkWell(
                onTap: onSeek,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      Text(
                        offsetStr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // ── Species info ────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (group.count > 1)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '×${group.count}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.scientificName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          group.best.confidencePercent,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _confidenceColor(
                              group.bestConfidence,
                              theme,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Delete button ───────────────────────────────
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: theme.colorScheme.onSurface.withAlpha(120),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatOffset(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }

  Color _confidenceColor(double confidence, ThemeData theme) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.4) return Colors.amber;
    return Colors.red;
  }
}
