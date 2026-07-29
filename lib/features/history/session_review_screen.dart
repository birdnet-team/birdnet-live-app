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
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:audio_session/audio_session.dart';
import 'package:fftea/fftea.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/scheduler.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/score_colors.dart';
import '../../shared/models/gps_point.dart';
import '../../shared/models/taxonomy_species.dart';
import '../../shared/models/weather_snapshot.dart';
import '../../shared/services/weather_service.dart';
import '../../shared/providers/settings_providers.dart';
import '../../shared/services/taxonomy_service.dart';
import '../../shared/services/link_launcher.dart';
import '../../shared/utils/app_icons.dart';
import '../../shared/utils/timestamp_format.dart';
import '../../shared/utils/weather_format.dart';
import '../../shared/widgets/app_help_bottom_sheet.dart';
import '../../shared/widgets/confirm_destructive.dart';
import '../../shared/widgets/stat_chip.dart';
import '../explore/explore_providers.dart';
import '../explore/widgets/species_info_overlay.dart';
import '../live/live_providers.dart';
import '../live/live_session.dart';
import '../recording/audio_decoder.dart';
import '../recording/native_audio_decoder.dart';
import '../recording/playback_normalizer.dart';
import '../spectrogram/color_maps.dart';
import '../spectrogram/spectrogram_widget.dart';
import 'export_metadata_helper.dart';
import 'session_export.dart';
import 'session_map_screen.dart';
import 'services/share_file_params.dart';
import 'widgets/clip_player_sheet.dart';
import 'widgets/detection_actions.dart';
import 'widgets/voice_memo_overlay.dart';
import '../settings/settings_screen.dart';
import '../survey/survey_live_screen.dart';
import '../survey/widgets/survey_map_widget.dart';
import '../../core/services/reverse_geocoding_service.dart';
import 'services/detection_sharing_service.dart';
import 'services/session_audio_trim.dart';

part 'widgets/session_review_widgets.dart';

/// Sort modes for the species list on the Session Review screen.
///
/// Persisted via [PrefKeys.sessionReviewSpeciesSort] (stored as
/// `name`). [confidence] is the default so review starts with the most
/// likely identifications. [firstSeen] stays available for users who want
/// the historical behavior.
enum SpeciesSortMode { alphabetical, count, confidence, firstSeen }

/// Compare Session Review detections for confidence-focused review order.
///
/// Used for expanded detection clusters when [SpeciesSortMode.confidence] is
/// active: clip-backed detections are most useful for review, then higher
/// confidence, then earlier time for deterministic ties.
int compareSessionReviewConfidenceSortEntries({
  required bool aHasAudioClip,
  required double aConfidence,
  required DateTime aTimestamp,
  required bool bHasAudioClip,
  required double bConfidence,
  required DateTime bTimestamp,
}) {
  if (aHasAudioClip != bHasAudioClip) return aHasAudioClip ? -1 : 1;

  final confidence = bConfidence.compareTo(aConfidence);
  if (confidence != 0) return confidence;

  return aTimestamp.compareTo(bTimestamp);
}

List<DetectionRecord> buildSessionReviewPlaybackOrder({
  required List<DetectionRecord> detections,
  required int maxGapSec,
  required SpeciesSortMode sortMode,
  required String Function(String scientificName, String fallbackCommonName)
  localizedCommonName,
  required bool Function(DetectionRecord detection) hasPlayableClip,
}) {
  final groups = _SessionReviewScreenState._buildSpeciesGroups(
    detections,
    maxGapSec,
  );
  final orderedGroups = _orderSessionReviewSpeciesGroups(
    groups: groups,
    sortMode: sortMode,
    localizedCommonName:
        (group) => localizedCommonName(group.scientificName, group.commonName),
    hasPlayableClip: hasPlayableClip,
  );

  return [
    for (final group in orderedGroups)
      for (final cluster in group.clusters)
        for (final record in cluster.records)
          if (hasPlayableClip(record)) record,
  ];
}

List<_SpeciesGroup> _orderSessionReviewSpeciesGroups({
  required Iterable<_SpeciesGroup> groups,
  required SpeciesSortMode sortMode,
  required String Function(_SpeciesGroup group) localizedCommonName,
  required bool Function(DetectionRecord detection) hasPlayableClip,
}) {
  final sorted = List<_SpeciesGroup>.of(groups);
  switch (sortMode) {
    case SpeciesSortMode.alphabetical:
      sorted.sort(
        (a, b) => localizedCommonName(
          a,
        ).toLowerCase().compareTo(localizedCommonName(b).toLowerCase()),
      );
      break;
    case SpeciesSortMode.count:
      sorted.sort((a, b) {
        final c = b.totalCount.compareTo(a.totalCount);
        if (c != 0) return c;
        return localizedCommonName(
          a,
        ).toLowerCase().compareTo(localizedCommonName(b).toLowerCase());
      });
      break;
    case SpeciesSortMode.confidence:
      sorted.sort((a, b) {
        final c = b.bestConfidence.compareTo(a.bestConfidence);
        if (c != 0) return c;
        return localizedCommonName(
          a,
        ).toLowerCase().compareTo(localizedCommonName(b).toLowerCase());
      });
      break;
    case SpeciesSortMode.firstSeen:
      sorted.sort((a, b) => a.firstTimestamp.compareTo(b.firstTimestamp));
      break;
  }

  return [
    for (final group in sorted)
      _orderSessionReviewSpeciesGroupClusters(
        group: group,
        sortMode: sortMode,
        hasPlayableClip: hasPlayableClip,
      ),
  ];
}

_SpeciesGroup _orderSessionReviewSpeciesGroupClusters({
  required _SpeciesGroup group,
  required SpeciesSortMode sortMode,
  required bool Function(DetectionRecord detection) hasPlayableClip,
}) {
  if (sortMode != SpeciesSortMode.confidence) return group;
  final clusters = List<_DetectionCluster>.of(group.clusters)..sort(
    (a, b) => compareSessionReviewConfidenceSortEntries(
      aHasAudioClip: a.records.any(hasPlayableClip),
      aConfidence: a.bestConfidence,
      aTimestamp: a.firstTimestamp,
      bHasAudioClip: b.records.any(hasPlayableClip),
      bConfidence: b.bestConfidence,
      bTimestamp: b.firstTimestamp,
    ),
  );
  return _SpeciesGroup(
    scientificName: group.scientificName,
    commonName: group.commonName,
    clusters: clusters,
  );
}

