part of '../session_review_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Data Models
// ═════════════════════════════════════════════════════════════════════════════

/// A cluster of consecutive detections of the same species.
class _DetectionCluster {
  _DetectionCluster(this.records) : assert(records.isNotEmpty);

  final List<DetectionRecord> records;

  int get count => records.length;
  DateTime get firstTimestamp => records.first.timestamp;
  DateTime get lastTimestamp => records.last.timestamp;
  double get bestConfidence =>
      records.map((r) => r.confidence).reduce(math.max);
  String get bestConfidencePercent =>
      '${(bestConfidence * 100).toStringAsFixed(1)} %';
}

/// All detections of one species, subdivided into time-span clusters.
class _SpeciesGroup {
  _SpeciesGroup({
    required this.scientificName,
    required this.commonName,
    required this.clusters,
  });

  final String scientificName;
  final String commonName;
  final List<_DetectionCluster> clusters;

  int get totalCount => clusters.fold<int>(0, (sum, c) => sum + c.count);
  double get bestConfidence =>
      clusters.map((c) => c.bestConfidence).reduce(math.max);
  String get bestConfidencePercent =>
      '${(bestConfidence * 100).toStringAsFixed(1)} %';
  DateTime get firstTimestamp => clusters.first.firstTimestamp;
  DateTime get lastTimestamp => clusters.last.lastTimestamp;

  List<DetectionRecord> get allRecords =>
      clusters.expand((c) => c.records).toList();
}

