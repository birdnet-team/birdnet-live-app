# Survey Mode

Survey Mode is the route-based workflow for long-running moving surveys.

## How to Open It

From Home, tap the **Survey Mode** card with the :material-routes: icon.

## Setup Flow

Survey setup is a five-step wizard.

### 1. Details

You can enter:

- survey name
- transect ID
- observer name
- GPS, manual coordinates, or no starting location

This step also exposes the map picker, refreshes GPS when you return from
system permission screens, and shows the background-GPS permission reminder
when needed. A weather card is available in the same location area. If weather
access is off, it asks for **Allow weather lookup** consent; once enabled, it
previews the site with a weather icon, temperature, and wind only. The same
cached Open-Meteo snapshot is reused when the survey is saved.

### 2. Parameters

This step contains Survey-specific parameters such as:

- microphone selection
- inference rate
- confidence threshold
- GPS interval
- maximum duration
- recording mode
- clip context for detection-only recording
- detection sampling mode
- top-N-per-species limit when sampling is limited

#### Detection sampling

A long survey can produce thousands of detections, and saving an audio clip for every one of them quickly fills up storage. Detection sampling controls **which clips are kept on disk** — *the detection records themselves are always kept*, so your full session log stays intact regardless of mode. Records whose audio was dropped simply have no playable clip in Session Review.

Three modes are available:

| Mode | What it does |
|---|---|
| **All** | Keep every clip. Most disk usage. Recommended for short surveys or when you want every detection's audio for later analysis. |
| **Top N** | Keep only the **N highest-confidence clips per species**. Other clips are deleted as the survey runs. Default N is 10, configurable from 1 to 50. |
| **Smart** | Same per-species cap of N as Top N, **plus** spatial distribution: if a new detection lands at the same "spot" as an already-kept clip (within ~500 m and ~2 min of each other), only the higher-confidence one keeps its clip. This prevents one stationary singer from monopolizing all N slots and biases the kept clips toward covering the full transect. |

The N limit is **per species, not global** — if you record 10 robins and 10 chaffinches, you keep 20 clips. There is no overall cap on the number of clips a survey can produce.

In Smart mode, if GPS is missing on a detection the same-spot check falls back to a time-only window (~2 min). With GPS available, both distance and time must overlap for two detections to count as the same spot.

### 3. Species alerts

Push-style notifications that fire mid-survey when something noteworthy is detected. Pick one of:

- **Off** — no alerts (default).
- **First in session** — one alert the first time each species is heard during this survey.
- **First ever** — alert only when the app encounters a species for the very first time across all your sessions in the app. Backed by a lifetime species history that is auto-populated from your existing sessions on first launch.
- **Rare for this location** — alert when the geo-model probability for the current location is below a configurable threshold. A live readout under the slider explains exactly what the current value will trigger on (e.g. *"Alerts on species with under 5 % likelihood at this location."*).
- **Watchlist** — alert only on species you've added to a saved custom list. The wizard step itself lets you create new watchlists, edit existing ones in a dedicated full-screen editor with searchable taxonomy and *Import from file* (any plain `.txt`/`.csv` of scientific names), and delete lists you no longer need.
- **Lifer** — alert when a species isn't on your imported eBird life list. Import the list from **Settings → eBird Life List**; until you do, this mode never fires.

A *Minimum confidence* slider sits under the mode picker and is automatically floored to your session confidence threshold (alerts are never more sensitive than the detections themselves). An **Advanced** section exposes throttling controls — a startup grace window, a hard minimum interval between any two alerts, and a sliding per-minute cap with optional coalescing of over-cap alerts into a single summary notification — all with one-tap chip selectors. The first time you switch to a non-Off mode, the wizard requests Android notification permission for you.

### 4. Field tips

A short pre-start checklist inside the setup flow.

### 5. Ready

The ready screen summarizes the active survey configuration before you start with :material-play:.

## Live Survey Dashboard

The live Survey screen has three main tabs plus a recent detections list.

### Top bar

- :material-stop: — end the survey
- :material-timer: — elapsed time
- :material-help-circle-outline: — open the Survey help sheet
- :material-tune: — open Survey settings

### Tabs

- :material-map-outline: — route map and mapped detections
- :material-equalizer: — spectrogram
- chart icon — summary statistics and species breakdown

### Stats and detections

Below the tab content, the survey dashboard shows a stats bar and a recent detections list. Tapping a detection opens the species details overlay.

Each detection row also exposes the same per-detection actions used in [Session Review](session-review.md): a one-tap :material-check: **Confirm** checkmark and a :material-dots-vertical: **More** overflow with **Share detection** and **Delete detection** (with SnackBar undo) — so you can validate, share, or remove a noisy hit mid-capture instead of waiting for the post-session review.

The same actions are available from the **live route map**: tap a detection marker to open the clip player sheet with confirm, share, and delete. Sharing during a survey works even when you've opted for one continuous WAV recording instead of per-detection clips — the relevant audio window is sliced out of the in-progress file on the fly. See [Session Review → Sharing a single detection](session-review.md#sharing-a-single-detection) for details.

### Logging an observation

The :material-plus-circle-outline: button on the live survey opens a small menu with **Add Species** and **Add note**. **Add Species** opens the same picker used in [Session Review](session-review.md#adding-a-species-by-hand), choose a species, then tick :material-ear-hearing: **Heard** and/or :material-eye: **Seen** on the confirmation sheet and tap **Add**. The entry is timestamped to that moment, tagged with the current GPS fix, and appears immediately in the detection list and on the route map with the manual badge and the matching ear / eye glyphs.

Voice memos are deliberately absent here: the microphone is busy with the survey's own capture. Attach them in Session Review after the survey ends.

## Background Operation

Survey Mode keeps a persistent foreground notification visible while recording so Android won't suspend the audio pipeline. The notification expands to show:

- the elapsed time, detection count, species count, and distance walked, and
- the **three most recent unique species** with their confidence and a relative timestamp (`just now`, `42s ago`, `5m ago`, `2h ago`).

The notification — title, recent detections, and stats footer — is fully translated into the app's selected language and uses the same species-locale and *Show scientific names* preferences as the in-app cards.

Species alerts (when enabled) appear on a separate Android notification channel so you can mute alerts independently of the silent ongoing recording notification. The alert icon matches the foreground notification icon (a monochrome bird), and alert bodies show only the *reason* — *"First detection of this survey"*, *"On your watchlist"*, *"Detected at this location with under 4% likelihood"*, *"New for your life list"* — leaving the species name in the bold notification title where Android renders it largest.

When you **resume** an unfinished survey from Session Library, the alert pipeline is re-armed from your *current* notification preferences — not whatever you had configured the day you started the survey. Toggle alerts off (or change the mode, watchlist, or throttling) before tapping Resume and the resumed survey will respect the new settings immediately.

## Reviewing on the Map

The fullscreen Survey map view (the :material-fullscreen: button in Session Review) opens a clip player when you tap a marker. The transport row has skip-previous and skip-next buttons flanking the play control — they walk through detections in chronological order, but **only those currently visible on the map**, so any active species, confidence, or mode-chip filter narrows the playlist accordingly. The buttons grey out at the first/last detection in the filtered list.

## After Stopping

BirdNET Live saves the finished survey and opens [Session Review](session-review.md).