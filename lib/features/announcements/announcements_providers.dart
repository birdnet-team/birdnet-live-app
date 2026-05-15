// =============================================================================
// AnnouncementsProviders
// =============================================================================
//
// Riverpod providers for the Announcements feature. Each user-facing
// setting is a `StateNotifierProvider` backed by `SharedPreferences`,
// following the same pattern as `lib/shared/providers/settings_providers.dart`.
//
// Verbosity / Frequency presets use a dedicated `AnnouncementsPresetNotifier`
// instead of the generic `StringSettingNotifier` because flipping a
// preset must *also* stamp the matching numeric profile into the
// Advanced prefs in one transaction (§6.1 of dev/announcements.md).
// Conversely, manually editing an Advanced numeric needs to downgrade
// the displayed preset to `custom` so the UI never lies; that downgrade
// is the responsibility of the Advanced setters and is not yet wired
// (Phase 3 — settings UI).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';
import 'domain/announcement_presets.dart';

// ---------------------------------------------------------------------------
// Master toggles
// ---------------------------------------------------------------------------

/// Master enable. Default `false`; flipped by the setup wizard.
final announcementsEnabledProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.announcementsEnabled, false);
    });

/// `true` once the user finished the 5-step setup wizard at least once.
/// Prevents the wizard from auto-opening a second time.
final announcementsWizardCompletedProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(
        prefs,
        PrefKeys.announcementsWizardCompleted,
        false,
      );
    });

// ---------------------------------------------------------------------------
// Presets — verbosity & frequency
// ---------------------------------------------------------------------------

/// User-facing verbosity preset. See [AnnouncementVerbosity] and §3 of
/// dev/announcements.md.
final announcementsVerbosityProvider =
    StateNotifierProvider<_VerbosityNotifier, AnnouncementVerbosity>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return _VerbosityNotifier(prefs);
    });

/// User-facing frequency preset. Setting this also stamps the matching
/// [FrequencyProfile] into all the Advanced numeric prefs so the
/// engine's behaviour matches what the UI claims.
final announcementsFrequencyProvider =
    StateNotifierProvider<_FrequencyNotifier, AnnouncementFrequency>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return _FrequencyNotifier(prefs);
    });

// ---------------------------------------------------------------------------
// Voice
// ---------------------------------------------------------------------------

/// BCP-47 voice locale (e.g. `en-US`). Empty string ⇒ track UI locale.
final announcementsVoiceLanguageProvider =
    StateNotifierProvider<StringSettingNotifier, String>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return StringSettingNotifier(
        prefs,
        PrefKeys.announcementsVoiceLanguage,
        '',
      );
    });

/// TTS rate multiplier (0.5–1.5).
final announcementsVoiceRateProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(prefs, PrefKeys.announcementsVoiceRate, 1.0);
    });

/// TTS pitch multiplier (0.7–1.3).
final announcementsVoicePitchProvider =
    StateNotifierProvider<DoubleSettingNotifier, double>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DoubleSettingNotifier(
        prefs,
        PrefKeys.announcementsVoicePitch,
        1.0,
      );
    });

// ---------------------------------------------------------------------------
// Advanced — routing / capture
// ---------------------------------------------------------------------------

/// Allow speaking through the device's built-in loudspeaker.
/// Default `true` so the app speaks out of the box; users who want
/// headphones-only operation can disable this in the advanced
/// announcements settings.
final announcementsSpeakerOutputAllowedProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(
        prefs,
        PrefKeys.announcementsSpeakerOutputAllowed,
        true,
      );
    });

/// Mute the input ring buffer for the duration of an utterance plus
/// the routing-mode guard band.
///
/// Defaults to `false`: on Android, briefly muting the active
/// `AudioRecord` stream produces a visible wobble in the live
/// spectrogram (the empty samples render as a flat band), and modern
/// TTS engines don't bleed loud enough through the built-in mic to
/// cause spurious detections in practice. Users who notice false
/// positives during long announcements can opt in.
final announcementsMuteCaptureDuringSpeechProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(
        prefs,
        PrefKeys.announcementsMuteCaptureDuringSpeech,
        false,
      );
    });

