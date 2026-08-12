# Settings

BirdNET Live reuses one Settings screen across multiple workflows. The :material-tune: button opens the sections that are relevant to the screen you came from.

## How Settings Scope Works

- Opening Settings from Home shows the full screen.
- Opening Settings from Live, Survey, Point Count, or File Analysis filters the screen to the relevant sections.

## General

### Theme

Choose **Dark**, **Light**, or **System**.

If **Dynamic Color** is enabled, BirdNET Live also tries to match your Android device's system palette. This has an effect only on supported Android devices; on iPhone and iPad the app keeps using the standard BirdNET Live theme, so turning the toggle on there changes nothing.

Enable **High Contrast Theme** to use a black-and-white light or dark UI palette with heavier text and bordered surfaces instead of tinted cards. It follows the **Dark**, **Light**, or **System** theme choice, overrides Dynamic Color while enabled, and preserves danger, warning, validation, mode, score, and spectrogram colors.

### App Language

Sets the interface language.

### Species Names

Controls the language used for species names. **System** uses the phone's preferred language when that name is available, even if the interface falls back to English. **Follow app** uses the interface language instead.

### Show scientific names

Shows scientific names below common names across the app.

### Show all detected species

Live Mode and Point Count only. Off by default, so these screens continue to show only species detected in the latest inference cycle: effectively the species that are currently vocalizing. Turn it on to keep every species detected during the running session visible in the list, even after it stops vocalizing or falls below the confidence threshold.

When this is enabled, **Species list sorting** appears. **Newest first** shows currently vocalizing species first, sorted by their current confidence, then retained species by their most recent detection. **Confidence** sorts by each species' highest confidence reached during the session, **Alphabetically** sorts by the localized common name, and **Occurrences** sorts by detection count. In every sorting mode, the confidence percentage and bar appear only while that species is currently vocalizing (retained rows that stopped vocalizing are dimmed), and repeated detections show a count chip at the end of the common-name row.

### Observer name

Survey, Point Count, and ARU setup remember the latest non-empty observer name entered in any of those modes and prefill it the next time you set up a field session. This keeps repeat use quick on a personal field phone while still letting you edit or clear the observer before starting a session.

### ARU/station ID

ARU setup remembers the latest non-empty ARU/station ID and pre-fills it for the next deployment. When present, the ID is included in the ARU session name and export filenames so repeated fixed-site deployments stay identifiable outside the app.

### Timestamp display

Controls how per-detection times appear in session review.

- **Relative** shows the offset from the start of the recording, e.g. `00:12:34`. Best for reviewing a single session and matching the spectrogram playhead.
- **Absolute** shows the local clock time when the detection was captured, e.g. `08:42:17`. Best for cross-referencing field notes, weather logs, or simultaneous recordings.

If a detection lands on a different calendar day from the session start (e.g. an overnight survey), the absolute time gains a `+1d` suffix so reviewers don't accidentally read tomorrow's dawn chorus as today's.

When **Absolute** is selected, an additional **Show seconds in timestamps** toggle appears. Disable it if you prefer the more compact `08:42` over `08:42:17` — useful when scanning long detection lists. Relative offsets always show seconds because reviewers need sub-minute precision to align with the spectrogram playhead.

Storage and exports always use UTC instants regardless of this setting, so the choice never affects the data — only the way it's displayed.

## Audio

These controls appear in audio-driven live workflows.

### Audio source

One sheet with two independent controls: **Microphone** — which input to record from — and **Processing** — how much the phone is allowed to alter the signal on the way in. They combine freely, so a USB microphone recorded *unprocessed* is a perfectly valid setup. Your selection is remembered across app launches, and the same picker appears on the Survey, Point Count, and ARU setup screens. Changes take effect immediately — even mid-recording, the app swaps the microphone under the running session rather than waiting for the next one.

**Microphone** lists every input the phone exposes, by name: USB, wired and Bluetooth mics, and on many phones the individual built-in mics too (e.g. *bottom* and *back*). Wireless mic kits like the Rode Wireless GO or DJI Mic connect through a USB-C receiver, so they show up here as ordinary USB audio devices at full quality.

