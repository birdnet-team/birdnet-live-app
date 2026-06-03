# Session Review

Session Review is where BirdNET Live turns detections into an editable record.

## How You Reach It

BirdNET Live opens Session Review automatically after completing:

- a Live session
- a Point Count
- a Survey
- a File Analysis run

You can also reopen any saved session from [Session Library](session-library.md).

## Main Areas

### Summary and playback

Session Review combines playback, spectrogram navigation, and a species list. For survey sessions it can also show mapped context.

The summary header at the top of the screen carries the date, location chip (lat/lon plus an optional resolved place name when **Settings → Privacy → Allow place name lookup** is on), and — when **Settings → Privacy → Allow weather lookup** was on at the time of recording — a **weather row** below the location showing the conditions captured at the end of the session: a one-liner like *"20.1 °C · Light rain · 3.2 m/s SW"* prefaced by a weather icon. Tap the row to expand a small sheet listing temperature, wind, precipitation, and cloud cover with the Open-Meteo attribution. The same snapshot is mirrored into the JSON export, the per-session metadata block, and the HTML report.

The spectrogram strip above the player is interactive: tap to seek, drag with one finger to scrub the timeline, and **pinch with two fingers to zoom in** on a narrow time window — useful when you want to inspect the timing of overlapping calls or pick apart a fast trill. Spread back out to return to the default 10-second overview. The play button on a species header always picks the first cluster that actually has a recorded clip, so the button is available whenever any of that species' detections are playable.

### Species list

Species are grouped into expandable rows. You can inspect detections by species and move through the recording while reviewing them. Cluster rows under an expanded species are indented so the parent species card stays visually distinct from its children.

A search field above the list filters species by common or scientific name, so finding one specific bird in a 100-species session is a few keystrokes instead of a long scroll. The :material-sort: button next to it changes the species order:

- **Highest confidence** (default) — species with the highest single-detection confidence first. Good for triaging the most certain identifications. When you expand a species in this mode, detections with playable audio clips appear before clipless detections, then by confidence.
- **Most detections** — species with the highest detection count first. Good for spotting the dominant choristers.
- **A → Z** — alphabetical by common name. Predictable, locale-aware, and easy to scan once a session has lots of species.
- **First detected** — chronological by first-detection time. The historical default; useful when reviewing alongside the spectrogram timeline.

The chosen sort persists across sessions.

### Per-detection actions

Every place a detection appears — the species list, the clip player sheet, the live survey list, and the survey map markers — uses the same set of actions:

- :material-check: **Confirm** — a one-tap inline checkmark that flags a detection as visually or acoustically verified. Confirmed clusters and map markers gain a small green check so they stand out at a glance, and the flag travels with every export format.
- :material-dots-vertical: **More** — opens an overflow menu with:
    - :material-share-variant: **Share detection** — see *Sharing* below.
    - :material-swap-horizontal: **Replace species** — pick a different species for this detection.
    - :material-delete-outline: **Delete detection** — removes the row immediately. An undo SnackBar appears for a few seconds so misfires are reversible. No confirmation dialog.
    - :material-delete-sweep-outline: **Delete species** — removes every detection of that species from the session in one shot, with the same SnackBar undo. Useful for sweeping out a misidentified noise source without expanding the species and deleting clusters one by one.

#### Swipe shortcuts on review rows

In the species list you can also act on a detection by swiping the row horizontally:

- swipe **right** → delete (with undo)
- swipe **left** → open the replace-species overlay

The two backgrounds are color-coded (error red vs primary blue) so the gesture's effect is obvious before you commit.

Swiping a **species header** row (left or right) deletes every detection of that species at once, with the same undo SnackBar. Useful when triaging a session full of misidentified noise.

### Sharing a single detection

The :material-share-variant: **Share detection** entry opens the platform share sheet with a terse, field-tool-friendly payload — common + scientific name, confidence, ISO 8601 UTC timestamp, and a `geo:` URI when the detection has GPS — and attaches the audio clip whenever one is available. The shared file is named `BirdNET_Live_<timestamp>_<species>.<ext>` to match the ZIP export scheme.

The audio attachment is resolved in this order:

1. The detection's own per-detection clip on disk.
2. **For sessions recording one continuous file**: the relevant audio window is sliced out of the recording on the fly. Both WAV and FLAC continuous recordings are supported, and the slice ships in the same container as the source (WAV in → WAV out, FLAC in → FLAC out).
3. If neither is available, the share is text-only — location and timestamp still land in the payload.

### Voice memos

You can attach short, spoken voice commentary to individual detection records:

