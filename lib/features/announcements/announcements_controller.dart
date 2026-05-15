// =============================================================================
// AnnouncementsController
// =============================================================================
//
// The orchestration layer between detections (input) and TTS speech
// (output). Implements the throttling rules in §3.4 / §3.5 / §5.2 of
// `dev/announcements.md` plus the "speaker mode is stricter than
// headphones" runtime override.
//
// What this controller deliberately does NOT do:
//   - Read SharedPreferences directly. The Riverpod sink layer
//     gathers the live preset / numeric values and hands a
//     `AnnouncementsControllerConfig` snapshot to `announce()`.
//   - Touch the audio capture pipeline. It calls the injected
//     `RingBuffer.muteFor()` and trusts the buffer to do the right
//     thing — keeping ring-buffer policy in one place.
//   - Make any platform calls itself. `TtsEngine` and `RoutingService`
//     are interfaces, swapped for fakes in tests.
//
// Throttling rules implemented:
//   1. Startup grace — no speech for the first N seconds of a session.
//   2. Min interval between *any* two utterances (speaker profile is
//      stricter than headphones, applied at runtime).
//   3. Max per minute (sliding 60 s window; speaker profile stricter).
//   4. Streak silence — same species muted for N seconds after we
//      announced it, unless the silence gap exceeds streak threshold.
//   5. Recency reset — used by `selectBucket` via the signals built
//      here; no separate gate.
//   6. HFP downgrade abort — if routing reports BT-SCO mic, suppress.
//
// See dev/announcements.md §10 for the design decisions, in particular
// decision 7 (accessibility default-on) which is enforced *outside*
// this controller (at app startup) — the controller just consumes
// whatever `enabled` value it's given.
// =============================================================================

import 'dart:async';
import 'dart:math';

import '../audio/ring_buffer.dart';
import 'domain/announcement_presets.dart';
import 'domain/announcement_signals.dart';
import 'phrasing/phrasing_engine.dart';
import 'platform/routing_service.dart';
import 'platform/tts_engine.dart';

/// One detection as the controller sees it. Decoupled from the live
/// detection record so the controller can be unit-tested without
/// pulling the inference layer.
class AnnouncementDetection {
  /// Stable identifier for the species (sci-name or label index — the
  /// caller picks; the controller just compares for equality).
  final String speciesId;

  /// Localized name to speak.
  final String displayName;

  /// Raw 0–1 model score.
  final double score;

  /// Timestamp the detection was produced.
  final DateTime at;

  /// Optional precomputed "how common is this species here right now"
  /// bucket from the geo-model (see [CommonnessBin]). When non-null,
  /// the Chatty engine appends a one-line commonness phrase the *first*
  /// time the species is announced this session. Null when no location
  /// fix is available, the geo-model isn't loaded, or the species is
  /// not in the geo-model labels — the engine then skips the addendum.
  final CommonnessBin? commonness;

  /// `true` when the species is currently outside its annual peak at
  /// the user's location (current-week probability is well below the
  /// species' annual maximum). Lets the Chatty engine append a short
  /// "...not usually here this time of year" tail for migrants caught
  /// outside their normal window. Ignored when [commonness] is null
  /// or `rare` (where the seasonal hint adds no information).
  final bool isOutOfSeason;

  const AnnouncementDetection({
    required this.speciesId,
    required this.displayName,
    required this.score,
    required this.at,
    this.commonness,
    this.isOutOfSeason = false,
  });
}

/// Snapshot of all the throttling / preset values for a single
/// `announce()` call. Built by the sink layer from the Riverpod
/// providers; never owned by the controller.
class AnnouncementsControllerConfig {
  final bool enabled;
  final AnnouncementVerbosity verbosity;
  final FrequencyProfile profile;

  /// Allow speaking when the device is routed to its built-in
  /// loudspeaker. When `false`, announcements are suppressed in
  /// speaker mode (headphones / BT A2DP only).
  final bool speakerOutputAllowed;

  /// Mute the input ring buffer for the duration of an utterance so
  /// the TTS audio doesn't bleed back into inference. Turn off if you
  /// want detections to keep flowing while the phone speaks.
  final bool muteCaptureDuringSpeech;

  /// Request `transient_may_duck` audio focus so background media
  /// (music, podcasts) is briefly attenuated during speech.
  final bool duckOtherAudio;

  /// Play a short system alert tone immediately before each utterance
  /// so the listener has a beat to switch their attention.
  final bool prerollCue;

  /// Estimated TTS speech duration after which the ring-buffer mute
  /// window auto-expires. Used as a fallback when the engine doesn't
  /// report an exact end time. Kept as a separate config knob so we
  /// can tune it without touching the controller.
  final Duration mutePadding;

  const AnnouncementsControllerConfig({
    required this.enabled,
    required this.verbosity,
    required this.profile,
    this.speakerOutputAllowed = true,
    this.muteCaptureDuringSpeech = true,
    this.duckOtherAudio = true,
    this.prerollCue = true,
    this.mutePadding = const Duration(milliseconds: 400),
  });
}

