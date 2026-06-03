<!-- TRANSLATION TODO (de) -->

# Session Review — Developer Guide

Technical documentation for the session review system.

## Overview

The session review screen (`session_review_screen.dart`) provides post-session analysis of bird detection data. It operates on a `LiveSession` object and supports playback, editing, manual species addition, annotations, recording trimming, and export.

## File Structure

```
lib/features/history/
  session_review_screen.dart          # Main screen + state management
  session_export.dart                 # Export logic (CSV, JSON, Raven Pro, ZIP)
  widgets/
    session_review_widgets.dart       # Private widget classes (part file)
```

## Data Models

### DetectionRecord

Stored in `lib/features/live/live_session.dart`:

| Field | Type | Description |
|-------|------|-------------|
| `scientificName` | `String` | Species scientific name |
| `commonName` | `String` | Species common name (English) |
| `confidence` | `double` | 0.0–1.0 confidence score |
| `timestamp` | `DateTime` | Wall-clock detection time |
| `audioClipPath` | `String?` | Path to audio clip (optional) |
| `source` | `DetectionSource` | `auto` (model) or `manual` (user-added) |

Static constants `unknownSpeciesName` and `unknownCommonName` are used for unknown/unidentifiable species.

### SessionAnnotation

| Field | Type | Description |
|-------|------|-------------|
| `text` | `String` | Free-form annotation text |
| `createdAt` | `DateTime` | When the annotation was created |
| `offsetInRecording` | `double?` | Seconds from session start (null = global) |

### LiveSession Extensions

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `annotations` | `List<SessionAnnotation>` | `[]` | User annotations |
| `trimStartSec` | `double?` | `null` | Trim start offset (seconds) |
| `trimEndSec` | `double?` | `null` | Trim end offset (seconds) |

## Detection Counting (Live Mode)

Detection accumulation during live sessions uses **card-visibility-based counting** rather than time-window merging:

1. The `LiveController` maintains `_activeCardSpecies: Map<String, DetectionRecord>` tracking species with visible cards.
2. Each inference cycle determines three sets:
   - **Appeared**: species in current detections but not in active set → new `DetectionRecord`
   - **Ongoing**: species in both → update confidence if higher
   - **Disappeared**: species in active set but not current → remove from tracking
3. Only `appeared` species create new detection records. This means a bird calling continuously counts as one detection, and a gap (card removal + reappearance) creates a second detection.

## Spectrogram

The review spectrogram is computed dynamically to balance RAM usage and CPU performance, especially for long sessions:

- **Standard Rendering (Sessions < 128 MB Decoded PCM)**:
  1. The entire audio file is decoded and resampled to the model's sample rate (32 kHz).
  2. The spectrogram is pre-computed as a single full-session `ui.Image` using a 2048-point FFT (yielding ~12 Hz/bin frequency resolution, showing formants and harmonics clearly) with a 1024-point hop.
  3. `_ReviewSpectrogramPainter` blits a 10-second viewport centered on the playback position, with a `Ticker` animating playhead movements at up to 60 fps.

- **Lazy Chunk Loading (Sessions ≥ 128 MB Decoded PCM)**:
  To prevent massive RAM allocations and out-of-memory crashes on hour-long sessions, the app uses a lazy-loading tile pipeline:
  1. The session is divided into 30-second chunks. Only chunks visible in (or immediately adjacent to) the current viewport are loaded.
  2. Up to 12 chunks are cached in memory; older/farthest chunks are evicted dynamically.
  3. The decode and FFT calculations run inside a background isolate (`Isolate.run` / `_runSpectrogramChunkIsolate`) to prevent the UI thread from dropping frames during scroll or pinch-to-zoom actions.

- **FLAC-to-WAV Transcoding Optimization**:
  FLAC files do not have a constant-bitrate layout or a seek table, meaning range-decoding requires sequentially decoding the file from the beginning—leading to O(N²) time complexity for lazy chunk loading on long sessions. To avoid this:
  1. If a session is large (≥ 128 MB PCM) and recorded in FLAC format, the app runs a one-time sequential transcode to a temporary WAV file in a background isolate (`_runFlacTranscodeIsolate`).
  2. The lazy spectrogram pipeline then uses the temporary WAV file, enabling fast O(1) random-access seek-and-read operations for individual chunks.
  3. The temporary WAV file is session-scoped and deleted when the review screen is disposed.

## Trim System

Trimming is metadata-only — the original recording is not modified:

1. `_TrimOverlay` renders draggable start/end handles over the spectrogram.
2. `_TrimOverlayPainter` draws dimmed regions and handle graphics.
3. **Apply Trim**: removes detections outside `[trimStartSec, trimEndSec]` from `_detections`, updates `_speciesGroups`, marks dirty.
4. **Reset Trim**: sets both offsets to null.
5. The export system includes `trimStartSec`/`trimEndSec` in JSON output.

## Add Species Overlay

`_AddSpeciesOverlay` is a full-screen route using `TaxonomyService.search()`:

- **Search**: real-time substring match on common + scientific names (limit 30).
- **Insert modes**: global (at session start), at timestamp (playhead position), replace (swaps an existing detection).
- **Unknown/Other**: quick action using `DetectionRecord.unknownSpeciesName`.
- Returns `_AddSpeciesResult` with the chosen species and mode.

## Annotations

`_AnnotationsSection` provides a collapsible section:

- Input field with global/timestamp toggle.
- Each annotation stored as `SessionAnnotation` in the session.
- Exported as `annotations.txt` in ZIP bundles.
- Persisted to JSON alongside detections.

## Export Pipeline

`session_export.dart` builds export files:

| Format | Function | Notes |
|--------|----------|-------|
| CSV | `_buildCsvExport()` | Header + rows, tab-delimited |
| JSON | `buildJsonExport()` | Full session data including annotations, trim, source |
| Raven Pro | `_buildRavenExport()` | Selection table format |
| ZIP | Bundle mode | Recording + CSV + JSON + Raven + annotations.txt |

The `_buildAnnotationsText()` helper formats annotations as plain text with timestamp labels.

## Session Lifecycle (App Focus)

`WidgetsBindingObserver` on `_LiveScreenState`:

- `paused`/`inactive` → auto-pause session, set `_pausedByLifecycle = true`
- `resumed` → auto-resume if `_pausedByLifecycle`
- 10-minute `Timer` triggers a continue/stop dialog

## Localization

All user-facing strings use ARB keys prefixed with `session`:

- `sessionAddSpecies`, `sessionSearchSpecies`, `sessionInsertGlobally`, etc.
- `sessionAnnotations`, `sessionAddAnnotation`, `sessionAnnotationGlobal`
- `sessionTrimRecording`, `sessionTrimApply`, `sessionTrimReset`, `sessionTrimWarning`
- `sessionHelpTitle`, `sessionHelpOverview`, `sessionHelpAddSpecies`, etc.
- `sessionDurationWarningTitle`, `sessionDurationWarningMessage`, `sessionContinue`

Translations are provided in all UI locale ARB files: English, German, Czech, Spanish, French, Italian, and Portuguese.