- **Record**: Tap the :material-dots-vertical: button on a detection cluster and select **Record voice memo** to open the voice memo dialog. Tap the large microphone button to start recording. A live waveform reflects your voice in real time. Tap the stop button when finished.
- **Review**: Once recorded, you can listen to the memo using the inline player. To replace the memo, tap the **Re-record** button. To save it, tap the **Save** button.
- **Delete**: If a detection already has an attached voice memo, you can delete it from either the overflow menu or the voice memo dialog.
- **Platform-Specific Formats**: On Android and other platforms, voice memos are recorded in highly-compressed AAC (`.m4a`) format at 16 kHz. On iOS, they automatically use WAV/PCM16 format (`.wav`) to prevent CoreAudio compatibility issues with the app's active audio sessions. Both formats are fully supported by the export ZIP packaging.
- **Exporting**: When exporting the session as a ZIP, voice memos are bundled inside the `memos/` directory and their relative paths are recorded in JSON and CSV metadata.

### Survey track map

Survey sessions show a small inline map of the GPS track and detection markers. Tap a marker on the inline map to focus a detection — the inline map centers on it. Tap the :material-fullscreen: **expand** button (top-right of the inline map) to open the **fullscreen map**; if a detection was focused, the fullscreen map opens centered and zoomed in on that detection so you keep your place.

#### Marker encoding

- **Confidence is color-coded** with a CVD-safe ramp: low → high confidence runs from purple-blue through teal/yellow to red. The ramp's lightness changes monotonically so it stays readable in monochrome and for users with red-green color vision deficiency.
- **Audio-bearing detections** show a colored ring around the species photo plus a corner play badge — tap them to open the same clip player sheet used elsewhere, with confirm, share, replace, and delete all available.
- **Silent detections** (no clip on disk) render smaller, faded, and with a neutral-grey ring so audio detections always read as the primary content.
- **Overlapping markers at the same spot** are z-ordered by importance: highlighted > audio > higher confidence, so a low-confidence silent marker can never obscure a strong audio detection.
- **Below zoom 14.5** silhouettes degrade to colored dots sized by confidence, and dense clusters collapse to a count bubble (clustering disables at zoom 15).

#### Filtering

The fullscreen map has a persistent **filter chip** anchored top-right of the map. Tap it to open the filter sheet; the chip's label always shows what's currently in effect (*"All species"*, *"With audio"*, *"≥ 80%"*, or a single species name). Available filters:

- **All detections** (default).
- **With audio clip** — only detections whose clip is still on disk and playable.
- **Manual additions** — only detections you added in Session Review (excludes auto-detected ones).

You can also restrict the detections by confidence level. The slider configures the confidence floor (starts at 10%).

Below the confidence slider is a **Limit to species** picker that lets you collapse the map to a single species — useful for asking "where exactly along the route did I hear the wood thrush?". An *All species* entry clears the species restriction. The filters combine: e.g. *With audio clip* + *Wood Thrush* + *> 80%* shows only the playable Wood Thrush markers that scored above 80%.

When a filter is active, the app-bar title gains a match-count subtitle (e.g. *"7 detections"*). *Reset* in the sheet returns to the default.

## Toolbar Icons

The toolbar uses the same icon meanings described in [Icons & Controls](icons-and-controls.md):

- :material-plus-circle-outline: — add content
- :material-undo-variant: / :material-redo-variant: — step through edits
- :material-content-cut: — trim mode
- :material-content-save: — save edits
- :material-share-variant: — export or share
- :material-delete-outline: — discard session
- :material-play: — continue a survey when that action is available
- :material-help-circle-outline: — open the Session Review help sheet
- :material-tune: — open Settings

## Typical Review Tasks

- check detections against playback and spectrogram context
- add a species or annotation
- trim the recording to the useful interval
- export the reviewed result set

## Export

Export behavior depends on the options selected in [Settings](settings.md). The app can package detections and, optionally, audio into the chosen export format. Every export now ships with full provenance metadata — the app version, model name and version, species locale, export timestamp, and a snapshot of all settings at export time — written to a `<prefix>.metadata.json` side-file (ZIP) or a top-level `meta` block (JSON) so that exports are self-describing and reproducible.

The JSON export's `settings` block records the values that were *actually applied to this session* — sensitivity, score-pooling mode and window count, microphone gain, and the high-pass cutoff — not whatever happens to be set in Settings now. This means you can reproduce a result months later, or compare two surveys, without remembering which sliders were where when you ran them.

All timestamps in exported filenames (`BirdNET_Live_<date>_<time>_…`) and inside CSV / JSON payloads are formatted in your phone's *current* local time. Underlying records are stored in UTC and converted on the way out.
