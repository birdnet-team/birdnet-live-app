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
import 'package:flutter/scheduler.dart';
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

part 'widgets/session_review_widgets.dart';

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
    // Save pending changes before sharing so the export is up to date.
    if (_isDirty) await _save();

    final exportFormat = ref.read(exportFormatProvider);
    final includeAudio = ref.read(includeAudioProvider);

    final exportPath = await buildSessionExport(
      widget.session,
      format: exportFormat,
      includeAudio: includeAudio,
    );

    if (exportPath == null) return;
    await Share.shareXFiles([XFile(exportPath)]);
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
          final nav = Navigator.of(context);
          final canPop = await _onWillPop();
          if (canPop) nav.pop();
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
  ///    shorter than [maxGapSec] or 3s into clusters.
  /// 4. Sort species by their earliest detection.
  static List<_SpeciesGroup> _buildSpeciesGroups(
    List<DetectionRecord> records,
    int maxGapSec,
  ) {
    if (records.isEmpty) return const [];

    // Force grouping gap to be at least 3 seconds.
    final effectiveMaxGapSec = math.max(3, maxGapSec);

    final bySpecies = <String, List<DetectionRecord>>{};
    for (final r in records) {
      bySpecies.putIfAbsent(r.scientificName, () => []).add(r);
    }

    final groups = <_SpeciesGroup>[];
    for (final entry in bySpecies.entries) {
      final sorted = List.of(entry.value)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Merge consecutive detections.
      final clusters = <_DetectionCluster>[];
      var current = <DetectionRecord>[sorted.first];

      for (var i = 1; i < sorted.length; i++) {
        final gap =
            sorted[i].timestamp.difference(sorted[i - 1].timestamp).inSeconds;
        if (gap <= effectiveMaxGapSec) {
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
