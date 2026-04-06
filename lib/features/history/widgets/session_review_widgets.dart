part of '../session_review_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Data Models
// ═════════════════════════════════════════════════════════════════════════════

/// Snapshot of mutable review state for undo/redo.
class _ReviewSnapshot {
  _ReviewSnapshot({
    required this.detections,
    required this.annotations,
    required this.trimStartSec,
    required this.trimEndSec,
    required this.clipOffsetSec,
  });

  final List<DetectionRecord> detections;
  final List<SessionAnnotation> annotations;
  final double? trimStartSec;
  final double? trimEndSec;
  final double clipOffsetSec;
}

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
    this.locationName,
    this.onShowMap,
  });

  final LiveSession session;
  final int detectionCount;
  final String? locationName;
  final VoidCallback? onShowMap;

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
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(178),
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
          if (session.latitude != null && session.longitude != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: onShowMap,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      locationName ??
                          '${session.latitude!.toStringAsFixed(4)}, '
                              '${session.longitude!.toStringAsFixed(4)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.map_outlined,
                      size: 18,
                      color: theme.colorScheme.primary.withAlpha(178)),
                ],
              ),
            ),
          ],
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
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodyMedium),
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
        height: 150,
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
        height: 150,
        color: Colors.black,
        child: CustomPaint(
          painter: _ReviewSpectrogramPainter(
            spectrogramImage: widget.spectrogramImage!,
            centerSec: _viewCenterSec,
            durationSec: widget.duration.inMicroseconds / 1000000.0,
            colorScheme: theme.colorScheme,
          ),
          size: const Size(double.infinity, 150),
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
// Play/Pause Button Overlay
// ═════════════════════════════════════════════════════════════════════════════

/// Semi-transparent play/pause button overlaid on the spectrogram strip.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.onToggle,
  });

  final bool isPlaying;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
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
    required this.onReplaceCluster,
  });

  final _SpeciesGroup group;
  final DateTime sessionStart;
  final bool isExpanded;
  final bool isActive;
  final VoidCallback onToggleExpand;
  final VoidCallback onSpeciesInfo;
  final ValueChanged<_DetectionCluster> onSeekCluster;
  final ValueChanged<_DetectionCluster> onDeleteCluster;
  final ValueChanged<_DetectionCluster> onReplaceCluster;

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
                      onReplace: () => onReplaceCluster(cluster),
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
    required this.onReplace,
  });

  final _DetectionCluster cluster;
  final DateTime sessionStart;
  final VoidCallback onSeek;
  final VoidCallback onDelete;
  final VoidCallback onReplace;

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
            onTap: onReplace,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.swap_horiz,
                size: 24,
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ),
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

// ═════════════════════════════════════════════════════════════════════════════
// Add Species Overlay — Search and insert a manual detection
// ═════════════════════════════════════════════════════════════════════════════

/// Insertion mode chosen by the user when adding a manual species detection.
enum _InsertMode {
  /// Insert a single detection with confidence 1.0 at the session start.
  global,

  /// Insert at a specific playback timestamp.
  atTimestamp,

  /// Replace an existing detection.
  replace,
}

/// Full-screen overlay for searching and adding a species to the session.
///
/// Returns a [_AddSpeciesResult] or null if cancelled.
class _AddSpeciesOverlay extends ConsumerStatefulWidget {
  const _AddSpeciesOverlay({
    required this.sessionStart,
    required this.positionSec,
    required this.existingDetections,
    this.initialMode,
    this.initialReplaceTarget,
  });

  final DateTime sessionStart;
  final double positionSec;
  final List<DetectionRecord> existingDetections;
  final _InsertMode? initialMode;
  final DetectionRecord? initialReplaceTarget;

  @override
  ConsumerState<_AddSpeciesOverlay> createState() => _AddSpeciesOverlayState();
}

class _AddSpeciesResult {
  _AddSpeciesResult({
    required this.scientificName,
    required this.commonName,
    required this.mode,
    this.replaceRecord,
  });

