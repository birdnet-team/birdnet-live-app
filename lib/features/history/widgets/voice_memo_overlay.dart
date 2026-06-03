// =============================================================================
// voice_memo_overlay.dart — Per-detection voice-memo recorder dialog
// =============================================================================
//
// Purpose:
//   Lets a reviewer record (or re-record) a short spoken note that gets
//   attached to a single [DetectionRecord]. The memo file lives next to the
//   session's other audio under `<appDir>/recordings/<sessionId>/memos/`,
//   and its absolute path is persisted on `DetectionRecord.voiceMemoPath`
//   so it survives JSON round-trips and is included in ZIP exports.
//
// Why a dialog (rather than an inline overlay):
//   The recorder needs an exclusive mic — the live capture pipeline must
//   already be torn down by the time Session Review opens, but we still
//   want a clear modal context so the user knows recording is active.
//   `showDialog` gives us a barrier-dismissible modal that auto-disposes
//   the recorder when popped via the back gesture.
//
// Recording format:
//   iOS uses WAV/PCM16 (.wav) because the `record_ios` AAC path can
//   produce header-only files on some iPhone / iOS combinations in this
//   app's audio-session mix. Other platforms keep AAC-LC in an MP4
//   container (.m4a). Both are 16 kHz mono, which is more than enough
//   fidelity for spoken commentary while staying small enough for ZIP
//   exports.
//
// UI design:
//   The dialog has a single transport area that switches between three
//   mutually exclusive states — idle / recording / has-memo — so there is
//   never more than one play-or-record affordance competing for the same
//   tap. During recording we poll `getAmplitude()` ourselves at ~16 Hz
//   (the platform's `onAmplitudeChanged` stream throttles to ~1 Hz on
//   Android, which produced visible stutter) and render a live bar
//   waveform that grows from the right. A `SingleTickerProvider`-driven
//   `AnimationController` runs every frame and tweens the just-pushed
//   bar from 0 → its captured amplitude, so even between polls the
//   right edge keeps moving smoothly instead of snapping. The captured
//   samples are reused as the static waveform during playback, with a
//   left-to-right progress fill driven by the AudioPlayer's position
//   stream. A subtle "Re-record" outlined button below the player lets
//   the user replace the take without involving the big mic button again.
//
// Permission handling:
//   Live and Survey modes already prompt for mic permission at startup.
//   File-Analysis sessions never touch the mic, so this is the first
//   point where the permission may need to be requested. We rely on the
//   `record` package's own `hasPermission()` which surfaces the system
//   permission dialog on first call.
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:birdnet_live/shared/utils/app_icons.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../l10n/app_localizations.dart';

/// Result returned to the caller when the dialog is dismissed.
///
/// `null` means the user closed the dialog without changing anything
/// (e.g. tapped outside or pressed the back button without saving).
class VoiceMemoResult {
  VoiceMemoResult({this.savedPath, this.deleted = false});

  /// Path to the newly-recorded memo file. `null` when no recording
  /// was made (or the user chose to delete an existing memo — see
  /// [deleted]).
  final String? savedPath;

  /// True when the user explicitly deleted an existing memo.
  /// In that case [savedPath] is `null` and the caller should clear
  /// `voiceMemoPath` on the detection.
  final bool deleted;
}

/// Opens the voice-memo recorder dialog for [sessionId].
///
/// [existingMemoPath] is the current `voiceMemoPath` (if any). When
/// supplied, the dialog opens in playback mode and shows a "Replace"
/// option; otherwise it opens directly in record mode.
Future<VoiceMemoResult?> showVoiceMemoDialog({
  required BuildContext context,
  required String sessionId,
  String? existingMemoPath,
}) {
  return showDialog<VoiceMemoResult>(
    context: context,
    builder:
        (ctx) => _VoiceMemoDialog(
          sessionId: sessionId,
          existingMemoPath: existingMemoPath,
        ),
  );
}

class _VoiceMemoDialog extends StatefulWidget {
  const _VoiceMemoDialog({required this.sessionId, this.existingMemoPath});

  final String sessionId;
  final String? existingMemoPath;

  @override
  State<_VoiceMemoDialog> createState() => _VoiceMemoDialogState();
}