/// Request `transient_may_duck` audio focus.
final announcementsDuckOtherAudioProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(
        prefs,
        PrefKeys.announcementsDuckOtherAudio,
        true,
      );
    });

/// Play a short pre-roll cue tone before each utterance (§10 dec. 2).
final announcementsPrerollCueProvider =
    StateNotifierProvider<BoolSettingNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return BoolSettingNotifier(prefs, PrefKeys.announcementsPrerollCue, true);
    });

// ---------------------------------------------------------------------------
// Advanced — throttling numerics (stamped by frequency presets)
// ---------------------------------------------------------------------------

final announcementsStartupGraceSecondsProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(
        prefs,
        PrefKeys.announcementsStartupGraceSeconds,
        30,
      );
    });

final announcementsMinIntervalSecondsProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(
        prefs,
        PrefKeys.announcementsMinIntervalSeconds,
        8,
      );
    });

final announcementsMaxPerMinuteProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(prefs, PrefKeys.announcementsMaxPerMinute, 6);
    });

final announcementsStreakSilenceSecondsProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(
        prefs,
        PrefKeys.announcementsStreakSilenceSeconds,
        45,
      );
    });

final announcementsRecencyResetSecondsProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(
        prefs,
        PrefKeys.announcementsRecencyResetSeconds,
        120,
      );
    });

final announcementsSessionResetSecondsProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(
        prefs,
        PrefKeys.announcementsSessionResetSeconds,
        900,
      );
    });

final announcementsCoalesceWindowSecondsProvider =
    StateNotifierProvider<IntSettingNotifier, int>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return IntSettingNotifier(
        prefs,
        PrefKeys.announcementsCoalesceWindowSeconds,
        3,
      );
    });

// Trigger mode (`What to announce` picker) was removed in 0.13.8.
// The PrefKey is left declared so older installs don't see schema
// migration errors, but the provider is gone — the controller never
// honoured the value anyway.

// ---------------------------------------------------------------------------
// Custom notifiers
// ---------------------------------------------------------------------------

class _VerbosityNotifier extends StateNotifier<AnnouncementVerbosity> {
  _VerbosityNotifier(this._prefs)
    : super(parseVerbosity(_prefs.getString(PrefKeys.announcementsVerbosity)));

  final SharedPreferences _prefs;

  Future<void> set(AnnouncementVerbosity value) async {
    state = value;
    await _prefs.setString(PrefKeys.announcementsVerbosity, value.name);
  }
}

/// Frequency preset notifier. Setting a non-`custom` value also writes
/// the matching [FrequencyProfile] into the Advanced numeric prefs in
/// one batch — this is the contract documented in §6.1 of
/// dev/announcements.md.
class _FrequencyNotifier extends StateNotifier<AnnouncementFrequency> {
  _FrequencyNotifier(this._prefs)
    : super(parseFrequency(_prefs.getString(PrefKeys.announcementsFrequency)));

  final SharedPreferences _prefs;

  Future<void> set(AnnouncementFrequency value) async {
    state = value;
    await _prefs.setString(PrefKeys.announcementsFrequency, value.name);
    final profile = frequencyProfileFor(value);
    if (profile == null) return;
    await Future.wait([
      _prefs.setInt(
        PrefKeys.announcementsStartupGraceSeconds,
        profile.startupGraceSeconds,
      ),
      _prefs.setInt(
        PrefKeys.announcementsMinIntervalSeconds,
        profile.minIntervalSeconds,
      ),
      _prefs.setInt(PrefKeys.announcementsMaxPerMinute, profile.maxPerMinute),
      _prefs.setInt(
        PrefKeys.announcementsStreakSilenceSeconds,
        profile.streakSilenceSeconds,
      ),
      _prefs.setInt(
        PrefKeys.announcementsRecencyResetSeconds,
        profile.recencyResetSeconds,
      ),
      _prefs.setInt(
        PrefKeys.announcementsSessionResetSeconds,
        profile.sessionResetSeconds,
      ),
      _prefs.setInt(
        PrefKeys.announcementsCoalesceWindowSeconds,
        profile.coalesceWindowSeconds,
      ),
    ]);
  }
}