**Processing** is the part that matters most, and it is **Android only**. Phones apply a speech-tuned DSP to microphone audio by default — noise reduction, spectral shaping and automatic gain — because the mic is overwhelmingly used for phone calls. That processing treats bird song as noise to be suppressed, and no ordinary setting turns it off. The only way around it is to ask Android for a different *audio source*:

| Option | What it does |
|---|---|
| **Phone default** | Whatever your phone does normally, voice processing included. The original behaviour, and still the default so nothing changes under existing users. |
| **Unprocessed** | The raw microphone signal — no noise reduction, no automatic gain. Usually the best choice for birds. |
| **Voice recognition** | Also turns off noise reduction and automatic gain, and works on nearly every phone. |

**Try them and compare.** Which one wins genuinely depends on the handset. *Unprocessed* is the ideal, but Android only honours it on phones whose manufacturer declares support — on the rest it silently falls back and sounds identical to *System default*. That is what *Voice recognition* is for: Android's compatibility rules **require** automatic gain and noise suppression to be off for it, so it reliably delivers unprocessed audio even on phones that ignore *Unprocessed*. If switching to *Unprocessed* changes nothing, switch to *Voice recognition*.

Expect the unprocessed options to sound **quieter** — that is the automatic gain being gone, not a fault. Raise **Gain** to compensate if the level meter looks low.

**On iOS** the Processing control is hidden and the sheet is simply a microphone list. iOS already hands the app essentially unprocessed audio, so there is nothing equivalent to choose.

### Gain

Linear amplifier applied to incoming audio before it reaches the spectrogram and the classifier. Leave at **1.0×** unless your input is consistently too quiet — for example a high-impedance lavalier mic on a phone, or a USB interface whose preamp is set too low. Pushing gain above 1.0 will not magically reveal calls that the mic never captured; it just rescales whatever the mic delivered, so loud nearby sounds may clip. Below 1.0 is useful in the rare case where a hot input is saturating the spectrogram.

### High-pass filter (Hz)

Cuts low-frequency content before inference using a 24 dB/octave Butterworth filter — the slider value is the −3 dB cutoff. **0 Hz disables it.** A 100–200 Hz cutoff strips wind, traffic rumble, and handling noise without touching most species; pushing toward 500–1000 Hz starts removing low whoots, owls, grouse, and bittern booms, so only go that high if you are deliberately ignoring those species in exchange for a much cleaner spectrogram in a noisy urban environment. The cutoff you pick should be visible as a sharp horizontal line on the live spectrogram.

## Inference

### Window duration

Controls the length of the analysis window. Available steps are **1**, **3**, **5**, **7**, **10**, and **15** seconds.

### Confidence threshold

Sets how conservative detections should be. The default is **35%**, which keeps the live list focused on stronger matches while still leaving room for distant or partially masked calls. Lower it if you are surveying rare or quiet species and plan to review more candidates later; raise it when background noise or common false positives are crowding the session.

### Sensitivity

An x-axis offset applied to the model's raw probability scores before score pooling, geographic filtering, and the confidence threshold. BirdNET's audio model already includes a sigmoid activation, so BirdNET Live first converts each probability back to logit space, adds the sensitivity bias, then converts it back to a probability. Higher values make the detector more permissive — fainter or more ambiguous calls cross the threshold, at the cost of more false positives. Lower values are stricter and only let confident detections through. The default of **1.0** applies no offset and matches the BirdNET reference. Try **1.25** if you suspect the model is missing distant calls; drop to **0.75** if you are flooded with low-quality detections of common species. Sensitivity is hot-applied: changing it mid-session takes effect on the next inference window.

### Inference rate

Controls how frequently BirdNET runs inference. The slider uses the same
**0.10–1.00 Hz** steps as Survey and ARU setup. Windows are anchored to
captured audio samples rather than timer completion, so recording a clip or a
temporarily slow model call does not shift later windows. With matching
inference settings, Live Mode, Point Count, and Survey analyze the same windows
and report the same detections. Lower rates reduce model work and battery use
but leave wider gaps between windows, so very brief vocalizations are easier to
miss. New Surveys default to **0.70 Hz** as a middle ground; **0.30 Hz**
remains an explicit maximum-battery option. File Analysis has no inference rate
— it uses an [overlap](file-analysis.md) setting instead.