  final String scientificName;
  final String commonName;
  final _InsertMode mode;
  final DetectionRecord? replaceRecord;
}

class _AddSpeciesOverlayState extends ConsumerState<_AddSpeciesOverlay> {
  final _searchController = TextEditingController();
  List<TaxonomySpecies> _results = [];
  late _InsertMode _mode;
  DetectionRecord? _replaceTarget;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode ?? _InsertMode.global;
    _replaceTarget = widget.initialReplaceTarget;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final svc = ref.read(taxonomyServiceProvider).valueOrNull;
    if (svc == null) return;
    final geoScores = ref.read(geoScoresProvider).valueOrNull;
    setState(() {
      if (query.isEmpty) {
        _results = [];
        return;
      }
      // Fetch a larger pool, then sort by geo score + text relevance.
      final raw = svc.search(query, limit: 200);
      if (geoScores != null && geoScores.isNotEmpty) {
        final lower = query.toLowerCase();
        raw.sort((a, b) {
          final scoreA = geoScores[a.scientificName] ?? 0.0;
          final scoreB = geoScores[b.scientificName] ?? 0.0;
          if (scoreA != scoreB) return scoreB.compareTo(scoreA);
          final aStarts = a.commonName.toLowerCase().startsWith(lower) ||
              a.scientificName.toLowerCase().startsWith(lower);
          final bStarts = b.commonName.toLowerCase().startsWith(lower) ||
              b.scientificName.toLowerCase().startsWith(lower);
          if (aStarts != bStarts) return aStarts ? -1 : 1;
          return a.commonName.compareTo(b.commonName);
        });
      }
      _results = raw.length > 30 ? raw.sublist(0, 30) : raw;
    });
  }

  void _selectSpecies(String sciName, String comName) {
    Navigator.of(context).pop(
      _AddSpeciesResult(
        scientificName: sciName,
        commonName: comName,
        mode: _mode,
        replaceRecord: _mode == _InsertMode.replace ? _replaceTarget : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomyAsync = ref.watch(taxonomyServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionAddSpecies),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Search field ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.sessionSearchSpecies,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // ── Insert mode selector ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<_InsertMode>(
              segments: [
                ButtonSegment(
                  value: _InsertMode.global,
                  label: Text(
                    l10n.sessionInsertGlobally,
                    style: const TextStyle(fontSize: 11),
                  ),
                  icon: const Icon(Icons.public, size: 16),
                ),
                ButtonSegment(
                  value: _InsertMode.atTimestamp,
                  label: Text(
                    l10n.sessionInsertAtTimestamp,
                    style: const TextStyle(fontSize: 11),
                  ),
                  icon: const Icon(Icons.schedule, size: 16),
                ),
                ButtonSegment(
                  value: _InsertMode.replace,
                  label: Text(
                    l10n.sessionReplaceDetection,
                    style: const TextStyle(fontSize: 11),
                  ),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),

          // ── Replace target picker (shown only in replace mode) ──
          if (_mode == _InsertMode.replace) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonFormField<DetectionRecord>(
                value: _replaceTarget,
                decoration: InputDecoration(
                  labelText: l10n.sessionReplaceDetection,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: widget.existingDetections.map((d) {
                  final locName = taxonomyAsync.valueOrNull
                          ?.lookup(d.scientificName)
                          ?.commonNameForLocale(speciesLocale) ??
                      d.commonName;
                  return DropdownMenuItem(
                    value: d,
                    child: Text(
                      '$locName (${d.confidencePercent})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _replaceTarget = v),
              ),
            ),
          ],

          const Divider(height: 16),

          // ── Unknown / Other quick action ───────────────────
          ListTile(
            leading: Icon(
              Icons.help_outline,
              color: theme.colorScheme.tertiary,
            ),
            title: Text(l10n.sessionUnknownSpecies),
            subtitle: Text(
              DetectionRecord.unknownSpeciesName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            onTap: () => _selectSpecies(
              DetectionRecord.unknownSpeciesName,
              DetectionRecord.unknownCommonName,
            ),
          ),
          const Divider(height: 1),

          // ── Search results ────────────────────────────────
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final sp = _results[index];
                final locName = sp.commonNameForLocale(speciesLocale);
                return ListTile(
                  title: Text(locName),
                  subtitle: Text(
                    sp.scientificName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  onTap: () => _selectSpecies(sp.scientificName, sp.commonName),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Annotations Section
// ═════════════════════════════════════════════════════════════════════════════

/// Collapsible section listing session annotations with an add button.
class _AnnotationsSection extends StatefulWidget {
  const _AnnotationsSection({
    required this.annotations,
    required this.positionSec,
    required this.onAdd,
    required this.onDelete,
  });

  final List<SessionAnnotation> annotations;
  final double positionSec;
  final ValueChanged<SessionAnnotation> onAdd;
  final ValueChanged<int> onDelete;

  @override
  State<_AnnotationsSection> createState() => _AnnotationsSectionState();
}

class _AnnotationsSectionState extends State<_AnnotationsSection> {
  final _textController = TextEditingController();
  bool _atTimestamp = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(SessionAnnotation(
      text: text,
      createdAt: DateTime.now(),
      offsetInRecording: _atTimestamp ? widget.positionSec : null,
    ));
    _textController.clear();
    setState(() => _atTimestamp = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            l10n.sessionAnnotations,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Existing annotations ────────────────────────────
        for (var i = 0; i < widget.annotations.length; i++)
          _AnnotationRow(
            annotation: widget.annotations[i],
            onDelete: () => widget.onDelete(i),
          ),

        // ── Add annotation ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: l10n.sessionAddAnnotation,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _atTimestamp ? Icons.schedule : Icons.public,
                      size: 20,
                      color: _atTimestamp
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withAlpha(120),
                    ),
                    tooltip: _atTimestamp
                        ? l10n.sessionInsertAtTimestamp
                        : l10n.sessionAnnotationGlobal,
                    onPressed: () =>
                        setState(() => _atTimestamp = !_atTimestamp),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: _submit,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnnotationRow extends StatelessWidget {
  const _AnnotationRow({
    required this.annotation,
    required this.onDelete,
  });

  final SessionAnnotation annotation;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    String offsetLabel;
    if (annotation.offsetInRecording != null) {
      final m = annotation.offsetInRecording! ~/ 60;
      final s = (annotation.offsetInRecording! % 60).toInt();
      offsetLabel =
          '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    } else {
      offsetLabel = l10n.sessionAnnotationGlobal;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              offsetLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              annotation.text,
              style: theme.textTheme.bodySmall,
            ),
          ),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Trim Handles — Overlay for recording start/end trimming
// ═════════════════════════════════════════════════════════════════════════════

/// Overlay painted on top of the spectrogram strip showing trim handles.
///
/// Users drag the left handle for trim-start and right handle for trim-end,
/// similar to video cropping in Google Photos.
class _TrimOverlay extends StatefulWidget {
  const _TrimOverlay({
    required this.durationSec,
    required this.initialStartSec,
    required this.initialEndSec,
    required this.onChanged,
  });

  final double durationSec;
  final double initialStartSec;
  final double initialEndSec;
  final void Function(double startSec, double endSec) onChanged;

  @override
  State<_TrimOverlay> createState() => _TrimOverlayState();
}

class _TrimOverlayState extends State<_TrimOverlay> {
  late double _startFrac;
  late double _endFrac;
  bool _draggingStart = false;
  bool _draggingEnd = false;

  @override
  void initState() {
    super.initState();
    _startFrac = widget.durationSec > 0
        ? (widget.initialStartSec / widget.durationSec).clamp(0.0, 1.0)
        : 0.0;
    _endFrac = widget.durationSec > 0
        ? (widget.initialEndSec / widget.durationSec).clamp(0.0, 1.0)
        : 1.0;
  }

  void _reportChange() {
    widget.onChanged(
      _startFrac * widget.durationSec,
      _endFrac * widget.durationSec,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final leftX = _startFrac * w;
        final rightX = _endFrac * w;

        return GestureDetector(
          onHorizontalDragStart: (d) {
            final x = d.localPosition.dx;
            // Decide which handle is closest.
            if ((x - leftX).abs() < (x - rightX).abs()) {
              _draggingStart = true;
              _draggingEnd = false;
            } else {
              _draggingStart = false;
              _draggingEnd = true;
            }
          },
          onHorizontalDragUpdate: (d) {
            setState(() {
              final frac = (d.localPosition.dx / w).clamp(0.0, 1.0);
              if (_draggingStart) {
                _startFrac = math.min(frac, _endFrac - 0.01);
              } else if (_draggingEnd) {
                _endFrac = math.max(frac, _startFrac + 0.01);
              }
            });
          },
          onHorizontalDragEnd: (_) {
            _draggingStart = false;
            _draggingEnd = false;
            _reportChange();
          },
          child: CustomPaint(
            painter: _TrimOverlayPainter(
              startFrac: _startFrac,
              endFrac: _endFrac,
              accentColor: theme.colorScheme.primary,
            ),
            size: Size(w, h),
          ),
        );
      },
    );
  }
}

class _TrimOverlayPainter extends CustomPainter {
  _TrimOverlayPainter({
    required this.startFrac,
    required this.endFrac,
    required this.accentColor,
  });

  final double startFrac;
  final double endFrac;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withAlpha(140);
    final handlePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // Dimmed regions outside the trim.
    canvas.drawRect(
      Rect.fromLTRB(0, 0, startFrac * size.width, size.height),
      dimPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(endFrac * size.width, 0, size.width, size.height),
      dimPaint,
    );

    // Top/bottom borders of the selected region.
    final borderPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTRB(
        startFrac * size.width,
        0,
        endFrac * size.width,
        size.height,
      ),
      borderPaint,
    );

    // Left handle.
    const hw = 14.0;
    const hh = 32.0;
    final ly = (size.height - hh) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startFrac * size.width - hw / 2, ly, hw, hh),
        const Radius.circular(4),
      ),
      handlePaint,
    );
    // Grip lines on left handle.
    final gripPaint = Paint()
      ..color = Colors.white.withAlpha(200)
      ..strokeWidth = 1.5;
    for (var i = -1; i <= 1; i++) {
      final cx = startFrac * size.width;
      final cy = size.height / 2 + i * 5.0;
      canvas.drawLine(Offset(cx - 3, cy), Offset(cx + 3, cy), gripPaint);
    }

    // Right handle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(endFrac * size.width - hw / 2, ly, hw, hh),
        const Radius.circular(4),
      ),
      handlePaint,
    );
    for (var i = -1; i <= 1; i++) {
      final cx = endFrac * size.width;
      final cy = size.height / 2 + i * 5.0;
      canvas.drawLine(Offset(cx - 3, cy), Offset(cx + 3, cy), gripPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrimOverlayPainter old) =>
      old.startFrac != startFrac || old.endFrac != endFrac;
}

// ═════════════════════════════════════════════════════════════════════════════
// Zoomable Trim Spectrogram View
// ═════════════════════════════════════════════════════════════════════════════

/// Full-recording spectrogram with pinch-to-zoom, scroll, and trim handles.
///
/// Replaces the fixed-viewport spectrogram strip when trim mode is active.
/// At zoom=1 the entire recording fits on screen.  Pinch to zoom in for
/// precise handle placement.  Drag horizontally to scroll when zoomed.
class _TrimSpectrogramView extends StatefulWidget {
  const _TrimSpectrogramView({
    required this.spectrogramImage,
    required this.durationSec,
    required this.initialStartSec,
    required this.initialEndSec,
    required this.onChanged,
  });

  final ui.Image spectrogramImage;
  final double durationSec;
  final double initialStartSec;
  final double initialEndSec;
  final void Function(double startSec, double endSec) onChanged;

  @override
  State<_TrimSpectrogramView> createState() => _TrimSpectrogramViewState();
}

class _TrimSpectrogramViewState extends State<_TrimSpectrogramView> {
  double _zoom = 1.0;
  double _scrollSec = 0.0;
  double _baseZoom = 1.0;
  Offset? _lastFocalPoint;
  late double _startSec;
  late double _endSec;
  String? _activeDrag; // 'start', 'end', or null for zoom/pan

  @override
  void initState() {
    super.initState();
    _startSec = widget.initialStartSec;
    _endSec = widget.initialEndSec;
  }

  double get _viewDurationSec => widget.durationSec / _zoom;

  double _secToX(double sec, double width) {
    return (sec - _scrollSec) / _viewDurationSec * width;
  }

  double _xToSec(double x, double width) {
    return _scrollSec + x / width * _viewDurationSec;
  }

  void _clampScroll() {
    final maxScroll = widget.durationSec - _viewDurationSec;
    _scrollSec = _scrollSec.clamp(0.0, math.max(0.0, maxScroll));
  }

  void _onScaleStart(ScaleStartDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final w = box.size.width;
    final startX = _secToX(_startSec, w);
    final endX = _secToX(_endSec, w);
    final touchX = details.localFocalPoint.dx;

    const handleThreshold = 28.0;
    final distToStart = (touchX - startX).abs();
    final distToEnd = (touchX - endX).abs();
    if (distToStart < handleThreshold && distToStart <= distToEnd) {
      _activeDrag = 'start';
    } else if (distToEnd < handleThreshold) {
      _activeDrag = 'end';
    } else {
      _activeDrag = null;
      _baseZoom = _zoom;
      _lastFocalPoint = details.localFocalPoint;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final w = box.size.width;

    if (_activeDrag != null) {
      final sec =
          _xToSec(details.localFocalPoint.dx, w).clamp(0.0, widget.durationSec);
      setState(() {
        if (_activeDrag == 'start') {
          _startSec = math.min(sec, _endSec - 0.5);
        } else {
          _endSec = math.max(sec, _startSec + 0.5);
        }
      });
    } else {
      setState(() {
        _zoom = (_baseZoom * details.scale).clamp(1.0, 20.0);
        final dx = details.localFocalPoint.dx -
            (_lastFocalPoint?.dx ?? details.localFocalPoint.dx);
        final secPerPx = _viewDurationSec / w;
        _scrollSec -= dx * secPerPx;
        _clampScroll();
        _lastFocalPoint = details.localFocalPoint;
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_activeDrag != null) {
      widget.onChanged(_startSec, _endSec);
    }
    _activeDrag = null;
    _lastFocalPoint = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: Container(
        height: 150,
        color: Colors.black,
        child: CustomPaint(
          painter: _TrimSpectrogramPainter(
            spectrogramImage: widget.spectrogramImage,
            durationSec: widget.durationSec,
            scrollSec: _scrollSec,
            viewDurationSec: _viewDurationSec,
            trimStartSec: _startSec,
            trimEndSec: _endSec,
            accentColor: theme.colorScheme.primary,
          ),
          size: const Size(double.infinity, 150),
        ),
      ),
    );
  }
}

class _TrimSpectrogramPainter extends CustomPainter {
  _TrimSpectrogramPainter({
    required this.spectrogramImage,
    required this.durationSec,
    required this.scrollSec,
    required this.viewDurationSec,
    required this.trimStartSec,
    required this.trimEndSec,
    required this.accentColor,
  });

  final ui.Image spectrogramImage;
  final double durationSec;
  final double scrollSec;
  final double viewDurationSec;
  final double trimStartSec;
  final double trimEndSec;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (durationSec <= 0) return;
    final imgW = spectrogramImage.width.toDouble();
    final imgH = spectrogramImage.height.toDouble();
    final pxPerSec = imgW / durationSec;

    // Draw the visible portion of the spectrogram.
    final srcX1 = (scrollSec * pxPerSec).clamp(0.0, imgW);
    final srcX2 = ((scrollSec + viewDurationSec) * pxPerSec).clamp(0.0, imgW);
    if (srcX2 > srcX1) {
      canvas.drawImageRect(
        spectrogramImage,
        Rect.fromLTRB(srcX1, 0, srcX2, imgH),
        Rect.fromLTRB(0, 0, size.width, size.height),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    // Dimmed regions outside the trim selection.
    final dimPaint = Paint()..color = Colors.black.withAlpha(140);
    final trimStartX =
        (trimStartSec - scrollSec) / viewDurationSec * size.width;
    final trimEndX = (trimEndSec - scrollSec) / viewDurationSec * size.width;

    if (trimStartX > 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, 0, trimStartX.clamp(0, size.width), size.height),
        dimPaint,
      );
    }
    if (trimEndX < size.width) {
      canvas.drawRect(
        Rect.fromLTRB(
            trimEndX.clamp(0, size.width), 0, size.width, size.height),
        dimPaint,
      );
    }

    // Border around the selected region.
    final borderPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTRB(
        trimStartX.clamp(0, size.width),
        0,
        trimEndX.clamp(0, size.width),
        size.height,
      ),
      borderPaint,
    );

    // ── Trim handles ──────────────────────────────────────────────
    const hw = 14.0;
    const hh = 32.0;
    final handlePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    final gripPaint = Paint()
      ..color = Colors.white.withAlpha(200)
      ..strokeWidth = 1.5;
    for (final hx in [trimStartX, trimEndX]) {
      if (hx < -hw || hx > size.width + hw) continue;
      final ly = (size.height - hh) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(hx - hw / 2, ly, hw, hh),
          const Radius.circular(4),
        ),
        handlePaint,
      );
      for (var i = -1; i <= 1; i++) {
        final cy = size.height / 2 + i * 5.0;
        canvas.drawLine(Offset(hx - 3, cy), Offset(hx + 3, cy), gripPaint);
      }
    }

    // ── Time labels ───────────────────────────────────────────────
    final textStyle = TextStyle(
      color: Colors.white.withAlpha(180),
      fontSize: 9,
    );
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    double interval = 2.0;
    if (viewDurationSec > 120) {
      interval = 30.0;
    } else if (viewDurationSec > 60) {
      interval = 10.0;
    } else if (viewDurationSec > 30) {
      interval = 5.0;
    }

    final firstLabel = ((scrollSec / interval).ceil() * interval);
    for (var t = firstLabel; t < scrollSec + viewDurationSec; t += interval) {
      final x = (t - scrollSec) / viewDurationSec * size.width;
      if (x < 0 || x > size.width - 30) continue;
      final m = t ~/ 60;
      final s = (t % 60).toInt();
      tp.text = TextSpan(
        text: '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
        style: textStyle,
      );
      tp.layout();
      tp.paint(canvas, Offset(x + 2, size.height - tp.height - 2));
      canvas.drawLine(
        Offset(x, size.height - 2),
        Offset(x, size.height),
        Paint()..color = Colors.white.withAlpha(60),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrimSpectrogramPainter old) => true;
}

// ═════════════════════════════════════════════════════════════════════════════
// Help Dialog
// ═════════════════════════════════════════════════════════════════════════════

/// Bottom sheet displaying help documentation for the session review screen.
class _SessionHelpSheet extends StatelessWidget {
  const _SessionHelpSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // Drag handle.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.sessionHelpTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _helpSection(
                theme,
                icon: Icons.info_outline,
                body: l10n.sessionHelpOverview,
              ),
              _helpSection(
                theme,
                icon: Icons.add_circle_outline,
                body: l10n.sessionHelpAddSpecies,
              ),
              _helpSection(
                theme,
                icon: Icons.note_add_outlined,
                body: l10n.sessionHelpAnnotations,
              ),
              _helpSection(
                theme,
                icon: Icons.content_cut,
                body: l10n.sessionHelpTrimming,
              ),
              _helpSection(
                theme,
                icon: Icons.share,
                body: l10n.sessionHelpExport,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _helpSection(ThemeData theme,
      {required IconData icon, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(body, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
