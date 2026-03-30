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

`AudioCaptureService` wraps the platform microphone and pushes PCM16 data to the ring buffer. It also provides an RMS level stream (~15 Hz) for UI metering.

## Recording Service

`RecordingService` supports two modes:

- **Full**: Continuously flush the ring buffer to a WAV file (1-second intervals)
- **Detections Only**: Save audio clips centered on detection timestamps (pre + post buffer)