// ═════════════════════════════════════════════════════════════════════════════
// Summary Header
// ═════════════════════════════════════════════════════════════════════════════

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          const SizedBox(height: 6),
          Row(
            children: [
              _StatChip(
                icon: Icons.timer_outlined,
                label: _formatDuration(duration),
              ),
              const SizedBox(width: 16),
              _StatChip(
                icon: Icons.flutter_dash,
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
    if (hours > 0) return '${hours}h ${minutes}m';
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

// ═════════════════════════════════════════════════════════════════════════════
// Spectrogram Strip
// ═════════════════════════════════════════════════════════════════════════════

/// Shows a scrollable spectrogram from a pre-computed image.
///
/// The painter derives pixels-per-second from image width / player duration,
/// ensuring perfect alignment regardless of sample rate discrepancies.
class _SpectrogramStrip extends StatefulWidget {
  const _SpectrogramStrip({
    required this.spectrogramImage,
    required this.decoding,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.onPause,
    required this.isPlaying,
  });

  final ui.Image? spectrogramImage;
  final bool decoding;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPause;
  final bool isPlaying;

  @override
  State<_SpectrogramStrip> createState() => _SpectrogramStripState();
}

class _SpectrogramStripState extends State<_SpectrogramStrip>
    with SingleTickerProviderStateMixin {
  /// When non-null the view is pinned to this center (user panned).
  /// When null the view follows the playback position.
  double? _pannedCenterSec;

  late final Ticker _ticker;
  double _interpolatedPositionSec = 0.0;
  DateTime _lastTickTime = DateTime.now();

  double get _viewCenterSec => _pannedCenterSec ?? _interpolatedPositionSec;

  @override
  void initState() {
    super.initState();
    _interpolatedPositionSec = widget.position.inMicroseconds / 1000000.0;
    _ticker = createTicker((elapsed) {
      if (widget.isPlaying && _pannedCenterSec == null) {
        final now = DateTime.now();
        final delta = now.difference(_lastTickTime).inMicroseconds / 1000000.0;
        setState(() {
          _interpolatedPositionSec += delta;
        });
        _lastTickTime = now;
      } else {
        _lastTickTime = DateTime.now();
      }
    });
    _ticker.start();
  }

  @override
  void didUpdateWidget(_SpectrogramStrip oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sync interpolated position with the source of truth whenever it updates
    if (widget.position != oldWidget.position) {
      final actualSec = widget.position.inMicroseconds / 1000000.0;
      // If we've drifted significantly (more than 100ms), snap it to fix desyncs.
      if ((_interpolatedPositionSec - actualSec).abs() > 0.1) {
        _interpolatedPositionSec = actualSec;
      }
    }

    if (widget.isPlaying && !oldWidget.isPlaying) {
      _lastTickTime = DateTime.now();
    }

    // When playback resumes while the view is panned, seek to the panned
    // position so playback continues from the white center marker.
    if (widget.isPlaying && !oldWidget.isPlaying && _pannedCenterSec != null) {
      final seekTarget = _pannedCenterSec!;
      _pannedCenterSec = null;
      _interpolatedPositionSec = seekTarget;
      widget.onSeek(Duration(microseconds: (seekTarget * 1e6).round()));
    } else if (widget.isPlaying && !oldWidget.isPlaying) {
      _pannedCenterSec = null;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.decoding || widget.spectrogramImage == null) {
      return Container(
        height: 160,
        color: Colors.black,
        child: widget.decoding
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      );
    }

    return GestureDetector(
      onTapDown: _handleTap,
      onHorizontalDragUpdate: _handleDrag,
      child: Container(
        height: 160,
        color: Colors.black,
        child: CustomPaint(
          painter: _ReviewSpectrogramPainter(
            spectrogramImage: widget.spectrogramImage!,
            centerSec: _viewCenterSec,
            durationSec: widget.duration.inMicroseconds / 1000000.0,
            colorScheme: theme.colorScheme,
          ),
          size: const Size(double.infinity, 160),
        ),
      ),
    );
  }

  void _handleTap(TapDownDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || widget.duration == Duration.zero) return;
    const viewSeconds = _ReviewSpectrogramPainter._viewSeconds;
    final startSec = _viewCenterSec - viewSeconds / 2;
    final fraction = details.localPosition.dx / box.size.width;
    final targetSec = startSec + fraction * viewSeconds;
    final clampedMs =
        (targetSec * 1000).round().clamp(0, widget.duration.inMilliseconds);
    widget.onSeek(Duration(milliseconds: clampedMs));
    setState(() => _pannedCenterSec = null);
  }

  void _handleDrag(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final secPerPixel = _ReviewSpectrogramPainter._viewSeconds / box.size.width;
    final durationSec = widget.duration.inMicroseconds / 1000000.0;

    // Pause playback on first drag gesture.
    if (widget.isPlaying && _pannedCenterSec == null) {
      widget.onPause();
    }

    setState(() {
      _pannedCenterSec ??= widget.position.inMicroseconds / 1000000.0;
      _pannedCenterSec = (_pannedCenterSec! - details.delta.dx * secPerPixel)
          .clamp(0.0, durationSec);
    });
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Review Spectrogram Painter
// ═════════════════════════════════════════════════════════════════════════════

/// Viewport-blit painter for the pre-computed spectrogram image.
///
/// Derives pixels-per-second from `imageWidth / durationSec` so the
/// spectrogram always spans exactly the player duration.  No sample-rate
/// dependency — the image is simply stretched to fit the timeline.
class _ReviewSpectrogramPainter extends CustomPainter {
  _ReviewSpectrogramPainter({
    required this.spectrogramImage,
    required this.centerSec,
    required this.durationSec,
    required this.colorScheme,
  });

  final ui.Image spectrogramImage;
  final double centerSec;
  final double durationSec;
  final ColorScheme colorScheme;

  /// How many seconds of audio the widget viewport shows.
  static const double _viewSeconds = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (durationSec <= 0) return;

    final imgW = spectrogramImage.width.toDouble();
    final imgH = spectrogramImage.height.toDouble();

    // Derive pixel mapping from image width and player duration.
    final pxPerSec = imgW / durationSec;

    final startSec = centerSec - _viewSeconds / 2;
    final endSec = centerSec + _viewSeconds / 2;

    // Convert time to image pixel x.
    final srcX1 = (startSec * pxPerSec).clamp(0.0, imgW);
    final srcX2 = (endSec * pxPerSec).clamp(0.0, imgW);

    // Destination x: offset when the view extends before/after the image.
    final dstX1 = startSec < 0 ? (-startSec / _viewSeconds * size.width) : 0.0;
    final dstX2 = endSec > durationSec
        ? size.width - ((endSec - durationSec) / _viewSeconds * size.width)
        : size.width;

    if (srcX2 > srcX1 && dstX2 > dstX1) {
      canvas.drawImageRect(
        spectrogramImage,
        Rect.fromLTRB(srcX1, 0, srcX2, imgH),
        Rect.fromLTRB(dstX1, 0, dstX2, size.height),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    // ── Playhead (fixed at center) ────────────────────────────────────
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5,
    );

    // ── Time labels ───────────────────────────────────────────────────
    final pxPerSecScreen = size.width / _viewSeconds;
    final textStyle = TextStyle(
      color: Colors.white.withAlpha(180),
      fontSize: 9,
    );
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    final firstLabel = ((startSec / 2).ceil() * 2).toDouble();
    for (var t = firstLabel; t < endSec; t += 2) {
      if (t < 0) continue;
      final x = (t - startSec) * pxPerSecScreen;
      if (x < 0 || x > size.width - 30) continue;
      tp.text = TextSpan(text: _fmtSec(t), style: textStyle);
      tp.layout();
      tp.paint(canvas, Offset(x + 2, size.height - tp.height - 2));
      canvas.drawLine(
        Offset(x, size.height - 2),
        Offset(x, size.height),
        Paint()..color = Colors.white.withAlpha(60),
      );
    }
  }

  String _fmtSec(double sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(covariant _ReviewSpectrogramPainter old) {
    return old.centerSec != centerSec ||
        old.durationSec != durationSec ||
        !identical(old.spectrogramImage, spectrogramImage);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Audio Player Bar
// ═════════════════════════════════════════════════════════════════════════════

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
            iconSize: 44,
            color: theme.colorScheme.primary,
            onPressed: () {
              if (isPlaying) {
                player.pause();
              } else {
                player.play();
              }
            },
          ),
          SizedBox(
            width: 44,
            child: Text(
              _formatPosition(position),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
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
                onChanged: (v) =>
                    player.seek(Duration(milliseconds: v.toInt())),
              ),
            ),
          ),
          SizedBox(
            width: 44,
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
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Species Tile — Expandable row for one species
// ═════════════════════════════════════════════════════════════════════════════

class _SpeciesTile extends ConsumerWidget {
  const _SpeciesTile({
    required this.group,
    required this.sessionStart,
    required this.isExpanded,
    required this.isActive,
    required this.onToggleExpand,
    required this.onSpeciesInfo,
    required this.onSeekCluster,
    required this.onDeleteCluster,
  });

  final _SpeciesGroup group;
  final DateTime sessionStart;
  final bool isExpanded;
  final bool isActive;
  final VoidCallback onToggleExpand;
  final VoidCallback onSpeciesInfo;
  final ValueChanged<_DetectionCluster> onSeekCluster;
  final ValueChanged<_DetectionCluster> onDeleteCluster;

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
    final offsetStr = _fmtOffset(offset);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primaryContainer.withAlpha(90)
            : Colors.transparent,
        border: isActive
            ? Border(
                left: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 3,
                ),
              )
            : null,
      ),
      child: Column(
        children: [
          // ── Main species row ───────────────────────────────
          InkWell(
            onTap: onToggleExpand,
            onLongPress: onSpeciesInfo,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Seek to first detection.
                  InkWell(
                    onTap: () => onSeekCluster(group.clusters.first),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 24,
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

                  // Species info.
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (group.totalCount > 1)
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
                                  '×${group.totalCount}',
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
                                  color: theme.colorScheme.onSurface
                                      .withAlpha(153),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              group.bestConfidencePercent,
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

                  // Expand chevron.
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 24,
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded cluster list ─────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 56, bottom: 4),
              child: Column(
                children: [
                  for (final cluster in group.clusters)
                    _ClusterRow(
                      cluster: cluster,
                      sessionStart: sessionStart,
                      onSeek: () => onSeekCluster(cluster),
                      onDelete: () => onDeleteCluster(cluster),
                    ),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),

          const Divider(height: 1, indent: 60),
        ],
      ),
    );
  }

  String _fmtOffset(Duration d) {
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

// ═════════════════════════════════════════════════════════════════════════════
// Cluster Row — One time-span cluster within an expanded species
// ═════════════════════════════════════════════════════════════════════════════

class _ClusterRow extends StatelessWidget {
  const _ClusterRow({
    required this.cluster,
    required this.sessionStart,
    required this.onSeek,
    required this.onDelete,
  });

  final _DetectionCluster cluster;
  final DateTime sessionStart;
  final VoidCallback onSeek;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = cluster.firstTimestamp.difference(sessionStart);
    final end = cluster.lastTimestamp.difference(sessionStart) +
        const Duration(seconds: 3); // Include window duration.
    final isSingle = cluster.count == 1;

    final timeStr = isSingle
        ? _fmtOffset(start)
        : '${_fmtOffset(start)} – ${_fmtOffset(end)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          InkWell(
            onTap: onSeek,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 24,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              timeStr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
          ),
          if (cluster.count > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '×${cluster.count}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
            ),
          Text(
            cluster.bestConfidencePercent,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.close,
                size: 24,
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtOffset(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}
