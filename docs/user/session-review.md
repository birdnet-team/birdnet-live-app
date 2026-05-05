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

### Species list

Species are grouped into expandable rows. You can inspect detections by species and move through the recording while reviewing them.

### Survey track map

Survey sessions show a small inline map of the GPS track and detection markers. Tap it to open a **fullscreen map** with the same data.

The fullscreen map's app bar has a :material-filter-list-outlined: **filter** button that opens a sheet for restricting which markers are shown. Available filters:

- **All detections** (default).
- **With audio clip** — only detections whose clip is still on disk and playable.
- **Manual additions** — only detections you added in Session Review (excludes auto-detected ones).

You can also restrict the detections by confidence level. The slider configures the confidence floor (starts at 10%).

Below the confidence slider is a **Limit to species** picker that lets you collapse the map to a single species — useful for asking "where exactly along the route did I hear the wood thrush?". An *All species* entry clears the species restriction. The filters combine: e.g. *With audio clip* + *Wood Thrush* + *> 80%* shows only the playable Wood Thrush markers that scored above 80%.

When a filter is active, the app bar title gains a match-count subtitle (e.g. *"7 detections"*) and the filter button shows a small dot. *Reset* in the sheet returns to the default.

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