class _VoiceMemoDialogState extends State<_VoiceMemoDialog>
    with SingleTickerProviderStateMixin {
  late final AudioRecorder _recorder = AudioRecorder();
  late final AudioPlayer _player = AudioPlayer();
  Timer? _elapsedTimer;
  Timer? _ampTimer;
  late final AnimationController _waveAnim;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  Duration _elapsed = Duration.zero;
  Duration _playPosition = Duration.zero;
  Duration _playDuration = Duration.zero;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _loadedPlayerPath;
  String? _pendingPath; // freshly-recorded but not yet committed
  String? _committedExistingPath; // the original memo if any
  String? _errorMessage;

  /// Normalized amplitude history (0..1) captured during recording.
  /// Reused as the static waveform during playback so the user gets a
  /// visual reference of what they recorded. New samples are appended at
  /// the end; we trim to [_kMaxWaveBars] to keep the painter cheap.
  final List<double> _waveform = <double>[];
  static const int _kMaxWaveBars = 64;

  /// The amplitude target the right-most bar is tweening toward, plus
  /// the value it tweens *from*. The painter mixes them with
  /// `_waveAnim.value` so the live edge eases into each new sample
  /// instead of popping. Updated every poll in [_startRecording].
  double _ampFrom = 0.0;
  double _ampTo = 0.0;

  @override
  void initState() {
    super.initState();
    _committedExistingPath = widget.existingMemoPath;
    _waveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _playerStateSub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      final playing =
          s.playing && s.processingState != ProcessingState.completed;
      if (s.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
        if (_isPlaying) setState(() => _isPlaying = false);
      } else if (playing != _isPlaying) {
        setState(() => _isPlaying = playing);
      }
    });
    _posSub = _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _playPosition = pos);
    });
    _durSub = _player.durationStream.listen((d) {
      if (!mounted || d == null) return;
      setState(() => _playDuration = d);
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _ampTimer?.cancel();
    _waveAnim.dispose();
    _posSub?.cancel();
    _durSub?.cancel();
    _playerStateSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    // If the user opened the dialog, recorded something, then closed it
    // without tapping Save, drop the orphan file so we don't litter the
    // session directory.
    final pending = _pendingPath;
    if (pending != null) {
      // Best-effort cleanup; ignore errors (file may have been moved).
      // ignore: discarded_futures
      File(pending).delete().catchError((_) => File(pending));
    }
    super.dispose();
  }

  Future<String> _newMemoPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(appDir.path, 'recordings', widget.sessionId, 'memos'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, 'memo_$stamp.$_memoFileExtension');
  }

  String get _memoFileExtension => Platform.isIOS ? 'wav' : 'm4a';

  RecordConfig get _recordConfig {
    if (Platform.isIOS) {
      return const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );
    }
    return const RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 64000,
    );
  }

  Future<void> _startRecording() async {
    setState(() => _errorMessage = null);
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        setState(() {
          _errorMessage =
              AppLocalizations.of(
                context,
              )!.detectionVoiceMemoMicPermissionDenied;
        });
        return;
      }

      // Stop playback if it's running so the mic isn't competing.
      if (_player.playing) {
        await _player.stop();
      }
      _loadedPlayerPath = null;

      final path = await _newMemoPath();
      await _recorder.start(_recordConfig, path: path);

      _elapsed = Duration.zero;
      _waveform.clear();
      _ampFrom = 0.0;
      _ampTo = 0.0;
      _playPosition = Duration.zero;
      _playDuration = Duration.zero;
      _elapsedTimer?.cancel();
      _elapsedTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => setState(() => _elapsed += const Duration(milliseconds: 250)),
      );
      // Poll amplitude ourselves at ~16 Hz. The platform's
      // `onAmplitudeChanged` stream throttles aggressively (Android can
      // be as slow as 1 Hz), which makes the live waveform look like
      // it's stuttering. Manual polling gives consistent ~62 ms ticks.
      _ampTimer?.cancel();
      _ampTimer = Timer.periodic(const Duration(milliseconds: 62), (_) async {
        if (!mounted || !_isRecording) return;
        try {
          final amp = await _recorder.getAmplitude();
          if (!mounted) return;
          // `current` is dBFS (≤ 0). -50 dB ≈ quiet speech, 0 dB = full
          // scale. Map [-50, 0] dB → [0, 1] so bars feel responsive
          // without pinning at the top, and apply a light low-pass to
          // dampen single-sample spikes.
          final db = amp.current.isFinite ? amp.current : -60.0;
          final normalized = ((db + 50.0) / 50.0).clamp(0.0, 1.0);
          final smoothed =
              _waveform.isEmpty
                  ? normalized
                  : _waveform.last * 0.35 + normalized * 0.65;
          setState(() {
            _waveform.add(smoothed);
            if (_waveform.length > _kMaxWaveBars) {
              _waveform.removeAt(0);
            }
            _ampFrom = _ampTo;
            _ampTo = smoothed;
          });
          // Restart the per-sample tween so the painter eases the
          // freshest bar into its new height over the poll interval.
          _waveAnim.forward(from: 0);
        } catch (_) {
          // Best-effort: skip this tick if the recorder is mid-state.
        }
      });

      setState(() {
        _isRecording = true;
        _pendingPath = path;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _stopRecording() async {
    _elapsedTimer?.cancel();
    _ampTimer?.cancel();
    _ampTimer = null;
    _waveAnim.stop();
    String? stoppedPath;
    try {
      stoppedPath = await _recorder.stop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _errorMessage = e.toString();
      });
      return;
    }
    if (!mounted) return;

    final resolvedPath = (stoppedPath != null && stoppedPath.isNotEmpty)
        ? stoppedPath
        : _pendingPath;
    if (resolvedPath == null) {
      setState(() {
        _isRecording = false;
        _errorMessage = AppLocalizations.of(context)!.statusError;
      });
      return;
    }

    final recordedFile = File(resolvedPath);
    final exists = await recordedFile.exists();
    final size = exists ? await recordedFile.length() : 0;
    if (!exists || size <= 0) {
      if (exists) {
        // ignore: discarded_futures
        recordedFile.delete().catchError((_) => recordedFile);
      }
      setState(() {
        _isRecording = false;
        _pendingPath = null;
        _errorMessage = AppLocalizations.of(context)!.statusError;
      });
      return;
    }

    _pendingPath = resolvedPath;

    // Pre-load the freshly-recorded file into the player so the play
    // affordance lights up with an accurate duration.
    await _ensurePlayerLoaded(resolvedPath);
    if (!mounted) return;
    setState(() => _isRecording = false);
  }

  Future<void> _togglePlay() async {
    final path = _pendingPath ?? _committedExistingPath;
    if (path == null) return;
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    try {
      // Lazy-load by path: duration can stay non-null from a previous
      // source, so comparing against duration causes stale-source bugs.
      if (_loadedPlayerPath != path) {
        final ok = await _ensurePlayerLoaded(path);
        if (!ok) {
          if (mounted) {
            setState(() => _errorMessage = 'Cannot open voice memo file.');
          }
          return;
        }
      }
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  Future<bool> _ensurePlayerLoaded(String path) async {
    try {
      await _player.setFilePath(path);
      _loadedPlayerPath = path;
      return true;
    } catch (_) {
      // iOS can briefly report "Cannot open" right after recorder stop
      // while the container headers are still being finalized.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      try {
        await _player.setFilePath(path);
        _loadedPlayerPath = path;
        return true;
      } catch (_) {
        _loadedPlayerPath = null;
        return false;
      }
    }
  }

  void _save() {
    if (_pendingPath == null) {
      // Nothing changed.
      Navigator.of(context).pop();
      return;
    }
    // Commit: delete the previous memo file (if any) so we don't orphan it.
    final old = _committedExistingPath;
    final committed = _pendingPath!;
    _pendingPath = null; // prevent dispose() from cleaning it up
    if (old != null && old != committed) {
      // ignore: discarded_futures
      File(old).delete().catchError((_) => File(old));
    }
    Navigator.of(context).pop(VoiceMemoResult(savedPath: committed));
  }

  void _delete() {
    final old = _committedExistingPath;
    if (old != null) {
      // ignore: discarded_futures
      File(old).delete().catchError((_) => File(old));
    }
    Navigator.of(context).pop(VoiceMemoResult(deleted: true));
  }

  String _fmtDuration(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasExisting = _committedExistingPath != null && _pendingPath == null;
    final hasPending = _pendingPath != null;
    final hasMemo = hasExisting || hasPending;

    // Decide what the "transport" area shows. Three mutually exclusive
    // states keep the dialog free of competing affordances:
    //
    //  • Empty       → big record CTA (no memo yet, no recording).
    //  • Recording   → live waveform + stop button + elapsed counter.
    //  • Has memo    → compact player row (play/pause + waveform with
    //                  progress fill + position/duration), plus a quiet
    //                  "Re-record" outlined button below.
    Widget transport;
    if (_isRecording) {
      transport = _buildRecordingTransport(theme, l10n);
    } else if (hasMemo) {
      transport = _buildPlayerTransport(theme, l10n);
    } else {
      transport = _buildIdleTransport(theme, l10n);
    }

    return AlertDialog(
      title: Text(l10n.detectionVoiceMemoDialogTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            transport,
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (hasExisting && !hasPending)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.detectionDeleteVoiceMemo),
          ),
        TextButton(
          onPressed: _isRecording ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: (_isRecording || !hasPending) ? null : _save,
          child: Text(l10n.sessionSave),
        ),
      ],
    );
  }

  /// No memo yet, not recording — single big mic CTA.
  Widget _buildIdleTransport(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _RecordButton(isRecording: false, onTap: _startRecording),
        const SizedBox(height: 14),
        Text(
          l10n.detectionVoiceMemoHint,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          l10n.detectionVoiceMemoTapToRecord,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Recording in progress — live waveform plus stop button.
  Widget _buildRecordingTransport(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        const SizedBox(height: 4),
        SizedBox(
          height: 56,
          child: AnimatedBuilder(
            animation: _waveAnim,
            builder: (_, _) {
              // Tween the freshest bar from its previous height to the
              // newly-captured one over the poll interval, so the right
              // edge keeps moving every frame instead of holding for
              // ~62 ms and then snapping.
              final t = _waveAnim.value;
              final liveTail = _ampFrom + (_ampTo - _ampFrom) * t;
              return _Waveform(
                samples: _waveform,
                liveTail: liveTail,
                progress: 1.0, // every captured bar is "live"
                color: theme.colorScheme.error,
                inactiveColor: theme.colorScheme.error.withAlpha(60),
                growFromEnd: true,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _fmtDuration(_elapsed),
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 12),
        _RecordButton(isRecording: true, onTap: _stopRecording),
        const SizedBox(height: 8),
        Text(
          l10n.detectionVoiceMemoTapToStop,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// A memo exists — compact media-player row plus discreet re-record.
  Widget _buildPlayerTransport(ThemeData theme, AppLocalizations l10n) {
    final dur = _playDuration > Duration.zero ? _playDuration : _elapsed;
    final pos = _playPosition;
    final progress =
        dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton.filled(
              icon: Icon(_isPlaying ? AppIcons.pause : AppIcons.playArrow),
              tooltip: l10n.detectionVoiceMemoTooltip,
              onPressed: _togglePlay,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 44,
                child: _Waveform(
                  samples: _waveform,
                  progress: progress,
                  color: theme.colorScheme.primary,
                  inactiveColor: theme.colorScheme.primary.withAlpha(60),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 60, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmtDuration(pos),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _fmtDuration(dur),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: _startRecording,
            icon: const Icon(AppIcons.fiberManualRecord, size: 16),
            label: Text(l10n.detectionReplaceVoiceMemo),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Big circular record / stop button used in idle and recording states.
///
/// Pulled out so the two transport layouts share the exact same affordance
/// (size, color treatment, hit area), instead of duplicating the
/// `Container + GestureDetector` recipe inline.
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.isRecording, required this.onTap});

  final bool isRecording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: isRecording ? l10n.a11yLiveCaptureStop : l10n.a11yLiveCaptureStart,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isRecording
                    ? theme.colorScheme.error
                    : theme.colorScheme.primaryContainer,
            boxShadow:
                isRecording
                    ? [
                      BoxShadow(
                        color: theme.colorScheme.error.withAlpha(80),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                    : null,
          ),
          child: Icon(
            isRecording ? AppIcons.stop : AppIcons.mic,
            size: 40,
            color:
                isRecording
                    ? theme.colorScheme.onError
                    : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Bar-style waveform with a left-to-right progress fill.
///
/// During recording, [growFromEnd] makes the freshest bars appear on the
/// right edge so the user sees the live response. During playback, all
/// captured bars are shown statically and [progress] (0..1) controls how
/// many are drawn in the active color.
///
/// When [samples] is empty (e.g. an existing memo loaded from disk with no
/// in-memory amplitude history) the painter renders a flat decorative
/// pattern so the player row never collapses to zero height.
class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.samples,
    required this.progress,
    required this.color,
    required this.inactiveColor,
    this.growFromEnd = false,
    this.liveTail,
  });

  final List<double> samples;
  final double progress;
  final Color color;
  final Color inactiveColor;
  final bool growFromEnd;

  /// When non-null, the painter draws an extra trailing bar at the right
  /// edge with this height. Used during recording to provide a smoothly
  /// animated "live" indicator between amplitude polls.
  final double? liveTail;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaveformPainter(
        samples: samples,
        progress: progress,
        color: color,
        inactiveColor: inactiveColor,
        growFromEnd: growFromEnd,
        liveTail: liveTail,
      ),
      size: Size.infinite,
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.samples,
    required this.progress,
    required this.color,
    required this.inactiveColor,
    required this.growFromEnd,
    this.liveTail,
  });

  final List<double> samples;
  final double progress;
  final Color color;
  final Color inactiveColor;
  final bool growFromEnd;
  final double? liveTail;

  static const int _kBarCount = 48;
  static const double _kBarGap = 2.0;
  static const double _kMinBarHeight = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = _kBarCount;
    final totalGap = _kBarGap * (barCount - 1);
    final barWidth = (size.width - totalGap) / barCount;
    final centerY = size.height / 2;
    final maxBarHeight = size.height;

    // Build the bar-height array. If we have real samples, fit them onto
    // the painter's bar count by either down-sampling (recording: keep
    // the most recent), or by stretching across the full width (playback).
    final heights = List<double>.filled(barCount, 0);
    if (samples.isEmpty) {
      // Decorative idle pattern so the row never looks empty.
      for (int i = 0; i < barCount; i++) {
        final t = i / (barCount - 1);
        heights[i] = 0.15 + 0.10 * math.sin(t * math.pi * 4);
      }
    } else if (growFromEnd) {
      // Recording: pin samples to the right edge, oldest fade left.
      final n = samples.length.clamp(0, barCount);
      for (int i = 0; i < n; i++) {
        final srcIdx = samples.length - n + i;
        heights[barCount - n + i] = samples[srcIdx];
      }
      // Override the right-most bar with the live tween value so the
      // edge keeps moving between amplitude polls.
      if (liveTail != null) {
        heights[barCount - 1] = liveTail!.clamp(0.0, 1.0);
      }
    } else {
      // Playback: stretch the captured samples across all bars.
      for (int i = 0; i < barCount; i++) {
        final srcIdx = (i * samples.length / barCount).floor().clamp(
          0,
          samples.length - 1,
        );
        heights[i] = samples[srcIdx];
      }
    }

    final activePaint = Paint()..color = color;
    final inactivePaint = Paint()..color = inactiveColor;
    final fillCutoff = progress * barCount;

    for (int i = 0; i < barCount; i++) {
      final h = (heights[i].clamp(0.0, 1.0) * maxBarHeight).clamp(
        _kMinBarHeight,
        maxBarHeight,
      );
      final x = i * (barWidth + _kBarGap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - h / 2, barWidth, h),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, i < fillCutoff ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) {
    return old.progress != progress ||
        old.color != color ||
        old.inactiveColor != inactiveColor ||
        old.growFromEnd != growFromEnd ||
        old.liveTail != liveTail ||
        !identical(old.samples, samples) ||
        old.samples.length != samples.length;
  }
}