class _ReviewWarningCard extends StatelessWidget {
  const _ReviewWarningCard({
    required this.icon,
    required this.title,
    required this.body,
    this.onDismiss,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final showTitle = title.isNotEmpty;
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: theme.colorScheme.onErrorContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showTitle) ...[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
            if (onDismiss != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(AppIcons.close, size: 20),
                color: theme.colorScheme.onErrorContainer,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: l10n.tooltipClose,
                onPressed: onDismiss,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpectrogramChunk {
  const _SpectrogramChunk({
    required this.startSec,
    required this.endSec,
    required this.image,
    required this.hop,
  });

  final double startSec;
  final double endSec;
  final ui.Image image;
  final int hop;

  void dispose() => image.dispose();
}

/// Shortest clip the trim editor will produce. Anything below this is treated
/// as an accidental pinch of the handles and leaves the recording untrimmed,
/// which keeps us from writing a zero-length export or a `setClip` range the
/// platform players reject.
const double _kMinTrimSeconds = 0.25;

// ─────────────────────────────────────────────────────────────────────────────
// Background spectrogram-chunk rendering
// ─────────────────────────────────────────────────────────────────────────────
//
// Decoding an hour-long FLAC and running a STFT over 30 s at a time is far
// too heavy for the UI isolate — on a Pixel 10 Pro it skipped >120 frames
// per chunk during pinch-zoom. We move the decode + FFT loop into a
// background isolate via `Isolate.run` and only hand the finished RGBA
// buffer back to the UI isolate, which then calls
// `ui.decodeImageFromPixels` (cheap, asynchronous).

class _SpectrogramChunkRequest {
  const _SpectrogramChunkRequest({
    required this.path,
    required this.sourceSampleRate,
    required this.rawPcm16,
    required this.startSample,
    required this.count,
    required this.targetSampleRate,
    required this.fftSize,
    required this.hop,
    required this.maxDisplayBins,
    required this.colorMapName,
  });

  final String path;
  final int sourceSampleRate;
  final bool rawPcm16;
  final int startSample;
  final int count;
  final int targetSampleRate;

  /// FFT window size. Larger → finer frequency resolution, slower.
  final int fftSize;

  /// Hop between FFT columns in samples. Larger → fewer columns,
  /// faster, less time detail.
  final int hop;

  /// Hard cap on rendered frequency bins. Anything above what the strip
  /// can actually show as a pixel is wasted work, so we keep this near
  /// the spectrogram strip's physical pixel height.
  final int maxDisplayBins;

  /// Palette used to render spectrogram intensity.
  final String colorMapName;
}

class _SpectrogramChunkPixels {
  const _SpectrogramChunkPixels({
    required this.pixels,
    required this.width,
    required this.height,
  });

  final Uint8List pixels;
  final int width;
  final int height;
}

Future<_SpectrogramChunkPixels?> _decodeAndRenderSpectrogramChunk(
  _SpectrogramChunkRequest req,
) async {
  final DecodedAudio audio;
  if (req.rawPcm16) {
    audio = await _decodePcm16Range(
      req.path,
      sampleRate: req.sourceSampleRate,
      startSample: req.startSample,
      count: req.count,
    );
  } else if (await AudioDecoder.canDecodeDart(req.path)) {
    audio = await AudioDecoder.decodeRange(
      req.path,
      startSample: req.startSample,
      count: req.count,
    );
  } else {
    audio = await NativeAudioDecoder.decodeRange(
      req.path,
      startSample: req.startSample,
      count: req.count,
    );
  }
  final resampled = audio.resampleTo(req.targetSampleRate);
  return _renderSpectrogramChunkPixels(
    resampled,
    fftSize: req.fftSize,
    hop: req.hop,
    maxDisplayBins: req.maxDisplayBins,
    colorMapName: req.colorMapName,
  );
}

Future<DecodedAudio> _decodePcm16Range(
  String path, {
  required int sampleRate,
  required int startSample,
  required int count,
}) async {
  final file = File(path);
  final fileLength = await file.length();
  final totalSamples = fileLength ~/ 2;
  final safeStart = startSample.clamp(0, totalSamples);
  final safeEnd = (startSample + count).clamp(0, totalSamples);
  final bytesToRead = math.max(0, safeEnd - safeStart) * 2;
  final output = Int16List(count);
  if (bytesToRead <= 0) {
    return DecodedAudio(samples: output, sampleRate: sampleRate);
  }

  final raf = await file.open();
  try {
    await raf.setPosition(safeStart * 2);
    final bytes = await raf.read(bytesToRead);
    final byteData = ByteData.sublistView(bytes);
    final sampleOffset = safeStart - startSample;
    for (var i = 0; i < bytes.length ~/ 2; i++) {
      output[sampleOffset + i] = byteData.getInt16(i * 2, Endian.little);
    }
  } finally {
    await raf.close();
  }

  return DecodedAudio(samples: output, sampleRate: sampleRate);
}

_SpectrogramChunkPixels? _renderSpectrogramChunkPixels(
  DecodedAudio audio, {
  required int fftSize,
  required int hop,
  required int maxDisplayBins,
  required String colorMapName,
}) {
  const maxFreqHz = 16000;
  const dbFloor = -80.0;
  const dbCeiling = 0.0;

  if (audio.totalSamples < fftSize) return null;

  final numCols = (audio.totalSamples - fftSize) ~/ hop + 1;
  if (numCols <= 0) return null;

  final nyquist = audio.sampleRate / 2;
  final binCount = fftSize ~/ 2 + 1;
  final visibleBins = (maxFreqHz / nyquist * binCount).round().clamp(
    1,
    binCount,
  );
  // Down-sample bins when there are more frequency rows than the
  // spectrogram strip can paint as distinct pixels. Each output row
  // averages `binStride` adjacent FFT bins, giving a smoother (and much
  // cheaper) look on phone-sized strips.
  final binStride = math.max(1, (visibleBins / maxDisplayBins).ceil());
  final displayBins = (visibleBins / binStride).ceil();

  final lut = SpectrogramColorMap.lut(colorMapName);
  final pixels = Uint8List(numCols * displayBins * 4);

  final hann = Float64List(fftSize);
  final hannFactor = 2.0 * math.pi / fftSize;
  for (var i = 0; i < fftSize; i++) {
    hann[i] = 0.5 * (1.0 - math.cos(hannFactor * i));
  }
  final fft = FFT(fftSize);

  for (var c = 0; c < numCols; c++) {
    final colSample = c * hop;
    final chunk = audio.readFloat32(colSample, fftSize);
    final input = Float64List(fftSize);
    for (var i = 0; i < fftSize; i++) {
      input[i] = chunk[i] * hann[i];
    }
    final spectrum = fft.realFft(input);

    for (var row = 0; row < displayBins; row++) {
      final binStart = row * binStride;
      final binEnd = math.min(binStart + binStride, visibleBins);
      var power = 0.0;
      for (var bin = binStart; bin < binEnd; bin++) {
        final re = spectrum[bin].x;
        final im = spectrum[bin].y;
        power += re * re + im * im;
      }
      power /= (binEnd - binStart);
      final db = 10 * math.log(power + 1e-10) / math.ln10;
      final norm = ((db - dbFloor) / (dbCeiling - dbFloor)).clamp(0.0, 1.0);

      final y = displayBins - 1 - row;
      final pxOffset = (y * numCols + c) * 4;
      final lutIdx = (norm * 255).round().clamp(0, 255);
      final color = lut[lutIdx];
      pixels[pxOffset] = (color >> 16) & 0xFF;
      pixels[pxOffset + 1] = (color >> 8) & 0xFF;
      pixels[pxOffset + 2] = color & 0xFF;
      pixels[pxOffset + 3] = (color >> 24) & 0xFF;
    }
  }

  return _SpectrogramChunkPixels(
    pixels: pixels,
    width: numCols,
    height: displayBins,
  );
}

/// Run the FLAC→WAV transcode in a fresh background isolate.
///
/// Lives at top level on purpose: when the closure passed to
/// [Isolate.run] is constructed inside a `State` method, Dart's
/// isolate-send serializer pulls the entire enclosing closure context
/// along, which transitively reaches `this._player` (a just_audio
/// [AudioPlayer]) and the rxdart `BehaviorSubject` it holds — and
/// `BehaviorSubject` is not sendable, so the spawn fails with
/// "object is unsendable". By keeping this wrapper top-level, the
/// closure only captures the two `String` parameters.
/// Run the spectrogram chunk decode+render in a fresh background isolate.
///
/// Top-level closures constructed inside a `State` method capture `this`,
/// which pulls in just_audio's [AudioPlayer] → rxdart `BehaviorSubject`
/// (unsendable) and aborts the spawn with "object is unsendable".
Future<_SpectrogramChunkPixels?> _runSpectrogramChunkIsolate(
  _SpectrogramChunkRequest request,
) {
  final token = RootIsolateToken.instance;
  return Isolate.run(() {
    if (token != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    }
    return _decodeAndRenderSpectrogramChunk(request);
  });
}

class _SpectrogramImageResult {
  const _SpectrogramImageResult({required this.image, required this.stride});

  final ui.Image image;
  final int stride;
}

class _VoiceMemoPlaybackEvent {
  const _VoiceMemoPlaybackEvent({
    required this.key,
    required this.path,
    required this.triggerSec,
  });

  final String key;
  final String path;
  final double triggerSec;
}

/// Review screen displayed after a live session ends.
class SessionReviewScreen extends ConsumerStatefulWidget {
  const SessionReviewScreen({
    super.key,
    required this.session,
    this.autoSaved = true,
  });

  /// The completed session to review.
  final LiveSession session;

  /// Whether the session was already persisted to the library before this
  /// screen opened. Reopening an existing session (library, file analysis,
  /// ARU, survey) always passes `true`.
  ///
  /// When `false` — the user disabled *Save sessions automatically* and just
  /// finished a Live / Point Count session — the session is treated as
  /// **unsaved**: the save icon is highlighted, best-effort metadata writes
  /// (location / weather) are held back, and leaving review without saving
  /// deletes the session and its recordings. See [_isUnsaved].
  final bool autoSaved;

  @override
  ConsumerState<SessionReviewScreen> createState() =>
      _SessionReviewScreenState();
}

class _SessionReviewScreenState extends ConsumerState<SessionReviewScreen> {
  static const double _memoTriggerGraceSec = 0.75;

  // ── State ───────────────────────────────────────────────────────────

  late List<DetectionRecord> _detections;
  late List<SessionAnnotation> _annotations;
  late List<_SpeciesGroup> _speciesGroups;
  bool _groupsBuilding = false;
  final Set<String> _expandedSpecies = {};
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _clipPlayer = AudioPlayer();

  /// Secondary player for auto-playing voice memos *on top of* the main
  /// recording. It must not touch the shared audio session: disabling
  /// session activation and interruption handling keeps it from requesting
  /// (or releasing) audio focus, so it mixes with [_player] instead of
  /// pausing it. The main player owns the active session while playing.
  final AudioPlayer _memoAutoPlayer = AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: false,
  );
  final Set<String> _autoPlayedMemoKeys = {};
  double? _lastMemoCheckPositionSec;
  double? _mainVolumeBeforeMemoOverlay;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<PlayerState>? _clipPlayerStateSubscription;
  StreamSubscription<PlayerState>? _memoAutoPlayerStateSubscription;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(
    Duration.zero,
  );
  Duration get _position => _positionNotifier.value;
  double get _currentSourcePositionSec =>
      _clipOffsetSec + _position.inMicroseconds / 1000000.0;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _audioAvailable = false;

  /// Cluster currently being played via [_clipPlayer] (survey mode
  /// without a full recording). Used to highlight the active row and
  /// route taps on it to a pause action.
  _DetectionCluster? _activeClipCluster;

  /// When set, playback automatically pauses once [_position] reaches
  /// this value. Set by [_seekToCluster] so a single-cluster playback
  /// stops at the end of the detection's continuous-detection window.
  /// Cleared on any other player interaction (manual play/pause, drag,
  /// tap-to-seek, completion).
  Duration? _autoStopPosition;
  bool _isDirty = false;

  /// True when this session has never been written to the library yet (the
  /// user disabled automatic saving). Unlike [_isDirty] — which tracks
  /// *edits* to an already-saved session — an unsaved session has no
  /// persisted copy to fall back to, so discarding it deletes the recordings
  /// outright. Set once from `widget.autoSaved` in [initState]; cleared by
  /// [_save].
  bool _isUnsaved = false;

  /// Whether there is work that would be lost on leaving without saving:
  /// either pending edits ([_isDirty]) or a never-saved session
  /// ([_isUnsaved]). Drives the save-icon highlight and the leave prompt.
  bool get _hasUnsavedWork => _isDirty || _isUnsaved;

  bool _trimMode = false;

  /// The *applied* trim, in original-recording seconds. These are the values
  /// that drive the player clip, the spectrogram crop and what [_save]
  /// persists. Null means the whole recording.
  double? _trimStartSec;
  double? _trimEndSec;

  /// Set once [commitSessionTrim] reports the recording's container cannot
  /// be cut. The trim stays valid as a playback/export range, but saving is
  /// no longer destructive — so stop warning about deleted audio and stop
  /// retrying the cut on every save. Reopening the session tries again.
  bool _trimCommitUnsupported = false;

  /// Live handle positions while the trim editor is open.
  ///
  /// Kept separate from [_trimStartSec]/[_trimEndSec] so dragging a handle
  /// can never leak into a save, an undo snapshot or an export: the pending
  /// values are only promoted by [_applyTrim] and are discarded when the
  /// user leaves trim mode without confirming.
  double? _pendingTrimStartSec;
  double? _pendingTrimEndSec;

  // ── Clip state (after trim is applied) ─────────────────────────────

  /// Offset in original-recording seconds of the clip start (0 = no clip).
  double _clipOffsetSec = 0.0;

  /// True while the player is clipped to a trim range.
  ///
  /// Set *before* every `setClip` call and cleared *before* every clip
  /// removal, because just_audio pushes the new (clipped) length through
  /// `durationStream` while `setClip` is still awaiting. Without this flag
  /// that event would overwrite [_fullDurationSec] with the clip length —
  /// which silently breaks the spectrogram crop, the trim editor and the
  /// undo path, since every one of them maps absolute recording seconds
  /// through the full duration.
  bool _clipActive = false;

  /// The clip range currently installed on the player, in original-recording
  /// seconds. Null when the player is playing the whole recording. Used to
  /// make [_syncPlayerClip] idempotent so undo/redo don't reload the source
  /// (and reset playback) when the clip didn't actually change.
  ({double start, double end})? _appliedClipRange;

  /// Full recording duration before any clip was applied.
  double _fullDurationSec = 0.0;

  /// Length of the untrimmed recording in seconds.
  ///
  /// Prefers the player's reported duration and falls back to the decoded
  /// audio metadata — `just_audio_windows` can report a null duration from
  /// `setFilePath()` and only publish it later via `durationStream`.
  double get _sourceDurationSec {
    if (_fullDurationSec > 0) return _fullDurationSec;
    final metadata = _spectrogramAudioMetadata;
    if (metadata != null) {
      return metadata.duration.inMicroseconds / 1e6;
    }
    return 0.0;
  }

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

  /// Whether the screen is still doing its one-shot startup work
  /// (loading audio metadata, decoding the spectrogram, restoring trim).
  /// Drives the thin LinearProgressIndicator under the AppBar so users
  /// of large sessions get visible feedback that the screen isn't frozen.
  bool _initializing = true;

  /// True when the audio file ends materially before the session/detections.
  bool _audioTruncatedWarning = false;

  /// True if the user dismissed the audio truncated warning.
  bool _audioTruncatedWarningDismissed = false;

  /// True when long-session spectrogram detail is decoded on demand.
  bool _spectrogramLazy = false;

  /// Most recent visible window reported by `_SpectrogramStrip` via
  /// `onViewportChanged`. Used in lazy mode to (a) anchor trim-handle
  /// defaults when the user enters trim mode and (b) bound trim drags
  /// to the visible window, since we can't show handles outside what's
  /// painted on screen.
  double? _lastViewportCenterSec;
  double? _lastViewportViewSec;
  bool _spectrogramViewportLoadQueued = false;

  /// Source path/metadata for range-decoded spectrogram chunks.
  String? _spectrogramAudioPath;
  AudioMetadata? _spectrogramAudioMetadata;
  String? _spectrogramTempPcmPath;
  bool _spectrogramAudioIsRawPcm16 = false;

  /// Detailed spectrogram chunks keyed by absolute recording seconds.
  final List<_SpectrogramChunk> _spectrogramChunks = [];
  final Set<int> _loadingSpectrogramChunkIndexes = {};
  int _spectrogramGeneration = 0;
  int? _lastLoadedTargetHop;
  double? _lastLoadedChunkSeconds;

  bool get _canUndo => _undoStack.isNotEmpty;
  bool get _canRedo => _redoStack.isNotEmpty;
  double get _memoDucking =>
      ref.read(playbackVoiceMemoDuckingProvider).clamp(0.0, 0.95).toDouble();

  /// Cached reverse-geocoded location name for display.
  String? _locationName;

  /// Detection highlighted on the map (set by tapping a species/cluster).
  DetectionRecord? _highlightedDetection;

  /// Current visible map bounds (updated by camera move callback).
  /// When non-null, the species list is filtered to only show detections
  /// within these bounds.
  LatLngBounds? _visibleMapBounds;

  /// Free-text species filter. Matches case-insensitive substrings of
  /// the localized common name and the scientific name. Empty string
  /// = no filtering.
  String _speciesSearchQuery = '';
  final TextEditingController _speciesSearchController =
      TextEditingController();

  /// Active sort mode for the species list. Loaded asynchronously in
  /// [initState]; defaults to [SpeciesSortMode.confidence] so review starts
  /// with the most likely identifications.
  SpeciesSortMode _speciesSort = SpeciesSortMode.confidence;

  _ReviewSnapshot _takeSnapshot() => _ReviewSnapshot(
    detections: List.of(_detections),
    annotations: List.of(_annotations),
    trimStartSec: _trimStartSec,
    trimEndSec: _trimEndSec,
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
    unawaited(_syncPlayerClip());
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
    unawaited(_syncPlayerClip());
  }

  /// Normalizes a pair of trim handles into a usable clip range.
  ///
  /// Returns null when the pair doesn't describe a clip worth applying:
  /// no trim set, an unknown recording length, or a range that collapsed
  /// to (near) nothing after clamping. Callers treat null as "play the
  /// whole recording".
  ({double start, double end})? _resolveTrimRange(
    double? startSec,
    double? endSec,
  ) {
    if (startSec == null && endSec == null) return null;
    final total = _sourceDurationSec;
    if (total <= 0) return null;
    final start = (startSec ?? 0.0).clamp(0.0, total).toDouble();
    final end = (endSec ?? total).clamp(0.0, total).toDouble();
    if (end - start < _kMinTrimSeconds) return null;
    // A range covering the whole recording is not a trim.
    if (start <= 0 && end >= total) return null;
    return (start: start, end: end);
  }

  /// Re-synchronizes the player clip and the spectrogram with the current
  /// [_trimStartSec] / [_trimEndSec] values.
  ///
  /// This is the single place that talks to `setClip`, so applying a trim,
  /// resetting it, reopening a trimmed session and undo/redo all converge
  /// on the same state. It is a no-op when the resulting range already
  /// matches what the player is playing.
  Future<void> _syncPlayerClip() async {
    final hasTrim = _trimStartSec != null || _trimEndSec != null;
    // The recording length isn't known yet (just_audio_windows publishes it
    // asynchronously). Leave the player alone rather than clipping against
    // a zero duration — the trim values survive and are applied once the
    // duration arrives.
    if (hasTrim && _sourceDurationSec <= 0) return;

    final range = _resolveTrimRange(_trimStartSec, _trimEndSec);
    if (range == null) {
      if (_appliedClipRange == null) return; // Already unclipped.
      _appliedClipRange = null;
      _clipActive = false;
      await _player.setClip();
      await _player.seek(Duration.zero);
      _resetMemoAutoPlayback();
      if (!mounted) return;
      setState(() {
        _clipOffsetSec = 0.0;
        _duration = Duration(microseconds: (_sourceDurationSec * 1e6).round());
        if (_spectrogramImage != null &&
            !identical(_spectrogramImage, _fullSpectrogramImage)) {
          _spectrogramImage!.dispose();
        }
        _spectrogramImage = _fullSpectrogramImage;
      });
      _positionNotifier.value = Duration.zero;
      // The strip's own didUpdateWidget will fire a viewport request
      // for the actual visible window once the duration/clip changes
      // propagate; just make sure any stale lazy state (pending chunk
      // reservations or a stuck `_decoding=true`) is reset so that
      // follow-up request can succeed instead of being short-circuited.
      _invalidateLazySpectrogramPipeline();
      return;
    }

    final applied = _appliedClipRange;
    if (applied != null &&
        (applied.start - range.start).abs() < 0.001 &&
        (applied.end - range.end).abs() < 0.001) {
      // Already clipped to this exact range — but the spectrogram may have
      // been rebuilt underneath us (a color-map or quality change re-decodes
      // it and hands back the *uncropped* image), so re-crop in that case.
      if (_spectrogramImage == null ||
          identical(_spectrogramImage, _fullSpectrogramImage)) {
        await _cropSpectrogramForClip(range.start, range.end);
      }
      return;
    }

    // Mark the clip active *before* awaiting setClip: just_audio pushes the
    // clipped length through durationStream while this call is in flight.
    _appliedClipRange = range;
    _clipActive = true;
    final startDur = Duration(microseconds: (range.start * 1e6).round());
    final endDur = Duration(microseconds: (range.end * 1e6).round());
    final clippedDur = await _player.setClip(start: startDur, end: endDur);
    await _player.seek(Duration.zero);
    _resetMemoAutoPlayback();
    await _cropSpectrogramForClip(range.start, range.end);
    if (!mounted) return;
    setState(() {
      _clipOffsetSec = range.start;
      _duration = clippedDur ?? (endDur - startDur);
    });
    _positionNotifier.value = Duration.zero;
    // Drop any in-flight lazy chunk loads from the previous viewport so the
    // strip's follow-up request for the new clip range can schedule freshly
    // instead of getting stuck behind a stale `_decoding = true` flag.
    _invalidateLazySpectrogramPipeline();
  }

  /// Reset transient lazy-spectrogram bookkeeping after a clip change
  /// (apply trim / undo / redo). Bumps the generation counter so any
  /// in-flight chunk loads from the previous clip drop their results,
  /// clears the pending reservation set, and forces the spinner off if
  /// nothing is actually loading anymore.
  void _invalidateLazySpectrogramPipeline() {
    if (!_spectrogramLazy) return;
    _spectrogramGeneration++;
    _loadingSpectrogramChunkIndexes.clear();
    if (_decoding) {
      setState(() => _decoding = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _isUnsaved = !widget.autoSaved;
    _detections = List.of(widget.session.detections);
    _annotations = List.of(widget.session.annotations);
    _trimStartSec = widget.session.trimStartSec;
    _trimEndSec = widget.session.trimEndSec;
    _speciesGroups = const [];
    _groupsBuilding = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final groups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      if (mounted) {
        setState(() {
          _speciesGroups = groups;
          _groupsBuilding = false;
        });
      }
    });
    _initAudio();
    _resolveLocation();
    _resolveWeather();
    _loadSpeciesSort();
    _loadDismissedWarningState();
    _memoAutoPlayerStateSubscription = _memoAutoPlayer.playerStateStream.listen(
      (state) {
        if (!state.playing ||
            state.processingState == ProcessingState.completed) {
          unawaited(_restoreMainVolumeAfterMemoOverlay());
        }
      },
    );
  }

  Future<void> _loadDismissedWarningState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'dismissed_audio_warning_${widget.session.id}';
    if (prefs.getBool(key) == true) {
      if (mounted) {
        setState(() {
          _audioTruncatedWarningDismissed = true;
        });
      }
    }
  }

  Future<void> _dismissAudioWarning() async {
    setState(() {
      _audioTruncatedWarningDismissed = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dismissed_audio_warning_${widget.session.id}', true);
    } catch (_) {}
  }

  Future<void> _loadSpeciesSort() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(PrefKeys.sessionReviewSpeciesSort);
    if (stored == null || !mounted) return;
    final mode = SpeciesSortMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => SpeciesSortMode.confidence,
    );
    if (mode != _speciesSort) {
      setState(() => _speciesSort = mode);
    }
  }

  Future<void> _setSpeciesSort(SpeciesSortMode mode) async {
    if (mode == _speciesSort) return;
    setState(() => _speciesSort = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.sessionReviewSpeciesSort, mode.name);
  }

  Future<void> _initAudio() async {
    // Re-entrant: a destructive trim reloads the recording in place, and the
    // stream listeners below are re-registered each time, so drop the previous
    // ones instead of stacking a second set on the same player.
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _durationSubscription?.cancel();
    _durationSubscription = null;
    await _playerStateSubscription?.cancel();
    _playerStateSubscription = null;

    final path = widget.session.recordingPath;
    if (path == null || !File(path).existsSync()) {
      if (mounted) setState(() => _initializing = false);
      return;
    }

    try {
      await _configureSessionReviewAudioSession();
      final playbackPath = await PlaybackNormalizer.resolveSource(path);
      if (!mounted) return;
      final dur = await _player.setFilePath(playbackPath);
      if (!mounted) return;
      setState(() {
        _duration = dur ?? Duration.zero;
        _fullDurationSec = _duration.inMicroseconds / 1e6;
        _audioAvailable = true;
      });

      // just_audio_windows doesn't reliably resolve the duration from
      // setFilePath() itself — it can come back null/zero and only arrive
      // later via durationStream once the Media Foundation backend finishes
      // loading metadata. Without this, _duration (and therefore
      // _fullDurationSec) stays 0 forever, which makes the spectrogram
      // painter bail out on its `durationSec <= 0` guard even though the
      // spectrogram image itself decoded fine.
      _durationSubscription = _player.durationStream.listen((newDuration) {
        if (!mounted || newDuration == null || newDuration <= Duration.zero) {
          return;
        }
        if (newDuration == _duration) return;
        setState(() {
          _duration = newDuration;
          // While a trim clip is active the reported duration is the
          // *clip* length, not the recording length — see [_clipActive].
          if (!_clipActive) {
            _fullDurationSec = _duration.inMicroseconds / 1e6;
          }
        });
        // A saved trim that arrived before the recording length did was
        // deferred by [_syncPlayerClip]; now that we know the length, apply
        // it — otherwise reopening a trimmed session on Windows would play
        // back untrimmed.
        if (!_clipActive &&
            _appliedClipRange == null &&
            (_trimStartSec != null || _trimEndSec != null)) {
          unawaited(_syncPlayerClip());
        }
      });

      await _inspectAudioIntegrity(path);

      _positionSubscription = _player.positionStream.listen((pos) {
        if (!mounted) return;
        final stopAt = _autoStopPosition;
        if (stopAt != null && pos >= stopAt) {
          _autoStopPosition = null;
          _player.pause();
          // Snap to the exact stop position so the playhead doesn't
          // visually overshoot the end of the cluster.
          _player.seek(stopAt);
          _positionNotifier.value = stopAt;
          return;
        }

        _checkAndPlayVoiceMemos(pos);
        _positionNotifier.value = pos;
      });
      _playerStateSubscription = _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
          if (state.processingState == ProcessingState.completed) {
            _player.pause();
            _player.seek(Duration.zero);
            _resetMemoAutoPlayback();
          }
        }
      });

