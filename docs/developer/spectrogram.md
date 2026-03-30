# Spectrogram

FFT processing and CustomPainter rendering.

## Pipeline

```
RingBuffer → FftProcessor → SpectrogramPainter → Canvas
```

## FftProcessor

- Windowed FFT (Hann window) via the `fftea` package
- Converts complex spectrum to normalized dB magnitudes [0.0, 1.0]
- Configurable dB range (floor/ceiling) and FFT size

## SpectrogramPainter (CustomPainter)

Uses a synchronous canvas-shift rendering strategy:

1. Draw previous spectrogram image shifted left by N columns
2. Draw new columns as colored rectangles on the right edge
3. `Picture.toImageSync` produces a GPU-backed `ui.Image`
4. Single `drawImageRect` composites to the main canvas

This avoids async `decodeImageFromPixels` which caused frozen spectrograms.

## Color Maps

Pre-computed 256-entry ARGB lookup tables:

- **Viridis** — perceptually uniform, color-blind friendly (default)
- **Magma** — dark-to-bright purple/orange
- **Inferno** — dark black to vivid yellow
- **Grayscale** — simple luminance ramp
- **BirdNET** — custom brand blue palette

## SpectrogramWidget

Bridges the audio ring buffer, FFT, and painter into a Flutter widget:

- `Ticker` drives animation at up to 60 fps
- `RepaintBoundary` isolates repaints from the widget tree
- Supports optional log amplitude scaling and frequency axis labels
