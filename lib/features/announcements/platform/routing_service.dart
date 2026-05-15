// =============================================================================
// AnnouncementsRoutingService
// =============================================================================
//
// Wraps `package:audio_session` to configure the platform audio
// session for "speech alongside microphone capture" without breaking
// inference quality on Bluetooth devices.
//
// The hard problem (see `dev/announcements.md` §2 and §11):
//   - We must keep capturing 32 kHz mic audio for inference.
//   - We must speak short utterances out the *same* audio session.
//   - On Android + iOS, asking the OS to route audio "to a Bluetooth
//     device" can silently downgrade the BT link from A2DP (high-
//     fidelity sink-only) to HFP (telephony-grade duplex), which
//     crushes the mic to 8 kHz mono and ruins inference.
//
// The strategy here is conservative:
//   - Pick `AVAudioSessionCategory.playAndRecord` with options that
//     allow A2DP for output but explicitly *do not* request
//     `.allowBluetooth` (which on iOS implies HFP).
//   - On Android use `AndroidAudioUsage.assistanceAccessibility` so
//     the system treats our utterance like a screen-reader prompt
//     (ducks media, doesn't steal the mic).
//   - Detect HFP downgrade by sampling the available input devices
//     and only flagging it when *no* non-BT input (built-in mic /
//     wired headset mic) is present — the OS can only record over SCO
//     in that case. With any non-BT input available, a listed
//     `bluetoothSco` entry is just an available device, not the
//     active route.
//
// This file deliberately keeps the *interface* small. The platform
// glue lives behind a `RoutingService` abstraction so the controller
// and tests don't have to import `audio_session`.
// =============================================================================

import 'dart:async';

import 'package:audio_session/audio_session.dart';

/// Outcome of a routing-configuration attempt.
enum RoutingState {
  /// No issues — speech can proceed.
  ok,

  /// The active input device flipped to a BT-SCO microphone (HFP),
  /// which would degrade inference. Caller should suppress
  /// announcements until the user resolves the route.
  hfpDowngrade,

  /// Routing could not be configured at all (e.g. plugin error).
  /// Treated like `hfpDowngrade` by the controller.
  failed,
}

/// Pure interface so tests can swap a fake.
abstract class RoutingService {
  /// One-time initialization (idempotent). Call once when the
  /// Announcements feature is enabled.
  Future<void> init();

  /// Configure the audio session for an upcoming utterance and
  /// return the resulting [RoutingState].
  ///
  /// Should be called immediately before `TtsEngine.speak`.
  /// [duckOtherAudio] controls whether the session requests
  /// transient-may-duck focus; when `false` other audio (music,
  /// podcasts) plays through unattenuated.
  Future<RoutingState> prepareForSpeech({bool duckOtherAudio = true});

  /// Whether the most recently observed output device is the
  /// device's loudspeaker (as opposed to headphones / A2DP). The
  /// throttling layer uses this to apply the stricter speaker
  /// profile.
  bool get isSpeakerOutput;

  /// Free any platform resources. Safe to call multiple times.
  Future<void> dispose();
}

/// Production implementation backed by `audio_session`.
class AudioSessionRoutingService implements RoutingService {
  AudioSession? _session;
  bool _isSpeakerOutput = true;
  StreamSubscription<Set<AudioDevice>>? _devicesSub;
  bool _appliedDuck = true;

  @override
  bool get isSpeakerOutput => _isSpeakerOutput;

  @override
  Future<void> init() async {
    if (_session != null) return;
    final session = await AudioSession.instance;
    await _applyConfiguration(session, duck: _appliedDuck);
    _session = session;
    _devicesSub = session.devicesStream.listen((event) {
      _isSpeakerOutput = _detectSpeakerOutput(event);
    });
    // Seed the initial value.
    final initial = await session.getDevices();
    _isSpeakerOutput = _detectSpeakerOutput(initial);
  }

