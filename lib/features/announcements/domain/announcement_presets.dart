// =============================================================================
// AnnouncementPresets
// =============================================================================
//
// The two user-facing knobs (§3 intro of dev/announcements.md):
//
//   • Verbosity  — minimal | balanced (default) | chatty | custom
//   • Frequency  — rare | sparse | normal (default) | frequent | constant
//                  | custom
//
// Each preset stamps a fixed set of Advanced numerics into shared
// preferences in one transaction. The settings layer is responsible
// for the write; this file only owns the *profiles* (the value tables)
// and the parse/format helpers so every part of the codebase agrees on
// what a preset means.
//
// `custom` is never picked by the wizard — it appears only as the
// downgrade target when the user manually edits an Advanced numeric
// and we need to stop claiming a named preset is in effect.
// =============================================================================

/// How talkative the phrasing engine should be inside a bucket. See the
/// file header and §3 of dev/announcements.md.
enum AnnouncementVerbosity { minimal, balanced, chatty, custom }

/// How often the controller is allowed to speak. Maps to the throttling
/// constants below via [FrequencyProfile].
///
/// The five named levels span the practical range from "barely speaks at
/// all" ([rare]) to "keeps up with every detection cycle, no startup
/// delay" ([constant]). [custom] is the downgrade target when the user
/// edits an Advanced numeric individually.
enum AnnouncementFrequency { rare, sparse, normal, frequent, constant, custom }

/// Round-trip safe enum parsing — used by the providers to decode the
/// string-backed pref values. Anything unrecognized falls back to the
/// default ([AnnouncementVerbosity.balanced]) so a corrupted pref never
/// crashes startup.
AnnouncementVerbosity parseVerbosity(String? raw) {
  for (final v in AnnouncementVerbosity.values) {
    if (v.name == raw) return v;
  }
  return AnnouncementVerbosity.balanced;
}

/// Round-trip safe enum parsing for [AnnouncementFrequency]. Defaults
/// to [AnnouncementFrequency.normal].
AnnouncementFrequency parseFrequency(String? raw) {
  for (final f in AnnouncementFrequency.values) {
    if (f.name == raw) return f;
  }
  return AnnouncementFrequency.normal;
}

/// The numeric throttling constants a frequency preset stamps into
/// shared preferences. All values are seconds except [maxPerMinute].
///
/// The two routing-mode-specific overrides ([minIntervalSecondsSpeaker]
/// and [maxPerMinuteSpeaker]) are applied at *runtime* by the
/// controller when it detects it is speaking through the built-in
/// speaker — they are NOT separate prefs. This keeps the Settings
/// surface to one number per knob.
class FrequencyProfile {
  final int startupGraceSeconds;
  final int minIntervalSeconds;
  final int minIntervalSecondsSpeaker;
  final int maxPerMinute;
  final int maxPerMinuteSpeaker;
  final int streakSilenceSeconds;
  final int recencyResetSeconds;
  final int sessionResetSeconds;
  final int coalesceWindowSeconds;

  const FrequencyProfile({
    required this.startupGraceSeconds,
    required this.minIntervalSeconds,
    required this.minIntervalSecondsSpeaker,
    required this.maxPerMinute,
    required this.maxPerMinuteSpeaker,
    required this.streakSilenceSeconds,
    required this.recencyResetSeconds,
    required this.sessionResetSeconds,
    required this.coalesceWindowSeconds,
  });
}

/// Profile lookup. The `normal` profile is the §5.2 baseline. The other
/// four levels are rough geometric steps either side of it so users have
/// a real spectrum to dial in:
///
///   • [rare]     — long survey use, only the most distinct calls.
///   • [sparse]   — background listening; 1–2 utterances/min.
///   • [normal]   — conversational cadence (default).
///   • [frequent] — short Live sessions where you want most calls voiced.
///   • [constant] — demo / accessibility — almost every detection cycle
///                  is allowed to speak.
///
/// All presets share a 5-second startup grace so the audio session has
/// time to settle before the first utterance.
const Map<AnnouncementFrequency, FrequencyProfile> kFrequencyProfiles = {
  AnnouncementFrequency.rare: FrequencyProfile(
    startupGraceSeconds: 5,
    minIntervalSeconds: 60,
    minIntervalSecondsSpeaker: 90,
    maxPerMinute: 1,
    maxPerMinuteSpeaker: 1,
    streakSilenceSeconds: 600,
    recencyResetSeconds: 600,
    sessionResetSeconds: 3600,
    coalesceWindowSeconds: 8,
  ),
  AnnouncementFrequency.sparse: FrequencyProfile(
    startupGraceSeconds: 5,
    minIntervalSeconds: 30,
    minIntervalSecondsSpeaker: 45,
    maxPerMinute: 2,
    maxPerMinuteSpeaker: 2,
    streakSilenceSeconds: 180,
    recencyResetSeconds: 300,
    sessionResetSeconds: 1800,
    coalesceWindowSeconds: 5,
  ),
  AnnouncementFrequency.normal: FrequencyProfile(
    startupGraceSeconds: 5,
    minIntervalSeconds: 8,
    minIntervalSecondsSpeaker: 12,
    maxPerMinute: 6,
    maxPerMinuteSpeaker: 4,
    streakSilenceSeconds: 45,
    recencyResetSeconds: 120,
    sessionResetSeconds: 900,
    coalesceWindowSeconds: 3,
  ),
  AnnouncementFrequency.frequent: FrequencyProfile(
    startupGraceSeconds: 5,
    minIntervalSeconds: 4,
    minIntervalSecondsSpeaker: 8,
    maxPerMinute: 12,
    maxPerMinuteSpeaker: 6,
    streakSilenceSeconds: 25,
    recencyResetSeconds: 90,
    sessionResetSeconds: 600,
    coalesceWindowSeconds: 2,
  ),
  // [constant] keeps the same 5-second startup grace as every other
  // preset (just enough for the audio session to settle) but allows
  // the highest cadence; the per-species streak silence still
  // prevents the same bird from being announced over and over while
  // it keeps singing.
  AnnouncementFrequency.constant: FrequencyProfile(
    startupGraceSeconds: 5,
    minIntervalSeconds: 2,
    minIntervalSecondsSpeaker: 4,
    maxPerMinute: 20,
    maxPerMinuteSpeaker: 10,
    streakSilenceSeconds: 12,
    recencyResetSeconds: 60,
    sessionResetSeconds: 300,
    coalesceWindowSeconds: 1,
  ),
};

/// Profile for the [AnnouncementFrequency.custom] sentinel: returns
/// `null`, signalling to callers that they should keep whatever values
/// are currently in shared preferences instead of overwriting them.
FrequencyProfile? frequencyProfileFor(AnnouncementFrequency f) {
  return kFrequencyProfiles[f];
}