      // Decode audio for spectrogram, then restore saved trim if present.
      await _decodeAudioForSpectrogram(path);
      await _restoreSavedTrim();
    } catch (e, st) {
      // Audio not available — review still works without playback.
      debugPrint('[SessionReview] _initAudio failed for $path: $e\n$st');
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _configureSessionReviewAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers |
              AVAudioSessionCategoryOptions.allowBluetoothA2dp |
              AVAudioSessionCategoryOptions.allowAirPlay,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
              AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );
    } catch (_) {
      // Playback still works with the platform default; we just may not get
      // reliable overlay mixing on every device.
    }
  }

  Future<void> _refreshSpectrogramForColorMap() async {
    final path = widget.session.recordingPath;
    if (path == null || !File(path).existsSync() || _decoding) return;

    await _decodeAudioForSpectrogram(path);
    await _restoreSavedTrim();
  }

  Future<void> _inspectAudioIntegrity(String path) async {
    try {
      final canDart = await AudioDecoder.canDecodeDart(path);
      final metadata =
          canDart
              ? await AudioDecoder.inspectFile(path)
              : await NativeAudioDecoder.inspectFile(
                path,
                _formatLabelForPath(path),
              );
      final audioSec = metadata.duration.inMicroseconds / 1e6;
      final expectedSec = widget.session.expectedRecordedAudioSeconds;
      final isTruncated = expectedSec > 0 && audioSec + 5 < expectedSec;
      if (mounted && isTruncated != _audioTruncatedWarning) {
        setState(() => _audioTruncatedWarning = isTruncated);
      }
    } catch (_) {
      // Integrity diagnostics should never block review playback.
    }
  }

  String _formatLabelForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) return 'MP3';
    if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'OGG';
    if (lower.endsWith('.opus')) return 'OPUS';
    if (lower.endsWith('.m4a') || lower.endsWith('.aac')) return 'AAC';
    if (lower.endsWith('.mp4')) return 'AAC';
    if (lower.endsWith('.wma')) return 'WMA';
    if (lower.endsWith('.amr')) return 'AMR';
    return 'AUDIO';
  }

  /// Re-apply a previously saved trim after audio and spectrogram are loaded.
  ///
  /// When a session with trim values is reopened, [_initAudio] loads the full
  /// recording.  This clips the player and crops the spectrogram to match the
  /// persisted trim range so the user sees the trimmed state.
  Future<void> _restoreSavedTrim() async {
    if (_trimStartSec == null && _trimEndSec == null) return;
    await _syncPlayerClip();
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
      // Keep the resolved name in memory so a later explicit save includes it.
      widget.session.locationName = name;
      // Don't silently persist a session the user hasn't chosen to keep yet;
      // it would be saved on their explicit Save instead.
      if (!_isUnsaved) {
        final repo = ref.read(sessionRepositoryProvider);
        await repo.save(widget.session);
      }
    }
  }

  /// Attempt to retrieve a weather snapshot for the session location.
  ///
  /// Mirrors [_resolveLocation]: if the session already has weather data
  /// (captured at session-end or by the setup wizard), keep it untouched.
  /// Otherwise — typically because the original capture failed (no
  /// consent at the time, no internet, Open-Meteo unreachable) — try
  /// once more now that the user has explicitly opened the review.
  /// [WeatherService.fetch] honors the privacy gate and the persistent
  /// 6 h cache, so this is cheap to call repeatedly. Successful results
  /// are persisted so the next open is a no-op.
  Future<void> _resolveWeather() async {
    if (widget.session.weather != null) return;
    final lat = widget.session.latitude;
    final lon = widget.session.longitude;
    if (lat == null || lon == null) return;

    try {
      final svc = ref.read(weatherServiceProvider);
      final snap = await svc.fetch(
        latitude: lat,
        longitude: lon,
        observedAt: widget.session.endTime ?? DateTime.now(),
      );
      if (snap != null && mounted) {
        setState(() {
          // No dedicated state field — _SummaryHeader reads
          // widget.session.weather directly, so updating the model
          // and triggering rebuild is enough.
        });
        widget.session.weather = snap;
        // As with location, hold back persistence for a not-yet-saved session.
        if (!_isUnsaved) {
          final repo = ref.read(sessionRepositoryProvider);
          await repo.save(widget.session);
        }
      }
    } catch (_) {
      // Best-effort retry — silently give up; we'll try again next open.
    }
  }

  Future<void> _decodeAudioForSpectrogram(String path) async {
    final generation = ++_spectrogramGeneration;
    setState(() => _decoding = true);
    try {
      final canDart = await AudioDecoder.canDecodeDart(path);
      final metadata =
          canDart
              ? await AudioDecoder.inspectFile(path)
              : await NativeAudioDecoder.inspectFile(
                path,
                _formatLabelForPath(path),
              );
      // Native-decoded formats (MP3, OGG, AAC, etc.) always lazy-load the
      // spectrogram, but first stream the compressed file to a temporary PCM
      // cache. Per-tile compressed seeks are not sample-exact enough for MP3
      // and can create visible gaps; PCM ranges behave like the FLAC path.
      // Dart-decodable formats (WAV/FLAC) keep the 128 MB threshold since
      // their range-decode is essentially free (direct byte reads).
      final shouldLazyLoad =
          !canDart || metadata.decodedPcmBytes >= 128 * 1024 * 1024;
      var sourcePath = path;
      var sourceMetadata = metadata;
      var sourceIsRawPcm16 = false;

      if (shouldLazyLoad && !canDart) {
        final decoded = await NativeAudioDecoder.decodeToTempPcmFile(path);
        if (!mounted) {
          try {
            final file = File(decoded.pcmPath);
            if (file.existsSync()) file.deleteSync();
          } catch (_) {}
          return;
        }
        sourcePath = decoded.pcmPath;
        sourceMetadata = AudioMetadata(
          sampleRate: decoded.sampleRate,
          totalSamples: decoded.totalSamples,
          format: '${metadata.format} PCM',
        );
        sourceIsRawPcm16 = true;
      }

      if (mounted) {
        setState(() {
          _clearSpectrogramChunks();
          _deleteSpectrogramTempPcm();
          _spectrogramAudioPath = sourcePath;
          _spectrogramAudioMetadata = sourceMetadata;
          _spectrogramAudioIsRawPcm16 = sourceIsRawPcm16;
          _spectrogramTempPcmPath = sourceIsRawPcm16 ? sourcePath : null;
          _spectrogramLazy = shouldLazyLoad;
          if (_spectrogramImage != null &&
              !identical(_spectrogramImage, _fullSpectrogramImage)) {
            _spectrogramImage!.dispose();
          }
          _spectrogramImage = null;
          _fullSpectrogramImage?.dispose();
          _fullSpectrogramImage = null;
        });
      }

      if (shouldLazyLoad) {
        final totalSec = sourceMetadata.duration.inMicroseconds / 1000000.0;
        final userPref = ref.read(spectrogramDurationProvider).toDouble();
        final bootstrapView =
            totalSec <= 0
                ? userPref
                : totalSec <= 300.0
                ? math.min(userPref, totalSec)
                : (totalSec * 0.1).clamp(userPref, 60.0).toDouble();
        await _ensureSpectrogramForViewport(
          absoluteCenterSec: bootstrapView / 2,
          viewSeconds: bootstrapView,
          generation: generation,
        );
        return;
      }

      // Use pure-Dart decoder for WAV/FLAC, native for compressed formats.
      DecodedAudio audio;
      if (canDart) {
        audio = await AudioDecoder.decodeFile(path);
      } else {
        audio = await NativeAudioDecoder.decodeFile(path);
      }
      if (!mounted) return;
      // Resample to model sample rate so spectrogram matches inference.
      audio = audio.resampleTo(AppConstants.sampleRate);
      final result = await _computeSpectrogramImage(audio);
      if (!mounted || generation != _spectrogramGeneration) {
        result?.image.dispose();
        return;
      }
      if (result == null) return;
      setState(() {
        _fullSpectrogramImage?.dispose();
        _fullSpectrogramImage = result.image;
        _spectrogramImage = result.image;
      });
    } catch (e, st) {
      // Spectrogram unavailable — non-fatal.
      // ignore: avoid_print
      print('[spec] _decodeAudioForSpectrogram failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _decoding = false);
    }
  }

  /// Compute a spectrogram [ui.Image] for a decoded audio buffer.
  ///
  /// Uses a fixed FFT size and hop.  Each pixel column = one FFT frame.
  /// The painter scrolls through the image using pixels-per-second.
  Future<_SpectrogramImageResult?> _computeSpectrogramImage(
    DecodedAudio audio, {
    int maxColumns = 6000,
  }) async {
    final String quality = ref.read(spectrogramQualityProvider);
    int maxDisplayBins;
    int hop;

    switch (quality.toLowerCase()) {
      case 'low':
        maxDisplayBins = 128;
        hop = 2048;
        break;
      case 'medium':
        maxDisplayBins = 256;
        hop = 1024;
        break;
      case 'high':
      default:
        maxDisplayBins = 512;
        hop = 512;
        break;
    }

    const fftSize = 2048;
    const maxFreqHz = 16000;
    const dbFloor = -80.0;
    const dbCeiling = 0.0;

    if (audio.totalSamples < fftSize) return null;

    final rawCols = (audio.totalSamples - fftSize) ~/ hop + 1;
    final stride = math.max(1, (rawCols / maxColumns).ceil());
    final effectiveHop = hop * stride;
    final numCols = (audio.totalSamples - fftSize) ~/ effectiveHop + 1;
    if (numCols <= 0) return null;

    final nyquist = audio.sampleRate / 2;
    final binCount = fftSize ~/ 2 + 1;
    final visibleBins = (maxFreqHz / nyquist * binCount).round().clamp(
      1,
      binCount,
    );
    final binStride = (visibleBins / maxDisplayBins).ceil().clamp(
      1,
      visibleBins,
    );
    final displayBins = (visibleBins / binStride).ceil();

    final lut = SpectrogramColorMap.lut(ref.read(colorMapProvider));
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
        if (!mounted) return null;
      }

      final colSample = c * effectiveHop;
      final chunk = audio.readFloat32(colSample, fftSize);
      final input = Float64List(fftSize);
      for (var i = 0; i < fftSize; i++) {
        input[i] = chunk[i] * hann[i];
      }
      final spectrum = fft.realFft(input);

      for (var row = 0; row < displayBins; row++) {
        final binStart = row * binStride;
        final binEnd = (binStart + binStride).clamp(0, visibleBins);
        var power = 0.0;
        for (var bin = binStart; bin < binEnd; bin++) {
          final re = spectrum[bin].x;
          final im = spectrum[bin].y;
          power += re * re + im * im;
        }
        power /= (binEnd - binStart);
        final db = 10 * math.log(power + 1e-10) / math.ln10;
        final norm = ((db - dbFloor) / (dbCeiling - dbFloor)).clamp(0.0, 1.0);

        final y = displayBins - 1 - row;
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
    return _SpectrogramImageResult(image: image, stride: stride);
  }

  void _clearSpectrogramChunks() {
    for (final chunk in _spectrogramChunks) {
      chunk.dispose();
    }
    _spectrogramChunks.clear();
    _loadingSpectrogramChunkIndexes.clear();
  }

  void _deleteSpectrogramTempPcm() {
    final path = _spectrogramTempPcmPath;
    _spectrogramTempPcmPath = null;
    _spectrogramAudioIsRawPcm16 = false;
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Best-effort cleanup of a temporary spectrogram cache.
    }
  }

  void _requestSpectrogramViewport(
    double absoluteCenterSec,
    double viewSeconds,
  ) {
    // Remember the strip's current visible window even when we're not
    // lazy-loading: trim-mode initialization reads it to default the
    // handles to whatever the user is currently looking at.
    _lastViewportCenterSec = absoluteCenterSec;
    _lastViewportViewSec = viewSeconds;
    if (!_spectrogramLazy) return;
    if (_spectrogramViewportLoadQueued) return;
    _spectrogramViewportLoadQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _spectrogramViewportLoadQueued = false;
      if (!mounted || !_spectrogramLazy) return;
      final center = _lastViewportCenterSec;
      final view = _lastViewportViewSec;
      if (center == null || view == null) return;
      unawaited(
        _ensureSpectrogramForViewport(
          absoluteCenterSec: center,
          viewSeconds: view,
          generation: _spectrogramGeneration,
        ),
      );
    });
  }

  Future<void> _ensureSpectrogramForViewport({
    required double absoluteCenterSec,
    required double viewSeconds,
    required int generation,
  }) async {
    final metadata = _spectrogramAudioMetadata;
    final durationSec = metadata?.duration.inMicroseconds ?? 0;
    if (!_spectrogramLazy || metadata == null || durationSec <= 0) return;

    final totalSec = durationSec / 1000000.0;
    // Define zoom levels, dynamic chunk seconds, hop multipliers, and cache sizes.
    final double chunkSeconds;
    final int hopMultiplier;
    final int maxCachedChunks;
    if (viewSeconds <= 20.0) {
      chunkSeconds = 30.0;
      hopMultiplier = 1;
      maxCachedChunks = 16;
    } else if (viewSeconds <= 60.0) {
      chunkSeconds = 120.0;
      hopMultiplier = 4;
      maxCachedChunks = 16;
    } else {
      chunkSeconds = 480.0;
      hopMultiplier = 16;
      maxCachedChunks = 16;
    }

    final padding = math.min(math.max(5.0, viewSeconds * 0.25), chunkSeconds);
    final startSec = (absoluteCenterSec - viewSeconds / 2 - padding).clamp(
      0.0,
      totalSec,
    );
    final endSec = (absoluteCenterSec + viewSeconds / 2 + padding).clamp(
      0.0,
      totalSec,
    );
    final firstIndex = (startSec / chunkSeconds).floor();
    final lastIndex = math.max(
      firstIndex,
      ((endSec - 0.000001) / chunkSeconds).floor(),
    );

    // Determine the base hop to compute target hop
    final String quality = ref.read(spectrogramQualityProvider);
    final long = totalSec > 600.0;
    int baseHop;
    switch (quality.toLowerCase()) {
      case 'low':
        baseHop = long ? 3072 : 2048;
        break;
      case 'medium':
        baseHop = long ? 2048 : 1024;
        break;
      case 'high':
      default:
        baseHop = long ? 1024 : 512;
        break;
    }
    final targetHop = baseHop * hopMultiplier;

    // Clear pending load indexes when transition between zoom levels occurs.
    var activeGeneration = generation;
    if (_lastLoadedTargetHop != targetHop ||
        _lastLoadedChunkSeconds != chunkSeconds) {
      _lastLoadedTargetHop = targetHop;
      _lastLoadedChunkSeconds = chunkSeconds;
      _spectrogramGeneration++;
      activeGeneration = _spectrogramGeneration;
      _loadingSpectrogramChunkIndexes.clear();
      _clearSpectrogramChunks();
    }

    // Collect candidate indexes that don't have a chunk with the targetHop covering the required range.
    final centerIndex = (absoluteCenterSec / chunkSeconds).floor();
    final candidates = <int>[];
    for (var index = firstIndex; index <= lastIndex; index++) {
      final reqStart = index * chunkSeconds;
      final reqEnd = math.min(reqStart + chunkSeconds, totalSec);
      bool covered = false;
      for (final chunk in _spectrogramChunks) {
        if (chunk.startSec <= reqStart + 0.001 &&
            chunk.endSec >= reqEnd - 0.001 &&
            chunk.hop <= targetHop) {
          covered = true;
          break;
        }
      }
      if (covered) continue;
      if (_loadingSpectrogramChunkIndexes.contains(index)) continue;
      candidates.add(index);
    }
    candidates.sort(
      (a, b) => (a - centerIndex).abs().compareTo((b - centerIndex).abs()),
    );
    final inFlight = _loadingSpectrogramChunkIndexes.length;
    final budget = math.max(0, maxCachedChunks - inFlight);
    final scheduled = candidates.take(budget).toList();

    if (scheduled.isEmpty) {
      // Nothing new to load — make sure the spinner doesn't linger.
      if (mounted && _decoding != _loadingSpectrogramChunkIndexes.isNotEmpty) {
        setState(() => _decoding = _loadingSpectrogramChunkIndexes.isNotEmpty);
      }
      return;
    }
    _loadingSpectrogramChunkIndexes.addAll(scheduled);
    if (mounted) setState(() => _decoding = true);

    // Hold a snapshot of what we reserved so the finally block can
    // guarantee cleanup even if `_loadSpectrogramChunk` throws (e.g.
    // a range-read failure near a freshly applied clip boundary).
    final reserved = scheduled.toSet();
    try {
      for (final index in scheduled) {
        if (!mounted || activeGeneration != _spectrogramGeneration) {
          // Drop pending reservations so a follow-up request can retry.
          _loadingSpectrogramChunkIndexes.removeAll(reserved);
          if (mounted) {
            setState(
              () => _decoding = _loadingSpectrogramChunkIndexes.isNotEmpty,
            );
          }
          return;
        }
        // Each chunk load is best-effort: one bad chunk shouldn't stop
        // the rest of the viewport from filling in.
        try {
          await _loadSpectrogramChunk(
            index,
            activeGeneration,
            cacheCenterSec: absoluteCenterSec,
            maxCachedChunks: maxCachedChunks,
            hop: targetHop,
            chunkSeconds: chunkSeconds,
          );
        } catch (e, st) {
          // ignore: avoid_print
          print('[spec] chunk $index failed: $e\n$st');
        } finally {
          reserved.remove(index);
        }
      }
    } finally {
      if (reserved.isNotEmpty) {
        _loadingSpectrogramChunkIndexes.removeAll(reserved);
      }
      if (mounted && _decoding != _loadingSpectrogramChunkIndexes.isNotEmpty) {
        setState(() => _decoding = _loadingSpectrogramChunkIndexes.isNotEmpty);
      }
    }
  }

  Future<void> _loadSpectrogramChunk(
    int index,
    int generation, {
    required double cacheCenterSec,
    required int maxCachedChunks,
    required int hop,
    required double chunkSeconds,
  }) async {
    try {
      final path = _spectrogramAudioPath;
      final metadata = _spectrogramAudioMetadata;
      if (path == null || metadata == null) return;

      final totalSec = metadata.duration.inMicroseconds / 1000000.0;
      final chunkStartSec = index * chunkSeconds;
      final chunkEndSec = math.min(totalSec, chunkStartSec + chunkSeconds);
      if (chunkEndSec <= chunkStartSec) return;

      final startSample = (chunkStartSec * metadata.sampleRate).floor();
      final count =
          ((chunkEndSec - chunkStartSec) * metadata.sampleRate).ceil();

      final String quality = ref.read(spectrogramQualityProvider);
      final fftSize = 2048;

      int baseMaxDisplayBins;
      switch (quality.toLowerCase()) {
        case 'low':
          baseMaxDisplayBins = 128;
          break;
        case 'medium':
          baseMaxDisplayBins = 256;
          break;
        case 'high':
        default:
          baseMaxDisplayBins = 512;
          break;
      }

      final long = totalSec > 600.0;
      int baseHop;
      switch (quality.toLowerCase()) {
        case 'low':
          baseHop = long ? 3072 : 2048;
          break;
        case 'medium':
          baseHop = long ? 2048 : 1024;
          break;
        case 'high':
        default:
          baseHop = long ? 1024 : 512;
          break;
      }
      final hopMultiplier = math.max(1, hop ~/ baseHop);
      final int binDivisor =
          hopMultiplier == 1 ? 1 : (hopMultiplier <= 4 ? 2 : 4);
      final maxDisplayBins = math.max(32, baseMaxDisplayBins ~/ binDivisor);

      // Decode + STFT in a background isolate so pinch-zoom never stalls
      // the UI thread. Only the cheap GPU upload happens on main.
      final pixelData = await _runSpectrogramChunkIsolate(
        _SpectrogramChunkRequest(
          path: path,
          sourceSampleRate: metadata.sampleRate,
          rawPcm16: _spectrogramAudioIsRawPcm16,
          startSample: startSample,
          count: count,
          targetSampleRate: AppConstants.sampleRate,
          fftSize: fftSize,
          hop: hop,
          maxDisplayBins: maxDisplayBins,
          colorMapName: ref.read(colorMapProvider),
        ),
      );
      if (pixelData == null) return;

      if (!mounted || generation != _spectrogramGeneration) return;

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixelData.pixels,
        pixelData.width,
        pixelData.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final image = await completer.future;

      if (!mounted || generation != _spectrogramGeneration) {
        image.dispose();
        return;
      }

      setState(() {
        for (var i = _spectrogramChunks.length - 1; i >= 0; i--) {
          final chunk = _spectrogramChunks[i];
          if (chunk.startSec >= chunkStartSec - 0.001 &&
              chunk.endSec <= chunkEndSec + 0.001 &&
              chunk.hop >= hop) {
            _spectrogramChunks.removeAt(i).dispose();
          }
        }

        _spectrogramChunks.add(
          _SpectrogramChunk(
            startSec: chunkStartSec,
            endSec: chunkEndSec,
            image: image,
            hop: hop,
          ),
        );
        _spectrogramChunks.sort((a, b) => a.startSec.compareTo(b.startSec));
        while (_spectrogramChunks.length > maxCachedChunks) {
          var farthestIndex = 0;
          var farthestDistance = -1.0;
          for (var i = 0; i < _spectrogramChunks.length; i++) {
            final chunk = _spectrogramChunks[i];
            final chunkCenter = (chunk.startSec + chunk.endSec) / 2;
            final distance = (chunkCenter - cacheCenterSec).abs();
            if (distance > farthestDistance) {
              farthestDistance = distance;
              farthestIndex = i;
            }
          }
          _spectrogramChunks.removeAt(farthestIndex).dispose();
        }
      });
    } finally {
      _loadingSpectrogramChunkIndexes.remove(index);
      if (mounted) {
        setState(() => _decoding = _loadingSpectrogramChunkIndexes.isNotEmpty);
      }
    }
  }

  /// Crop the full spectrogram to the current clip range and update
  /// [_spectrogramImage].  Must be called whenever the clip changes.
  Future<void> _cropSpectrogramForClip(double startSec, double endSec) async {
    final src = _fullSpectrogramImage;
    final totalSec = _sourceDurationSec;
    if (src == null || totalSec <= 0) return;

    final startFrac = (startSec / totalSec).clamp(0.0, 1.0);
    final endFrac = (endSec / totalSec).clamp(0.0, 1.0);
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
    _positionNotifier.dispose();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _clipPlayerStateSubscription?.cancel();
    _memoAutoPlayerStateSubscription?.cancel();
    if (!identical(_spectrogramImage, _fullSpectrogramImage)) {
      _spectrogramImage?.dispose();
    }
    _fullSpectrogramImage?.dispose();
    _clearSpectrogramChunks();
    _deleteSpectrogramTempPcm();
    _player.dispose();
    _clipPlayer.dispose();
    _memoAutoPlayer.dispose();
    _speciesSearchController.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (_trimMode) {
      _toggleTrimMode();
      return false;
    }
    if (!_hasUnsavedWork) return true;
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.sessionReviewTitle),
            // A never-saved session prompts to keep or discard the whole
            // session; an edited-but-saved session prompts about the edits.
            content: Text(
              _isUnsaved
                  ? l10n.sessionUnsavedSession
                  : l10n.sessionUnsavedChanges,
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                ),
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
      // A declined trim confirmation cancels the save, and with it the exit —
      // otherwise leaving would silently drop the edits the user asked to keep.
      return _save();
    }
    if (result == 'discard') {
      // For a never-saved session there is no persisted copy to revert to, so
      // discarding must remove the session and its on-disk recordings.
      if (_isUnsaved) {
        final repo = ref.read(sessionRepositoryProvider);
        await repo.delete(widget.session.id);
        ref.invalidate(sessionListProvider);
      }
      return true;
    }
    return false; // Dialog dismissed.
  }

  Future<void> _showRenameDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text:
          widget.session.customName ??
          _sessionReviewTitle(l10n, widget.session),
    );
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.sessionRenameTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.sessionRenameHint),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: Text(l10n.sessionSave),
              ),
            ],
          ),
    );
    if (result == null) return;
    final trimmed = result.trim();
    setState(() {
      widget.session.customName = trimmed.isEmpty ? null : trimmed;
      _isDirty = true;
    });
  }

  /// Persists the session, cutting a pending trim into the recording first.
  ///
  /// Returns false when the user backed out of the trim confirmation, in
  /// which case nothing was written and the session stays dirty.
  Future<bool> _save() async {
    final l10n = AppLocalizations.of(context)!;
    // Resolve everything that needs `ref` or `context` up front. The cut
    // below is destructive, and the save that records it must not depend on
    // this widget still being alive by the time it runs.
    final repo = ref.read(sessionRepositoryProvider);

    final trimRange = _resolveTrimRange(_trimStartSec, _trimEndSec);
    // `_resolveTrimRange` also returns null when the recording length is
    // unknown (missing file, or a duration just_audio hasn't published yet).
    // That is not the user clearing the trim, so leave the stored range be
    // instead of quietly dropping it on an unrelated save.
    final trimUnresolved =
        trimRange == null &&
        (_trimStartSec != null || _trimEndSec != null) &&
        _sourceDurationSec <= 0;

    // Saving is what makes a trim permanent: the audio outside the range is
    // cut from the recording and the space it used is reclaimed. Undo, redo
    // and Reset all still work up to this point, so this is the last chance
    // to back out — ask before deleting audio. A trim we already know can't
    // be cut deletes nothing, so it neither warns nor retries.
    final willCutAudio = trimRange != null && !_trimCommitUnsupported;
    if (willCutAudio) {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.sessionTrimCommitTitle,
        body: l10n.sessionTrimCommitMessage,
        confirmLabel: l10n.sessionTrimCommitConfirm,
        cancelLabel: l10n.cancel,
      );
      if (!confirmed || !mounted) return false;
    }

    // Do not mutate the shared session object before the destructive prompt:
    // cancelling Save must leave provider and persisted state untouched.
    widget.session.detections
      ..clear()
      ..addAll(_detections);
    widget.session.annotations
      ..clear()
      ..addAll(_annotations);
    if (!trimUnresolved) {
      widget.session.trimStartSec = trimRange?.start;
      widget.session.trimEndSec = trimRange?.end;
    }

    SessionTrimCommit? outcome;
    if (willCutAudio) {
      outcome = await _cutTrimIntoRecording();
    }

    // Persist before anything slow or lifecycle-dependent runs. Past this
    // point the audio is already gone from disk, and a stored trim that
    // outlives the cut it describes would be applied a second time — to the
    // already-shortened recording — the next time the session is opened.
    await repo.save(widget.session);
    if (!mounted) return true;
    ref.invalidate(sessionListProvider);

    // Reload playback from what is now on disk: the shorter file after a
    // successful cut, or the untouched recording re-clipped to the trim
    // range when the cut didn't happen.
    if (outcome != null) await _reloadRecordingAfterCommit();
    if (!mounted) return true;

    setState(() {
      _isDirty = false;
      _isUnsaved = false;
      _undoStack.clear();
      _redoStack.clear();
    });
    final trimCommitFailed =
        outcome != null && outcome != SessionTrimCommit.applied;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // A trim that couldn't be cut is not a failed save — the session was
        // written and the range still shapes playback and exports — but the
        // user asked for the audio to go, so say that it didn't.
        content: Text(
          trimCommitFailed ? l10n.sessionTrimCommitFailed : l10n.sessionSaved,
        ),
        duration: Duration(seconds: trimCommitFailed ? 5 : 2),
      ),
    );
    return true;
  }

  /// Cuts the pending trim into the recording on disk.
  ///
  /// The player is stopped first: on Windows an open handle makes the file
  /// swap fail outright, and elsewhere it would go on reading the file we are
  /// about to replace. Deliberately does *not* reload the audio — the caller
  /// persists the rebased session first, so the window in which the bytes and
  /// the stored session disagree stays as short as possible.
  Future<SessionTrimCommit> _cutTrimIntoRecording() async {
    await _player.stop();
    _clipActive = false;
    _appliedClipRange = null;

    final outcome = await commitSessionTrim(widget.session);
    if (outcome == SessionTrimCommit.unsupported) {
      _trimCommitUnsupported = true;
    }
    if (!mounted) return outcome;

    if (outcome == SessionTrimCommit.applied) {
      // The recording *is* the trim now — there is no range left to apply.
      setState(() {
        _detections = List.of(widget.session.detections);
        _annotations = List.of(widget.session.annotations);
        _speciesGroups = _buildSpeciesGroups(
          _detections,
          widget.session.settings.windowDuration,
        );
        _trimStartSec = null;
        _trimEndSec = null;
        _pendingTrimStartSec = null;
        _pendingTrimEndSec = null;
        _clipOffsetSec = 0.0;
        _fullDurationSec = 0.0;
        _duration = Duration.zero;
      });
      _positionNotifier.value = Duration.zero;
    }
    return outcome;
  }

  /// Reloads the recording from disk after a trim commit attempt.
  Future<void> _reloadRecordingAfterCommit() async {
    if (!mounted) return;
    setState(() => _initializing = true);
    await _initAudio();
  }

  Future<void> _discard() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.sessionDiscardTitle,
      body: l10n.sessionDiscardMessage,
      confirmLabel: l10n.sessionDiscard,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed || !mounted) return;

    final repo = ref.read(sessionRepositoryProvider);
    await repo.delete(widget.session.id);
    ref.invalidate(sessionListProvider);
    if (mounted) Navigator.of(context).pop();
  }

  /// Whether this session may be resumed ("Continue survey").
  ///
  /// Only survey sessions qualify, and only when they were NOT recorded in
  /// full-audio mode. Full-audio recordings are a single continuous file that
  /// cannot be safely concatenated across a stop/resume (the FLAC stream is
  /// already finalized), so resuming them would desync the audio timeline
  /// from the detections. Clip-subsampling and no-recording sessions have no
  /// such continuous file and resume cleanly.
  bool get _canContinueSurvey {
    if (widget.session.type != SessionType.survey) return false;
    return switch (widget.session.settings.recordingMode) {
      'detections' || 'detectionsOnly' || 'off' => true,
      // A legacy session without a recording-mode snapshot is safe to resume
      // only when it has no associated audio. An existing path may point to a
      // finalized full recording, which must not be overwritten.
      null => widget.session.recordingPath == null,
      _ => false,
    };
  }

  /// Resume an unfinished survey session (after user confirmation).
  Future<void> _continueSurvey() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.surveyResumeTitle),
            content: Text(l10n.surveyResumeMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.surveyResumeConfirm),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder:
            (_) => SurveyLiveScreen(
              customName: widget.session.customName,
              transectId: widget.session.transectId,
              observerName: widget.session.observerName,
              startLatitude: widget.session.latitude,
              startLongitude: widget.session.longitude,
              resumeSession: widget.session,
            ),
      ),
    );
  }

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context)!;
    // Save pending changes before sharing so the export is up to date. This
    // also persists a not-yet-saved session — exporting implies keeping it.
    // Backing out of the trim confirmation cancels the share too: the export
    // would otherwise disagree with what is on screen.
    if (_hasUnsavedWork && !await _save()) return;

    final exportFormats = ref.read(exportSelectionProvider);
    final includeAudio = ref.read(includeAudioProvider);
    final shareAudioAsWav = ref.read(shareAudioAsWavProvider);
    final includeHtmlReport = ref.read(exportHtmlReportProvider);
    final includeAppMetadata = ref.read(includeAppMetadataProvider);
    final taxonomy = ref.read(taxonomyServiceProvider).value;
    final speciesLocale = ref.read(effectiveSpeciesLocaleProvider);
    // Legacy sessions persisted before SessionSettings.clipContextSeconds
    // existed default to 0, which would falsely place every detection at
    // the very start of every clip in Raven/CSV exports. When the session
    // has clip files but no recorded context value, fall back to the
    // device's current survey clip-context preference.
    final sessionClipContext = widget.session.settings.clipContextSeconds;
    final clips = widget.session.detections.where(
      (d) => d.audioClipPath != null && d.audioClipPath!.isNotEmpty,
    );
    final hasOnlyLegacyClips =
        clips.isNotEmpty && clips.every((d) => d.clipTimestamp == null);
    final clipContextOverride =
        (hasOnlyLegacyClips && sessionClipContext == 0)
            ? ref.read(surveyClipContextProvider)
            : null;

    final exportPath = await buildSessionExport(
      widget.session,
      formats: exportFormats,
      includeAudio: includeAudio,
      shareAudioAsWav: shareAudioAsWav,
      taxonomy: taxonomy,
      speciesLocale: speciesLocale,
      clipContextSecondsOverride: clipContextOverride,
      metadata: await buildSessionExportMetadata(
        widget.session,
        speciesLocale: speciesLocale,
      ),
      useAbsoluteSurveyTime:
          ref.read(timestampDisplayModeProvider) == 'absolute',
      includeHtmlReport: includeHtmlReport,
      includeAppMetadata: includeAppMetadata,
    );

    if (exportPath == null) {
      if (mounted && includeAudio && widget.session.hasAudioTrim) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.sessionTrimExportFailed)));
      }
      return;
    }
    await SharePlus.instance.share(shareParamsForFile(exportPath));
  }

  void _done() {
    Navigator.of(context).pop();
  }

  // ── Add Species ───────────────────────────────────────────────────

  Future<void> _addSpecies() async {
    // Use the spectrogram's visible center (accounts for user panning) rather
    // than the audio playhead, which may lag behind after a pan.
    final centerSec =
        _lastViewportCenterSec ??
        (_clipOffsetSec + _position.inMicroseconds / 1000000.0);
    final positionSec = centerSec;
    final result = await Navigator.of(context).push<AddSpeciesResult>(
      MaterialPageRoute(
        builder:
            (_) => AddSpeciesOverlay(
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
        case AddSpeciesInsertMode.global:
          // Insert global detection — applies to the whole session.
          _detections.add(
            DetectionRecord(
              scientificName: result.scientificName,
              commonName: result.commonName,
              confidence: 1.0,
              timestamp: widget.session.startTime,
              source:
                  result.userSpecified
                      ? DetectionSource.userSpecified
                      : DetectionSource.manualGlobal,
            ),
          );
          break;

        case AddSpeciesInsertMode.atTimestamp:
          // centerSec is an offset into the recorded audio, which is not
          // `startTime + centerSec` once the session has segments — a resumed
          // survey collapses its stopped gap, and a destructive trim leaves
          // the audio starting later than the session did.
          final ts = widget.session.relativeToAbsolute(centerSec);
          _detections.add(
            DetectionRecord(
              scientificName: result.scientificName,
              commonName: result.commonName,
              confidence: 1.0,
              timestamp: ts,
              endTimestamp: ts.add(
                Duration(seconds: widget.session.settings.windowDuration),
              ),
              source:
                  result.userSpecified
                      ? DetectionSource.userSpecified
                      : DetectionSource.manual,
            ),
          );
          break;

        case AddSpeciesInsertMode.replace:
          if (result.replaceRecord != null) {
            final idx = _detections.indexOf(result.replaceRecord!);
            if (idx != -1) {
              _detections[idx] = DetectionRecord(
                scientificName: result.scientificName,
                commonName: result.commonName,
                confidence: result.replaceRecord!.confidence,
                timestamp: result.replaceRecord!.timestamp,
                endTimestamp: result.replaceRecord!.endTimestamp,
                audioClipPath: result.replaceRecord!.audioClipPath,
                clipTimestamp: result.replaceRecord!.clipTimestamp,
                source:
                    result.userSpecified
                        ? DetectionSource.userSpecified
                        : DetectionSource.manual,
                confirmedAt: result.replaceRecord!.confirmedAt,
                note: result.replaceRecord!.note,
                voiceMemoPath: result.replaceRecord!.voiceMemoPath,
                latitude: result.replaceRecord!.latitude,
                longitude: result.replaceRecord!.longitude,
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

  /// Swap the annotation at [index] for [annotation], deleting the
  /// previous voice-memo file if the new entry no longer references it.
  /// Used by the chip-tap edit flow.
  void _replaceAnnotation(int index, SessionAnnotation annotation) {
    _pushUndo();
    final old = _annotations[index];
    final oldMemo = old.voiceMemoPath;
    setState(() {
      _annotations[index] = annotation;
      _isDirty = true;
    });
    if (oldMemo != null && oldMemo != annotation.voiceMemoPath) {
      Future<void>(() async {
        try {
          final f = File(oldMemo);
          if (await f.exists()) await f.delete();
        } catch (_) {
          // Ignore — best-effort cleanup.
        }
      });
    }
  }

  /// Play back the voice memo attached to the annotation at [index].
  ///
  /// Opens the voice-memo dialog in playback mode. If the user re-records,
  /// the annotation's memo path is updated in place. If the user deletes the
  /// memo, the annotation is deleted (same as tapping ×).
  Future<void> _playVoiceMemoAnnotation(int index) async {
    final a = _annotations[index];
    await _pausePlayersForVoiceMemo();
    if (!mounted) return;
    final result = await showVoiceMemoDialog(
      context: context,
      sessionId: widget.session.id,
      existingMemoPath: a.voiceMemoPath,
    );
    if (!mounted || result == null) return;
    if (result.deleted) {
      _deleteAnnotation(index);
      return;
    }
    if (result.savedPath != null && result.savedPath != a.voiceMemoPath) {
      if (!mounted) return;
      // Route through the metadata dialog so the user can update title and
      // scope — consistent with the add-new-memo flow.
      await _showVoiceMemoInput(
        editingIndex: index,
        overridePath: result.savedPath,
      );
    }
  }

  /// Reopen the appropriate editor for an existing annotation. Wired to the
  /// chip's long-press (for voice memos) or tap (for text annotations).
  void _editAnnotation(int index) {
    final a = _annotations[index];
    if (a.hasVoiceMemo) {
      _showVoiceMemoInput(editingIndex: index);
    } else {
      _showAnnotationInput(editingIndex: index);
    }
  }

  void _deleteAnnotation(int index) {
    _pushUndo();
    final removed = _annotations[index];
    setState(() {
      _annotations.removeAt(index);
      _isDirty = true;
    });
    // Best-effort cleanup of the underlying memo file when the
    // annotation owned one — keeps the session folder from
    // accumulating orphaned `.m4a` blobs after edits.
    final memoPath = removed.voiceMemoPath;
    if (memoPath != null) {
      Future<void>(() async {
        try {
          final f = File(memoPath);
          if (await f.exists()) await f.delete();
        } catch (_) {
          // Ignore — the file may already be gone or locked by a player.
        }
      });
    }
  }

  // ── Trim ──────────────────────────────────────────────────────────

  void _toggleTrimMode() {
    if (_trimMode) {
      // Leaving trim mode without applying — throw the pending handle
      // positions away so they can never be saved as a trim the user
      // never confirmed.
      setState(() {
        _trimMode = false;
        _pendingTrimStartSec = null;
        _pendingTrimEndSec = null;
      });
      return;
    }

    // Entering trim mode — seed the handles from the applied trim.
    var pendingStart = _trimStartSec;
    var pendingEnd = _trimEndSec;

    // For long (lazy-loaded) recordings we don't have a full-file
    // spectrogram thumbnail to scrub against, so the trim editor
    // operates on whatever portion of the strip the user is currently
    // looking at. Default the handles to the visible window edges so
    // the user just zooms/scrolls to the region of interest first,
    // then drags the handles inward to refine. Any prior applied
    // trim that falls inside the visible window is preserved.
    if (_spectrogramLazy &&
        _lastViewportCenterSec != null &&
        _lastViewportViewSec != null) {
      final totalSec = _sourceDurationSec;
      final visibleStart = (_lastViewportCenterSec! - _lastViewportViewSec! / 2)
          .clamp(0.0, totalSec);
      final visibleEnd = (_lastViewportCenterSec! + _lastViewportViewSec! / 2)
          .clamp(0.0, totalSec);
      final existingStart = pendingStart;
      final existingEnd = pendingEnd;
      pendingStart =
          (existingStart != null &&
                  existingStart >= visibleStart &&
                  existingStart < visibleEnd)
              ? existingStart
              : visibleStart;
      pendingEnd =
          (existingEnd != null &&
                  existingEnd > visibleStart &&
                  existingEnd <= visibleEnd)
              ? existingEnd
              : visibleEnd;
    }

    setState(() {
      _trimMode = true;
      _pendingTrimStartSec = pendingStart;
      _pendingTrimEndSec = pendingEnd;
    });
  }

  void _onTrimChanged(double startSec, double endSec) {
    _pendingTrimStartSec = startSec;
    _pendingTrimEndSec = endSec;
  }

  Future<void> _applyTrim() async {
    // Handles default to the full recording, so a range that resolves to
    // "no clip" means the user confirmed without narrowing anything —
    // fall through to the reset path rather than persisting a no-op trim.
    final range = _resolveTrimRange(_pendingTrimStartSec, _pendingTrimEndSec);
    if (range == null) {
      if (_trimStartSec == null && _trimEndSec == null) {
        setState(() {
          _trimMode = false;
          _pendingTrimStartSec = null;
          _pendingTrimEndSec = null;
        });
        return;
      }
      await _resetTrim();
      return;
    }
    final start = range.start;
    final end = range.end;

    // Snapshot the state *before* the trim: _trimStartSec/_trimEndSec still
    // hold the applied values because the editor writes to the pending
    // fields, so this is simply the current state.
    _pushUndo();

    // A detection survives the trim as long as its recorded-audio interval
    // overlaps [start, end). Keep its capture timestamps unchanged; playback
    // and exports clamp the derived audio offsets to the retained clip.
    //
    // Comparison happens in *recorded-audio* seconds, not wall clock: a
    // resumed session's audio is the gap-removed concatenation of its
    // segments, so `startTime + trimStart` would land somewhere entirely
    // different from the audio position the user dragged the handle to.
    final session = widget.session;
    final retained = detectionsOverlappingTrim(
      session: session,
      detections: _detections,
      startSec: start,
      endSec: end,
    );
    setState(() {
      _detections
        ..clear()
        ..addAll(retained);
      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      // Promote the pending handles to the applied trim. Storing the
      // resolved (clamped) range keeps what we persist identical to what
      // the player and the export are given.
      _trimStartSec = start;
      _trimEndSec = end;
      _pendingTrimStartSec = null;
      _pendingTrimEndSec = null;
      _isDirty = true;
      _trimMode = false;
    });

    await _syncPlayerClip();
  }

  Future<void> _resetTrim() async {
    final hadTrim = _trimStartSec != null || _trimEndSec != null;
    List<DetectionRecord>? restoredDetections;
    final range = _resolveTrimRange(_trimStartSec, _trimEndSec);
    if (range != null) {
      // Applying a trim hides detections outside the retained audio. Restore
      // only those automatically removed records when resetting, while
      // preserving edits or deletions the user made to visible detections.
      _ReviewSnapshot? untrimmedSnapshot;
      // Use the nearest untrimmed state. An older snapshot may predate
      // detections added or edited between two separate trim/reset cycles.
      for (final snapshot in _undoStack.reversed) {
        if (snapshot.trimStartSec == null && snapshot.trimEndSec == null) {
          untrimmedSnapshot = snapshot;
          break;
        }
      }
      if (untrimmedSnapshot != null) {
        final retainedByTrim =
            detectionsOverlappingTrim(
              session: widget.session,
              detections: untrimmedSnapshot.detections,
              startSec: range.start,
              endSec: range.end,
            ).toSet();
        restoredDetections = [
          ..._detections,
          for (final detection in untrimmedSnapshot.detections)
            if (!retainedByTrim.contains(detection) &&
                !_detections.contains(detection))
              detection,
        ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
    }
    if (hadTrim) _pushUndo();

    setState(() {
      if (restoredDetections != null) {
        _detections
          ..clear()
          ..addAll(restoredDetections);
        _speciesGroups = _buildSpeciesGroups(
          _detections,
          widget.session.settings.windowDuration,
        );
      }
      _trimStartSec = null;
      _trimEndSec = null;
      _pendingTrimStartSec = null;
      _pendingTrimEndSec = null;
      if (hadTrim) _isDirty = true;
      _trimMode = false;
    });

    await _syncPlayerClip();
  }

  // ── Help ──────────────────────────────────────────────────────────

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SessionHelpSheet(showContinueSurvey: _canContinueSurvey),
    );
  }

  /// Open fullscreen survey track map with all detections.
  void _openFullscreenSurveyMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => _FullscreenSurveyMapScreen(
              session: widget.session,
              gpsTrack: widget.session.gpsTrack,
              detections: _detections,
              initialHighlight: _highlightedDetection,
              onConfirmChanged: () {
                // Detections were mutated in place from the in-sheet
                // checkmark; mark dirty so save/discard prompts trigger
                // and rebuild so species rows + badges refresh.
                if (mounted) setState(() => _isDirty = true);
              },
              onNoteChanged: () {
                if (mounted) setState(() => _isDirty = true);
              },
              onVoiceMemoChanged: () {
                if (mounted) setState(() => _isDirty = true);
              },
              onDeleteDetection: (record) {
                _deleteDetectionWithUndo(_DetectionCluster([record]));
              },
            ),
      ),
    );
  }

  /// Highlight a detection on the map and scroll to show it.
  void _showDetectionOnMap(DetectionRecord detection) {
    if (detection.latitude == null || detection.longitude == null) return;
    setState(() {
      _highlightedDetection = detection;
    });
  }

  /// Filter species groups to only include detections visible on the map.
  List<_SpeciesGroup> get _filteredSpeciesGroups {
    var groups = _speciesGroups;
    if (widget.session.type == SessionType.survey &&
        _visibleMapBounds != null) {
      final bounds = _visibleMapBounds!;
      final visible =
          _detections.where((d) {
            if (d.latitude == null || d.longitude == null) return true;
            return bounds.contains(LatLng(d.latitude!, d.longitude!));
          }).toList();
      groups = _buildSpeciesGroups(
        visible,
        widget.session.settings.windowDuration,
      );
    }
    return groups;
  }

  /// Toggle the confirmed flag on every record in [cluster]. The new
  /// state is determined by the cluster as a whole: if any record is
  /// already confirmed, the action clears confirmation across the
  /// cluster; otherwise it stamps every record with the same confirmation
  /// timestamp so they group cleanly in exports.
  void _toggleClusterConfirmation(_DetectionCluster cluster) {
    final anyConfirmed = cluster.records.any((r) => r.isConfirmed);
    final stamp = anyConfirmed ? null : DateTime.now().toUtc();
    setState(() {
      for (final r in cluster.records) {
        r.confirmedAt = stamp;
      }
      _isDirty = true;
    });
  }

  /// Remove every record in [cluster] and surface a SnackBar with an
  /// UNDO action. The modal confirm dialog used previously is gone now
  /// that swipe-to-dismiss + the overflow menu's delete entry both call
  /// here — the undo affordance covers misfires and a confirm tap on
  /// every delete became an annoying speed bump for reviewers cleaning
  /// up dozens of false positives in one pass.
  void _deleteDetectionWithUndo(_DetectionCluster cluster) {
    final l10n = AppLocalizations.of(context)!;
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
    _showUndoSnackBar(l10n.sessionDetectionRemoved);
  }

  /// Removes every detection of [scientificName] from the session in
  /// one shot. Mirrors [_deleteDetectionWithUndo] but scoped to a whole
  /// species — the SnackBar undo restores the full pre-delete state via
  /// the same undo stack, so a misfire is fully recoverable.
  void _deleteSpeciesWithUndo(String scientificName) {
    final l10n = AppLocalizations.of(context)!;
    _pushUndo();
    setState(() {
      _detections.removeWhere((r) => r.scientificName == scientificName);
      _speciesGroups = _buildSpeciesGroups(
        _detections,
        widget.session.settings.windowDuration,
      );
      _expandedSpecies.remove(scientificName);
      _isDirty = true;
    });
    _showUndoSnackBar(l10n.sessionSpeciesRemoved);
  }

  /// Shows an undo SnackBar using Flutter's built-in accessibility behavior,
  /// but with an explicit safety timeout to prevent snackbars from staying
  /// open indefinitely on devices with active accessibility services (such as
  /// Android password managers or custom gestures on Pixel devices).
  void _showUndoSnackBar(String text) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    const lifetime = Duration(seconds: 5);
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: lifetime,
        action: SnackBarAction(
          label: l10n.sessionUndo,
          onPressed: () {
            if (mounted) _undo();
          },
        ),
      ),
    );
    Future.delayed(lifetime, () {
      try {
        controller.close();
      } catch (_) {}
    });
  }

  bool get _usePlaybackOverlay {
    // Never show on sessions that have full audio.
    if (_audioAvailable) return false;

    // Event-driven check; read current setting without creating a watch.
    return ref.read(sessionReviewPlaybackOverlayProvider);
  }

  Future<void> _triggerPlaybackOverlay(_DetectionCluster cluster) async {
    final clip = cluster.records.where(_hasPlayableDetectionClip).firstOrNull;
    if (clip == null) return;

    final playable = buildSessionReviewPlaybackOrder(
      detections: _visibleReviewDetectionsForPlayback(),
      maxGapSec: widget.session.settings.windowDuration,
      sortMode: _speciesSort,
      localizedCommonName: _localizedCommonNameForPlayback,
      hasPlayableClip: _hasPlayableDetectionClip,
    );

    Future<void> showOverlayForRecord(DetectionRecord record) async {
      if (!mounted) return;

      final idx = playable.indexOf(record);
      final prev = idx > 0 ? playable[idx - 1] : null;
      final next =
          idx >= 0 && idx < playable.length - 1 ? playable[idx + 1] : null;

      await showClipPlayerSheet(
        context,
        detection: record,
        session: widget.session,
        onPrevious:
            prev == null
                ? null
                : () {
                  if (mounted) showOverlayForRecord(prev);
                },
        onNext:
            next == null
                ? null
                : () {
                  if (mounted) showOverlayForRecord(next);
                },
        onConfirmChanged: () {
          if (mounted) setState(() {});
          _isDirty = true;
        },
        onNoteChanged: () {
          if (mounted) setState(() {});
          _isDirty = true;
        },
        onVoiceMemoChanged: () {
          if (mounted) setState(() {});
          _isDirty = true;
        },
        onDelete: () {
          _deleteDetectionWithUndo(_DetectionCluster([record]));
        },
      );
    }

    await showOverlayForRecord(clip);
  }

  bool _hasPlayableDetectionClip(DetectionRecord detection) {
    final path = detection.audioClipPath;
    return path != null && File(path).existsSync();
  }

  String _localizedCommonNameForPlayback(
    String scientificName,
    String fallbackCommonName,
  ) {
    final speciesLocale = ref.read(effectiveSpeciesLocaleProvider);
    final taxonomy = ref.read(taxonomyServiceProvider).value;
    return taxonomy
            ?.lookup(scientificName)
            ?.commonNameForLocale(speciesLocale) ??
        fallbackCommonName;
  }

  List<DetectionRecord> _visibleReviewDetectionsForPlayback() {
    final groups = _filteredSpeciesGroups;
    final query = _speciesSearchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return groups.expand((group) => group.allRecords).toList();
    }

    return [
      for (final group in groups)
        if (_localizedCommonNameForPlayback(
              group.scientificName,
              group.commonName,
            ).toLowerCase().contains(query) ||
            group.scientificName.toLowerCase().contains(query))
          ...group.allRecords,
    ];
  }

  void _seekToCluster(_DetectionCluster cluster) {
    if (_usePlaybackOverlay) {
      _pausePlayer();
      _triggerPlaybackOverlay(cluster);
      return;
    }

    // Full recording available — seek the main player.
    if (_audioAvailable && _duration != Duration.zero) {
      final clipOffset = Duration(microseconds: (_clipOffsetSec * 1e6).round());
      final relativeSec = widget.session.absoluteToRelative(
        cluster.firstTimestamp,
      );
      final offset = Duration(microseconds: (relativeSec * 1e6).round());
      var seekPos = offset - clipOffset;
      // Clamp into the playable range [0, duration] so detections that
      // landed slightly before the recorder fully spun up (negative
      // offset) or after the trim end still play back from a sensible
      // position instead of silently failing.
      if (seekPos.isNegative) seekPos = Duration.zero;
      if (seekPos > _duration) seekPos = _duration;

      // Tapping a cluster used to auto-pause once playback walked past
      // the cluster's last detection (a few seconds in). In practice
      // this just made review feel like the player kept stopping for
      // no reason — users almost always want to keep listening for the
      // call to repeat or for context. Cancel any pending auto-stop and
      // let playback continue until the user pauses or the recording
      // ends.
      _autoStopPosition = null;
      _resetMemoAutoPlayback(stopMemo: false);

      _player.seek(seekPos);
      _positionNotifier.value = seekPos;
      if (!_isPlaying) {
        _player.play();
      }
      return;
    }
    // No full recording — try to play the first detection clip.
    _playDetectionClip(cluster);
  }

  /// Play the first available detection clip from the given cluster.
  Future<void> _playDetectionClip(_DetectionCluster cluster) async {
    final clip =
        cluster.records
            .where(
              (r) =>
                  r.audioClipPath != null &&
                  File(r.audioClipPath!).existsSync(),
            )
            .firstOrNull;
    if (clip == null) return;
    await _clipPlayer.stop();
    final clipPath = clip.audioClipPath!;
    final playbackPath = await PlaybackNormalizer.resolveSource(clipPath);
    if (!mounted) return;
    await _clipPlayer.setFilePath(playbackPath);
    if (!mounted) return;
    setState(() => _activeClipCluster = cluster);
    _clipPlayerStateSubscription ??= _clipPlayer.playerStateStream.listen((
      state,
    ) {
      if (!mounted) return;
      if (!state.playing ||
          state.processingState == ProcessingState.completed) {
        if (_activeClipCluster != null) {
          setState(() => _activeClipCluster = null);
        }
      }
    });
    _clipPlayer.play();
  }

  void _seekToPosition(Duration position) {
    if (!_audioAvailable || _duration == Duration.zero) return;
    if (position.isNegative) position = Duration.zero;
    if (position > _duration) position = _duration;
    // Manual seek cancels any pending auto-stop — the user is taking
    // over the timeline.
    _autoStopPosition = null;
    _resetMemoAutoPlayback();
    _player.seek(position);
    _positionNotifier.value = position;
  }

  void _checkAndPlayVoiceMemos(Duration pos) {
    if (!ref.read(playbackVoiceMemosProvider)) return;
    final clipPosSec = pos.inMicroseconds / 1e6;
    final prevSec =
        _lastMemoCheckPositionSec ??
        (clipPosSec - _memoTriggerGraceSec).clamp(0.0, clipPosSec);
    _lastMemoCheckPositionSec = clipPosSec;
    if (clipPosSec < prevSec) {
      _autoPlayedMemoKeys.clear();
      return;
    }

    for (final event in _voiceMemoPlaybackEvents()) {
      if (_autoPlayedMemoKeys.contains(event.key)) continue;
      if (prevSec < event.triggerSec && event.triggerSec <= clipPosSec) {
        _autoPlayedMemoKeys.add(event.key);
        unawaited(_triggerMemoAutoPlay(event.path));
      }
    }
  }

  Iterable<_VoiceMemoPlaybackEvent> _voiceMemoPlaybackEvents() sync* {
    final durationSec = _duration.inMicroseconds / 1e6;

    // Timed annotations use original-recording offsets. Rebase them onto the
    // active clip for playback. Global memos intentionally do not auto-play.
    for (final annotation in _annotations) {
      final path = annotation.voiceMemoPath;
      final offsetSec = annotation.offsetInRecording;
      if (path == null || offsetSec == null) continue;
      final triggerSec = offsetSec - _clipOffsetSec;
      if (triggerSec < 0 || triggerSec > durationSec) continue;
      yield _VoiceMemoPlaybackEvent(
        key: 'annotation:${annotation.createdAt.toIso8601String()}:$path',
        path: path,
        triggerSec: triggerSec,
      );
    }

    // Detection memos are tied to absolute session timestamps. Convert them
    // to the current clip's player position so trimmed review starts them at
    // the visible detection start.
    for (final detection in _detections) {
      final path = detection.voiceMemoPath;
      if (path == null || path.trim().isEmpty) continue;
      final triggerSec =
          widget.session.absoluteToRelative(detection.timestamp) -
          _clipOffsetSec;
      if (triggerSec < 0 || triggerSec > durationSec) continue;
      yield _VoiceMemoPlaybackEvent(
        key: 'detection:${detection.timestamp.toIso8601String()}:$path',
        path: path,
        triggerSec: triggerSec,
      );
    }
  }

  Future<void> _triggerMemoAutoPlay(String path) async {
    try {
      if (!mounted || !_isPlaying) return;
      await _memoAutoPlayer.stop();
      await _restoreMainVolumeAfterMemoOverlay();
      final playbackPath = await PlaybackNormalizer.resolveSource(path);
      await _memoAutoPlayer.setFilePath(playbackPath);
      if (!mounted || !_isPlaying) return;
      await _duckMainVolumeForMemoOverlay();
      await _memoAutoPlayer.play();
    } catch (_) {
      await _restoreMainVolumeAfterMemoOverlay();
      // Best-effort: a failed memo auto-play must not interrupt the session.
    }
  }

  Future<void> _duckMainVolumeForMemoOverlay() async {
    try {
      _mainVolumeBeforeMemoOverlay ??= _player.volume;
      await _memoAutoPlayer.setVolume(1.0);
      await _player.setVolume(1.0 - _memoDucking);
    } catch (_) {
      // Volume ducking is best-effort; memo playback should still continue.
    }
  }

  Future<void> _restoreMainVolumeAfterMemoOverlay() async {
    final previous = _mainVolumeBeforeMemoOverlay;
    if (previous == null) return;
    _mainVolumeBeforeMemoOverlay = null;
    try {
      await _player.setVolume(previous);
    } catch (_) {
      // Best-effort; the player may already be disposing.
    }
  }

  void _resetMemoAutoPlayback({bool stopMemo = true}) {
    _lastMemoCheckPositionSec = null;
    _autoPlayedMemoKeys.clear();
    if (stopMemo && _memoAutoPlayer.playing) {
      unawaited(_memoAutoPlayer.stop());
    }
    if (stopMemo) {
      unawaited(_restoreMainVolumeAfterMemoOverlay());
    }
  }

  void _pausePlayer() {
    _autoStopPosition = null;
    if (_isPlaying) _player.pause();
    if (_clipPlayer.playing) _clipPlayer.pause();
    if (_memoAutoPlayer.playing) {
      _memoAutoPlayer.stop();
      unawaited(_restoreMainVolumeAfterMemoOverlay());
    }
    if (_activeClipCluster != null) {
      setState(() => _activeClipCluster = null);
    }
  }

  // ── Add Content Menu ──────────────────────────────────────────────

  Future<void> _showAddMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final value = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.addCircleOutline),
                  title: Text(l10n.sessionAddSpecies),
                  onTap: () => Navigator.of(ctx).pop('species'),
                ),
                ListTile(
                  leading: const Icon(AppIcons.noteAdd),
                  title: Text(l10n.sessionAddAnnotationOption),
                  onTap: () => Navigator.of(ctx).pop('annotation'),
                ),
                ListTile(
                  leading: const Icon(AppIcons.micNone),
                  title: Text(l10n.sessionAddVoiceMemoOption),
                  onTap: () => Navigator.of(ctx).pop('voice_memo'),
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
    } else if (value == 'voice_memo') {
      _showVoiceMemoInput();
    }
  }

  /// Add or edit a voice-memo annotation.
  ///
  /// When [editingIndex] is null: opens the memo recorder, then a
  /// title+scope dialog to capture the new annotation's metadata.
  ///
  /// When [editingIndex] is set: skips straight to the title+scope
  /// dialog, prefilled from the existing entry. The dialog also exposes
  /// a "Replace recording…" button that re-opens the memo recorder
  /// without losing the title or scope.
  Future<void> _showVoiceMemoInput({
    int? editingIndex,
    String? overridePath,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = editingIndex != null;
    final existing = isEdit ? _annotations[editingIndex] : null;
    final positionSec = _currentSourcePositionSec;

    await _pausePlayersForVoiceMemo();
    if (!mounted) return;

    String? memoPath;
    if (isEdit) {
      memoPath = overridePath ?? existing!.voiceMemoPath;
    } else {
      final result = await showVoiceMemoDialog(
        context: context,
        sessionId: widget.session.id,
      );
      if (!mounted || result == null || result.savedPath == null) return;
      memoPath = result.savedPath;
    }

    // Default scope mirrors text annotations: at-current-position when
    // playback has progressed past the start, otherwise session-global.
    var atTimestamp =
        isEdit ? existing!.offsetInRecording != null : positionSec > 0.5;
    final titleController = TextEditingController(
      text: isEdit ? existing!.title : '',
    );
    var savedOffset =
        isEdit
            ? existing!.offsetInRecording
            : (atTimestamp ? positionSec : null);
    var currentMemoPath = memoPath;

    final saved = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  title: Text(
                    isEdit
                        ? l10n.sessionEditVoiceMemo
                        : l10n.sessionAddVoiceMemoOption,
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            hintText: l10n.sessionAnnotationName,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          autofocus: !isEdit,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              avatar: const Icon(AppIcons.public, size: 18),
                              label: Text(l10n.sessionAnnotationGlobal),
                              selected: !atTimestamp,
                              onSelected: (_) {
                                setDialogState(() {
                                  atTimestamp = false;
                                  savedOffset = null;
                                });
                              },
                            ),
                            ChoiceChip(
                              avatar: const Icon(AppIcons.schedule, size: 18),
                              label: Text(l10n.sessionInsertAtTimestamp),
                              selected: atTimestamp,
                              onSelected: (_) {
                                setDialogState(() {
                                  atTimestamp = true;
                                  savedOffset = positionSec;
                                });
                              },
                            ),
                          ],
                        ),
                        if (isEdit) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(AppIcons.mic, size: 18),
                            label: Text(l10n.detectionReplaceVoiceMemo),
                            onPressed: () async {
                              await _pausePlayersForVoiceMemo();
                              if (!ctx.mounted) return;
                              // Open idle mode (no existing path) so the user
                              // taps to record — same flow as the initial add.
                              final result = await showVoiceMemoDialog(
                                context: ctx,
                                sessionId: widget.session.id,
                              );
                              if (result?.savedPath != null) {
                                setDialogState(
                                  () => currentMemoPath = result!.savedPath,
                                );
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(l10n.cancel),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(l10n.sessionSave),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );

    if (!mounted || saved != true) {
      // Delete any newly-recorded file that wasn't committed. For a new memo,
      // that's anything in currentMemoPath. For an edit with overridePath (re-
      // record from playback), that's the overridePath file. Regular edits
      // where the path never changed must NOT be deleted.
      final unchanged =
          isEdit &&
          overridePath == null &&
          currentMemoPath == existing?.voiceMemoPath;
      if (!unchanged && currentMemoPath != null) {
        Future<void>(() async {
          try {
            final f = File(currentMemoPath!);
            if (await f.exists()) await f.delete();
          } catch (_) {
            // Best-effort.
          }
        });
      }
      return;
    }

    final annotation = SessionAnnotation(
      text: '',
      title: titleController.text.trim(),
      createdAt: isEdit ? existing!.createdAt : DateTime.now(),
      offsetInRecording: savedOffset,
      voiceMemoPath: currentMemoPath,
    );
    if (isEdit) {
      _replaceAnnotation(editingIndex, annotation);
    } else {
      _addAnnotation(annotation);
    }
  }

  /// Add or edit a text annotation.
  ///
  /// Pass [editingIndex] to prefill the dialog from an existing entry
  /// and replace it on save (used by the chip-tap edit flow).
  void _showAnnotationInput({int? editingIndex}) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = editingIndex != null;
    final existing = isEdit ? _annotations[editingIndex] : null;
    final titleController = TextEditingController(
      text: isEdit ? existing!.title : '',
    );
    final controller = TextEditingController(
      text: isEdit ? existing!.text : '',
    );
    var atTimestamp = isEdit ? existing!.offsetInRecording != null : false;
    showDialog<void>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  title: Text(
                    isEdit
                        ? l10n.sessionEditAnnotation
                        : l10n.sessionAddAnnotationOption,
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            hintText: l10n.sessionAnnotationName,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 8),
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
                              avatar: const Icon(AppIcons.public, size: 18),
                              label: Text(l10n.sessionAnnotationGlobal),
                              selected: !atTimestamp,
                              onSelected:
                                  (_) =>
                                      setDialogState(() => atTimestamp = false),
                            ),
                            ChoiceChip(
                              avatar: const Icon(AppIcons.schedule, size: 18),
                              label: Text(l10n.sessionInsertAtTimestamp),
                              selected: atTimestamp,
                              onSelected:
                                  (_) =>
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
                        final title = titleController.text.trim();
                        // Need at least *some* content — title or body.
                        if (text.isEmpty && title.isEmpty) return;
                        final positionSec =
                            isEdit
                                ? (existing!.offsetInRecording ??
                                    _currentSourcePositionSec)
                                : _currentSourcePositionSec;
                        final annotation = SessionAnnotation(
                          text: text,
                          title: title,
                          createdAt:
                              isEdit ? existing!.createdAt : DateTime.now(),
                          offsetInRecording: atTimestamp ? positionSec : null,
                        );
                        if (isEdit) {
                          _replaceAnnotation(editingIndex, annotation);
                        } else {
                          _addAnnotation(annotation);
                        }
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        isEdit
                            ? l10n.sessionSave
                            : l10n.sessionAddAnnotationOption,
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _editClusterNote(_DetectionCluster cluster) async {
    final l10n = AppLocalizations.of(context)!;
    final target = cluster.records.first;
    final hadNote = target.hasNote;
    final controller = TextEditingController(text: target.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.detectionNoteDialogTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l10n.detectionNoteHint),
            ),
            actions: [
              if (hadNote)
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(''),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.error,
                  ),
                  child: Text(l10n.detectionDeleteNote),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: Text(l10n.sessionSave),
              ),
            ],
          ),
    );
    if (result == null || !mounted) return;
    final trimmed = result.trim();
    final wasEmpty = !target.hasNote;
    final isNowEmpty = trimmed.isEmpty;
    if (wasEmpty && isNowEmpty) return;
    setState(() {
      target.note = isNowEmpty ? null : trimmed;
      _isDirty = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isNowEmpty ? l10n.detectionNoteCleared : l10n.detectionNoteSaved,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _editClusterVoiceMemo(_DetectionCluster cluster) async {
    final l10n = AppLocalizations.of(context)!;
    final target = cluster.records.first;
    await _pausePlayersForVoiceMemo();
    if (!mounted) return;
    final result = await showVoiceMemoDialog(
      context: context,
      sessionId: widget.session.id,
      existingMemoPath: target.voiceMemoPath,
    );
    if (result == null || !mounted) return;
    if (result.deleted) {
      setState(() {
        target.voiceMemoPath = null;
        _isDirty = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.detectionVoiceMemoDeleted),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (result.savedPath != null) {
      setState(() {
        target.voiceMemoPath = result.savedPath;
        _isDirty = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.detectionVoiceMemoSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pausePlayersForVoiceMemo() async {
    try {
      if (_player.playing) {
        await _player.pause();
      }
    } catch (_) {
      // Best-effort: keep memo flow moving even if pause throws.
    }
    try {
      if (_clipPlayer.playing) {
        await _clipPlayer.pause();
      }
    } catch (_) {
      // Best-effort.
    }
    try {
      if (_memoAutoPlayer.playing) {
        await _memoAutoPlayer.stop();
      }
      await _restoreMainVolumeAfterMemoOverlay();
    } catch (_) {
      // Best-effort.
    }
    if (mounted && _isPlaying) {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _deleteClusterVoiceMemo(_DetectionCluster cluster) async {
    final l10n = AppLocalizations.of(context)!;
    final target = cluster.records.first;
    final path = target.voiceMemoPath;
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // best-effort
    }
    if (!mounted) return;
    setState(() {
      target.voiceMemoPath = null;
      _isDirty = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.detectionVoiceMemoDeleted),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _replaceDetection(_DetectionCluster cluster) async {
    final positionSec = _position.inMicroseconds / 1000000.0;
    final target = cluster.records.first;
    final result = await Navigator.of(context).push<AddSpeciesResult>(
      MaterialPageRoute(
        builder:
            (_) => AddSpeciesOverlay(
              sessionStart: widget.session.startTime,
              positionSec: positionSec,
              existingDetections: _detections,
              initialMode: AddSpeciesInsertMode.replace,
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
            endTimestamp: result.replaceRecord!.endTimestamp,
            audioClipPath: result.replaceRecord!.audioClipPath,
            clipTimestamp: result.replaceRecord!.clipTimestamp,
            source:
                result.userSpecified
                    ? DetectionSource.userSpecified
                    : DetectionSource.manual,
            confirmedAt: result.replaceRecord!.confirmedAt,
            note: result.replaceRecord!.note,
            voiceMemoPath: result.replaceRecord!.voiceMemoPath,
            latitude: result.replaceRecord!.latitude,
            longitude: result.replaceRecord!.longitude,
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
    ref.listen<String>(colorMapProvider, (previous, next) {
      if (previous != null && previous != next) {
        unawaited(_refreshSpectrogramForColorMap());
      }
    });

    return PopScope(
      canPop: !_hasUnsavedWork,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final nav = Navigator.of(context);
          final canPop = await _onWillPop();
          if (canPop) nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: _showRenameDialog,
            child: Semantics(
              button: true,
              label: l10n.sessionRenameTap,
              child: ExcludeSemantics(
                child: Tooltip(
                  message: l10n.sessionRenameTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _sessionReviewTitle(l10n, widget.session),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        AppIcons.edit,
                        size: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(153),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(AppIcons.close),
            tooltip: l10n.tooltipClose,
            onPressed: () async {
              if (_hasUnsavedWork) {
                final canPop = await _onWillPop();
                if (canPop && mounted) _done();
              } else {
                _done();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(AppIcons.helpOutline),
              tooltip: l10n.sessionHelpTitle,
              onPressed: _showHelp,
            ),
            IconButton(
              icon: const Icon(AppIcons.tuneRounded),
              tooltip: l10n.settings,
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
            ),
          ],
          // Indeterminate progress under the AppBar while the screen is
          // doing its one-shot setup (audio metadata + spectrogram
          // decode). Keeps the rest of the UI responsive but makes it
          // obvious that something is loading on large sessions where
          // decoding can take several seconds.
          bottom:
              (_initializing || _decoding)
                  ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                  : null,
        ),
        body: _buildReviewBody(context, theme, l10n),
      ),
    );
  }

  // ── Review Body — orientation-aware layout ────────────────────────

  Widget _buildReviewBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final toolbar = _buildToolbar(theme, l10n);
    final speciesList = _buildSpeciesList(theme, l10n);

    if (isLandscape) {
      // Landscape: toolbar on top, then left = scrollable media, right = species.
      return Column(
        children: [
          toolbar,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: scrollable media column.
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Column(
                      children: _buildMediaWidgets(context, theme, l10n),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                // Right: species list. Slightly wider than the media column
                // because each detection row carries a play affordance plus
                // four trailing action buttons; cramming those into a 50/50
                // split makes the row text overflow on phone-sized landscape.
                Expanded(flex: 3, child: speciesList),
              ],
            ),
          ),
        ],
      );
    }

    // Portrait: original vertical stack.
    return Column(
      children: [
        toolbar,
        ..._buildMediaWidgets(context, theme, l10n),
        const Divider(height: 1),
        Expanded(child: speciesList),
      ],
    );
  }

  Widget _buildToolbar(ThemeData theme, AppLocalizations l10n) {
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(AppIcons.addCircleOutline),
            tooltip: l10n.sessionAddContent,
            onPressed: _showAddMenu,
          ),
          IconButton(
            icon: Icon(
              AppIcons.undo,
              color:
                  !_trimMode && _canUndo
                      ? null
                      : theme.colorScheme.onSurface.withAlpha(80),
            ),
            tooltip: l10n.sessionUndo,
            onPressed: !_trimMode && _canUndo ? _undo : null,
          ),
          IconButton(
            icon: Icon(
              AppIcons.redo,
              color:
                  !_trimMode && _canRedo
                      ? null
                      : theme.colorScheme.onSurface.withAlpha(80),
            ),
            tooltip: l10n.sessionRedo,
            onPressed: !_trimMode && _canRedo ? _redo : null,
          ),
          if (_audioAvailable)
            IconButton(
              icon: Icon(AppIcons.contentCut),
              tooltip: l10n.sessionTrimRecording,
              onPressed: _toggleTrimMode,
              color: _trimMode ? theme.colorScheme.primary : null,
            ),
          IconButton(
            icon: Icon(
              AppIcons.save,
              color:
                  _hasUnsavedWork
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withAlpha(80),
            ),
            tooltip: l10n.sessionSave,
            onPressed: !_trimMode && _hasUnsavedWork ? _save : null,
          ),
          IconButton(
            icon: const Icon(AppIcons.share),
            tooltip: l10n.sessionShare,
            onPressed: _trimMode ? null : _share,
          ),
          IconButton(
            icon: const Icon(AppIcons.deleteOutline),
            tooltip: l10n.sessionDiscard,
            onPressed: _discard,
          ),
          if (_canContinueSurvey)
            IconButton(
              icon: Icon(
                AppIcons.playArrowRounded,
                color: theme.colorScheme.primary,
              ),
              tooltip: l10n.surveyContinue,
              onPressed: _continueSurvey,
            ),
        ],
      ),
    );
  }

  /// Builds the media widgets: summary header, map, spectrogram, trim bar,
  /// and annotations. Used by both portrait and landscape layouts.
  ///
  /// A survey recorded with full audio is the only session that has both a
  /// GPS track and a continuous recording to show. Stacking the two panels
  /// leaves each of them too short to be useful, so that one case puts them
  /// behind tabs instead ([_MediaTabPanel]); every other session still shows
  /// whichever single panel it has.
  List<Widget> _buildMediaWidgets(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final mapPanel = _buildSurveyMapPanel(context);
    final audioPanel = _buildAudioPanel();
    final useTabs = mapPanel != null && audioPanel != null;

    return [
      _SummaryHeader(
        session: widget.session,
        detectionCount: _detections.length,
        locationName: _locationName,
        onShowMap:
            widget.session.latitude != null
                ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => SessionMapScreen(
                          latitude: widget.session.latitude!,
                          longitude: widget.session.longitude!,
                          locationName: _locationName,
                        ),
                  ),
                )
                : null,
        onFetchWeather: _resolveWeather,
      ),
      if (_audioTruncatedWarning && !_audioTruncatedWarningDismissed)
        _ReviewWarningCard(
          icon: AppIcons.warningAmberRounded,
          title: l10n.sessionReviewAudioShortTitle,
          body: l10n.sessionReviewAudioShortBody,
          onDismiss: _dismissAudioWarning,
        ),
      if (useTabs)
        _MediaTabPanel(
          map: mapPanel,
          spectrogram: audioPanel,
          trimming: _trimMode,
        )
      else ...[
        if (mapPanel != null)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.18,
            child: mapPanel,
          ),
        if (audioPanel != null) audioPanel,
      ],
      if (_trimMode)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AppIcons.warningAmberRounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.sessionTrimWarning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _toggleTrimMode,
                    child: Text(l10n.cancel),
                  ),
                  TextButton(
                    onPressed: _resetTrim,
                    child: Text(l10n.sessionTrimReset),
                  ),
                  FilledButton(
                    onPressed: _applyTrim,
                    child: Text(l10n.sessionTrimApply),
                  ),
                ],
              ),
            ],
          ),
        ),
      if (_annotations.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _annotations.length; i++)
                _buildAnnotationChip(i),
            ],
          ),
        ),
    ];
  }

  /// The survey track map, or null when this session has no location to show.
  ///
  /// Returned unsized so the caller can decide the height — standalone it
  /// gets a share of the screen, inside [_MediaTabPanel] it matches the
  /// spectrogram strip.
  Widget? _buildSurveyMapPanel(BuildContext context) {
    final hasLocation =
        widget.session.gpsTrack.isNotEmpty ||
        (widget.session.latitude != null && widget.session.longitude != null);
    if (widget.session.type != SessionType.survey || !hasLocation) return null;

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            child: SurveyMapWidget(
              gpsTrack: widget.session.gpsTrack,
              detections: _detections,
              autoFollow: false,
              fitAllPoints: widget.session.gpsTrack.length >= 2,
              highlightedDetection: _highlightedDetection,
              initialCenter:
                  widget.session.latitude != null &&
                          widget.session.longitude != null
                      ? LatLng(
                        widget.session.latitude!,
                        widget.session.longitude!,
                      )
                      : null,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _openFullscreenSurveyMap(context),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  AppIcons.fullscreen,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The spectrogram strip (or the trim editor while trimming), or null when
  /// this session has no continuous recording.
  Widget? _buildAudioPanel() {
    if (!_audioAvailable) return null;

    // The zoomable trim editor paints the *full-recording* spectrogram, so it
    // is only usable while that image exists. A clip-cropped image would make
    // the handles address the wrong seconds; fall through to the overlay
    // editor in that case.
    if (_trimMode && _fullSpectrogramImage != null && _sourceDurationSec > 0) {
      final totalSec = _sourceDurationSec;
      return _TrimSpectrogramView(
        spectrogramImage: _fullSpectrogramImage!,
        durationSec: totalSec,
        initialStartSec: (_pendingTrimStartSec ?? 0.0).clamp(0.0, totalSec),
        initialEndSec: (_pendingTrimEndSec ?? totalSec).clamp(0.0, totalSec),
        onChanged: _onTrimChanged,
        quality: ref.watch(spectrogramQualityProvider),
      );
    }

    return Stack(
      children: [
        _SpectrogramStrip(
          session: widget.session,
          spectrogramImage: _spectrogramImage,
          spectrogramChunks: List.unmodifiable(_spectrogramChunks),
          decoding: _decoding,
          positionNotifier: _positionNotifier,
          duration: _duration,
          timelineOffsetSec: _clipOffsetSec,
          onViewportChanged: _requestSpectrogramViewport,
          onSeek: _seekToPosition,
          onPause: _pausePlayer,
          isPlaying: _isPlaying,
          userDefaultViewSeconds:
              ref.watch(spectrogramDurationProvider).toDouble(),
          quality: ref.watch(spectrogramQualityProvider),
        ),
        // Lazy trim editor: no full-file spectrogram thumbnail is
        // available, so we overlay trim handles directly on the
        // live (chunk-painted) strip and operate on whatever
        // window is currently visible. The user pre-zooms to the
        // region of interest, then drags handles inward.
        if (_trimMode &&
            _spectrogramLazy &&
            _lastViewportCenterSec != null &&
            _lastViewportViewSec != null)
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final totalSec = _sourceDurationSec;
                final visibleStart = (_lastViewportCenterSec! -
                        _lastViewportViewSec! / 2)
                    .clamp(0.0, totalSec);
                final visibleEnd = (_lastViewportCenterSec! +
                        _lastViewportViewSec! / 2)
                    .clamp(0.0, totalSec);
                return _TrimOverlay.windowed(
                  visibleStartSec: visibleStart,
                  visibleEndSec: visibleEnd,
                  initialStartSec: _pendingTrimStartSec ?? visibleStart,
                  initialEndSec: _pendingTrimEndSec ?? visibleEnd,
                  onChanged: _onTrimChanged,
                );
              },
            ),
          ),
        Positioned(
          left: 8,
          bottom: 8,
          child: _PlayPauseButton(
            isPlaying: _isPlaying,
            onToggle: () {
              // Manual play/pause cancels any pending auto-stop.
              _autoStopPosition = null;
              if (_isPlaying) {
                _player.pause();
              } else {
                _player.play();
              }
            },
          ),
        ),
      ],
    );
  }

  /// Compact chip for a single annotation. Tapping reopens the editor
  /// (text dialog or voice-memo dialog depending on the kind), and the
  /// trailing × button deletes the entry. Label priority is title →
  /// text excerpt → "Voice memo" placeholder, so memo-only entries
  /// without a title still show *something* meaningful.
  Widget _buildAnnotationChip(int i) {
    final l10n = AppLocalizations.of(context)!;
    final a = _annotations[i];
    final title = a.title.trim();
    final text = a.text.trim();
    final String label;
    if (title.isNotEmpty) {
      label = title;
    } else if (text.isNotEmpty) {
      label = text;
    } else {
      label = l10n.sessionAnnotationVoiceMemoLabel;
    }

    final isTimed = a.offsetInRecording != null && _audioAvailable;

    void seekToOffset() {
      final clipRelativeSec = a.offsetInRecording! - _clipOffsetSec;
      _seekToPosition(Duration(microseconds: (clipRelativeSec * 1e6).round()));
    }

    // Timed entries always show the clock icon so global vs timed is
    // immediately visible regardless of whether it's a voice memo or text.
    // Global voice memos keep the mic icon; global text keeps the text icon.
    final chip = InputChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      avatar: Icon(
        a.offsetInRecording != null
            ? AppIcons.schedule
            : (a.hasVoiceMemo ? AppIcons.mic : AppIcons.shortText),
        size: 16,
      ),
      onPressed: () {
        if (a.hasVoiceMemo) {
          _playVoiceMemoAnnotation(i);
        } else if (isTimed) {
          // Timed text annotations: tap seeks the playhead to the marked
          // position (the point of a timed note); long-press edits.
          seekToOffset();
        } else {
          _editAnnotation(i);
        }
      },
      tooltip:
          a.hasVoiceMemo
              ? l10n.sessionEditVoiceMemo
              : (isTimed
                  ? l10n.detectionSeekToPosition
                  : l10n.sessionEditAnnotation),
      deleteIcon: const Icon(AppIcons.close, size: 16),
      onDeleted: () => _deleteAnnotation(i),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    if (isTimed) {
      // Voice memos: long-press seeks (tap already plays).
      // Text annotations: long-press edits (tap already seeks).
      return GestureDetector(
        onLongPress: a.hasVoiceMemo ? seekToOffset : () => _editAnnotation(i),
        child: chip,
      );
    }
    return chip;
  }

  Widget _buildSpeciesList(ThemeData theme, AppLocalizations l10n) {
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    final taxonomy = ref.watch(taxonomyServiceProvider).value;

    // Locale-aware common-name resolver — mirrors the lookup used by
    // the species tile so the filter/sort match what the user sees.
    String localizedCommonName(_SpeciesGroup group) {
      final localized = taxonomy
          ?.lookup(group.scientificName)
          ?.commonNameForLocale(speciesLocale);
      return localized ?? group.commonName;
    }

    // Apply free-text filter (locale-aware common name + sci name).
    final query = _speciesSearchQuery.trim().toLowerCase();
    var groups = _filteredSpeciesGroups;
    if (query.isNotEmpty) {
      groups =
          groups.where((g) {
            final common = localizedCommonName(g).toLowerCase();
            final sci = g.scientificName.toLowerCase();
            return common.contains(query) || sci.contains(query);
          }).toList();
    }

    final sorted = _orderSessionReviewSpeciesGroups(
      groups: groups,
      sortMode: _speciesSort,
      localizedCommonName: localizedCommonName,
      hasPlayableClip: _hasPlayableDetectionClip,
    );

    final header = _buildSpeciesListHeader(theme, l10n);
    final hasAnyGroups = _filteredSpeciesGroups.isNotEmpty;

    Widget body;
    if (_groupsBuilding) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!hasAnyGroups) {
      body = Center(
        child: Text(
          l10n.sessionNoDetections,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: _reviewOnSurface(theme, 120),
          ),
        ),
      );
    } else if (sorted.isEmpty) {
      // The search filter eliminated every species but the session is
      // not actually empty — show a query-specific empty state so the
      // user knows to clear/refine the search instead of suspecting
      // that detections were lost.
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.sessionNoResultsFor(_speciesSearchQuery),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _reviewOnSurface(theme, 140),
            ),
          ),
        ),
      );
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final group = sorted[index];
          final isExpanded = _expandedSpecies.contains(group.scientificName);
          return _SpeciesTile(
            key: ValueKey('species-tile-${group.scientificName}'),
            group: group,
            session: widget.session,
            isExpanded: isExpanded,
            positionNotifier: _positionNotifier,
            isPlaying: _isPlaying,
            activeCluster: _activeClipCluster,
            clipOffsetSec: _clipOffsetSec,
            windowSec: widget.session.settings.windowDuration,
            isSurvey: widget.session.type == SessionType.survey,
            audioAvailable: _audioAvailable,
            onToggleExpand:
                () => setState(() {
                  if (isExpanded) {
                    _expandedSpecies.remove(group.scientificName);
                  } else {
                    _expandedSpecies.add(group.scientificName);
                  }
                }),
            onSpeciesInfo:
                () => SpeciesInfoOverlay.show(
                  context,
                  ref,
                  scientificName: group.scientificName,
                  commonName: group.commonName,
                ),
            onSeekCluster: _seekToCluster,
            onPause: _pausePlayer,
            onDeleteCluster: _deleteDetectionWithUndo,
            onDeleteSpecies: () => _deleteSpeciesWithUndo(group.scientificName),
            onReplaceCluster: _replaceDetection,
            onToggleConfirmCluster: _toggleClusterConfirmation,
            onShareCluster:
                (cluster) => shareDetection(
                  cluster.records.first,
                  session: widget.session,
                  shareAudioAsWav: ref.read(shareAudioAsWavProvider),
                ),
            onEditNoteCluster: _editClusterNote,
            onEditVoiceMemoCluster: _editClusterVoiceMemo,
            onDeleteVoiceMemoCluster: _deleteClusterVoiceMemo,
            onShowOnMap: _showDetectionOnMap,
          );
        },
      );
    }

    return Column(children: [header, Expanded(child: body)]);
  }

  /// Sticky header above the species list with a search field and
  /// sort menu. Hidden entirely when the session has no detections at
  /// all so the empty-state message stays prominent.
  Widget _buildSpeciesListHeader(ThemeData theme, AppLocalizations l10n) {
    if (_speciesGroups.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _speciesSearchController,
                onChanged: (v) => setState(() => _speciesSearchQuery = v),
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.sessionSearchSpecies,
                  prefixIcon: const Icon(AppIcons.search, size: 18),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  suffixIcon:
                      _speciesSearchQuery.isEmpty
                          ? null
                          : IconButton(
                            icon: const Icon(AppIcons.clear, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            tooltip: l10n.tooltipClearSearch,
                            onPressed: () {
                              _speciesSearchController.clear();
                              setState(() => _speciesSearchQuery = '');
                            },
                          ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          PopupMenuButton<SpeciesSortMode>(
            tooltip: l10n.sessionSpeciesSortMenu,
            icon: const Icon(AppIcons.sort),
            initialValue: _speciesSort,
            onSelected: _setSpeciesSort,
            itemBuilder:
                (context) => [
                  CheckedPopupMenuItem(
                    value: SpeciesSortMode.confidence,
                    checked: _speciesSort == SpeciesSortMode.confidence,
                    child: Text(l10n.sessionSpeciesSortConfidence),
                  ),
                  CheckedPopupMenuItem(
                    value: SpeciesSortMode.alphabetical,
                    checked: _speciesSort == SpeciesSortMode.alphabetical,
                    child: Text(l10n.sessionSpeciesSortAlphabetical),
                  ),
                  CheckedPopupMenuItem(
                    value: SpeciesSortMode.count,
                    checked: _speciesSort == SpeciesSortMode.count,
                    child: Text(l10n.sessionSpeciesSortCount),
                  ),
                  CheckedPopupMenuItem(
                    value: SpeciesSortMode.firstSeen,
                    checked: _speciesSort == SpeciesSortMode.firstSeen,
                    child: Text(l10n.sessionSpeciesSortFirstSeen),
                  ),
                ],
          ),
        ],
      ),
    );
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

      groups.add(
        _SpeciesGroup(
          scientificName: entry.key,
          commonName: sorted.first.commonName,
          clusters: clusters,
        ),
      );
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
    case SessionType.batchAnalysis:
      return l10n.sessionTypeBatchAnalysis;
    case SessionType.aru:
      return l10n.sessionTypeAru;
  }
}

