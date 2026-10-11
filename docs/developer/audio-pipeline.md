# Audio Pipeline

Audio capture, ring buffer, and processing.

## Data Flow

```
Microphone (Oboe / AVAudioEngine)
  → Uint8List (PCM16 little-endian, 32 kHz mono)
  → pcm16ToFloat32 (normalized −1.0 … 1.0)
  → RingBuffer.write
  → downstream consumers (spectrogram, inference, recording)
```

## Ring Buffer

`RingBuffer` is a fixed-size circular buffer of `Float32List` samples. Multiple consumers can read from it simultaneously:

- **Spectrogram**: reads the latest `fftSize` samples each frame
- **Inference**: reads `windowDuration * sampleRate` samples each cycle
- **Recording**: periodically flushes new samples to a WAV file

## Audio Capture Service

`AudioCaptureService` wraps the platform microphone and pushes PCM16 data into the ring buffer. It also exposes an RMS level stream (~15 Hz) for UI metering.

## Microphone-loss handling

A lost microphone (stalled stream or stream error) is retried with a capped
exponential back-off while the app is in the foreground. In the background
the watchdog only retries when something legitimately keeps the app capturing:
on Android a mode must own the shared microphone foreground service
(`ForegroundServiceGuard.owner != null`), and the retry cadence drops to a
probe every 30 s to 2 min so a contended microphone is never hammered (that
wedged the audio HAL on some devices); on iOS the `audio` background mode keeps
the app alive and the `record` plugin pauses on an interruption without
resuming, so the normal cadence applies. Without a reason to capture, the
recorder is released once and reclaimed on the next foreground transition.

## Recording Service

`RecordingService` supports two modes:

- **Full**: Continuously flushes the ring buffer to an audio file (WAV or FLAC, depending on user settings) at 1-second intervals via `AudioFileWriter`. The service writes through `IsolateAudioFileWriter`, which hosts the real `WavWriter` / `FlacEncoder` on a worker isolate and forwards each call: the FLAC encoder is pure Dart, and the UI isolate is also the platform thread on Android and iOS, so a second of encoding every second must not run there. Each call completes when the worker has finished it, which preserves the flush loop's back-pressure.
- **Detections Only**: Saves audio clips centered on detection timestamps (pre-context + inference window + post-context) in the chosen format (WAV or FLAC). Every clip of a detection round is encoded from one snapshot in a single `Isolate.run` (`writeClipFiles`).

On iOS, voice memos automatically fall back to `.wav` (PCM16) format to avoid Apple CoreAudio AAC compression collisions, while preserving full file-sharing and packaging compatibility.
