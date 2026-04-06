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

import '../../shared/models/taxonomy_species.dart';
import '../../shared/providers/settings_providers.dart';
import '../explore/explore_providers.dart';
import '../explore/widgets/species_info_overlay.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../recording/audio_decoder.dart';
import '../spectrogram/color_maps.dart';
import 'session_export.dart';
import 'session_map_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/services/reverse_geocoding_service.dart';

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
  late List<SessionAnnotation> _annotations;
  late List<_SpeciesGroup> _speciesGroups;
  final Set<String> _expandedSpecies = {};
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _audioAvailable = false;
  bool _isDirty = false;
  bool _trimMode = false;
  double? _trimStartSec;
  double? _trimEndSec;

  /// Pre-trim-mode values of [_trimStartSec]/[_trimEndSec], saved when
  /// entering trim mode so the undo snapshot captures the real pre-trim state
  /// instead of the transient handle positions set by [_onTrimChanged].
  double? _preTrimStartSec;
  double? _preTrimEndSec;

  // ── Clip state (after trim is applied) ─────────────────────────────

  /// Offset in original-recording seconds of the clip start (0 = no clip).
  double _clipOffsetSec = 0.0;

  /// Full recording duration before any clip was applied.
  double _fullDurationSec = 0.0;

  /// Full-recording spectrogram (never cropped).  Kept for undo / trim view.
  ui.Image? _fullSpectrogramImage;

  // ── Undo / Redo ────────────────────────────────────────────────────

  final List<_ReviewSnapshot> _undoStack = [];
  final List<_ReviewSnapshot> _redoStack = [];

  /// Pre-computed spectrogram image covering the current playback range.
  /// When a clip is active this is cropped to the trimmed region.
  ui.Image? _spectrogramImage;

  /// Whether the audio is being decoded and the spectrogram computed.
  bool _decoding = false;

  bool get _canUndo => _undoStack.isNotEmpty;
  bool get _canRedo => _redoStack.isNotEmpty;

  /// Cached reverse-geocoded location name for display.
  String? _locationName;

  _ReviewSnapshot _takeSnapshot() => _ReviewSnapshot(
        detections: List.of(_detections),
        annotations: List.of(_annotations),
        trimStartSec: _trimStartSec,
        trimEndSec: _trimEndSec,
        clipOffsetSec: _clipOffsetSec,
      );

  void _pushUndo() {
    _undoStack.add(_takeSnapshot());
    _redoStack.clear();
  }

  void _undo() {
    if (!_canUndo) return;
    _redoStack.add(_takeSnapshot());
    final snap = _undoStack.removeLast();
    setState(() {
      _detections = snap.detections;
      _annotations = snap.annotations;
      _trimStartSec = snap.trimStartSec;
      _trimEndSec = snap.trimEndSec;
      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _isDirty = _undoStack.isNotEmpty;
    });
    _syncPlayerClip(snap.clipOffsetSec);
  }

  void _redo() {
    if (!_canRedo) return;
    _undoStack.add(_takeSnapshot());
    final snap = _redoStack.removeLast();
    setState(() {
      _detections = snap.detections;
      _annotations = snap.annotations;
      _trimStartSec = snap.trimStartSec;
      _trimEndSec = snap.trimEndSec;
      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _isDirty = true;
    });
    _syncPlayerClip(snap.clipOffsetSec);
  }

  /// Re-synchronize the player clip and spectrogram after restoring a
  /// snapshot (undo/redo).  [snapshotClipOffset] is the clip offset that
  /// was active when the snapshot was taken.
  Future<void> _syncPlayerClip(double snapshotClipOffset) async {
    if (snapshotClipOffset == _clipOffsetSec) return; // No clip change.

    if (snapshotClipOffset > 0) {
      // Re-apply clip matching the snapshot's trim range.
      final start = _trimStartSec ?? 0.0;
      final end = _trimEndSec ?? _fullDurationSec;
      final startDur = Duration(microseconds: (start * 1e6).round());
      final endDur = Duration(microseconds: (end * 1e6).round());
      final clippedDur = await _player.setClip(start: startDur, end: endDur);
      await _player.seek(Duration.zero);
      await _cropSpectrogramForClip(start, end);
      if (mounted) {
        setState(() {
          _clipOffsetSec = snapshotClipOffset;
          _duration = clippedDur ?? (endDur - startDur);
          _position = Duration.zero;
        });
      }
    } else {
      // Remove clip — restore full recording.
      await _player.setClip();
      await _player.seek(Duration.zero);
      if (mounted) {
        setState(() {
          _clipOffsetSec = 0.0;
          _duration = Duration(microseconds: (_fullDurationSec * 1e6).round());
          _position = Duration.zero;
          if (_spectrogramImage != null &&
              !identical(_spectrogramImage, _fullSpectrogramImage)) {
            _spectrogramImage!.dispose();
          }
          _spectrogramImage = _fullSpectrogramImage;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _detections = List.of(widget.session.detections);
    _annotations = List.of(widget.session.annotations);
    _trimStartSec = widget.session.trimStartSec;
    _trimEndSec = widget.session.trimEndSec;
    _speciesGroups = _buildSpeciesGroups(
      _detections,
      widget.session.settings.windowDuration,
    );
    _initAudio();
    _resolveLocation();
  }

  Future<void> _initAudio() async {
    final path = widget.session.recordingPath;
    if (path == null || !File(path).existsSync()) return;

    try {
      final dur = await _player.setFilePath(path);
      if (!mounted) return;
      setState(() {
        _duration = dur ?? Duration.zero;
        _fullDurationSec = _duration.inMicroseconds / 1e6;
        _audioAvailable = true;
      });

      _player.positionStream.listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
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

      // Decode audio for spectrogram, then restore saved trim if present.
      await _decodeAudioForSpectrogram(path);
      await _restoreSavedTrim();
    } catch (_) {
      // Audio not available — review still works without playback.
    }
  }

  /// Re-apply a previously saved trim after audio and spectrogram are loaded.
  ///
  /// When a session with trim values is reopened, [_initAudio] loads the full
  /// recording.  This method clips the player and crops the spectrogram to
  /// match the persisted trim range so the user sees the trimmed state.
  Future<void> _restoreSavedTrim() async {
    if (_trimStartSec == null && _trimEndSec == null) return;

    final start = _trimStartSec ?? 0.0;
    final end = _trimEndSec ?? _fullDurationSec;

    final startDur = Duration(microseconds: (start * 1e6).round());
    final endDur = Duration(microseconds: (end * 1e6).round());
    final clippedDur = await _player.setClip(start: startDur, end: endDur);
    await _player.seek(Duration.zero);

    await _cropSpectrogramForClip(start, end);

    if (mounted) {
      setState(() {
        _clipOffsetSec = start;
        _duration = clippedDur ?? (endDur - startDur);
        _position = Duration.zero;
      });
    }
  }

  /// Attempt to reverse-geocode the session location.
  ///
  /// If the session already has a [locationName] (e.g. from a previous save),
  /// that value is reused.  Otherwise a network request via the Nominatim API
  /// is made and the result is persisted so future opens skip the request.
  Future<void> _resolveLocation() async {
    final lat = widget.session.latitude;
    final lon = widget.session.longitude;
    if (lat == null || lon == null) return;

    // Use cached name if already resolved.
    if (widget.session.locationName != null) {
      setState(() => _locationName = widget.session.locationName);
      return;
    }

    final name = await reverseGeocode(latitude: lat, longitude: lon);
    if (name != null && mounted) {
      setState(() => _locationName = name);
      // Persist so we don't re-fetch next time.
      widget.session.locationName = name;
      final repo = ref.read(sessionRepositoryProvider);
      await repo.save(widget.session);
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
        _fullSpectrogramImage?.dispose();
        _fullSpectrogramImage = image;
        _spectrogramImage = image;
      });
    } else {
      image.dispose();
    }
  }

  /// Crop the full spectrogram to the current clip range and update
  /// [_spectrogramImage].  Must be called whenever the clip changes.
  Future<void> _cropSpectrogramForClip(
    double startSec,
    double endSec,
  ) async {
    final src = _fullSpectrogramImage;
    if (src == null || _fullDurationSec <= 0) return;

    final startFrac = (startSec / _fullDurationSec).clamp(0.0, 1.0);
    final endFrac = (endSec / _fullDurationSec).clamp(0.0, 1.0);
    final srcStartX = (startFrac * src.width).round();
    final srcEndX = (endFrac * src.width).round();
    final cropWidth = srcEndX - srcStartX;
    if (cropWidth <= 0) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      src,
      Rect.fromLTRB(
        srcStartX.toDouble(),
        0,
        srcEndX.toDouble(),
        src.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, cropWidth.toDouble(), src.height.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(cropWidth, src.height);
    picture.dispose();

    if (mounted) {
      setState(() {
        if (_spectrogramImage != null &&
            !identical(_spectrogramImage, _fullSpectrogramImage)) {
          _spectrogramImage!.dispose();
        }
        _spectrogramImage = cropped;
      });
    } else {
      cropped.dispose();
    }
  }

  @override
  void dispose() {
    if (!identical(_spectrogramImage, _fullSpectrogramImage)) {
      _spectrogramImage?.dispose();
    }
    _fullSpectrogramImage?.dispose();
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
    widget.session.annotations
      ..clear()
      ..addAll(_annotations);
    widget.session.trimStartSec = _trimStartSec;
    widget.session.trimEndSec = _trimEndSec;
    final repo = ref.read(sessionRepositoryProvider);
    await repo.save(widget.session);
    ref.invalidate(sessionListProvider);
    setState(() {
      _isDirty = false;
      _undoStack.clear();
      _redoStack.clear();
    });
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

  // ── Add Species ───────────────────────────────────────────────────

  Future<void> _addSpecies() async {
    final positionSec = _position.inMicroseconds / 1000000.0;
    final result = await Navigator.of(context).push<_AddSpeciesResult>(
      MaterialPageRoute(
        builder: (_) => _AddSpeciesOverlay(
          sessionStart: widget.session.startTime,
          positionSec: positionSec,
          existingDetections: _detections,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == null || !mounted) return;

    _pushUndo();
    setState(() {
      switch (result.mode) {
        case _InsertMode.global:
          // Insert global detection — applies to the whole session.
          _detections.add(DetectionRecord(
            scientificName: result.scientificName,
            commonName: result.commonName,
            confidence: 1.0,
            timestamp: widget.session.startTime,
            source: DetectionSource.manualGlobal,
          ));
          break;

        case _InsertMode.atTimestamp:
          // Insert at the current playhead position.
          final ts = widget.session.startTime.add(_position);
          _detections.add(DetectionRecord(
            scientificName: result.scientificName,
            commonName: result.commonName,
            confidence: 1.0,
            timestamp: ts,
            source: DetectionSource.manual,
          ));
          break;

        case _InsertMode.replace:
          if (result.replaceRecord != null) {
            final idx = _detections.indexOf(result.replaceRecord!);
            if (idx != -1) {
              _detections[idx] = DetectionRecord(
                scientificName: result.scientificName,
                commonName: result.commonName,
                confidence: result.replaceRecord!.confidence,
                timestamp: result.replaceRecord!.timestamp,
                audioClipPath: result.replaceRecord!.audioClipPath,
                source: DetectionSource.manual,
              );
            }
          }
          break;
      }

      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _isDirty = true;
    });
  }

  // ── Annotations ───────────────────────────────────────────────────

  void _addAnnotation(SessionAnnotation annotation) {
    _pushUndo();
    setState(() {
      _annotations.add(annotation);
      _isDirty = true;
    });
  }

  void _deleteAnnotation(int index) {
    _pushUndo();
    setState(() {
      _annotations.removeAt(index);
      _isDirty = true;
    });
  }

  // ── Trim ──────────────────────────────────────────────────────────

  void _toggleTrimMode() {
    if (!_trimMode) {
      // Entering trim mode — remember the applied trim state so _applyTrim
      // can build an accurate undo snapshot.
      _preTrimStartSec = _trimStartSec;
      _preTrimEndSec = _trimEndSec;
    }
    setState(() => _trimMode = !_trimMode);
  }

  void _onTrimChanged(double startSec, double endSec) {
    _trimStartSec = startSec;
    _trimEndSec = endSec;
  }

  Future<void> _applyTrim() async {
    if (_trimStartSec == null && _trimEndSec == null) return;
    final start = _trimStartSec ?? 0.0;
    final end = _trimEndSec ?? _fullDurationSec;

    // Build undo snapshot with the state *before* trim mode was entered.
    // _trimStartSec/_trimEndSec now hold transient handle positions from
    // _onTrimChanged; the pre-trim values were saved by _toggleTrimMode.
    _undoStack.add(_ReviewSnapshot(
      detections: List.of(_detections),
      annotations: List.of(_annotations),
      trimStartSec: _preTrimStartSec,
      trimEndSec: _preTrimEndSec,
      clipOffsetSec: _clipOffsetSec,
    ));
    _redoStack.clear();

    setState(() {
      _detections.removeWhere((d) {
        final offsetSec =
            d.timestamp.difference(widget.session.startTime).inMicroseconds /
                1000000.0;
        return offsetSec < start || offsetSec > end;
      });
      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _isDirty = true;
      _trimMode = false;
    });

    // Clip the player to the trimmed range.
    final startDur = Duration(microseconds: (start * 1e6).round());
    final endDur = Duration(microseconds: (end * 1e6).round());
    final clippedDur = await _player.setClip(start: startDur, end: endDur);
    await _player.seek(Duration.zero);

    // Crop the spectrogram to the trimmed portion.
    await _cropSpectrogramForClip(start, end);

    if (mounted) {
      setState(() {
        _clipOffsetSec = start;
        _duration = clippedDur ?? (endDur - startDur);
        _position = Duration.zero;
      });
    }
  }

  Future<void> _resetTrim() async {
    _pushUndo();

    // Remove the player clip and restore the full recording.
    await _player.setClip();
    await _player.seek(Duration.zero);

    setState(() {
      _trimStartSec = null;
      _trimEndSec = null;
      _clipOffsetSec = 0.0;
      _duration = Duration(microseconds: (_fullDurationSec * 1e6).round());
      _position = Duration.zero;
      // Restore the full-recording spectrogram.
      if (_spectrogramImage != null &&
          !identical(_spectrogramImage, _fullSpectrogramImage)) {
        _spectrogramImage!.dispose();
      }
      _spectrogramImage = _fullSpectrogramImage;
      _isDirty = true;
      _trimMode = false;
    });
  }

  // ── Help ──────────────────────────────────────────────────────────

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SessionHelpSheet(),
    );
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

    _pushUndo();
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
    // Subtract the clip offset so the seek is relative to the clipped range.
    final clipOffset = Duration(microseconds: (_clipOffsetSec * 1e6).round());
    final seekPos = offset - clipOffset;
    if (seekPos.isNegative || seekPos > _duration) return;
    _player.seek(seekPos);
    if (!_isPlaying) _player.play();
  }

  void _seekToPosition(Duration position) {
    if (!_audioAvailable || _duration == Duration.zero) return;
    if (position.isNegative) position = Duration.zero;
    if (position > _duration) position = _duration;
    _player.seek(position);
    if (!_isPlaying) _player.play();
  }

  void _pausePlayer() {
    if (_isPlaying) _player.pause();
  }

  // ── Add Content Menu ──────────────────────────────────────────────

  Future<void> _showAddMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(l10n.sessionAddSpecies),
              onTap: () => Navigator.of(ctx).pop('species'),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: Text(l10n.sessionAddAnnotationOption),
              onTap: () => Navigator.of(ctx).pop('annotation'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || value == null) return;
    if (value == 'species') {
      _addSpecies();
    } else if (value == 'annotation') {
      _showAnnotationInput();
    }
  }

  void _showAnnotationInput() {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    var atTimestamp = false;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(l10n.sessionAddAnnotationOption),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: l10n.sessionAddAnnotation,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 5,
                  minLines: 2,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.public, size: 18),
                      label: Text(l10n.sessionAnnotationGlobal),
                      selected: !atTimestamp,
                      onSelected: (_) =>
                          setDialogState(() => atTimestamp = false),
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.schedule, size: 18),
                      label: Text(l10n.sessionInsertAtTimestamp),
                      selected: atTimestamp,
                      onSelected: (_) =>
                          setDialogState(() => atTimestamp = true),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                final positionSec = _position.inMicroseconds / 1000000.0;
                _addAnnotation(SessionAnnotation(
                  text: text,
                  createdAt: DateTime.now(),
                  offsetInRecording: atTimestamp ? positionSec : null,
                ));
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.sessionAddAnnotationOption),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _replaceDetection(_DetectionCluster cluster) async {
    final positionSec = _position.inMicroseconds / 1000000.0;
    final target = cluster.records.first;
    final result = await Navigator.of(context).push<_AddSpeciesResult>(
      MaterialPageRoute(
        builder: (_) => _AddSpeciesOverlay(
          sessionStart: widget.session.startTime,
          positionSec: positionSec,
          existingDetections: _detections,
          initialMode: _InsertMode.replace,
          initialReplaceTarget: target,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == null || !mounted) return;

    _pushUndo();
    setState(() {
      if (result.replaceRecord != null) {
        final idx = _detections.indexOf(result.replaceRecord!);
        if (idx != -1) {
          _detections[idx] = DetectionRecord(
            scientificName: result.scientificName,
            commonName: result.commonName,
            confidence: result.replaceRecord!.confidence,
            timestamp: result.replaceRecord!.timestamp,
            audioClipPath: result.replaceRecord!.audioClipPath,
            source: DetectionSource.manual,
          );
        }
      }
      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _isDirty = true;
    });
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
            _sessionReviewTitle(l10n, widget.session),
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
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: l10n.settings,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Toolbar ─────────────────────────────────────
            Container(
              color: theme.colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: l10n.sessionAddContent,
                    onPressed: _showAddMenu,
                  ),
                  IconButton(
                    icon: Icon(Icons.undo,
                        color: _canUndo
                            ? null
                            : theme.colorScheme.onSurface.withAlpha(80)),
                    tooltip: l10n.sessionUndo,
                    onPressed: _canUndo ? _undo : null,
                  ),
                  IconButton(
                    icon: Icon(Icons.redo,
                        color: _canRedo
                            ? null
                            : theme.colorScheme.onSurface.withAlpha(80)),
                    tooltip: l10n.sessionRedo,
                    onPressed: _canRedo ? _redo : null,
                  ),
                  if (_audioAvailable)
                    IconButton(
                      icon: Icon(
                        _trimMode
                            ? Icons.content_cut
                            : Icons.content_cut_outlined,
                      ),
                      tooltip: l10n.sessionTrimRecording,
                      onPressed: _toggleTrimMode,
                      color: _trimMode ? theme.colorScheme.primary : null,
                    ),
                  IconButton(
                    icon: Icon(Icons.save,
                        color: _isDirty
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withAlpha(80)),
                    tooltip: l10n.sessionSave,
                    onPressed: _isDirty ? _save : null,
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
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    tooltip: l10n.sessionHelpTitle,
                    onPressed: _showHelp,
                  ),
                ],
              ),
            ),

            // ── Summary header ──────────────────────────────
            _SummaryHeader(
              session: widget.session,
              detectionCount: _detections.length,
              locationName: _locationName,
              onShowMap: widget.session.latitude != null
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SessionMapScreen(
                            latitude: widget.session.latitude!,
                            longitude: widget.session.longitude!,
                            locationName: _locationName,
                          ),
                        ),
                      )
                  : null,
            ),

            // ── Spectrogram ─────────────────────────────────
            if (_audioAvailable) ...[
              if (_trimMode &&
                  (_fullSpectrogramImage ?? _spectrogramImage) != null)
                _TrimSpectrogramView(
                  spectrogramImage:
                      (_fullSpectrogramImage ?? _spectrogramImage)!,
                  durationSec: _fullDurationSec > 0
                      ? _fullDurationSec
                      : _duration.inMicroseconds / 1000000.0,
                  initialStartSec: _trimStartSec ?? 0.0,
                  initialEndSec: _trimEndSec ??
                      (_fullDurationSec > 0
                          ? _fullDurationSec
                          : _duration.inMicroseconds / 1000000.0),
                  onChanged: _onTrimChanged,
                )
              else
                Stack(
                  children: [
                    _SpectrogramStrip(
                      spectrogramImage: _spectrogramImage,
                      decoding: _decoding,
                      position: _position,
                      duration: _duration,
                      onSeek: _seekToPosition,
                      onPause: _pausePlayer,
                      isPlaying: _isPlaying,
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _PlayPauseButton(
                        isPlaying: _isPlaying,
                        onToggle: () {
                          if (_isPlaying) {
                            _player.pause();
                          } else {
                            _player.play();
                          }
                        },
                      ),
                    ),
                  ],
                ),
            ],

            // ── Trim confirm bar ────────────────────────────
            if (_trimMode)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      l10n.sessionTrimRecording,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _resetTrim,
                      child: Text(l10n.sessionTrimReset),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: _applyTrim,
                      child: Text(l10n.sessionTrimApply),
                    ),
                  ],
                ),
              ),

            // ── Annotation chips ────────────────────────────
            if (_annotations.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < _annotations.length; i++)
                      Chip(
                        label: Text(
                          _annotations[i].text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        avatar: Icon(
                          _annotations[i].offsetInRecording != null
                              ? Icons.schedule
                              : Icons.public,
                          size: 16,
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _deleteAnnotation(i),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
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
                          onReplaceCluster: _replaceDetection,
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
    final clipOffset = Duration(microseconds: (_clipOffsetSec * 1e6).round());
    for (final r in group.allRecords) {
      final offset = r.timestamp.difference(widget.session.startTime);
      // Map the absolute offset into clip-relative coordinates.
      final rel = offset - clipOffset;
      final detEnd = rel + Duration(seconds: windowSec);
      if (_position >= rel && _position <= detEnd) return true;
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

/// Returns a localized display label for the given [SessionType].
String _sessionTypeLabel(AppLocalizations l10n, SessionType type) {
  switch (type) {
    case SessionType.live:
      return l10n.sessionTypeLive;
    case SessionType.fileUpload:
      return l10n.sessionTypeFileUpload;
    case SessionType.pointCount:
      return l10n.sessionTypePointCount;
    case SessionType.survey:
      return l10n.sessionTypeSurvey;
  }
}

/// Returns a numbered review-screen title such as "Live Session #3 Review".
///
/// Falls back to just the un-numbered type label when [session.sessionNumber]
/// is `null` (legacy sessions).
String _sessionReviewTitle(AppLocalizations l10n, LiveSession session) {
  final n = session.sessionNumber;
  if (n == null) return _sessionTypeLabel(l10n, session.type);
  switch (session.type) {
    case SessionType.live:
      return l10n.sessionTitleLiveNum(n);
    case SessionType.fileUpload:
      return l10n.sessionTitleFileUploadNum(n);
    case SessionType.pointCount:
      return l10n.sessionTitlePointCountNum(n);
    case SessionType.survey:
      return l10n.sessionTitleSurveyNum(n);
  }
}