/// Outcome of a single announce attempt. Useful for tests and for
/// surfacing "why nothing was spoken" in a debug view later.
enum AnnounceOutcome {
  spoken,
  disabled,
  startupGrace,
  minIntervalNotMet,
  maxPerMinuteHit,
  streakSilence,
  routingFailed,
  speakerOutputDisallowed,
  emptyBatch,
  duplicateInflight,
}

/// Per-species bookkeeping kept across `announce()` calls.
class _SpeciesState {
  DateTime lastAnnouncedAt;
  DateTime lastSeenAt;
  int streakLength;
  _SpeciesState({
    required this.lastAnnouncedAt,
    required this.lastSeenAt,
    required this.streakLength,
  });
}

class AnnouncementsController {
  PhrasingEngine _engine;
  final TtsEngine _tts;
  final RoutingService _routing;
  final RingBuffer _ringBuffer;
  final DateTime Function() _now;

  /// Estimated speech rate in characters per second, for sizing the
  /// ring-buffer mute window when the TTS engine completes
  /// asynchronously. Calibrated for a "normal" rate of 1.0; fast/slow
  /// users should still be covered by the [mutePadding] guard band.
  static const double _charsPerSecond = 14.0;

  final DateTime _sessionStartedAt;
  DateTime? _lastAnnouncedAt;
  final List<DateTime> _utteranceTimestamps = <DateTime>[];
  final Map<String, _SpeciesState> _bySpecies = <String, _SpeciesState>{};
  bool _speaking = false;

  AnnouncementsController({
    required PhrasingEngine engine,
    required TtsEngine tts,
    required RoutingService routing,
    required RingBuffer ringBuffer,
    DateTime Function()? now,
  }) : _engine = engine,
       _tts = tts,
       _routing = routing,
       _ringBuffer = ringBuffer,
       _now = now ?? DateTime.now,
       _sessionStartedAt = (now ?? DateTime.now)();

  /// Process a fresh batch of detections and decide whether to speak.
  ///
  /// The batch typically holds the top 1–N detections produced by the
  /// most recent inference cycle. The controller picks at most one
  /// utterance per call (a single-species announce or a coalesced
  /// multi-species announce).
  Future<AnnounceOutcome> announce(
    List<AnnouncementDetection> detections,
    AnnouncementsControllerConfig config,
  ) async {
    if (!config.enabled) return AnnounceOutcome.disabled;
    if (detections.isEmpty) return AnnounceOutcome.emptyBatch;
    if (_speaking) return AnnounceOutcome.duplicateInflight;

    final now = _now();
    final profile = config.profile;
    final isSpeaker = _routing.isSpeakerOutput;
    final minIntervalSec =
        isSpeaker
            ? profile.minIntervalSecondsSpeaker
            : profile.minIntervalSeconds;
    final maxPerMin =
        isSpeaker ? profile.maxPerMinuteSpeaker : profile.maxPerMinute;

    // 1. Startup grace.
    if (now.difference(_sessionStartedAt).inSeconds <
        profile.startupGraceSeconds) {
      _touchSpecies(detections, now);
      return AnnounceOutcome.startupGrace;
    }

    // 2. Global min-interval gate.
    final last = _lastAnnouncedAt;
    if (last != null && now.difference(last).inSeconds < minIntervalSec) {
      _touchSpecies(detections, now);
      return AnnounceOutcome.minIntervalNotMet;
    }

    // 3. Max-per-minute sliding window.
    _utteranceTimestamps.removeWhere((t) => now.difference(t).inSeconds >= 60);
    if (_utteranceTimestamps.length >= maxPerMin) {
      _touchSpecies(detections, now);
      return AnnounceOutcome.maxPerMinuteHit;
    }

    // Decide whether this is a single-species or coalesced batch. The
    // sink coalesces by §3.6 already; here we just look at the unique
    // speciesIds present.
    final unique = <String, AnnouncementDetection>{};
    for (final d in detections) {
      final existing = unique[d.speciesId];
      if (existing == null || d.score > existing.score) {
        unique[d.speciesId] = d;
      }
    }
    final pickedDetections = unique.values.toList(growable: false);

    String text;
    List<String> spokenSpeciesIds;

    if (pickedDetections.length == 1) {
      final det = pickedDetections.first;
      // 4. Streak silence — per-species mute.
      final st = _bySpecies[det.speciesId];
      if (st != null) {
        final sinceLastSpoken = now.difference(st.lastAnnouncedAt).inSeconds;
        if (sinceLastSpoken < profile.streakSilenceSeconds) {
          _touchSpecies(detections, now);
          return AnnounceOutcome.streakSilence;
        }
      }
      final signals = _signalsFor(det, profile, now);
      text = _engine.speakOne(
        name: det.displayName,
        signals: signals,
        verbosity: config.verbosity,
      );
      spokenSpeciesIds = [det.speciesId];
    } else {
      // Coalesced multi-species: pick the highest-scoring N (engine
      // handles the H_three / H_many split internally).
      final sorted =
          pickedDetections.toList()..sort((a, b) => b.score.compareTo(a.score));
      final top = sorted.take(4).toList();
      text = _engine.speakMany(
        names: top.map((d) => d.displayName).toList(growable: false),
        verbosity: config.verbosity,
      );
      spokenSpeciesIds = top.map((d) => d.speciesId).toList(growable: false);
    }

    if (text.isEmpty) return AnnounceOutcome.emptyBatch;

    // Routing — last gate before we touch the speaker.
    final routing = await _routing.prepareForSpeech(
      duckOtherAudio: config.duckOtherAudio,
    );
    if (routing != RoutingState.ok) {
      _touchSpecies(detections, now);
      return AnnounceOutcome.routingFailed;
    }

    // Honour "don't speak through the built-in loudspeaker". We check
    // after `prepareForSpeech` so the routing state reflects whatever
    // the audio session resolved to.
    if (!config.speakerOutputAllowed && _routing.isSpeakerOutput) {
      _touchSpecies(detections, now);
      return AnnounceOutcome.speakerOutputDisallowed;
    }

    // Mute the input ring buffer for the estimated speech duration
    // plus a small guard band. The actual TTS speak() future settles
    // when the engine reports completion; we unmute either way.
    final estimated = _estimateDuration(text) + config.mutePadding;
    final shouldMute = config.muteCaptureDuringSpeech;
    if (shouldMute) {
      _ringBuffer.muteFor(estimated);
    }

    _speaking = true;
    try {
      if (config.prerollCue) {
        await _tts.playPrerollCue();
      }
      await _tts.speak(text);
    } finally {
      _speaking = false;
      if (shouldMute) {
        _ringBuffer.unmute();
      }
    }

    final spokenAt = _now();
    _lastAnnouncedAt = spokenAt;
    _utteranceTimestamps.add(spokenAt);
    for (final id in spokenSpeciesIds) {
      _bySpecies[id] = _SpeciesState(
        lastAnnouncedAt: spokenAt,
        lastSeenAt: spokenAt,
        streakLength: (_bySpecies[id]?.streakLength ?? 0) + 1,
      );
    }
    _touchSpecies(detections, spokenAt);

    return AnnounceOutcome.spoken;
  }