/// Returns a numbered review-screen title such as "Live Session #3 Review".
///
/// Falls back to just the un-numbered type label when [session.sessionNumber]
/// is `null` (legacy sessions).
String _sessionReviewTitle(AppLocalizations l10n, LiveSession session) {
  if (session.customName != null && session.customName!.isNotEmpty) {
    return session.customName!;
  }
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
    case SessionType.batchAnalysis:
      return l10n.sessionTitleBatchAnalysisNum(n);
    case SessionType.aru:
      return l10n.sessionTitleAruNum(n);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fullscreen Survey Track Map
// ─────────────────────────────────────────────────────────────────────────────

/// Filter modes available on the fullscreen survey track map. The
/// confidence threshold is a separate slider that can stack with any of
/// these modes (e.g. "with audio" + ≥75% confidence).
enum _MapFilterMode { all, withAudio, manual }

/// Default confidence floor for the slider. 0.5 keeps every detection a
/// typical survey would keep, so the slider visibly reduces markers as
/// the user drags it up.
const double _defaultConfidenceFloor = 0.1;

/// Fullscreen map showing the complete survey track with species markers.
/// Tapping a species marker plays the detection's audio clip. The app bar
/// hosts a filter button that opens a bottom sheet for restricting which
/// detections are shown (audio only, manual additions, minimum
/// confidence, single species).
class _FullscreenSurveyMapScreen extends ConsumerStatefulWidget {
  const _FullscreenSurveyMapScreen({
    required this.session,
    required this.gpsTrack,
    required this.detections,
    this.initialHighlight,
    this.onConfirmChanged,
    this.onNoteChanged,
    this.onVoiceMemoChanged,
    this.onDeleteDetection,
  });

  /// Host session — forwarded to the clip player sheet so its share
  /// button can fall back to slicing the full recording when a marker
  /// has no per-detection clip of its own.
  final LiveSession session;

  final List<GpsPoint> gpsTrack;
  final List<DetectionRecord> detections;

  /// Invoked after the in-sheet confirm checkmark mutates a detection's
  /// [DetectionRecord.confirmedAt]. The host uses this hook to mark the
  /// session dirty and refresh derived UI (species rows, marker badges).
  final VoidCallback? onConfirmChanged;
  final VoidCallback? onNoteChanged;
  final VoidCallback? onVoiceMemoChanged;

  /// Invoked when the user picks `Delete detection` from the clip
  /// player sheet's overflow menu. The host removes the record from
  /// the session and surfaces the undo SnackBar; this screen rebuilds
  /// so the corresponding marker disappears immediately.
  final ValueChanged<DetectionRecord>? onDeleteDetection;

  /// Detection that the inline review map was currently focused on. When
  /// non-null the fullscreen map opens centered and zoomed in on this
  /// detection instead of fitting the whole track — keeps the user's
  /// place when expanding from the small map.
  final DetectionRecord? initialHighlight;

  @override
  ConsumerState<_FullscreenSurveyMapScreen> createState() =>
      _FullscreenSurveyMapScreenState();
}

class _FullscreenSurveyMapScreenState
    extends ConsumerState<_FullscreenSurveyMapScreen> {
  DetectionRecord? _highlight;
  _MapFilterMode _mode = _MapFilterMode.all;
  double _minConfidence = _defaultConfidenceFloor;
  String? _speciesFilter; // scientific name, or null for "all species"

  @override
  void initState() {
    super.initState();
    // Carry the inline map's focus into the fullscreen view so users land
    // on the same detection they were inspecting instead of being yanked
    // back out to a whole-track fit.
    _highlight = widget.initialHighlight;
  }

  bool get _isFilterActive =>
      _mode != _MapFilterMode.all ||
      _speciesFilter != null ||
      _minConfidence > _defaultConfidenceFloor;

  /// Localized one-line summary for the persistent filter chip — pinpoints
  /// what's currently hidden so users don't have to open the sheet to find
  /// out why some markers vanished. Order of precedence: species > mode >
  /// confidence > inactive.
  String _filterChipSummary(AppLocalizations l10n) {
    if (!_isFilterActive) return l10n.surveyMapFilterChipAll;
    if (_speciesFilter != null) {
      // Find any record with that scientific name to recover a display name.
      final match = widget.detections.firstWhere(
        (d) => d.scientificName == _speciesFilter,
        orElse: () => widget.detections.first,
      );
      return _localizedName(match.scientificName, match.commonName);
    }
    switch (_mode) {
      case _MapFilterMode.withAudio:
        return l10n.surveyMapFilterWithAudio;
      case _MapFilterMode.manual:
        return l10n.surveyMapFilterManual;
      case _MapFilterMode.all:
        // Only the confidence floor differs — show the threshold.
        return '≥ ${(_minConfidence * 100).round()}%';
    }
  }

  /// Localized common name for [sciName]. Falls back to the record's stored
  /// common name when the taxonomy hasn't loaded yet.
  String _localizedName(String sciName, String fallback) {
    final taxonomy = ref.watch(taxonomyServiceProvider).value;
    final speciesLocale = ref.watch(effectiveSpeciesLocaleProvider);
    return taxonomy?.lookup(sciName)?.commonNameForLocale(speciesLocale) ??
        fallback;
  }

  List<DetectionRecord> get _filtered {
    return widget.detections.where((d) {
      switch (_mode) {
        case _MapFilterMode.all:
          break;
        case _MapFilterMode.withAudio:
          final p = d.audioClipPath;
          if (p == null || !File(p).existsSync()) return false;
          break;
        case _MapFilterMode.manual:
          if (d.source != DetectionSource.manual &&
              d.source != DetectionSource.manualGlobal &&
              d.source != DetectionSource.userSpecified) {
            return false;
          }
          break;
      }
      if (d.confidence < _minConfidence) return false;
      if (_speciesFilter != null && d.scientificName != _speciesFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _onMarkerTap(DetectionRecord detection) async {
    // Only play markers whose own clip is still on disk. The map widget
    // already prefers the audio-bearing record when grouping, so a tap on
    // a "play badge" marker reaches us here with [audioClipPath] set; a
    // tap on a no-audio marker is a silent no-op.
    final path = detection.audioClipPath;
    if (path == null || !File(path).existsSync()) return;

    setState(() => _highlight = detection);

    // Build the prev/next neighbors from the *currently filtered* list,
    // restricted to detections that still have a playable clip on disk
    // \u2014 otherwise the skip button would open onto an empty sheet.
    // Ordered by timestamp so "next" / "prev" matches the user's mental
    // model of stepping forward / backward in time.
    final playable =
        _filtered.where((d) {
            final p = d.audioClipPath;
            return p != null && File(p).existsSync();
          }).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final idx = playable.indexOf(detection);
    final prev = idx > 0 ? playable[idx - 1] : null;
    final next =
        idx >= 0 && idx < playable.length - 1 ? playable[idx + 1] : null;

    await showClipPlayerSheet(
      context,
      detection: detection,
      session: widget.session,
      onPrevious:
          prev == null
              ? null
              : () {
                if (mounted) _onMarkerTap(prev);
              },
      onNext:
          next == null
              ? null
              : () {
                if (mounted) _onMarkerTap(next);
              },
      onConfirmChanged: () {
        // Rebuild this screen so the marker's confirmed badge updates
        // immediately, then forward to the host so the session is marked
        // dirty and the inline review screen refreshes on pop.
        if (mounted) setState(() {});
        widget.onConfirmChanged?.call();
      },
      onNoteChanged: () {
        if (mounted) setState(() {});
        widget.onNoteChanged?.call();
      },
      onVoiceMemoChanged: () {
        if (mounted) setState(() {});
        widget.onVoiceMemoChanged?.call();
      },
      onDelete:
          widget.onDeleteDetection == null
              ? null
              : () {
                widget.onDeleteDetection!(detection);
                if (mounted) setState(() => _highlight = null);
              },
    );
    if (mounted) setState(() => _highlight = null);
  }

  Future<void> _openFilterSheet() async {
    final l10n = AppLocalizations.of(context)!;

    // Build a localized, deduplicated species list once. Each entry
    // captures the scientific name (the filter key), the localized
    // display name, and a max-confidence value used to grey out species
    // that the current confidence floor would already exclude.
    final byScientific = <String, _SpeciesPickerEntry>{};
    for (final d in widget.detections) {
      final existing = byScientific[d.scientificName];
      final localized = _localizedName(d.scientificName, d.commonName);
      if (existing == null) {
        byScientific[d.scientificName] = _SpeciesPickerEntry(
          scientificName: d.scientificName,
          displayName: localized,
          maxConfidence: d.confidence,
        );
      } else if (d.confidence > existing.maxConfidence) {
        byScientific[d.scientificName] = existing.copyWith(
          maxConfidence: d.confidence,
        );
      }
    }
    final speciesEntries =
        byScientific.values.toList()..sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );

    // Live-apply changes as the user interacts (#33). Each chip /
    // slider / species tap fires `onChanged` and we update map state
    // immediately so the user can see markers appear/disappear without
    // hunting for an Apply button. Slider drags are debounced inside
    // the sheet so we don't rebuild the map on every pixel.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _MapFilterSheet(
          initialMode: _mode,
          initialMinConfidence: _minConfidence,
          initialSpecies: _speciesFilter,
          speciesEntries: speciesEntries,
          l10n: l10n,
          onChanged: (choice) {
            if (!mounted) return;
            setState(() {
              _mode = choice.mode;
              _minConfidence = choice.minConfidence;
              _speciesFilter = choice.species;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.surveyTrackMap),
            if (_isFilterActive)
              Text(
                l10n.surveyMapMatchCount(filtered.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(170),
                ),
              ),
          ],
        ),
        actions: [
          if (Platform.isIOS)
            IconButton(
              icon: const Icon(AppIcons.openInNew),
              tooltip: l10n.openInAppleMaps,
              onPressed: () {
                final lat =
                    widget.session.latitude ??
                    (widget.gpsTrack.isNotEmpty
                        ? widget.gpsTrack.first.latitude
                        : null);
                final lng =
                    widget.session.longitude ??
                    (widget.gpsTrack.isNotEmpty
                        ? widget.gpsTrack.first.longitude
                        : null);
                if (lat != null && lng != null) {
                  openExternalUrl(
                    context,
                    'https://maps.apple.com/?q=$lat,$lng',
                  );
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          SurveyMapWidget(
            gpsTrack: widget.gpsTrack,
            detections: filtered,
            autoFollow: false,
            fitAllPoints: true,
            highlightedDetection: _highlight,
            onMarkerTap: _onMarkerTap,
          ),
          // Persistent filter chip — promotes the AppBar action to a
          // first-class on-map affordance so the filter is discoverable
          // (#33: users were missing the AppBar icon entirely). The chip
          // shows the active filter summary so users can see at a glance
          // what's hiding markers.
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: _MapFilterChip(
                isActive: _isFilterActive,
                summary: _filterChipSummary(l10n),
                onTap: _openFilterSheet,
              ),
            ),
          ),
          if (filtered.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(AppIcons.infoOutline),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l10n.surveyMapFilterEmpty)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Captured state for one species in the filter sheet's picker.
class _SpeciesPickerEntry {
  const _SpeciesPickerEntry({
    required this.scientificName,
    required this.displayName,
    required this.maxConfidence,
  });

  final String scientificName;
  final String displayName;
  final double maxConfidence;

  _SpeciesPickerEntry copyWith({double? maxConfidence}) => _SpeciesPickerEntry(
    scientificName: scientificName,
    displayName: displayName,
    maxConfidence: maxConfidence ?? this.maxConfidence,
  );
}

/// Stateful filter sheet — extracted as its own widget so the search
/// field, mode chips, confidence slider, and species list each rebuild
/// in isolation when the user interacts with them.
class _MapFilterSheet extends StatefulWidget {
  const _MapFilterSheet({
    required this.initialMode,
    required this.initialMinConfidence,
    required this.initialSpecies,
    required this.speciesEntries,
    required this.l10n,
    required this.onChanged,
  });

  final _MapFilterMode initialMode;
  final double initialMinConfidence;
  final String? initialSpecies;
  final List<_SpeciesPickerEntry> speciesEntries;
  final AppLocalizations l10n;

  /// Fired whenever the user changes mode / confidence / species so the
  /// host can apply the new filter immediately (#33). Slider drags are
  /// debounced inside the sheet to avoid rebuilding the map per pixel.
  final ValueChanged<_MapFilterChoice> onChanged;

  @override
  State<_MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<_MapFilterSheet> {
  late _MapFilterMode _mode = widget.initialMode;
  late double _minConfidence = widget.initialMinConfidence;
  late String? _species = widget.initialSpecies;
  String _query = '';

  // Coalesces rapid slider drags so the map doesn't rebuild on every
  // pixel. ~200 ms feels responsive but prunes 90%+ of intermediate
  // events on a typical drag.
  Timer? _sliderDebounce;

  @override
  void dispose() {
    _sliderDebounce?.cancel();
    super.dispose();
  }

  void _emitNow() {
    widget.onChanged(
      _MapFilterChoice(
        mode: _mode,
        minConfidence: _minConfidence,
        species: _species,
      ),
    );
  }

  void _emitDebounced() {
    _sliderDebounce?.cancel();
    _sliderDebounce = Timer(const Duration(milliseconds: 200), _emitNow);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = widget.l10n;

    final lowerQuery = _query.trim().toLowerCase();
    final filteredSpecies =
        lowerQuery.isEmpty
            ? widget.speciesEntries
            : widget.speciesEntries
                .where(
                  (e) =>
                      e.displayName.toLowerCase().contains(lowerQuery) ||
                      e.scientificName.toLowerCase().contains(lowerQuery),
                )
                .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return Column(
            children: [
              // Drag handle.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.surveyMapFilterTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: [
                    // Mode chips.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.surveyMapFilterAll),
                          selected: _mode == _MapFilterMode.all,
                          onSelected: (_) {
                            setState(() => _mode = _MapFilterMode.all);
                            _emitNow();
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.surveyMapFilterWithAudio),
                          selected: _mode == _MapFilterMode.withAudio,
                          onSelected: (_) {
                            setState(() => _mode = _MapFilterMode.withAudio);
                            _emitNow();
                          },
                        ),
                        ChoiceChip(
                          label: Text(l10n.surveyMapFilterManual),
                          selected: _mode == _MapFilterMode.manual,
                          onSelected: (_) {
                            setState(() => _mode = _MapFilterMode.manual);
                            _emitNow();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Confidence slider.
                    Row(
                      children: [
                        Text(
                          l10n.surveyMapFilterMinConfidence,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(_minConfidence * 100).round()}%',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _minConfidence,
                      min: 0.1,
                      max: 0.99,
                      divisions: 89,
                      label: '${(_minConfidence * 100).round()}%',
                      onChanged: (v) {
                        setState(() => _minConfidence = v);
                        _emitDebounced();
                      },
                      onChangeEnd: (_) {
                        // Flush the final value immediately when the
                        // user lifts their finger so the map doesn't lag
                        // behind by the debounce interval.
                        _sliderDebounce?.cancel();
                        _emitNow();
                      },
                    ),
                    const SizedBox(height: 8),
                    // Species picker header + search.
                    Text(
                      l10n.surveyMapFilterSpecies,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(AppIcons.search, size: 20),
                        hintText: l10n.surveyMapFilterSpeciesSearchHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 8),
                    // "All species" pill — always visible at the top of
                    // the picker so clearing the species filter is one tap.
                    _SpeciesPickerTile(
                      label: l10n.surveyMapFilterAllSpecies,
                      selected: _species == null,
                      onTap: () {
                        setState(() => _species = null);
                        _emitNow();
                      },
                    ),
                    for (final e in filteredSpecies)
                      _SpeciesPickerTile(
                        label: e.displayName,
                        scientificName: e.scientificName,
                        selected: _species == e.scientificName,
                        onTap: () {
                          setState(() => _species = e.scientificName);
                          _emitNow();
                        },
                      ),
                  ],
                ),
              ),
              // Bottom action bar. Filter changes apply live (#33) so we
              // no longer need an Apply button — Done just dismisses.
              // Reset wipes filters in-place (still live) so the user can
              // see the full map come back without closing the sheet.
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _mode = _MapFilterMode.all;
                            _minConfidence = _defaultConfidenceFloor;
                            _species = null;
                          });
                          _sliderDebounce?.cancel();
                          _emitNow();
                        },
                        child: Text(l10n.clearFilters),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.done),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lightweight tappable row used by the species picker. Avoids the
/// heavy radio-list look (which felt cluttered with hundreds of
/// detections) and gives a clear selected-state pill.
class _SpeciesPickerTile extends ConsumerWidget {
  const _SpeciesPickerTile({
    required this.label,
    this.scientificName,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? scientificName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showSciNames = ref.watch(showSciNamesProvider);
    final displaySci =
        scientificName == null
            ? null
            : ref
                    .watch(taxonomyServiceProvider)
                    .value
                    ?.displayScientificName(scientificName!) ??
                scientificName;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(
              selected
                  ? AppIcons.checkCircleRounded
                  : AppIcons.radioButtonUnchecked,
              size: 20,
              color:
                  selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (showSciNames && displaySci != null && displaySci != label)
                    Text(
                      displaySci,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: _reviewOnSurface(theme, 180),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapFilterChoice {
  const _MapFilterChoice({
    required this.mode,
    required this.minConfidence,
    required this.species,
  });
  final _MapFilterMode mode;
  final double minConfidence;
  final String? species;
}

// -----------------------------------------------------------------------------
// _MapFilterChip � persistent on-map filter affordance.
//
// Promotes the filter from a hidden AppBar action to a chip overlay anchored
// top-right of the fullscreen survey map. Solves the discoverability problem
// reported in #33: users were missing the AppBar icon entirely. The chip
// also serves as a status read-out � its label always shows what the active
// filter is (All species, = 50%, Owl species, etc.) so users don't
// have to open the sheet to find out why some markers vanished.
// -----------------------------------------------------------------------------

class _MapFilterChip extends StatelessWidget {
  const _MapFilterChip({
    required this.isActive,
    required this.summary,
    required this.onTap,
  });

  final bool isActive;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg =
        isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.surface.withAlpha(230);
    final fg =
        isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    return Material(
      color: bg,
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.filterList, size: 18, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    summary,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
