// =============================================================================
// PlatformTtsEngine
// =============================================================================
//
// Thin abstraction over the app's own `com.birdnet/tts` platform channel for
// the Announcements feature. The interface (`TtsEngine`) is small on purpose —
// the controller and tests should never reach into platform details. Tests
// can inject a `FakeTtsEngine` (or Mocktail mock) without touching
// MethodChannels.
//
// Why an in-house channel instead of a plugin: the `flutter_tts` plugin we
// shipped before created its Android `TextToSpeech` instance on every app
// launch and probed the engine from `onInit` on the main thread. Each of
// those calls is a blocking Binder round-trip into the engine process, and a
// slow engine produced Play Console ANRs. The native halves of this channel
// (`TtsChannel.kt`, `TtsChannel.swift`, `tts_channel.cpp`) create the engine
// lazily on first use and keep every engine call off the UI thread.
//
// Channel contract (arguments are maps, replies are plain values):
//   setLanguage {tag}        -> bool   a voice for the BCP-47 tag was applied;
//                                      also drops any pinned voice
//   setVoice {name, locale}  -> bool   the installed voice was applied
//   setRate {rate}           -> null   1.0 = the platform's normal pace
//   setPitch {pitch}         -> null   1.0 = the platform's normal pitch
//   getVoices                -> [{name, locale}]
//   speak {text}             -> bool   settles when the utterance ends;
//                                      false when it was stopped or failed
//   stop                     -> null   also settles a pending speak
//
// Robustness (this was the "flaky TTS" bug): `speak` settles on the native
// completion callback, and we wrap it in a duration-scaled timeout so even a
// totally silent OEM engine unblocks the announcement pipeline.
//
// Language resolution: we probe `setLanguage` down a fallback chain
// (exact → language-only → en-US → en), producing a predictable fallback
// when the requested language is not installed.
//
// Routing (which output device speech goes to) is the
// `AnnouncementsRoutingService`'s job, not this adapter's — keeping
// concerns separable means we can unit-test rate/pitch/queueing in
// isolation from the Bluetooth-route mess.
// =============================================================================

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';

/// A selectable platform voice. `name` is the engine-specific voice
/// identifier (what `setVoice` expects); `locale` is the BCP-47 tag the
/// voice speaks. Both come straight from the platform's voice list.
class TtsVoice {
  final String name;
  final String locale;
  const TtsVoice({required this.name, required this.locale});

  @override
  bool operator ==(Object other) =>
      other is TtsVoice && other.name == name && other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);
}

/// Pure interface — what the rest of the Announcements code touches.
abstract class TtsEngine {
  /// Configure the platform voice for [languageTag] (BCP-47, e.g.
  /// `en-US`), [rate] (0.5–1.5, where 1.0 is the platform default
  /// "normal" pace), and [pitch] (0.7–1.3).
  ///
  /// [voiceName] optionally pins a specific installed voice (as returned
  /// by [PlatformTtsEngine.voicesForLanguage]); `null`/empty leaves the
  /// platform default voice for the resolved language.
  ///
  /// Safe to call repeatedly when the user changes settings.
  Future<void> configure({
    required String languageTag,
    required double rate,
    required double pitch,
    String? voiceName,
  });

  /// Speak [text] and complete when the platform signals speech end (or
  /// a safety timeout elapses — see the class header).
  ///
  /// If a previous utterance is still playing it is cancelled before
  /// the new one starts (never queued — stale calls have no value).
  Future<void> speak(String text);

  /// Play a short pre-roll cue before an utterance to give the listener
  /// a moment to switch attention. Fire-and-forget on failure — the cue
  /// is decorative and must never block speech.
  Future<void> playPrerollCue();

  /// Cancel any in-flight utterance immediately.
  Future<void> stop();

  /// Release platform resources. Safe to call multiple times.
  Future<void> dispose();
}