  /// Reset all per-session bookkeeping. Called when the user starts a
  /// new Live / Survey / Point Count session.
  void resetSession() {
    _lastAnnouncedAt = null;
    _utteranceTimestamps.clear();
    _bySpecies.clear();
    _engine.reset();
  }

  /// Swap in a freshly built phrasing engine — used by the sink when
  /// the user changes their species/voice language mid-session and we
  /// need to point at a different template bundle without resetting
  /// throttling state.
  void replaceEngine(PhrasingEngine engine) {
    _engine = engine;
  }

  // ---- internals ----

  /// Build the `AnnouncementSignals` for a single detection given the
  /// current per-species state.
  AnnouncementSignals _signalsFor(
    AnnouncementDetection det,
    FrequencyProfile profile,
    DateTime now,
  ) {
    final st = _bySpecies[det.speciesId];
    final isFirstInSession = st == null;
    // "First time we're actually about to *speak* this species." A
    // species can be `_touchSpecies`'d for many cycles while the
    // throttling gates filter it out; the lastAnnouncedAt sentinel
    // (epoch) marks "seen but never voiced". This is the trigger for
    // the Chatty commonness/season tag-on.
    final isFirstAnnouncement =
        st == null || st.lastAnnouncedAt.millisecondsSinceEpoch == 0;
    final isRecent =
        st != null &&
        now.difference(st.lastSeenAt).inSeconds < profile.recencyResetSeconds;
    final streakLength =
        st == null
            ? 1
            : (now.difference(st.lastSeenAt).inSeconds <
                    profile.streakSilenceSeconds
                ? st.streakLength + 1
                : 1);
    return AnnouncementSignals(
      confidence: confidenceBinFor(det.score),
      isRecent: isRecent,
      isFirstInSession: isFirstInSession,
      isFirstAnnouncement: isFirstAnnouncement,
      streakLength: streakLength,
      commonness: det.commonness,
      // The seasonal tail only adds information when the species is
      // common enough at this location for "off-peak" to mean
      // something. For genuinely rare birds the tail would just
      // restate the obvious.
      isOutOfSeason:
          det.isOutOfSeason &&
          det.commonness != null &&
          det.commonness != CommonnessBin.rare,
    );
  }

  void _touchSpecies(List<AnnouncementDetection> dets, DateTime now) {
    for (final d in dets) {
      final st = _bySpecies[d.speciesId];
      if (st == null) {
        _bySpecies[d.speciesId] = _SpeciesState(
          lastAnnouncedAt: DateTime.fromMillisecondsSinceEpoch(0),
          lastSeenAt: now,
          streakLength: 1,
        );
      } else {
        st.lastSeenAt = now;
      }
    }
  }

  Duration _estimateDuration(String text) {
    final secs = max(0.5, text.length / _charsPerSecond);
    return Duration(milliseconds: (secs * 1000).round());
  }
}
