// =============================================================================
// AnnouncementsTtsAdapter
// =============================================================================
//
// Thin abstraction over `flutter_tts` for the Announcements feature.
// The interface (`TtsEngine`) is small on purpose — the controller and
// tests should never reach into platform plugin details. Tests can
// inject a `FakeTtsEngine` (or Mocktail mock) without touching
// MethodChannels.
//
// Responsibilities:
//   - Initialize the platform engine for the user's voice locale,
//     rate, and pitch.
//   - Speak an utterance and return a `Future<void>` that completes
//     when the platform reports speech end (so the caller can clear
//     the ring-buffer mute window at exactly the right moment).
//   - Forward platform errors as exceptions instead of silent drops.
//
// Routing (which output device speech goes to) is the
// `AnnouncementsRoutingService`'s job, not this adapter's — keeping
// concerns separable means we can unit-test rate/pitch/queueing in
// isolation from the Bluetooth-route mess.
//
// See `dev/announcements.md` §4 for engine choice and §3.4–3.5 for
// throttling context.
// =============================================================================

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Pure interface — what the rest of the Announcements code touches.
abstract class TtsEngine {
  /// Configure the platform voice for [languageTag] (BCP-47, e.g.
  /// `en-US`), [rate] (0.5–1.5, where 1.0 is the platform default
  /// "normal" pace), and [pitch] (0.7–1.3).
  ///
  /// Safe to call repeatedly when the user changes settings.
  Future<void> configure({
    required String languageTag,
    required double rate,
    required double pitch,
  });

  /// Speak [text] and complete when the platform signals speech end.
  ///
  /// If a previous utterance is still playing it is cancelled before
  /// the new one starts (never queued — stale calls have no value).
  Future<void> speak(String text);

  /// Play a short pre-roll cue (system alert tone) before an
  /// utterance to give the listener a moment to switch attention.
  /// Fire-and-forget on failure — the cue is decorative and must
  /// never block speech.
  Future<void> playPrerollCue();

  /// Cancel any in-flight utterance immediately.
  Future<void> stop();

  /// Release platform resources. Safe to call multiple times.
  Future<void> dispose();
}

/// Production [TtsEngine] backed by `flutter_tts`.
class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  Completer<void>? _activeUtterance;

  String? _languageTag;
  double? _rate;
  double? _pitch;
  bool _handlersWired = false;

  @override
  Future<void> configure({
    required String languageTag,
    required double rate,
    required double pitch,
  }) async {
    if (!_handlersWired) {
      _tts.setCompletionHandler(() {
        _activeUtterance?.complete();
        _activeUtterance = null;
      });
      _tts.setCancelHandler(() {
        _activeUtterance?.complete();
        _activeUtterance = null;
      });
      _tts.setErrorHandler((msg) {
        final err = StateError('TTS error: $msg');
        _activeUtterance?.completeError(err);
        _activeUtterance = null;
      });
      _handlersWired = true;
    }
    if (_languageTag != languageTag) {
      await _tts.setLanguage(languageTag);
      _languageTag = languageTag;
    }
    if (_rate != rate) {
      // flutter_tts speech rates: Android 0.0–1.0 (0.5 = normal),
      // iOS 0.0–1.0 (0.5 = normal). Map our 0.5–1.5 range so 1.0 ≈
      // platform default (0.5 of plugin units).
      await _tts.setSpeechRate(rate * 0.5);
      _rate = rate;
    }
    if (_pitch != pitch) {
      await _tts.setPitch(pitch);
      _pitch = pitch;
    }
  }

  @override
  Future<void> speak(String text) async {
    // Cancel any in-flight utterance so we never queue.
    final inflight = _activeUtterance;
    if (inflight != null && !inflight.isCompleted) {
      await _tts.stop();
      // Don't await `inflight.future` here — `setCancelHandler` will
      // complete it as part of `stop()`.
    }
    final completer = Completer<void>();
    _activeUtterance = completer;
    await _tts.speak(text);
    return completer.future;
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    final inflight = _activeUtterance;
    if (inflight != null && !inflight.isCompleted) {
      inflight.complete();
    }
    _activeUtterance = null;
  }

  @override
  Future<void> playPrerollCue() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      // Give the OS a brief moment to render the tone before speech
      // starts so the cue isn't talked over.
      await Future<void>.delayed(const Duration(milliseconds: 180));
    } catch (_) {
      // Cue tone is decorative — never let a platform hiccup block
      // the actual announcement.
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
  }
}