### Ignore species

Opens an overlay with binary inference filters. Check **Birds**, **Mammals**, **Amphibians**, or **Insects** to suppress that entire taxonomic class. All four checkboxes are off by default.

The **Ignore common species above** slider runs from **80–100%** and suppresses species whose current geo-model score is strictly above the selected cutoff. It defaults to **100%**, which ignores no species by commonness; lowering it ignores progressively more common species. The overlay runs the geo model once for the current location and shows the resulting total number of ignored species. Moving the slider or changing a checkbox reuses that cached prediction instead of running inference again. The common-species rule needs a location-based geo-model result, while taxonomic-group filtering works without a location.

The filter is applied to both geo-model and audio-model probabilities immediately after sigmoid activation. Ignored scores become exactly zero before temporal pooling, so they cannot contribute to a later pooled result or become a displayed, saved, announced, or exported detection. Changes made during an active Live Mode, Point Count, Survey, or ARU Session apply to the next inference window; File Analysis uses the values selected when analysis starts.

BirdNET Live internally smooths scores across recent inference windows to
reduce one-off false positives. This pooling is not exposed as a user setting;
the default uses adaptive Log-Mean-Exp pooling with five recent windows and a
10-second real-time age cap. Accepted detections display the strongest recent
supported model confidence, so obvious vocalizations can still show high
confidence instead of being flattened by smoothing. Every mode now turns that
pooling result into detections the same way: a detection starts at its earliest
supporting window, carries the strongest supported score, and ends at the end
of the last supporting window.

## Spectrogram

### FFT size

Controls frequency resolution in the spectrogram.

### Color map

Choose **Viridis**, **Magma**, **Plasma**, **Cividis**, **Jet**, **Turbo**, **Grayscale**, or **BirdNET**. **Turbo** is the modern Jet-like rainbow option.

### Duration (scroll speed)

Controls how much time is visible in the spectrogram window.

### Frequency range

Sets the upper display frequency.

### Log amplitude

Applies logarithmic scaling to the spectrogram for easier visual reading.

### Quality

Controls how smoothly the spectrogram image is scaled. **Medium** is the default balance. Choose **Low** on older phones when scrolling stutters or the device gets hot; choose **High** when you prefer smoother visuals and your device has enough GPU headroom. The intuition: this changes rendering cost only, not the audio analysis or detection results.

## Announcements

This section controls whether BirdNET Live **reads detections aloud through your headphones or the phone speaker** while a session is recording. The whole feature is **off by default** because it changes the acoustic environment around the microphone — turning it on is a deliberate trade-off. There is no setup wizard: the verbosity × frequency pickers below *are* the entire setup, so you can tap a different preset at any time and immediately hear the difference. The intuition: in long surveys you can't keep glancing at the screen; a discreet voice in your ear means you can keep your eyes on the habitat and still know what was just heard.

### Speak detections aloud (master toggle)

Off by default. When on, the app speaks each accepted detection using your device's built-in text-to-speech. **Headphones are strongly recommended** — using the phone speaker risks the announcement being picked up by the microphone and re-detected, so the app briefly mutes the recorder around each utterance to prevent that loop (see *Mute mic while speaking* below).

### Verbosity preset

How much the app says about each detection. **Minimal** speaks just the species name (best for very long surveys where you only want the cue). **Balanced** is the default — short, varied phrases like *"Robin"*, *"Heard a Robin"*, *"Robin again"*. **Chatty** adds a touch more context and is closer to having someone narrate alongside you. **Custom** appears automatically if you tweak the Advanced numerics by hand. The intuition: the same throttling settings can feel either too quiet or too noisy depending on phrasing — verbosity lets you keep the cadence and just dial the wordiness.

### Frequency preset