/// Production [TtsEngine] backed by the app's `com.birdnet/tts` channel.
class PlatformTtsEngine implements TtsEngine {
  PlatformTtsEngine({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  /// The app-owned platform channel. Exposed so tests can mock it.
  static const MethodChannel defaultChannel = MethodChannel('com.birdnet/tts');

  final MethodChannel _channel;

  /// Approx characters spoken per second at normal rate, used only to
  /// size the safety timeout on [speak]. Deliberately pessimistic (slow)
  /// so the guard band is generous.
  static const double _charsPerSecond = 11.0;

  String? _requestedLanguage; // last tag asked for (before fallback)
  String? _appliedLanguage; // tag actually set on the engine
  double? _rate;
  double? _pitch;
  String? _appliedVoiceName; // null ⇒ platform default voice

  @override
  Future<void> configure({
    required String languageTag,
    required double rate,
    required double pitch,
    String? voiceName,
  }) async {
    if (_requestedLanguage != languageTag) {
      final resolved = await _resolveLanguage(languageTag);
      if (resolved != null) {
        _appliedLanguage = resolved;
        // Applying a language resets the engine to that language's
        // default voice, so any prior explicit pin no longer applies.
        _appliedVoiceName = null;
      }
      _requestedLanguage = languageTag;
    }

    if (_rate != rate) {
      await _channel.invokeMethod<void>('setRate', {'rate': rate});
      _rate = rate;
    }
    if (_pitch != pitch) {
      await _channel.invokeMethod<void>('setPitch', {'pitch': pitch});
      _pitch = pitch;
    }

    await _applyVoice(voiceName);
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    // Cancel anything still playing. The controller serialises calls, but
    // a stray in-flight utterance (e.g. a preview) must not overlap.
    await stop();

    // Hard ceiling: even if the engine never reports completion, the
    // pipeline must unblock.
    final guard = speakGuard(text, _rate ?? 1.0);
    try {
      // The native side settles this future when the utterance ends.
      await _channel.invokeMethod<bool>('speak', {'text': text}).timeout(guard);
    } on TimeoutException {
      await stop();
    }
  }

  /// Safety timeout for [speak]: scaled by text length so long Chatty
  /// sentences get room, slowed down for slower rates (at 0.5× the same
  /// sentence takes about twice as long), plus a fixed guard band for
  /// engine latency.
  @visibleForTesting
  static Duration speakGuard(String text, double rate) {
    final rateMultiplier = rate.clamp(0.5, 1.5);
    final estMs = (text.length / (_charsPerSecond * rateMultiplier) * 1000)
        .round();
    return Duration(milliseconds: estMs + 6000);
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  @override
  Future<void> playPrerollCue() async {
    try {
      // `alert` is a genuine tone on iOS; on much of Android it is a
      // no-op, so we also fire a light haptic as a fallback pre-cue.
      await SystemSound.play(SystemSoundType.alert);
      if (!kIsWeb && Platform.isAndroid) {
        await HapticFeedback.selectionClick();
      }
      // Give the OS a brief moment to render the cue before speech starts
      // so it isn't talked over.
      await Future<void>.delayed(const Duration(milliseconds: 160));
    } catch (_) {
      // Cue is decorative — never let a platform hiccup block speech.
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
  }

  /// Voices installed for [languageTag] (matched on language subtag), for
  /// the Settings voice picker. Returns an empty list when the engine
  /// exposes no voices (some minimal Android engines) — the caller then
  /// shows a "manage voices in system settings" hint.
  Future<List<TtsVoice>> voicesForLanguage(String languageTag) async {
    final subtag = _subtag(languageTag);
    final raw = await _rawVoices();
    final seen = <String>{};
    final out = <TtsVoice>[];
    for (final v in raw) {
      final name = v['name'];
      final locale = v['locale'] ?? '';
      if (name == null || name.isEmpty) continue;
      if (subtag.isNotEmpty && _subtag(locale) != subtag) continue;
      if (!seen.add(name)) continue;
      out.add(TtsVoice(name: name, locale: locale));
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  // --- internals -----------------------------------------------------------

  /// Apply [tag] or one of its fallbacks and return the first tag the
  /// engine accepted, or `null` to leave the current language in place.
  /// The explicit English tail gives devices without the requested
  /// language a predictable last resort instead of relying on an OEM's
  /// undocumented fallback.
  Future<String?> _resolveLanguage(String tag) async {
    for (final candidate in _languageCandidates(tag)) {
      try {
        final ok = await _channel.invokeMethod<bool>('setLanguage', {
          'tag': candidate,
        });
        if (ok == true) return candidate;
      } catch (_) {
        // setLanguage can throw on odd engines; keep probing.
      }
    }
    return null;
  }

  Future<void> _applyVoice(String? voiceName) async {
    final target = (voiceName == null || voiceName.isEmpty) ? null : voiceName;
    if (target == _appliedVoiceName) return;

    if (target == null) {
      // Revert to the platform default voice for the resolved language.
      await _reapplyLanguage();
      _appliedVoiceName = null;
      return;
    }

    try {
      final raw = await _rawVoices();
      Map<String, String>? match;
      final languageSubtag = _subtag(_appliedLanguage ?? '');
      for (final v in raw) {
        final voiceSubtag = _subtag(v['locale'] ?? '');
        if (v['name'] == target &&
            (languageSubtag.isEmpty || voiceSubtag == languageSubtag)) {
          match = v;
          break;
        }
      }
      if (match != null) {
        final ok = await _channel.invokeMethod<bool>('setVoice', {
          'name': match['name']!,
          'locale': match['locale'] ?? _appliedLanguage ?? '',
        });
        if (ok == true) {
          _appliedVoiceName = target;
          return;
        }
      }
      // A persisted voice may have been removed, or may belong to the
      // language used before the species-name locale changed. Reapply the
      // resolved language so an old explicit voice cannot remain active.
      await _reapplyLanguage();
      _appliedVoiceName = null;
    } catch (_) {}
  }

  Future<void> _reapplyLanguage() async {
    final lang = _appliedLanguage;
    if (lang == null) return;
    try {
      await _channel.invokeMethod<bool>('setLanguage', {'tag': lang});
    } catch (_) {}
  }

  Future<List<Map<String, String>>> _rawVoices() async {
    try {
      final list = await _channel.invokeMethod<List<dynamic>>('getVoices');
      if (list == null) return const [];
      return [
        for (final e in list)
          if (e is Map)
            {
              for (final entry in e.entries)
                entry.key.toString(): entry.value.toString(),
            },
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Fallback chain for language resolution: exact tag, language-only,
  /// then English. Deduped, order preserved.
  static List<String> _languageCandidates(String tag) {
    final normalized = tag.replaceAll('_', '-').trim();
    final out = <String>[];
    void add(String s) {
      if (s.isNotEmpty && !out.contains(s)) out.add(s);
    }

    add(normalized);
    final dash = normalized.indexOf('-');
    if (dash > 0) add(normalized.substring(0, dash));
    add('en-US');
    add('en');
    return out;
  }

  static String _subtag(String tag) {
    final normalized = tag.replaceAll('_', '-').trim().toLowerCase();
    if (normalized.isEmpty) return '';
    final dash = normalized.indexOf('-');
    return dash > 0 ? normalized.substring(0, dash) : normalized;
  }
}
