# Session Review

After ending a Live Mode session, the Session Review screen lets you examine, edit, and export your bird detection data. Think of it as a research-grade tool for creating accurate species reports from audio recordings.

## Screen Layout

| Area | Description |
|------|-------------|
| **App bar** | Session name, help (?), add species (+), save, share, delete |
| **Summary header** | Date, duration, species count, detection count |
| **Spectrogram strip** | Pre-computed full-session spectrogram with playback position marker |
| **Trim controls** | Toggle trim mode, apply/reset trim handles |
| **Audio player** | Play/pause, seek slider, position/duration |
| **Annotations** | Add and view session annotations (global or timestamped) |
| **Species list** | Expandable species rows with clustered detections |

## Adding Species Manually

Tap the **+** button in the app bar to add a species that the model missed:

1. **Search** by common name or scientific name — results update as you type.
2. **Choose an insert mode**:
    - **Insert globally** — Adds a detection at the session start (the species was present throughout).
    - **Insert at playback position** — Adds a detection at the current white playhead marker.
    - **Replace detection** — Corrects a misidentified species by selecting an existing detection to replace.
3. **Unknown / Other** — Use this for unidentifiable calls. Adds an "Unknown species" entry.

Manually added detections are tagged as "Manual" and exported with `source: manual`.

## Annotations

Add free-text notes describing the recording conditions, location, weather, or any observation:

- **Global annotations** apply to the whole session.
- **Timestamped annotations** are tied to a specific playback position.
- Annotations are included in the exported ZIP bundle as a separate `annotations.txt` file.

To add an annotation:

1. Type your text in the annotation field below the species list.
2. Toggle the clock icon to attach the current playback timestamp, or leave it as global.
3. Tap the send button or press Enter.

## Trimming the Recording

Trim unwanted audio (e.g., speech at the beginning, silence at the end):

1. Tap **Trim Recording** below the spectrogram.
2. Drag the **left handle** to set the start point and the **right handle** to set the end point. Dimmed areas are excluded.
3. Tap **Apply Trim** to remove detections outside the trim range.
4. Tap **Reset Trim** to restore the full recording.

Trimming updates the `trimStartSec` and `trimEndSec` metadata — the original audio file is not modified.

## Playback and Navigation

- **Tap the spectrogram** to seek to that position.
- **Drag the spectrogram** to pan through the recording (pauses playback).
- **Press play** while panned to continue from the panned position.
- **Tap the play button** on a species row to jump to that detection.

The white vertical line on the spectrogram shows the current playback position.

## Editing Detections

- **Expand** a species row to see individual detection clusters.
- **Delete** a cluster by tapping the × button (confirmation required).
- All changes are tracked — save explicitly with the save button.
- **Unsaved changes warning** appears if you try to leave without saving.

## Exporting and Sharing

Tap the **share** button to export the session. The export format is configured in Settings > Export:

| Format | Description |
|--------|-------------|
| **ZIP bundle** | Recording + CSV + JSON + Raven Pro selections + annotations.txt |
| **CSV** | Comma-separated detection list |
| **JSON** | Full session data including annotations and trim offsets |
| **Raven Pro** | Selection table compatible with Cornell's Raven Pro software |

## Session Duration Warning

After 10 minutes of continuous recording in Live Mode, a dialog asks whether you want to continue or end the session. This prevents accidentally leaving a session running.

## App Lifecycle

When the app goes to the background during an active session, it automatically pauses. When you return, it resumes from where it left off.

## Help

Tap the **?** button in the app bar for a quick reference of all session review features.