How often the app is allowed to speak at all. Five steps from quietest to most talkative. **Rare** and **Sparse** wait a long time between announcements and cap the rate — well-suited to multi-hour surveys where you want a sense of activity without a running commentary. **Normal** is the default conversational cadence. **Frequent** shortens the gaps and lifts the cap; appropriate for short Live sessions or when you want closer-to-real-time feedback. **Constant** removes the startup delay entirely and lets the app speak on almost every detection cycle — useful for demos, accessibility, or whenever the gap before the first announcement on *Frequent* feels too long. **Custom** appears when you change the timing fields in Advanced. The intuition: this is the one knob that decides whether the app stays in the background or becomes a presence — tap a different preset and you'll hear the new cadence within the next detection cycle, no save button required.

### Voice

Tap the voice row to choose among the text-to-speech voices installed for the announcement language, or leave **Default voice** selected to let the device choose. Voice availability and quality depend on the operating system and installed speech packages; additional voices can be installed from the device's text-to-speech settings.

**Speed** ranges 0.5×–1.5×; the default 1.0× is the platform "normal" pace. **Pitch** ranges 0.7×–1.3×. A small reduction in pitch and a slight slowdown can make announcements easier to parse outdoors with wind or moving water in the background. *Speak a sample* previews the selected voice, current phrasing style, speed, and pitch without leaving Settings. Changes apply to the next announcement.

### Advanced

A disclosure that exposes a handful of audio-routing toggles plus the trigger-mode picker. You generally do not need to open this — the verbosity and frequency presets above are the only knobs that matter day to day. The rate-limiting numerics (startup grace, minimum gap, max per minute, streak silence, recency reset) are bundled into the **Frequency** slider so there is one obvious place to dial cadence up or down.

- **Allow phone speaker** — When off, announcements are silently skipped if no headphones or external speaker is connected. When on, the phone speaker is used as a fallback. Turn this on for casual listening at home; leave it off for fieldwork to guarantee no acoustic feedback into the microphone.
- **Mute mic while speaking** — Replaces incoming audio with silence while the app speaks, so the speaker output cannot be picked up by the microphone and re-detected. Highly recommended (and the default). Only turn this off if your microphone is acoustically isolated from the phone speaker — for example a clip-on lapel mic on a different cable or a Bluetooth headset.
- **Lower other audio** — Briefly reduces the volume of music or podcasts from other apps during the announcement and restores it afterwards. On by default. Off plays at full mix.
- **Cue tone before speaking** — Plays a short, quiet tone before each utterance so your ear has a moment to switch from passive listening to attending to the voice. On by default. Particularly helpful when announcements are infrequent or when you have music playing in the background.
- **What to announce** — Picks which detections are eligible for an announcement at all. *Every detection* (default) lets the throttling decide. *First time per session* announces a species only the first time it appears in the current session. *Watchlist only* limits announcements to species on your watchlist (useful for targeted survey work where you want to hear about your priority taxa and nothing else).

## Recording

### Mode

- **Full** — save the whole recording
- **Detections only** — save clips around detections
- **Off** — no audio recording

### Clip context

When **Detections only** is active, the app shows a single **Clip context** slider (0–5 s) that sets how much audio is preserved on **both sides** of each detection. Each clip is `analysis window + 2 × clip context` long, so with a 3 s analysis window and the default 1 s context the saved clip is 5 s. Setting the context to 2 s yields a 7 s clip (2 s pre-roll + 3 s analyzed audio + 2 s post-roll). Larger values give you more room for visual inspection or external review tools at the cost of disk space; 0 saves only the analyzed window itself.

### Format

Choose **WAV** or **FLAC**. WAV is larger but widely compatible and quick to inspect. FLAC keeps the same lossless audio quality while using less storage, which is usually better for long sessions.

This setting applies to audio recorded by BirdNET Live. **File Analysis** keeps an app-managed copy of the imported file in its original format, so MP3, AAC, WAV, and FLAC uploads stay reviewable without an extra conversion step.

### Auto-start recording (Live mode only)

When enabled, Live mode begins recording as soon as the screen opens and the model finishes loading — no need to tap the microphone button. Useful for kiosk-style deployments, hands-free use (e.g. mounting the device in the field), or any workflow where the user already knows that opening Live always means "start now". Disabled by default so an accidental tap on the Live tile from the home screen does not silently begin a session. The auto-start fires only once per screen visit, so stopping a session and tapping the mic again still works as a manual restart.

