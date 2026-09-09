# File Analysis

File Analysis processes an existing recording through the same BirdNET pipeline that powers the live workflows.

## How to Open It

From Home, tap the **File Analysis** card with the :material-file-music: icon.

### From another app

You can also hand a recording to BirdNET Live from somewhere else. On Android, sharing an audio file with **BirdNET Live** or choosing **Open With** opens File Analysis immediately. On iOS, **Open With** is also immediate; after using the share sheet, open or return to BirdNET Live and the pending recording is selected automatically. The app copies the recording into its own temporary storage before analysis.

## App Bar

- :material-tune: — open File Analysis settings
- :material-close: — cancel an active analysis run

## Supported Inputs

The current file picker accepts:

- WAV / WAVE
- FLAC
- MP3
- OGG / OGA / Opus
- M4A / AAC / MP4
- WMA / AMR

## Four-Step Wizard

### 1. Pick File

Choose a file and review its metadata card:

- file name
- format
- duration
- file size
- sample rate

### 2. Location and date

You can:

- use current GPS
- enter coordinates manually
- skip location
- pick a point on the map
- set an optional recording date

### 3. Parameters

The wizard exposes:

- window duration
- overlap
- sensitivity
- confidence threshold
- species filter mode

Overlap controls how far each analysis window advances, and is specific to
File Analysis: the whole file is always examined, and more overlap simply
examines it more finely. The live modes use an inference rate instead, because
they have to decide how often to run against incoming audio rather than how
finely to cover a fixed recording.

However File Analysis reaches its windows, it turns them into detections with
the same rules as Live Mode, Point Count, and Survey: a detection starts at its
earliest supporting window, carries the strongest supported score, and ends at
the end of the last supporting window.

### 4. Analyze

The progress screen shows:

- windows processed
- detections found
- species found
- cancel button

## Result

When analysis finishes, BirdNET Live converts the output into a saved session and opens [Session Review](session-review.md).
