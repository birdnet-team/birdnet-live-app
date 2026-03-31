// =============================================================================
// Session Review Screen — Post-session review, playback, and spectrogram
// =============================================================================
//
// Shown after finalizing a live session, or when reopening from the library.
//
// ### UX highlights
//
//   • **Species-collapsed list** — All detections of the same species are
//     merged into one expandable row.  The row shows the species name, best
//     confidence, total count, and first/last timestamps.
//
//   • **Consecutive clustering** — Within a species, adjacent detections
//     whose gap is shorter than the inference window duration are grouped
//     into time-span clusters so that a bird calling for 30 continuous
//     seconds shows as one cluster, not 10 rows.
//
//   • **Playback highlighting** — When audio plays through a detection's
//     timestamp, the corresponding species row pulses with a highlight so
//     the user can visually follow along.
//
//   • **Scrolling spectrogram** — A strip above the player shows ~10 seconds
//     of decoded audio centered on the playback position, scrolling in
//     real-time.  Detection markers are overlaid.
//
//   • **Delete confirmation** — Removing a detection shows a confirmation
//     dialog.  Changes are tracked as "dirty" and require an explicit Save.
//
//   • **Session naming** — The session displays its `displayName`
//     (`BirdNET-Live_Session_YYYY-MM-DD_HH-MM-SS`) which is also used for
//     the ZIP export filename.
//
// ### Layout (top → bottom)
//
//   1. AppBar with session name, save / share / discard actions.
//   2. Summary header — date, duration, species count, detections.
//   3. Spectrogram strip — ~160 dp tall scrolling FFT view.
//   4. Audio player bar — play/pause, seek slider, position / duration.
//   5. Species detection list — expandable rows, scrollable.
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:fftea/fftea.dart';
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
import '../recording/audio_decoder.dart';
import '../spectrogram/color_maps.dart';
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
  // ── State ───────────────────────────────────────────────────────────

  late List<DetectionRecord> _detections;
  late List<_SpeciesGroup> _speciesGroups;
  final Set<String> _expandedSpecies = {};
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _audioAvailable = false;
  bool _isDirty = false;

  /// Pre-computed spectrogram image covering the entire recording.
  ui.Image? _spectrogramImage;

  /// Whether the audio is being decoded and the spectrogram computed.
  bool _decoding = false;

  @override
  void initState() {
    super.initState();
    _detections = List.of(widget.session.detections);
    _speciesGroups = _buildSpeciesGroups(
      _detections,
      widget.session.settings.windowDuration,
    );
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

      // Decode audio for spectrogram in the background.
      _decodeAudioForSpectrogram(path);
    } catch (_) {
      // Audio not available — review still works without playback.
    }
  }

  Future<void> _decodeAudioForSpectrogram(String path) async {
    setState(() => _decoding = true);
    try {
      final audio = await AudioDecoder.decodeFile(path);
      if (!mounted) return;
      await _buildSpectrogramImage(audio);
    } catch (_) {
      // Spectrogram unavailable — non-fatal.
    } finally {
      if (mounted) setState(() => _decoding = false);
    }
  }

  /// Pre-compute the entire session spectrogram as a [ui.Image].
  ///
  /// Uses a fixed FFT size and hop.  Each pixel column = one FFT frame.
  /// The painter scrolls through the image using pixels-per-second.
  Future<void> _buildSpectrogramImage(DecodedAudio audio) async {
    const fftSize = 1024;
    const hop = 512;
    const maxFreqHz = 16000;
    const dbFloor = -80.0;
    const dbCeiling = 0.0;

    if (audio.totalSamples < fftSize) return;

    final numCols = (audio.totalSamples - fftSize) ~/ hop + 1;
    if (numCols <= 0) return;

    final nyquist = audio.sampleRate / 2;
    final binCount = fftSize ~/ 2 + 1;
    final displayBins =
        (maxFreqHz / nyquist * binCount).round().clamp(1, binCount);

    final lut = SpectrogramColorMap.lut('viridis');
    final pixels = Uint8List(numCols * displayBins * 4);

    // Periodic Hann window (matches FftProcessor).
    final hann = Float64List(fftSize);
    final hannFactor = 2.0 * math.pi / fftSize;
    for (var i = 0; i < fftSize; i++) {
      hann[i] = 0.5 * (1.0 - math.cos(hannFactor * i));
    }
    final fft = FFT(fftSize);

    for (var c = 0; c < numCols; c++) {
      if (c > 0 && c % 200 == 0) {
        await Future.delayed(Duration.zero);
        if (!mounted) return;
      }

      final colSample = c * hop;
      final chunk = audio.readFloat32(colSample, fftSize);
      final input = Float64List(fftSize);
      for (var i = 0; i < fftSize; i++) {
        input[i] = chunk[i] * hann[i];
      }
      final spectrum = fft.realFft(input);

      for (var bin = 0; bin < displayBins; bin++) {
        final re = spectrum[bin].x;
        final im = spectrum[bin].y;
        final power = re * re + im * im;
        final db = 10 * math.log(power + 1e-10) / math.ln10;
        final norm = ((db - dbFloor) / (dbCeiling - dbFloor)).clamp(0.0, 1.0);

        final y = displayBins - 1 - bin;
        final pxOffset = (y * numCols + c) * 4;
        final lutIdx = (norm * 255).round().clamp(0, 255);
        final color = lut[lutIdx];
        pixels[pxOffset] = (color >> 16) & 0xFF;
        pixels[pxOffset + 1] = (color >> 8) & 0xFF;
        pixels[pxOffset + 2] = color & 0xFF;
        pixels[pxOffset + 3] = (color >> 24) & 0xFF;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      numCols,
      displayBins,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;

    if (mounted) {
      setState(() {
        _spectrogramImage?.dispose();
        _spectrogramImage = image;
      });
    } else {
      image.dispose();
    }
  }

  @override
  void dispose() {
    _spectrogramImage?.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sessionReviewTitle),
        content: Text(l10n.sessionUnsavedChanges),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: Text(l10n.sessionDiscard),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: Text(l10n.sessionSave),
          ),
        ],
      ),
    );
    if (result == 'save') {
      await _save();
      return true;
    }
    if (result == 'discard') return true;
    return false; // Dialog dismissed.
  }

  Future<void> _save() async {
    widget.session.detections
      ..clear()
      ..addAll(_detections);
    final repo = ref.read(sessionRepositoryProvider);
    await repo.save(widget.session);
    ref.invalidate(sessionListProvider);
    setState(() => _isDirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.sessionSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

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
    // Save pending changes before sharing so the ZIP is up to date.
    if (_isDirty) await _save();
    final zipPath = await buildSessionZip(widget.session);
    if (zipPath == null) return;
    await Share.shareXFiles([XFile(zipPath)]);
  }

  void _done() {
    Navigator.of(context).pop();
  }

  Future<void> _confirmDeleteDetection(
    _SpeciesGroup group,
    _DetectionCluster cluster,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sessionDeleteDetectionTitle),
        content: Text(l10n.sessionDeleteDetectionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.sessionRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      for (final r in cluster.records) {
        _detections.remove(r);
      }
      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _isDirty = true;
    });
  }

  void _seekToCluster(_DetectionCluster cluster) {
    if (!_audioAvailable || _duration == Duration.zero) return;
    final offset = cluster.firstTimestamp.difference(widget.session.startTime);
    if (offset.isNegative || offset > _duration) return;
    _player.seek(offset);
    if (!_isPlaying) _player.play();
  }

  void _seekToPosition(Duration position) {
    if (!_audioAvailable || _duration == Duration.zero) return;
    _player.seek(position);
    if (!_isPlaying) _player.play();
  }

  void _pausePlayer() {
    if (_isPlaying) _player.pause();
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final canPop = await _onWillPop();
          if (canPop && mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.session.displayName,
            style: theme.textTheme.titleSmall,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (_isDirty) {
                final canPop = await _onWillPop();
                if (canPop && mounted) _done();
              } else {
                _done();
              }
            },
          ),
          actions: [
            if (_isDirty)
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: l10n.sessionSave,
                onPressed: _save,
              ),
            if (_audioAvailable)
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: l10n.sessionShare,
                onPressed: _share,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.sessionDiscard,
              onPressed: _discard,
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

            // ── Spectrogram strip ───────────────────────────
            if (_audioAvailable)
              _SpectrogramStrip(
                spectrogramImage: _spectrogramImage,
                decoding: _decoding,
                position: _position,
                duration: _duration,
                onSeek: _seekToPosition,
                onPause: _pausePlayer,
                isPlaying: _isPlaying,
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

            // ── Species list ────────────────────────────────
            Expanded(
              child: _speciesGroups.isEmpty
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
                      itemCount: _speciesGroups.length,
                      itemBuilder: (context, index) {
                        final group = _speciesGroups[index];
                        final isExpanded =
                            _expandedSpecies.contains(group.scientificName);
                        final isActive = _isSpeciesActive(group);

                        return _SpeciesTile(
                          group: group,
                          sessionStart: widget.session.startTime,
                          isExpanded: isExpanded,
                          isActive: isActive,
                          onToggleExpand: () => setState(() {
                            if (isExpanded) {
                              _expandedSpecies.remove(group.scientificName);
                            } else {
                              _expandedSpecies.add(group.scientificName);
                            }
                          }),
                          onSpeciesInfo: () => SpeciesInfoOverlay.show(
                            context,
                            ref,
                            scientificName: group.scientificName,
                            commonName: group.commonName,
                          ),
                          onSeekCluster: _seekToCluster,
                          onDeleteCluster: (cluster) =>
                              _confirmDeleteDetection(group, cluster),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Whether any detection in [group] spans the current playback position.
  bool _isSpeciesActive(_SpeciesGroup group) {
    if (!_isPlaying && !_audioAvailable) return false;
    final windowSec = widget.session.settings.windowDuration;
    for (final r in group.allRecords) {
      final offset = r.timestamp.difference(widget.session.startTime);
      final detEnd = offset + Duration(seconds: windowSec);
      if (_position >= offset && _position <= detEnd) return true;
    }
    return false;
  }

  // ── Grouping Logic ──────────────────────────────────────────────────

  /// Build species-grouped, cluster-merged detection summaries.
  ///
  /// 1. Group all detections by scientific name.
  /// 2. Sort each group by timestamp.
  /// 3. Within each species, merge consecutive detections whose gap is
  ///    shorter than [maxGapSec] into clusters.
  /// 4. Sort species by their earliest detection.
  static List<_SpeciesGroup> _buildSpeciesGroups(
    List<DetectionRecord> records,
    int maxGapSec,
  ) {
    if (records.isEmpty) return const [];

    final bySpecies = <String, List<DetectionRecord>>{};
    for (final r in records) {
      bySpecies.putIfAbsent(r.scientificName, () => []).add(r);
    }

    final groups = <_SpeciesGroup>[];
    for (final entry in bySpecies.entries) {
      final sorted = List.of(entry.value)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Merge consecutive detections within one inference window.
      final clusters = <_DetectionCluster>[];
      var current = <DetectionRecord>[sorted.first];

      for (var i = 1; i < sorted.length; i++) {
        final gap =
            sorted[i].timestamp.difference(sorted[i - 1].timestamp).inSeconds;
        if (gap <= maxGapSec) {
          current.add(sorted[i]);
        } else {
          clusters.add(_DetectionCluster(current));
          current = [sorted[i]];
        }
      }
      clusters.add(_DetectionCluster(current));

      groups.add(_SpeciesGroup(
        scientificName: entry.key,
        commonName: sorted.first.commonName,
        clusters: clusters,
      ));
    }

    groups.sort((a, b) => a.firstTimestamp.compareTo(b.firstTimestamp));
    return groups;
  }
}

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

class _SpectrogramStripState extends State<_SpectrogramStrip> {
  /// When non-null the view is pinned to this center (user panned).
  /// When null the view follows the playback position.
  double? _pannedCenterSec;

  double get _viewCenterSec =>
      _pannedCenterSec ?? widget.position.inMicroseconds / 1000000.0;

  @override
  void didUpdateWidget(_SpectrogramStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When playback resumes while the view is panned, seek to the panned
    // position so playback continues from the white center marker.
    if (widget.isPlaying && !oldWidget.isPlaying && _pannedCenterSec != null) {
      final seekTarget = _pannedCenterSec!;
      _pannedCenterSec = null;
      widget.onSeek(Duration(microseconds: (seekTarget * 1e6).round()));
    } else if (widget.isPlaying && !oldWidget.isPlaying) {
      _pannedCenterSec = null;
    }
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
                      width: 46,
                      padding: const EdgeInsets.symmetric(vertical: 2),
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
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 22,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 22,
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