This setting governs opening Live mode from inside the app. The [Quick Listen widget](live-mode.md) starts listening when tapped, whatever this is set to, and leaves the setting untouched. If a Point Count, Survey, File Analysis, or ARU Mode Session is already running or starting, it preserves that Session and asks you to stop it first instead.

### Save sessions automatically (Live and Point Count)

When enabled (the default), a completed Live or Point Count session is added to your library automatically the moment it finishes. When disabled, a finished session opens in review marked as **unsaved**: the save icon is highlighted and you must tap it to keep the session. Leaving review without saving discards the session and its recordings. This suits quick listening sessions where you only want to keep the occasional noteworthy result instead of accumulating every short recording. Survey and ARU deployments always save automatically — a long unattended run is too costly to lose by forgetting to tap Save — so this toggle does not apply there.

## Playback

### Playback overlay in review

When enabled (which is the default), reviewing an audio clip in a clips-only Session Review (where no full audio recording/spectrogram is available) triggers a dedicated modal player overlay with transport controls and a spectrogram preview, rather than playing the clip in the background. If a session has full audio, this setting is bypassed and the playback overlay is never shown.

### Auto-play voice memos

Off by default. When enabled, a voice memo attached to a timed annotation plays automatically during Session Review the moment the playhead crosses its recorded position. The memo is mixed on top of the recording rather than pausing it, so you hear your spoken note in context alongside the original audio. Leave it off if you prefer to trigger memos manually by tapping their annotation chip.

### Voice memo ducking

Shown only when **Auto-play voice memos** is enabled. Controls how much the main recording is lowered while an automatic voice memo plays. Higher values make spoken memos easier to hear; lower values keep more of the original recording audible underneath the memo.

## Location

### Use GPS

Use device GPS instead of manual coordinates. On Android, fixes come from the
platform location provider rather than Google Play Services, so the app does
not trigger Google's location-accuracy resolution dialog. With this off, the
app never reads the GPS or asks for location permission on its own: the
Survey, Point Count and ARU setup wizards open on manual entry with your saved
coordinates, survey GPS tracking does not run, and offline map preparation
centres on those coordinates too.

### Manual coordinates

The coordinates used when **Use GPS** is off. Both Latitude and Longitude are editable text fields, so you can **type** an exact value or **paste** one copied from another app — far more precise than dragging a slider on a touch screen. Enter decimal degrees (e.g. `52.5200` and `13.4050`). You can also paste a combined `latitude, longitude` string (comma-, semicolon-, or space-separated) into *either* field and both fields fill at once, which matches what most maps and websites put on the clipboard. Out-of-range or non-numeric input is flagged inline and not saved; valid values persist as you type. The intuition: the most common reason to set a manual location is to ID a sound recorded somewhere other than where you are now, and that location usually comes as text from elsewhere — typing and pasting make that a single accurate step. If you would rather point at a spot than type numbers, **Pick on map** opens the same full-screen map picker used in the setup screens, seeded with the current coordinates, and fills both fields with the location you tap.

### Refresh GPS now

Forces a fresh location fix instead of reusing the last value the app cached. The intuition: GPS lookups are cached per-screen so a setup screen does not block waiting for a satellite fix on every open, but that cache can be miles out of date if you have driven to a new spot since the last session. Tap this when you have moved and want the geo-filter to use *here*, not where you started the morning. The current cached coordinates are shown in the subtitle so you can verify what the app thinks your location is. If GPS cannot get a fix within ~10 seconds, the app falls back to the OS-provided last-known location and warns you with a snackbar so you know the value is stale.

### Offline map downloads

Offline map downloads are currently hidden while BirdNET Live uses the public OpenStreetMap tile service. OpenStreetMap supports normal interactive map browsing with attribution, a clear user agent, and local caching, but it does not allow bulk prefetching or offline map-download features from `tile.openstreetmap.org`. The downloader implementation is kept for a future tile source that explicitly permits offline packs.

