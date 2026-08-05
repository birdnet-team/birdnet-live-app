import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:record/record.dart';

import '../../core/constants/app_constants.dart';
import 'audio_source.dart';
import 'ring_buffer.dart';

// =============================================================================
// Audio Capture Service
// =============================================================================
//
// Wraps the `record` package to stream raw PCM audio from the device
// microphone into the shared [RingBuffer].
//
// ### Data flow
//
// ```
// Microphone (Oboe / AVAudioEngine)
//   → Uint8List (PCM16 little-endian, 32 kHz mono)
//   → _pcm16ToFloat32 (normalized −1.0 … 1.0)
//   → RingBuffer.write
//   → downstream consumers (spectrogram, inference, recording)
// ```
//
// ### Level metering
//
// A periodic [Timer] (~15 Hz) reads the ring buffer's RMS and pushes it
// onto [levelStream] for the UI level meter.  This avoids per-sample
// stream events which would be expensive at 32 kHz.
//
// ### Error handling
//
// Errors during `start()` or from the audio stream are captured in
// [lastError] and the state moves to [CaptureState.error].  The UI can
// read both via the corresponding Riverpod providers.
// =============================================================================

/// State of the audio capture pipeline.
enum CaptureState {
  /// Not started or fully stopped.
  stopped,

  /// Capture is active and streaming audio data.
  capturing,

  /// An error occurred (see [AudioCaptureService.lastError]).
  error,
}