  Future<void> _applyConfiguration(
    AudioSession session, {
    required bool duck,
  }) async {
    await session.configure(
      AudioSessionConfiguration(
        // iOS: playAndRecord lets us mix capture and speech in one
        // session. Crucially we DO NOT pass `.allowBluetooth`, which on
        // iOS forces HFP. `.allowBluetoothA2DP` keeps Bluetooth output
        // at high fidelity without touching the mic route.
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetoothA2dp |
            AVAudioSessionCategoryOptions.defaultToSpeaker |
            (duck
                ? AVAudioSessionCategoryOptions.duckOthers
                : AVAudioSessionCategoryOptions.mixWithOthers),
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
        // Android: usage = assistanceAccessibility makes the system
        // treat our utterance like a screen-reader prompt (mixed with
        // / ducks media, doesn't steal the mic).
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.assistanceAccessibility,
        ),
        androidAudioFocusGainType:
            duck
                ? AndroidAudioFocusGainType.gainTransientMayDuck
                : AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ),
    );
    _appliedDuck = duck;
  }

  @override
  Future<RoutingState> prepareForSpeech({bool duckOtherAudio = true}) async {
    final session = _session;
    if (session == null) return RoutingState.failed;
    try {
      if (duckOtherAudio != _appliedDuck) {
        await _applyConfiguration(session, duck: duckOtherAudio);
      }
      // Deliberately *do not* call `session.setActive(true)` here.
      // On Android, toggling audio focus mid-capture briefly
      // re-routes the AudioRecord stream and shows up as a visible
      // gap / wobble in the live spectrogram. `flutter_tts` requests
      // its own focus when it actually speaks (with our configured
      // `assistanceAccessibility` usage), so the OS will duck other
      // audio without us touching the session per-utterance.
      //
      // Sample available inputs. `getDevices` returns the *available*
      // devices, not the active route, so a paired BT earbud will
      // always advertise both a `bluetoothA2dp` output and a
      // `bluetoothSco` input. We only treat this as a true HFP
      // downgrade when there's no other input the OS could record
      // from — i.e. no built-in mic and no wired headset mic.
      final devices = await session.getDevices(includeInputs: true);
      var hasScoInput = false;
      var hasNonBtInput = false;
      for (final d in devices) {
        if (!d.isInput) continue;
        if (_isBluetoothSco(d)) {
          hasScoInput = true;
        } else {
          hasNonBtInput = true;
        }
      }
      if (hasScoInput && !hasNonBtInput) {
        return RoutingState.hfpDowngrade;
      }
      return RoutingState.ok;
    } catch (_) {
      return RoutingState.failed;
    }
  }

  @override
  Future<void> dispose() async {
    await _devicesSub?.cancel();
    _devicesSub = null;
    final s = _session;
    if (s != null) {
      try {
        await s.setActive(false);
      } catch (_) {}
    }
    _session = null;
  }

  // --- Helpers ---

  bool _detectSpeakerOutput(Set<AudioDevice> devices) {
    // If any non-speaker output device is present (wired headphones,
    // A2DP sink, USB), treat it as "not speaker". Otherwise speaker.
    for (final d in devices) {
      if (!d.isOutput) continue;
      if (_isHeadphoneOrSinkLike(d)) return false;
    }
    return true;
  }

  bool _isHeadphoneOrSinkLike(AudioDevice d) {
    final name = d.name.toLowerCase();
    final type = d.type.toString().toLowerCase();
    if (type.contains('bluetootha2dp') ||
        type.contains('wiredheadphones') ||
        type.contains('wiredheadset') ||
        type.contains('usbheadset') ||
        type.contains('usbdevice')) {
      return true;
    }
    if (name.contains('headphone') ||
        name.contains('headset') ||
        name.contains('airpods')) {
      return true;
    }
    return false;
  }

  bool _isBluetoothSco(AudioDevice d) {
    final type = d.type.toString().toLowerCase();
    return type.contains('bluetoothsco');
  }
}