### Species filter

- **Off** — no geographic filtering
- **Location filter** — exclude species that fall below the geographic threshold
- **Adaptive location filter** — ask for more confidence the less common a species is here
- **Location weighting** — use the geo-model as an additional weighting signal

### Geo-filter threshold

Appears when **Location filter** or **Location weighting** is active. The adaptive filter works out its own bar from the local species mix, so it has no slider.

### How the adaptive filter decides

It scales the bar with how common a species is at your location, using the same abundance tiers you see on the **Explore** screen. Species in the *Abundant* tier are never filtered; below that the required detection score climbs steadily, and species that are not on the local list at all need around 0.92 or more. Anything scoring 0.99 or higher is kept whatever the location model says.

| Tier at your location | Detection score needed |
|---|---|
| Abundant | any |
| Common | ~0.55–0.70 |
| Frequent | ~0.70–0.82 |
| Uncommon | ~0.78–0.89 |
| Scarce / Rare | ~0.83–0.92 |
| Not on the local list | ~0.92–0.97 |

Because the tiers are rank-based, this behaves the same in a species-rich tropical forest as in the Arctic. Detections that survive keep their original score — the location model only votes on whether to show them. The aim is to cut false positives from uncommon species without losing a genuinely clear recording of one.

## Export & Sync

### Formats

Tick any combination of export formats — every save / share will bundle all the selected formats together inside a single ZIP. Pick a single format with no audio clips and no HTML report and you'll get a raw file (e.g. `session.csv`) instead of a ZIP, for backwards compatibility:

- Raven Selection Table — for use in Cornell Raven Pro.
- CSV — opens in any spreadsheet.
- JSON — easiest for programmatic processing; carries the full per-session metadata.
- GPX — track and waypoints for use in mapping tools (only meaningful when GPS was on).

The intuition: many workflows need more than one format at the same time — a CSV for the spreadsheet, a Raven table for the desktop reviewer, and a JSON for the analysis script. Untangling that with a single-format toggle used to mean exporting the same session three times. Now you tick all three once and they ride together in the ZIP.

### Include audio files

Include saved audio alongside the exported tables or metadata when supported by the export workflow. Sharing one detection follows this setting too: a full-session recording is cut to that detection's exact start-to-end timestamps, while a detection-only session uses its retained clip.

### Always share audio as WAV

Shown only when **Include audio files** is on. When enabled, FLAC recordings are converted to WAV before sharing or exporting. WAV is universally compatible but significantly larger than FLAC, so leave this off unless the tool on the receiving end cannot read FLAC — some older desktop analysis software and a few upload forms still can't.

### Include app metadata

When on, the export ZIP carries a `*.metadata.json` side-file describing how the session was produced: BirdNET Live version, model identity, the weather snapshot captured at session start, and any audio integrity warnings detected during recording. The intuition: that provenance is what lets you (or a reviewer) reproduce or audit a session months later. Turn it off when you want a clean share of just the audio and your selected formats — for example, dropping a single WAV into iNaturalist or eBird without any app-specific files riding along.

### Include HTML report