/// Audio capture service wrapping the `record` package.
///
/// Captures mono audio at [AppConstants.sampleRate] Hz and pushes
/// float32 samples into a [RingBuffer].  Exposes a [levelStream] for
/// UI level metering and an [onWindowReady] callback for downstream
/// consumers (inference, spectrogram).
class AudioCaptureService with WidgetsBindingObserver {
  AudioCaptureService({RingBuffer? ringBuffer})
    : _ringBuffer = ringBuffer ?? RingBuffer() {
    _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkWatchdog();
    });
    // Observe app lifecycle so we know whether we're allowed to fight for
    // the mic. Android will not hand the microphone to a backgrounded app
    // while a foreground app holds it, so we only retry in the foreground
    // (see [_checkWatchdog] / [setForeground]).
    final binding = WidgetsBinding.instance;
    _isForeground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        setForeground(true);
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        setForeground(false);
      case AppLifecycleState.inactive:
        // Transient (app switcher, notification shade, incoming-call banner).
        // Don't change our foreground stance on it — a real background
        // transition always arrives as `paused` right after.
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  AudioRecorder? _recorder;

  /// Lazily create the recorder to avoid platform channel calls at
  /// construction time (breaks unit tests).
  AudioRecorder get _rec => _recorder ??= AudioRecorder();

  final RingBuffer _ringBuffer;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  CaptureState _state = CaptureState.stopped;
  CaptureState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  /// The ring buffer receiving all captured samples.
  RingBuffer get ringBuffer => _ringBuffer;

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Emits RMS audio level (0.0 – 1.0) at ~15 Hz for the level meter.
  Stream<double> get levelStream => _levelController.stream;
  final _levelController = StreamController<double>.broadcast();

  /// Emits events whenever a new chunk of audio data has been written
  /// to the ring buffer.
  Stream<int> get onDataAvailable => _dataController.stream;
  final _dataController = StreamController<int>.broadcast();

  StreamSubscription<Uint8List>? _streamSub;
  Timer? _levelTimer;
  Timer? _watchdogTimer;

  bool _shouldBeCapturing = false;
  AudioSourceSelection _currentSource = AudioSourceSelection.systemDefault;
  DateTime _lastDataTime = DateTime.now();

  // ── Lifecycle serialization ─────────────────────────────────────────────
  //
  // start / stop / switchSource and the watchdog's restarts arrive from
  // independent callers (screens, the 2 s watchdog timer, lifecycle
  // callbacks), and all of them are async. Left unserialized, two of them
  // interleave inside each other's `await` gaps and a second
  // `startStream()` reaches the platform while the native recorder is still
  // running. `record` handles that by stopping the live recording and
  // restarting it from inside the stop callback — and when the fresh
  // AudioRecord then fails to initialize (the common case, since the reason
  // we were restarting is usually a contested mic) the plugin answers the
  // same method call twice and the Flutter engine aborts the app with
  // `IllegalStateException: Reply already submitted`.
  //
  // Two rules keep us off that path: every lifecycle operation runs to
  // completion before the next one starts, and [_startLocked] always
  // disposes the previous recorder first, so the plugin only ever sees a
  // freshly created recorder that is not recording yet.
  Future<void> _lifecycleQueue = Future<void>.value();
  bool _lifecycleBusy = false;

  /// Run [op] after every previously queued lifecycle operation has finished.
  ///
  /// The returned future carries [op]'s error to its caller; the queue itself
  /// swallows it so one failed start can't poison every later operation.
  Future<void> _serialize(Future<void> Function() op) {
    final next = _lifecycleQueue.then((_) async {
      _lifecycleBusy = true;
      try {
        await op();
      } finally {
        _lifecycleBusy = false;
      }
    });
    _lifecycleQueue = next.catchError((_) {});
    return next;
  }

  /// Whether the app is currently in the foreground. Kept up to date by the
  /// [WidgetsBindingObserver] hook. We only fight to reclaim a lost mic while
  /// foreground (see [_checkWatchdog]).
  bool _isForeground = true;

  /// Set once we've released the recorder because the mic was lost while
  /// backgrounded, so the watchdog doesn't keep tearing down every 2 s.
  /// Cleared when we return to the foreground or audio starts flowing again.
  bool _backgroundReleased = false;

  // ── Live-tunable DSP ────────────────────────────────────────
  //
  // Both apply to the float32 stream just before it lands in the
  // ring buffer, so inference, recording, and the live spectrogram
  // all see the same processed signal.

  /// User-set gain multiplier applied to incoming samples. `1.0` is a
  /// pass-through; values >1 boost quiet recordings at the cost of
  /// clipping loud peaks (we saturate to [-1, 1] in float).
  double _gain = 1.0;

  /// High-pass cutoff in Hz. `0` (or any value <=0) disables the
  /// filter. Typical values: 100–300 Hz to remove wind / handling
  /// rumble while preserving most bird vocalizations.
  double _hpfCutoffHz = 0.0;

  // 4th-order Butterworth HPF = two cascaded biquads with the same
  // cutoff but different Q values (0.5412 and 1.3066). Together they
  // give -3 dB at the design cutoff and a sharp 24 dB/octave roll-off,
  // which makes the cutoff visually obvious on the spectrogram.
  double _s1B0 = 1.0, _s1B1 = 0.0, _s1B2 = 0.0, _s1A1 = 0.0, _s1A2 = 0.0;
  double _s2B0 = 1.0, _s2B1 = 0.0, _s2B2 = 0.0, _s2A1 = 0.0, _s2A2 = 0.0;

  // Direct-Form II Transposed state for each stage; persists across
  // audio chunks so the filter doesn't "click" at chunk boundaries.
  double _s1Z1 = 0.0, _s1Z2 = 0.0;
  double _s2Z1 = 0.0, _s2Z2 = 0.0;

  bool get _hpfEnabled => _hpfCutoffHz > 0.0;

  /// Update the linear gain (`1.0` = unity). Takes effect on the next
  /// captured chunk.
  void setGain(double value) {
    _gain = value;
  }

  /// Update the high-pass cutoff in Hz. Pass `0` to bypass. Takes
  /// effect on the next captured chunk; filter state is reset so the
  /// new response settles cleanly.
  void setHighPassCutoff(double cutoffHz) {
    final next = cutoffHz <= 0 ? 0.0 : cutoffHz;
    if (next == _hpfCutoffHz) return;
    _hpfCutoffHz = next;
    if (next > 0) {
      _designHighPass(next, AppConstants.sampleRate);
    }
    _s1Z1 = 0.0;
    _s1Z2 = 0.0;
    _s2Z1 = 0.0;
    _s2Z2 = 0.0;
  }

  /// 4th-order Butterworth HPF = two cascaded RBJ biquads. The pole
  /// pairs of a 4th-order Butterworth lie on the unit circle at
  /// angles ±22.5° and ±67.5° from the imaginary axis, giving section
  /// Q values of 1/(2·cos 22.5°) ≈ 0.5412 and 1/(2·cos 67.5°) ≈ 1.3066.
  void _designHighPass(double cutoffHz, int sampleRate) {
    final w0 = 2 * math.pi * cutoffHz / sampleRate;
    final cosW0 = math.cos(w0);
    final sinW0 = math.sin(w0);

    void section(
      double q,
      void Function(double, double, double, double, double) write,
    ) {
      final alpha = sinW0 / (2 * q);
      final b0 = (1 + cosW0) / 2;
      final b1 = -(1 + cosW0);
      final b2 = (1 + cosW0) / 2;
      final a0 = 1 + alpha;
      final a1 = -2 * cosW0;
      final a2 = 1 - alpha;
      write(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
    }

    section(0.54119610014619701, (b0, b1, b2, a1, a2) {
      _s1B0 = b0;
      _s1B1 = b1;
      _s1B2 = b2;
      _s1A1 = a1;
      _s1A2 = a2;
    });
    section(1.3065629648763766, (b0, b1, b2, a1, a2) {
      _s2B0 = b0;
      _s2B1 = b1;
      _s2B2 = b2;
      _s2A1 = a1;
      _s2A2 = a2;
    });
  }

  // ── Microphone-loss handling ───────────────────────────────────────────
  //
  // Another app (the camera/video recorder, a voice recorder, a call) can
  // take exclusive control of the microphone at any time. When that happens
  // our audio stream stalls or errors out. How we react depends on whether
  // we're in the foreground:
  //
  //   • Foreground — retry with a capped exponential back-off so we reclaim
  //     the mic the moment the other app releases it, without hammering.
  //
  //   • Background — DO NOT retry. Android will not grant the mic to a
  //     backgrounded app while a foreground app holds it, and repeatedly
  //     re-opening `AudioRecord` against a contended mic wedges the device
  //     audio HAL (the whole phone loses mic access until it reboots). We
  //     release our handle cleanly and wait until the app is foregrounded
  //     again (see [setForeground]).
  //
  // Either way we surface [isMicContested] / [micContestedStream] so the UI
  // can show an "X" on the signal meter and the foreground notification can
  // explain why audio appears frozen.
  static const Duration _minRetryBackoff = Duration(seconds: 2);
  static const Duration _maxRetryBackoff = Duration(seconds: 20);

  /// How long a running stream may go without delivering audio before we
  /// treat the mic as lost. Kept above the watchdog period so a single
  /// slow chunk doesn't trip it.
  static const Duration _stallTimeout = Duration(seconds: 3);

  /// How long to wait for the platform to acknowledge a stop/dispose before
  /// abandoning the recorder (see [_teardownCapture]).
  static const Duration _teardownTimeout = Duration(seconds: 2);

  Duration _retryBackoff = _minRetryBackoff;
  DateTime? _nextRetryAt;
  bool _micContested = false;
  final _micContestedController = StreamController<bool>.broadcast();

  /// Whether the microphone is currently held by another app (or otherwise
  /// unavailable). Drives the survey signal-meter "X" and the foreground
  /// notification's status line.
  bool get isMicContested => _micContested;

  /// Emits `true` when the microphone becomes contested and `false`
  /// when normal capture resumes.
  Stream<bool> get micContestedStream => _micContestedController.stream;

  void _setMicContested(bool value) {
    if (_micContested == value) return;
    _micContested = value;
    if (!_micContestedController.isClosed) {
      _micContestedController.add(value);
    }
  }

  /// Inform the service whether the app is in the foreground. Wired
  /// automatically via the [WidgetsBindingObserver] hook; also exposed so
  /// callers/tests can drive it directly.
  ///
  /// Returning to the foreground after losing the mic in the background
  /// resets the back-off and immediately attempts to reclaim it.
  void setForeground(bool foreground) {
    if (_isForeground == foreground) return;
    _isForeground = foreground;
    debugPrint('AudioCapture: foreground=$foreground');
    if (!foreground) return;

    // Back in the foreground — allow retries again and try right away if we
    // dropped the mic while backgrounded.
    _backgroundReleased = false;
    _retryBackoff = _minRetryBackoff;
    _nextRetryAt = null;
    if (_shouldBeCapturing && _state != CaptureState.capturing) {
      _restart();
    }
  }

  void _checkWatchdog() {
    if (!_shouldBeCapturing || _lifecycleBusy) return;

    final now = DateTime.now();

    final isStalled =
        _state == CaptureState.capturing &&
        now.difference(_lastDataTime) > _stallTimeout;
    final isFailed =
        _state == CaptureState.error || _state == CaptureState.stopped;

    if (!isStalled && !isFailed) {
      // Audio is flowing — clear any lost/retry state.
      _onCaptureHealthy();
      return;
    }

    // Mic is lost. Surface it to the UI immediately so the signal meter
    // flips to "X" without waiting for a retry to fail.
    _setMicContested(true);

    if (!_isForeground) {
      // Background: stop fighting for the mic. Release our handle once and
      // wait for the foreground transition to try again.
      if (!_backgroundReleased) {
        _backgroundReleased = true;
        debugPrint(
          'Watchdog: mic lost while backgrounded — releasing until foreground',
        );
        _releaseForContention();
      }
      return;
    }

    // Foreground: retry with capped exponential back-off.
    if (_nextRetryAt != null && now.isBefore(_nextRetryAt!)) return;
    _retryBackoff =
        _nextRetryAt == null
            ? _minRetryBackoff
            : Duration(
              milliseconds: math.min(
                _retryBackoff.inMilliseconds * 2,
                _maxRetryBackoff.inMilliseconds,
              ),
            );
    _nextRetryAt = now.add(_retryBackoff);
    debugPrint(
      'Watchdog: mic lost in foreground (stalled: $isStalled, '
      'failed: $isFailed) — reclaiming, next retry in '
      '${_retryBackoff.inSeconds}s',
    );
    _restart();
  }

  /// Reset all lost/retry bookkeeping when audio is confirmed flowing.
  void _onCaptureHealthy() {
    if (!_micContested &&
        _nextRetryAt == null &&
        !_backgroundReleased &&
        _retryBackoff == _minRetryBackoff) {
      return;
    }
    _nextRetryAt = null;
    _retryBackoff = _minRetryBackoff;
    _backgroundReleased = false;
    _setMicContested(false);
  }

  /// Fully tear down capture and release the native recorder while keeping
  /// [_shouldBeCapturing] set, so we resume automatically once foregrounded.
  Future<void> _releaseForContention() => _serialize(() async {
    try {
      await _teardownCapture();
    } catch (_) {}
  });

  /// Queue a restart. Errors are swallowed — callers fire this from timers and
  /// lifecycle callbacks without awaiting it.
  Future<void> _restart() => _serialize(_restartLocked);

  /// Restart body. Assumes the lifecycle queue is already held.
  Future<void> _restartLocked() async {
    try {
      // Fully dispose the old recorder, not just stop it: a recorder that
      // lost the mic can stay wedged and never deliver audio again, so a
      // reliable reclaim needs a fresh AudioRecord instance. This also moves
      // [_state] off `capturing` so [_startLocked] doesn't take its
      // already-running early return.
      await _teardownCapture();
      _shouldBeCapturing = true;
      await _startLocked(source: _currentSource);
    } catch (_) {}
  }

  /// Switch to a different [source] without ending the session.
  ///
  /// The recorder has to be torn down and rebuilt — neither Android nor iOS
  /// can change the capture source on a live `AudioRecord` — so there is a
  /// sub-second gap in the audio. Everything downstream survives it: [stop]
  /// leaves the ring buffer, gain and high-pass settings alone, so the
  /// inference loop and spectrogram read straight through the seam.
  ///
  /// When capture isn't running this only records the choice; the next [start]
  /// picks it up.
  Future<void> switchSource(AudioSourceSelection source) =>
      _serialize(() => _switchSourceLocked(source));

  /// [switchSource] body. Assumes the lifecycle queue is already held.
  Future<void> _switchSourceLocked(AudioSourceSelection source) async {
    if (source == _currentSource) return;

    if (_state != CaptureState.capturing) {
      _currentSource = source;
      return;
    }

    debugPrint('Switching audio source to $source');
    _currentSource = source;
    await _restartLocked();
  }

  // ---------------------------------------------------------------------------
  // Device enumeration
  // ---------------------------------------------------------------------------

  /// List available audio input devices.
  Future<List<InputDevice>> listInputDevices() async {
    try {
      return await _rec.listInputDevices();
    } catch (e) {
      debugPrint('Failed to list input devices: $e');
      return [];
    }
  }

  /// Translate a profile into the Android capture source it selects.
  ///
  /// Inert on other platforms: `record` ignores `androidConfig` there, and the
  /// picker never offers anything but [AudioSourceProfile.systemDefault].
  static AndroidAudioSource _androidAudioSource(AudioSourceProfile profile) {
    switch (profile) {
      case AudioSourceProfile.systemDefault:
        return AndroidAudioSource.defaultSource;
      case AudioSourceProfile.unprocessed:
        return AndroidAudioSource.unprocessed;
      case AudioSourceProfile.voiceRecognition:
        return AndroidAudioSource.voiceRecognition;
    }
  }

  // ---------------------------------------------------------------------------
  // Capture lifecycle
  // ---------------------------------------------------------------------------

  /// Start capturing audio.
  ///
  /// [source] — which input device to record from and how much OS processing
  /// to allow. Omit it to reuse the last source, which is what makes a
  /// [switchSource] performed while stopped survive until the next start.
  Future<void> start({AudioSourceSelection? source}) =>
      _serialize(() => _startLocked(source: source));

  /// [start] body. Assumes the lifecycle queue is already held.
  Future<void> _startLocked({AudioSourceSelection? source}) async {
    _shouldBeCapturing = true;
    _lastDataTime = DateTime.now();

    // Callers may race with another mode that has already started the shared
    // recorder. Keep the active recorder and the requested selection aligned;
    // merely updating `_currentSource` here would make the UI claim a source
    // that the running AudioRecord was not actually using.
    if (_state == CaptureState.capturing) {
      if (source != null) await _switchSourceLocked(source);
      return;
    }

    if (source != null) _currentSource = source;

    // Never hand a second `startStream()` to a recorder the platform already
    // owns. `_state` alone can't tell us that: a stream error or a failed
    // start leaves us at `error`/`stopped` while the native recorder is still
    // very much alive, and starting on top of it is what triggers the
    // plugin's double-reply crash. Disposing first costs one channel round
    // trip and guarantees a clean recorder.
    await _teardownCapture();

    try {
      final hasPermission = await _rec.hasPermission();
      if (!hasPermission) {
        _state = CaptureState.error;
        _lastError = 'Microphone permission not granted';
        return;
      }

      // Configure for raw PCM streaming at 32 kHz mono 16-bit.
      //
      // The autoGain / echoCancel / noiseSuppress flags only disable the
      // software AudioEffect modules. The OEM voice DSP lives further down, in
      // the capture path of the audio source itself — `androidConfig` is what
      // steers around it.
      final deviceId = _currentSource.deviceId;
      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        device: deviceId != null ? InputDevice(id: deviceId, label: '') : null,
        androidConfig: AndroidRecordConfig(
          audioSource: _androidAudioSource(_currentSource.profile),
        ),
      );

      final stream = await _rec.startStream(config);

      _streamSub = stream.listen(
        _onAudioData,
        onError: _onStreamError,
        onDone: _onStreamDone,
      );

      // Periodic level metering (~15 Hz).
      _levelTimer = Timer.periodic(
        const Duration(milliseconds: 67),
        (_) => _emitLevel(),
      );

      _state = CaptureState.capturing;
      _lastError = null;
      // A fresh stream is open. Keep the mic marked lost until real audio
      // actually arrives (the other app may still hold it) — [_onAudioData]
      // clears it — but reset the release latch so the watchdog can act on
      // this new attempt.
      _backgroundReleased = false;
      debugPrint('Audio capture started @ ${AppConstants.sampleRate} Hz');
    } catch (e, st) {
      _state = CaptureState.error;
      _lastError = e.toString();
      debugPrint('Audio capture start failed: $e\n$st');
    }
  }

  /// Stop capturing audio (user- or session-initiated).
  Future<void> stop() => _serialize(() async {
    _shouldBeCapturing = false;
    await _teardownCapture();
    debugPrint('Audio capture stopped');
  });

  /// Cancel the level timer + audio stream and fully release the native
  /// recorder, leaving [_state] at [CaptureState.stopped].
  ///
  /// Fully disposing the recorder (not merely calling `stop()` on it) is what
  /// makes reclaiming the mic reliable: a recorder that lost the mic to
  /// another app can stay wedged, so every restart builds a fresh
  /// [AudioRecorder] via the lazy [_rec] getter. It also frees the mic for
  /// other apps promptly when we intentionally stop.
  Future<void> _teardownCapture() async {
    _levelTimer?.cancel();
    _levelTimer = null;

    await _streamSub?.cancel();
    _streamSub = null;

    final rec = _recorder;
    _recorder = null;
    if (rec != null) {
      // Both calls are bounded: `record` only completes `stop()` from its
      // recording thread's stop callback, and a recorder whose AudioRecord
      // died before it ever reached the recording state never fires that
      // callback. Waiting forever there would wedge the whole lifecycle
      // queue, so abandon the recorder instead — `dispose()` on the platform
      // side tears it down regardless.
      try {
        await rec.stop().timeout(_teardownTimeout);
      } catch (_) {
        // Recorder may already be stopped or wedged; ignore.
      }
      try {
        await rec.dispose().timeout(_teardownTimeout);
      } catch (_) {
        // Best-effort native release.
      }
    }

    _state = CaptureState.stopped;
  }

  /// Release all resources.  Call when the service is no longer needed.
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _watchdogTimer?.cancel();
    await stop();
    await _levelController.close();
    await _dataController.close();
    await _micContestedController.close();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  int _audioChunkCount = 0;

  /// Process incoming PCM16 audio data.
  void _onAudioData(Uint8List bytes) {
    _lastDataTime = DateTime.now();
    // Audio is flowing — clear any lost/retry state so the UI and the
    // foreground notification reflect the recovered mic.
    _onCaptureHealthy();

    // Convert signed 16-bit PCM (little-endian) → float32 [-1.0, 1.0].
    final samples = _pcm16ToFloat32(bytes);
    _applyDsp(samples);
    _ringBuffer.write(samples);
    _dataController.add(samples.length);

    _audioChunkCount++;
    if (_audioChunkCount % 50 == 1) {
      debugPrint(
        '[AudioCapture] chunk #$_audioChunkCount: '
        '${samples.length} samples, '
        'totalWritten=${_ringBuffer.totalWritten}',
      );
    }
  }

  void _onStreamError(Object error) {
    debugPrint('Audio stream error: $error');
    _state = CaptureState.error;
    _lastError = error.toString();
  }

  void _onStreamDone() {
    debugPrint('Audio stream ended');
    if (_state == CaptureState.capturing) {
      _state = CaptureState.stopped;
    }
  }

  void _emitLevel() {
    if (_state != CaptureState.capturing) return;
    final rms = _ringBuffer.rmsLevel(windowSize: 2048);
    _levelController.add(rms);
  }

  /// Convert signed 16-bit little-endian PCM bytes to Float32List [-1, 1].
  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    final result = Float32List(sampleCount);
    final byteData = ByteData.sublistView(bytes);

    for (var i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      result[i] = sample / 32768.0;
    }

    return result;
  }

  /// Apply the user-tunable DSP chain (gain → high-pass) in place.
  ///
  /// Both stages bypass cheaply when the user hasn't moved the slider
  /// off the default. Gain is clipped to [-1, 1] so downstream
  /// quantization to PCM16 doesn't wrap. The biquad uses Direct-Form
  /// II Transposed with state persisted on the service instance so
  /// chunk boundaries don't introduce clicks.
  void _applyDsp(Float32List samples) {
    final gain = _gain;
    final useGain = gain != 1.0;
    final useHpf = _hpfEnabled;
    if (!useGain && !useHpf) return;

    final s1B0 = _s1B0, s1B1 = _s1B1, s1B2 = _s1B2, s1A1 = _s1A1, s1A2 = _s1A2;
    final s2B0 = _s2B0, s2B1 = _s2B1, s2B2 = _s2B2, s2A1 = _s2A1, s2A2 = _s2A2;
    var s1Z1 = _s1Z1, s1Z2 = _s1Z2;
    var s2Z1 = _s2Z1, s2Z2 = _s2Z2;

    for (var i = 0; i < samples.length; i++) {
      var x = samples[i].toDouble();
      if (useGain) {
        x *= gain;
        if (x > 1.0) {
          x = 1.0;
        } else if (x < -1.0) {
          x = -1.0;
        }
      }
      if (useHpf) {
        // Stage 1.
        var y = s1B0 * x + s1Z1;
        s1Z1 = s1B1 * x - s1A1 * y + s1Z2;
        s1Z2 = s1B2 * x - s1A2 * y;
        // Stage 2 (input = stage-1 output).
        final x2 = y;
        y = s2B0 * x2 + s2Z1;
        s2Z1 = s2B1 * x2 - s2A1 * y + s2Z2;
        s2Z2 = s2B2 * x2 - s2A2 * y;
        x = y;
      }
      samples[i] = x;
    }

    if (useHpf) {
      _s1Z1 = s1Z1;
      _s1Z2 = s1Z2;
      _s2Z1 = s2Z1;
      _s2Z2 = s2Z2;
    }
  }
}