When on, every export ZIP also contains a `<session>_report.html` file alongside the table, audio clips, and GPX. Open it in any web browser and you get a print-ready summary of the session: header card with date, location, observer, and totals; an interactive map of the GPS track and detection markers; a card per detection with the Cornell taxonomy thumbnail, names, score pill, your confirmation, any note you typed, and the original audio clip inline as a player; and the analysis settings used. The intuition: a CSV is great for analysis pipelines but useless for sharing with a non-technical collaborator or printing a quick field summary — the HTML report fills that gap with one tap. Species thumbnails and map tiles need a connection the first time the file is opened (they're fetched live from the BirdNET taxonomy API and OpenStreetMap), but everything else — text, layout, audio playback, links — works fully offline. Turn this off if you only need the raw data and want to keep the ZIP a few KB smaller.

### Audio-only sharing

Untick every format **and** the HTML report **and** the app metadata box, leaving only **Include audio files**, and Share will hand the platform sheet the raw recording (e.g. `BirdNET_Live_…flac`) instead of a ZIP. That is the low-friction path for sending a session straight into iNaturalist, eBird, or any other app that wants an unwrapped audio file. Sessions made of multiple detection clips still produce a ZIP; sharing one detection hands over that one raw clip.

## eBird Life List

Import your eBird life list via CSV export so BirdNET Live can flag species it hears that you haven't personally logged yet — a **lifer**. This is separate from the app's own detection history: a species can be a lifer here even if BirdNET Live has heard it before, as long as you've never logged it on eBird. Once imported, lifers get a star badge on Live detections and in Session Review, and the Survey **Species alerts** mode picker gains a matching **Lifer** option (see [Survey Mode](survey-mode.md)). Re-importing replaces the list entirely; there's no merge with a previous import.

## Privacy

This section controls **which third-party services BirdNET Live may contact on your behalf**. Inference itself runs entirely on your device — these toggles only govern optional network features that enrich the experience. All three toggles are **off by default** on a fresh install; nothing reaches out until you say so. The intuition: each toggle is scoped to one concrete service and one concrete benefit, so you can opt into exactly what's useful to your workflow and nothing else.

### Allow map tiles

Required for any interactive map in the app (the location picker, the Survey live map, and the session map). When on, map widgets fetch raster tiles from the public **OpenStreetMap** servers; tile-coordinate requests reveal which area of the world you're viewing. Tiles are cached locally for up to six months, capped at 6000 tiles so repeated map views stay efficient without growing unbounded. Turning this on also enables **Allow place name lookup**, because most users who load maps expect sessions to show readable place names too. You can turn place-name lookup off again separately. When map tiles are off, every map screen falls back to a placeholder card so the rest of the app still works without network leakage.

### Allow place name lookup

When on, the app sends your recorded coordinates to **OpenStreetMap's Nominatim** service to resolve a short place name (e.g. *"Berlin, Germany"*) that is shown next to the session in Session Library and Session Review. The intuition: numeric coordinates are precise but hard to scan when scrolling through a long list of sessions — a place name turns the list into something you can read at a glance. When off, sessions show the raw lat/lon only, and Nominatim is never contacted.

### Allow weather lookup

When on, every saved session captures a one-shot snapshot of local conditions (temperature, precipitation, wind, cloud cover) at the recording coordinates and end time via **Open-Meteo**. The snapshot lands in Session Review under the location row and is mirrored into the JSON export, the per-session metadata block, and the HTML report. The intuition: weather is one of the strongest predictors of bird activity, and capturing it automatically — without you having to remember to check a separate app — turns every session into a more complete record. Open-Meteo is a free service and requires neither an account nor an API key. When off, no weather data is fetched or stored. Point Count and Survey setup also show a compact weather card near their location controls: it asks for this consent only when needed, previews the result as icon + temperature + wind once enabled, and reuses the same cached snapshot when the session is saved.

## About

The **About** row opens the in-app About screen.

## Danger Zone

### Reset Onboarding

Shows the onboarding sequence again the next time the app launches.

### Reset All Settings

Restores every preference on this screen to its default value. Sessions, recordings, voice memos, exports, and cached map tiles are kept untouched — only the saved preferences (sliders, switches, picker choices) get wiped. The app closes after confirmation so the new defaults take effect on next launch.

Useful when you are not sure which slider you nudged that broke something, or when handing the device to someone else and you want a clean configuration without losing the data you collected.

### Clear All Data

Permanently deletes sessions, detections, recordings, voice memos, custom species lists, saved preferences, and cached map, place-name, weather, playback, review, and share data. The confirmation dialog requires typing `DELETE`, then closes the app so the next launch starts from a clean local state.

Use this before handing a device to another observer, retiring a field phone, or removing location-linked history from the app. Export anything you need first; this action cannot be undone.

## Workflow-Specific Parameters Outside Settings

Some parameters are configured inside their own setup screens rather than in the shared Settings screen.

- [Point Count Mode](point-count-mode.md) has its own duration and location setup.
- [Survey Mode](survey-mode.md) has its own survey parameters screen.
- [File Analysis](file-analysis.md) has its own analysis-parameter step.
