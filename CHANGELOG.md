# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [1.1.2] - 2026-08-11

### Added

- BirdNET Live now accepts audio files from the system share sheet and file managers, opening File Analysis immediately on Android and iOS.

### Changed

- Sharing an audio recording to BirdNET Live on iOS now opens the app straight away. Previously the recording was only picked up the next time BirdNET Live was opened, so the share appeared to do nothing.
- Tapping the Quick Listen widget now opens Live Mode directly, instead of showing the home screen first.

### Fixed

- Norwegian Bokmål and Nynorsk users now see Norwegian species names instead of English names.
- Leaving File Analysis or a Point Count session no longer throws while the screen is torn down, which could leave the widget tree half-disposed.

## [1.1.1] - 2026-08-10

### Changed

- Exports no longer report an unreviewed detection as if a reviewer had judged its identification wrong. The `Confirmed` (true/false) column in CSV and Raven exports is replaced by `Review Status`, carrying `confirmed`, `rejected` or `unreviewed`, and `Confirmed At (UTC)` becomes `Reviewed At (UTC)`. JSON detections swap the `confirmed` boolean for a `reviewStatus` string plus `reviewedAt`. Scripts that read the old column or key need updating.

### Added

- New **Adaptive location filter** mode, alongside the existing Location filter and Location weighting. It asks for more confidence the less common a species is at your location, using the same abundance tiers as the Explore screen: abundant species are never filtered, while uncommon or unlisted ones need a high detection score before they show up. Detections that survive keep their original score, unlike Location weighting.

## [1.1.0] - 2026-08-07

### Changed

- File Analysis now shows a concise, actionable message when it cannot process an imported recording instead of exposing a raw filesystem exception.
- Live Mode, Point Count, and Survey now share one sample-aligned inference schedule, so matching inference settings produce matching windows, timestamps, peak scores, and detection spans across the three modes. File Analysis keeps its own overlap setting but applies the same detection rules.
- New Surveys now default to 0.70 Hz inference, improving coverage of short vocalizations while retaining a meaningful reduction in model work compared with 1.00 Hz. The 0.30 Hz option remains available for maximum battery savings.
- The Privacy Policy now identifies the app as BirdNET Live and the AppGallery developer as BirdNET-Team, and more precisely explains local personal-information processing and the data sent to optional map, place-name, and weather providers.

### Fixed

- Recording from an external USB-C microphone no longer produces distorted audio and a spectrogram mirrored across its middle. Such mics usually offer only stereo capture, and the second channel was being read as extra mono samples; both channels are now mixed down to mono as intended.
- Live and Survey detections now appear as soon as inference finishes; saving or replacing a detection clip continues in the background and no longer delays the UI or shifts the next audio window.
- Detection clips are now cut from the analysis window that produced the score, so a clip saved while the device is busy still contains the sound it was saved for.
- Detection clips now cover the whole analysis window. With a 5- or 10-second window they previously held only its last 3 seconds.
- Detection timestamps at the start of a session are no longer shifted by however long the microphone took to deliver its first audio.
- A species that stops and is heard again shortly afterwards is now always kept as its own detection. Previously the second detection could take over the first one's audio clip and delete it.
- Live Mode no longer smooths scores across a pause, which could date a detection heard after resuming inside the paused gap.
- File Analysis no longer stops recording new detections after 10,000. That ceiling exists for the live modes, which run until you stop them, and should never have applied to a file of known length.
- ARU cycles now analyze the audio captured while the model was loading instead of discarding it and waiting for a further full window.
- The Survey notification now lists the species heard most recently, so a bird that is still calling stays visible instead of being pushed out by species that have already stopped.
- User-guide links now open the existing Dutch, Polish, Russian, and Simplified Chinese translations instead of falling back to English.

## [1.0.6] - 2026-08-05

### Changed

- Session Review now draws the spectrogram in tiles for every recording, so a long session opens as quickly as a short one and never loads the whole file into memory. The full-recording view used for trimming is built when you open the trim editor instead of on every open.
- Reviewing an imported MP3, M4A, or other compressed recording no longer waits for the whole file to be decoded first. The spectrogram appears within seconds and fills in as decoding proceeds; a 44-minute MP3 went from about 3.5 minutes of blank strip to under 15 seconds. Leaving the screen now stops the decode instead of letting it run on.
- Tapping a detection in a long recording now zooms the spectrogram to the duration set under Settings → Spectrogram and draws just that window, so the call appears and plays right away instead of waiting on a view spanning several minutes.
- Spectrogram drawing is substantially faster, most noticeably when zoomed out and on imported recordings that are not already at 32 kHz — a wide tile went from 657 ms to 47 ms. Drawing now costs the same whatever span the view covers.
- Transcode caches left behind by a crash while reviewing a compressed recording are now cleaned up; each one could be several hundred megabytes.

### Fixed

- Short recordings no longer flash a black spectrogram while opening. Sessions up to two minutes schedule the whole recording in one sweep, while recordings that fit one tile skip the FLAC frame index they never seek against.
- Pinch-zooming the spectrogram no longer blanks the strip. The tiles you are looking at stay on screen until their replacements arrive.
- Fixed a crash that could close the app when audio capture restarted after losing the microphone to another app. Capture start, stop, and source switches now run one at a time and always release the old recorder first.
- Scrubbing and jumping to detections late in a long FLAC recording is no longer slow. Every spectrogram tile used to decode the recording from the beginning — about 19 seconds per tile an hour in — so Session Review now builds a frame index once when the session opens.
- Trimming a recording or sharing a detection from late in a FLAC session uses the same index instead of re-decoding everything before the cut.
- Opening a recording no longer freezes the interface while checking whether it needs a playback loudness boost; that decode moved to the background.

## [1.0.5] - 2026-08-04

### Fixed

- Sharing now works on iPad. Every share button passes the anchor rectangle iPadOS requires for the share popover, which previously made the buttons do nothing. A share the system refuses now reports an error instead of failing silently.
- Sharing one detection from a full-audio Session now includes an exact start-to-end audio clip and honors the saved export format, include-audio, WAV conversion, HTML report, and app-metadata settings instead of falling back to text-only sharing.

## [1.0.4] - 2026-08-03

### Changed

- Upgraded the Android build toolchain to AGP 9.0.1, Gradle 9.1.0, and Kotlin 2.3.20, which enables R8 optimized resource shrinking and trims the app bundle slightly. Needs on-device testing before release.
- File Analysis now sends up to four audio windows through each model call and uses five inference threads on Android, substantially improving offline-analysis throughput while preserving per-window timestamps, temporal pooling, and bounded-memory decoding.
- File Analysis now reads WAV files in bounded chunks, overlaps decoding with inference, and uses two concurrent Android decoders for compressed audio. A 31.5-minute MP3 decoded 2.17x faster on a Pixel 10 Pro while keeping memory bounded.

## [1.0.3] - 2026-08-01

### Fixed

- Fixed the crash that closed the app as soon as a recording started. A dependency update had silently swapped the bundled ONNX Runtime for a build that faults during inference on arm64 devices; the inference runtime is now pinned to the version that shipped in 1.0.1.
- The HTML report no longer looks broken when its map cannot load. It now always offers a "View on OpenStreetMap" link, and explains the problem if the browser blocks the map tiles — which mainly affected reports opened straight from disk in Firefox.
- The HTML report now explains why audio will not play when the report is opened from inside the export ZIP, instead of showing a player that silently does nothing.

## [1.0.2] - 2026-07-31

### Added

- Added **Ignore species** under Settings → Inference. Users can suppress birds, mammals, amphibians, or insects and ignore very common species with an 80–100% geo-model cutoff (100% by default). The overlay shows how many species are currently ignored from one cached geo-model prediction for the current location. The binary mask zeros geo-model and audio-model scores before temporal pooling, applies across Live Mode, Point Count, Survey, ARU Mode, and File Analysis, and is recorded in Session metadata.

## [1.0.1] - 2026-07-30

### Added

- Simplified Chinese (简体中文) is now a full app language: UI strings, spoken announcements, and offline species descriptions for 3,641 species. Chinese species common names were already bundled and now resolve for the Chinese app locale. Not yet verified on the Windows desktop build — see `dev/windows.md`.

### Fixed

- Species descriptions and Wikipedia links now resolve for regional species-language settings. Tags carrying a region (`zh-CN`, `es_ES`, `pt_PT`) missed the bundled files, which are keyed by bare language code, and silently fell back to English.
- Dates and newly resolved place names now follow the app language. Session cards separate the localized date and time with a dash instead of the hardcoded English word "at." A resolved place label remains attached to its Session and is not queried again after a language change.
- Wind-direction abbreviations now follow the app language in weather cards and dialogs, while stored bearings and export metadata remain language-neutral or English. JSON and GPX exports now localize species common names like the existing Raven, CSV, and HTML exports.

## [1.0.0] - 2026-07-30

### Added

- Manually added species can now record whether you **heard** or **saw** the bird. After picking a species, a confirmation sheet lets you tick Heard and/or Seen before the entry is added. This applies everywhere you add a species by hand: Session Review, the replace-species flow, and the live Survey. The choice shows as ear/eye glyphs on detection rows and ships in CSV, Raven, JSON, and HTML exports.

### Changed

- The HTML report in an export ZIP is now named after the Session (`<session>_report.html`) instead of `report.html`, so extracting several exports into the same folder no longer overwrites earlier reports.
- Species photo credits no longer show the image license in brackets, just the photographer and the source.
- Reduced scores for Black-crowned Night Heron detections through the model-specific score blacklist.

### Fixed

- The main menu logo no longer appears a beat after the rest of the screen. The background warm-up that prepares Live Mode was parsing the 11 MB taxonomy file on the main thread and holding up the logo behind it; that parse now runs off it.

## [0.20.0] - 2026-07-30

### Added

- Added a "Quick Listen" home-screen widget (Android), in 2x1 and 1x1 sizes, that jumps straight into Live Mode and starts listening. It reuses an already-open Live Mode screen without restarting its Session. If Point Count, Survey, File Analysis, or ARU Mode is running or starting, the app preserves that Session and asks the user to stop it first instead of replacing its screen.

## [0.19.5] - 2026-07-29

### Fixed

- The app no longer triggers Google's "turn on location services" dialog. Location fixes now come from Android's own location provider instead of the Play Services one, which pops that dialog on every request when you have declined Google Location Accuracy — a system dialog the app cannot suppress. GPS may take a little longer to get a first fix indoors; outdoors it is unchanged.
- Turning off **Use GPS** in Settings now stops all location access, not just some of it. Survey GPS tracking ran regardless of the setting, and the Survey, Point Count and ARU setup wizards still asked for a fix and could prompt for permission. All location access now goes through one place that honours the setting, and the setup wizards start on manual entry with your saved coordinates.
- Rotating the phone during a Live recording no longer stops it. The moment of lost focus while the screen turns was being treated as the app going to the background, and a quick turn could leave the session paused for good with no way to resume it. Surveys, point counts and ARU deployments were never affected.
- A Survey with GPS set to manual no longer takes a fresh location fix every time you rotate the phone. Only actually leaving the app and coming back records a fix now, which saves battery over a long survey. Recorded tracks are unchanged — the stray fixes were already being discarded as GPS jitter.

## [0.19.4] - 2026-07-29

### Changed

- Translation docs now cover both places strings live: the ARB files and the spoken announcement templates in `assets/announcements/`. A missing template file falls back to English silently, so an ARB-only translation pass left the app speaking English. Added a contributor guide next to the templates and a test that every language defines all ten phrasing buckets.

### Removed

- Unused `settingsAnnouncementsRunSetupWizard` string, a label for a setup wizard that was never built.

### Fixed

- Map tiles you have already loaded now keep showing when the signal drops. The app was caching tiles to disk but still asking the tile server whether each one was current before drawing it, and OpenStreetMap marks tiles as needing a re-check after a day or so — so a survey area you had mapped the week before came up blank the moment you were out of coverage, which is exactly when an offline map matters. Tiles on disk are now drawn straight away. Maps also load noticeably faster on a slow connection, use less data while you pan and zoom (tiles that scroll out of view mid-download are now cancelled instead of downloaded for nothing), and no longer blank out on a single dropped request. The tile cache is now capped by actual size rather than by tile count, and the old cache left behind by earlier versions is deleted once on first launch to reclaim the space.
- The Summary tab of an active ARU deployment now lists every species detected, not just the 24 most frequent. The species count above the list already reported the true total, so a busy deployment looked like it was miscounting.

## [0.19.3] - 2026-07-29

### Added

- The map during an active survey can now be opened full screen, from the expand button in its top-right corner. The small map keeps following your position as before; the full screen one hands the camera to you, so panning and zooming to look ahead along a transect no longer gets undone by the next GPS fix. A button in the bottom-left corner recenters on your current position when you want it back.

### Fixed

- Detections without an audio clip no longer draw a larger pin on the survey map than the ones with a clip. Their marker was being stretched to fill the space reserved for the largest possible pin, which made a silent detection the most prominent thing on the map. Silent markers now render at their intended size, slightly smaller than a marker with a clip so the play badge on the latter doesn't make it look bigger — the two read as the same size, and audio still stands out through color rather than size.
- Playing a detection from the full screen survey map in Session Review now keeps its marker in view. The map centered on the detection and the player sheet then covered it; the map now offsets the marker above center, so you can see which detection you are listening to.
- Detection clips now come from the strongest part of a detection instead of its first moment. A detection lasts as long as the species keeps being heard — often many analysis windows — but a clip holds one window, and the app was always keeping the first one. Since birds typically enter just above the confidence threshold and peak a few seconds later, the saved audio was usually the weakest evidence of the detection and did not match the confidence shown next to it. The clip is now re-cut whenever a detection reaches a noticeably higher score, so what you end up with is the best window the app heard. This also makes **Top N** and **Smart** clip subsampling keep the right clips, since they rank detections by that peak score. Use the clip padding setting to keep more audio around the window. Live, Survey and ARU deployments all follow the same rule, and when several species peak in the same moment their clips are now all cut from that moment instead of drifting later one by one — which is what ARU deployments used to do on a busy dawn chorus.
- Session Review now shows the right times for clip-only sessions. A detection can run for half a minute while the clip saved for it holds a single analysis window plus your clip padding — so the start-to-end time on each row was describing the bird, not the audio, and the two no longer lined up once clips started following the strongest moment. Rows in sessions without a full recording now show the span the clip actually covers, and the full time the species was heard moved to the detection's player sheet, where it can't be mistaken for the clip length. Sessions with a full recording are unchanged. This also corrects the detection offsets written into Raven and CSV exports for clip-only sessions, which had been pointing at the moment the bird was first heard rather than the moment the clip was cut. Older clips without peak metadata stay anchored to the first detection window.
- Every detection now owns its own clip file. When several species appeared in the same moment they used to share a single file, so **Top N** and **Smart** subsampling could delete a clip that another detection still pointed at, leaving that detection with a broken play button. A species that was already being heard could also pick up a clip that had been cut for a different species entirely. Both are fixed. The trade-off is more audio on disk when many species are heard at once — subsampling still trims it back at the end of a detection.

## [0.19.2] - 2026-07-28

### Changed

- Trimming a recording in Session Review is now permanent once you save. **Apply Trim** still only stages the cut — undo, redo and **Reset Trim** all work as before — but saving the session removes the audio outside the trimmed range from the recording and reclaims the storage, after a confirmation prompt. The session's own start time and its detection timestamps are unchanged; only the audio and the offsets into it move. Sessions whose recording is in a format the app can't cut keep the trim as an editable range, and their exports still honour it.

### Fixed

- The live spectrogram now always shows the time span set under **Spectrogram duration**, whatever **FFT size** is selected. Smaller FFT sizes used to demand more columns per second than the display could produce, so columns were dropped: at 512 a "15 second" window really scrolled over roughly 30 seconds, and the smaller the FFT size the slower it crept. The scroll speed is now fixed by the duration setting alone, and the FFT size again only changes frequency resolution — finer detail vertically, same speed horizontally. Detection is unaffected either way; the spectrogram is only a display.
- Exporting a trimmed session now actually ships the trimmed audio, with every time column (Raven, CSV, JSON, HTML report) measured from the start of that audio rather than the original recording. Previously the full untrimmed file was exported, so the audio didn't match what was reviewed and the detection offsets pointed at the wrong place. When the recording's format can't be cut, the export now fails visibly — from Session Review and the session library alike — instead of quietly shipping a mismatch.
- Saving a trim can no longer damage a recording. The cut is written to the session the moment the audio changes, so an interrupted save can't leave a session that trims its already-shortened recording a second time when reopened; an interrupted cut restores the original; formats the built-in decoder can't safely handle (anything but mono 16-bit FLAC, which File Analysis can import) are refused rather than replaced by a corrupt decode of themselves; and a session whose recording is missing or still loading keeps its stored trim instead of silently losing it.
- Trimming a resumed survey now keeps the right detections. Trim boundaries are compared against the recorded audio timeline with the stopped gaps removed, so they match the position the handles were dragged to instead of drifting by the length of the pause. Detections that cross a cut boundary keep their real capture times, and those whose audio was removed are dropped rather than collapsing onto the start of the recording.
- Applying a trim no longer leaves the spectrogram and the player out of sync with each other. The screen was mistaking the trimmed clip's length for the length of the whole recording, which broke the spectrogram crop, the trim editor when reopened, and the range restored by undo, redo or **Reset**.
- Timed annotations and voice memos now stay aligned when reviewing, saving, or exporting a trimmed recording. Notes whose referenced audio is removed become session-global instead of pointing at unrelated audio.
- The trim editor is now harder to trigger by accident. Leaving trim mode discards handle positions that were never confirmed with **Apply**, the handles stay inside the recording and at least half a second apart, and Save, Share, Undo and Redo are disabled until the selection is applied or cancelled. Trim mode also gained a **Cancel** action and a warning that detections outside the range will be removed.

## [0.19.1] - 2026-07-28

### Changed

- Survey setup no longer asks about clip subsampling when the recording mode is **Full audio** or **Off**. Detection sampling (and the clip padding slider) only decides which per-detection clips are kept, so it had no effect in those modes; the controls and the setup summary row now appear only for **Detections**, matching the ARU setup screen.
- Session Review now shows the survey map and the spectrogram as tabs rather than stacking them, for surveys recorded with full audio — the only sessions that have both. Each view gets the full panel height instead of half, and switching tabs keeps the map position and the spectrogram's zoom. Starting a trim selects the spectrogram tab, since that is where trimming happens. Sessions with only a map or only a spectrogram are unchanged.

## [0.19.0] - 2026-07-27

### Fixed

- Fixed a serious problem where another app taking the microphone during a survey (for example, opening the camera to shoot a video) could leave the phone unable to record audio in any app until it was rebooted. The app no longer keeps re-grabbing a microphone it can't have while running in the background, which was what wedged the device audio system. Losing the microphone is now handled gracefully: the survey signal meter shows a crossed-out mic, the ongoing notification explains that another app is using the microphone, and audio recording resumes automatically as soon as you return to the app.
- Resuming a survey from Session Review now keeps the elapsed timer running correctly. Previously the counter froze shortly after resuming and the saved duration came out too short; the timer now continues from where it left off and counts only time the survey is actively recording, excluding the gap while it was stopped. The live detections-per-minute rate is likewise now based on active recording time rather than wall-clock time since the survey first started.
- Detection timestamps in exports (Raven selection tables, CSV, and JSON) now line up with the audio for resumed survey sessions. Offsets are measured against the actual recorded audio with the stopped gap removed, matching in-app playback, instead of counting the pause as if it were recorded.
- The "recording shorter than session" warning in Session Review and exports now measures the expected audio length the same way (gap-removed), so resumed sessions are no longer falsely flagged as truncated.

### Changed

- The **Continue Survey** button in Session Review is now hidden for sessions that recorded full audio, because a continuous audio file can't be safely extended across a stop-and-resume. Surveys recorded with clip subsampling (or no audio) can still be resumed as before, and a resumed survey now keeps its original recording mode.

## [0.18.9] - 2026-07-11

### Added

- Settings → Microphone is now **Audio source**, and on Android adds a **Processing** control offering **Unprocessed** or **Voice recognition** alongside the phone default. Phones apply speech-tuned noise reduction and automatic gain to microphone audio by default, which smears bird song; both new options turn that processing off. Unprocessed is the ideal, but is only honoured by phones whose manufacturer declares support — Voice recognition works on virtually every device, so try that if Unprocessed makes no audible difference. Expect unprocessed audio to sound quieter, since the automatic gain is gone; raise Gain to compensate.
- Microphone and processing are independent, so you can record from a USB or wireless mic *and* ask for unprocessed audio. The microphone list now also includes each built-in mic the phone exposes separately (e.g. bottom and back).
- The audio source picker now also appears on the Point Count setup screen, alongside the existing Survey and ARU ones.

### Changed

- Added upside-down portrait support, so the phone can be inverted to aim its bottom microphone upward while the app stays usable. Android phones leave the upside-down position out of their normal rotation, so this had to be requested explicitly; it still follows your auto-rotate setting, and does nothing while rotation is locked.
- The main menu now starts loading the taxonomy, inference, and location dependencies after its first frame, so going from launch to a running Live session is faster. The menu stays fully interactive while this happens, and opening Live or Explore before the warm-up has finished waits for it rather than starting the work over. Location is only warmed up when permission has already been granted — the menu never raises a permission prompt of its own.
- Changing the audio source now takes effect immediately, including mid-recording — the app swaps the microphone under the running session instead of waiting for the next one to start.
- German UI text now consistently uses the formal *Sie*; a few strings had slipped into the informal *du*.
- Updated the About credits to identify the Cornell Lab of Ornithology and clarify the Museum für Naturkunde Berlin's support.
- Removed obsolete score-pooling references from the user-facing inference and sensitivity descriptions in Settings.
- Moved the playback overlay toggle from General to the Playback section in Settings.
- Moved Audio source to the top of the Audio section in Settings.
- Added a help button to Audio source explaining microphone selection and Android processing profiles.
- Added help buttons for Dynamic Color and High Contrast Theme, kept section summaries informative, and moved the High Contrast, scientific-name, and log-amplitude explanations into their help overlays only.

## [0.18.8] - 2026-07-10

### Added

- Added a voice picker to Settings → Announcements so you can choose a specific installed text-to-speech voice instead of the device default — useful when the default voice sounds robotic or uses the wrong accent. Announcement templates are now provided in all app languages, including Dutch, Polish, and Russian.

### Changed

- Reworked the Settings → Announcements layout so it no longer breaks on languages with longer labels, and grouped the voice controls (voice, speed, pitch, sample) together.
- Rewrote the spoken announcement phrasing across all languages to sound more like a birding companion and less stiff.
- Announcements now start speaking sooner after a session begins, so the first solid detection is voiced promptly instead of being held back by an over-long startup delay.
- The chatty "how common is this bird here" hint now uses the same six abundance tiers shown on the Explore screen, so what you hear about a species lines up with the tier on its Explore card.

### Fixed

- Fixed announcements going silent partway through a session on some devices: the app no longer waits forever for a text-to-speech engine that never reports completion, and it now falls back sensibly when no voice is installed for the chosen language.
- Fixed survey map flicker when map tile loading is deactivated

## [0.18.7] - 2026-07-09

### Added

- Added an abundance filter to Explore so you can narrow the species list to specific tiers (Abundant, Common, Frequent, Uncommon, Scarce, or Rare).
- Added a tappable abundance legend in the Explore location header that jumps the list straight to the first species in a chosen tier.
- Added a "Scroll to top" button in Explore that appears once you scroll down the species list.
- Added a "Taxonomy" entry to the model information on the About screen showing the bundled taxonomy version.

### Changed

- Updated the About screen credits to name the Museum für Naturkunde Berlin as a development partner.
- Update default confidence threshold and support floor values

## [0.18.6] - 2026-07-08

### Added

- Added a "Pick on map" button to the manual coordinates setting, so you can tap a location on the map (the same picker used in the setup screens) instead of typing latitude and longitude.
- Added a "Save sessions automatically" setting for Live and Point Count. When turned off, a finished session opens in review as unsaved and is only kept in the library if you tap Save; leaving without saving discards it.
- Bundled offline Wikipedia species snippets for Dutch, Polish, and Russian.
- Added eBird Life List import: flag species you hear that aren't on your imported eBird life list yet with a star badge on Live detections and in Session Review, plus a new Survey "Lifer" alert mode.

### Changed

- Explore now shows an abundance tier (Abundant, Common, Frequent, Uncommon, Scarce, or Rare) on each species card instead of a raw percentage. Each tier is a small fill circle plus the tier's initial, colored along the red-to-green score scale. Tiers adapt to the local prediction strength, so the same score can map to different tiers in different places. The Explore help sheet now explains the tiers, colors, and fill circles.
- Tuned live score pooling to use Log-Mean-Exp pooling at all inference rates and relaxed the detection support gate slightly, so fainter birds surface a little sooner while still requiring consistent support.
- Revised the Session Library help overlay to reflect the current search, sort, filter, view, open, and multi-select controls.
- Enlarged species thumbnails in the Session Library's By Species view.

### Fixed

- Fixed ARU deployment restore so relaunching the app during an active recording window resumes the same recording cycle instead of dropping it and waiting for the next scheduled window.
- Fixed Session Library search so localized common names and text metadata such as Session titles, locations, dates, observers, transects, annotations, and notes are searchable across bundled locales.

## [0.18.5] - 2026-07-07

### Added

- Added a "Listen to this species on eBird" link in the species view that opens the eBird / Macaulay Library audio catalog (sorted best-quality first) in the browser.

### Changed

- Translated the Privacy Policy and Acceptable Use Policy into every interface language (including Dutch, Polish, and Russian), added an External Links section to the Privacy Policy describing third-party links, and made in-app policy links resolve to the matching localized page.

## [0.18.4] - 2026-07-05

### Added

- Added Live Mode and Point Count General settings to show all species detected during the current session, with sorting by newest detection, confidence, common name, or occurrence count, repeated-detection count chips, and dimmed inactive rows that hide confidence visuals. In newest-first sorting, currently vocalizing species float to the top ordered by their current confidence.
- Added ru, pl and nl locales

### Changed

- Tuned the session-mode accent colors for the high-contrast themes so each mode stays legible and distinct against the black-and-white surfaces, and switched the "detected" badges and detection-stats marker to a high-contrast-aware brand-blue/black styling.
- Apply the Sensitivity setting immediately after audio-model inference, before score pooling and filtering, by offsetting the model's sigmoid probabilities in logit space.
- Updated project licensing and policy docs so source code remains MIT-licensed, bundled BirdNET model weights are documented under Apache 2.0, and the former terms documentation is replaced by an Acceptable Use Policy.

### Fixed

- Localized the compact session status line under the Live Mode and Point Count spectrogram (the "now", "spp", and "det" tokens were previously hardcoded in English).
- Fixed Live Mode detection timestamps so pooled detections are anchored to the analyzed audio window, not inference completion time, and session review can show the earliest supporting recent window.
- Fixed species common-name fallback so the default System setting uses the phone's preferred language when the bundled taxonomy includes it, while the separate Follow app option still follows the interface language.
- Polished all locales

## [0.18.3] - 2026-07-02

### Added

- Added a Settings > General high-contrast theme toggle with black-and-white light and dark UI palettes, retained danger, warning, validation, and mode colors, heavier text, bordered cards and surfaces, high-contrast weekly abundance current-week markers, and unchanged score colors and spectrogram color maps.

### Changed

- Darkened muted text in the standard light theme for better readability.
- Improved screen-reader accessibility by announcing slider labels and values across Settings, announcements, File Analysis, Point Count, and Survey, and added missing tooltips for close, clear-search, and session-rename controls.

## [0.18.2] - 2026-07-01

### Added

- Added native decoding of compressed audio (such as M4A/AAC and MP3) on Windows, so those recordings now play back and render spectrograms in session review just like on Android and iOS.

### Fixed

- Fixed audio sharing and exports so converted FLAC files are written as valid WAV files, shared files keep their filename extensions, quiet single-detection audio shares are normalized, and continuous detections export their full start-to-end audio span instead of only one inference window. (#149)
- Fixed session review on Windows so the spectrogram renders reliably when the audio duration is reported late by the player backend.

## [0.18.1] - 2026-06-28

### Changed

- Refreshed the bundled taxonomy metadata from the BirdNET taxonomy API v0.2-Jun2026 and rebuilt the local 9,789-species taxonomy CSV.
- Updated the bundled geomodel to BirdNET+ Geomodel V3.0.4 and pruned the audio and geo models to their taxonomy-matched 9,789-species intersection after global 3% geo-cutoff screening.
- Rebuilt the offline species image and description bundle for the updated 9,789-species model set.
- Changed the File Analysis window-duration picker to the same discrete slider used in Settings.

### Fixed

- Fixed session exports so saved full recordings are still included when a recovered or in-progress session points at its recording directory, and added regression coverage for ZIP bundles that combine GPX, audio, app metadata, and the HTML report.
- Fixed single-detection audio shares so receivers such as Google Drive get the intended filename, extension, and audio MIME type.
- Enlarged the Home footer navigation tap targets while keeping the compact footer layout.
- Capped every user-facing live inference-rate control to the shared 0.10-1.00 Hz range, including Point Count setup, Survey, and ARU.

## [0.18.0] - 2026-06-28

### Changed

- Updated to the latest BirdNET+ models (V3.0-preview3.1 audio and Geomodel V3.0.3), now covering 10,208 species across birds, amphibians, mammals, and insects.
- Scientific names are now shown in their taxonomy-canonical form consistently across the app and in exports.

### Added

- Added domestic Dog, Cat, and Cattle to the recognized species so common backyard and farm animals can appear in Explore and detections.

### Changed

- Make hidden score pooling default to adaptive LME peak pooling: live-rate inference uses average pooling for stable detections, slower Survey/ARU cadences use LME, all modes keep a 10-second age gate, and accepted detections report the strongest recent supported model confidence.

## [0.17.17] - 2026-06-26

### Added

- Allow audio export as WAV independent from the recording format for iNat interoperability
- Add metadata support and enhance HTML report tests

### Changed

- Sort species chips in session card alphabetically and update top species logic
- Update taxonomy JSON file paths and preserve fallback assets during rebuild
- Updated taxonomy and species bundle
- Improve performance for large session detections and add loading indicator

### Fixed

- Add foreground GPS tracking option and manage lifecycle states.
- Improve text fitting for offset display in species card in session review
- Swap yelwar and yelwa1
- Include notes and voice memos in JSON export and enforce ZIP bundling for annotations and memos
- Adjust smart mode rivalry logic to trigger only after topN slots are filled
- Keep saved recording paths portable so iOS app updates do not orphan session audio.

## [0.17.16] - 2026-06-24

### Added

- New **Playback** settings section with an **Auto-play voice memos** toggle (off by default). When enabled, a voice memo attached to a timed annotation plays automatically during session review as the playhead crosses its recorded position — mixed on top of the recording without interrupting it.
- Manual detections in session review now have a dedicated play/seek control, so you can jump the playhead to a manually added entry just like a model detection.

### Changed

- The species count on the About screen now includes a per-group breakdown in parentheses, e.g. "5250 species (Birds: 4597, Mammals: 232, Amphibians: 253, Insects: 168)".
- Clarified the background location warning in Survey Setup (#132): the warning card now explicitly tells users to tap to open Settings and grant the background location permission.
- In session review, tapping a voice memo annotation now plays it back, and tapping a timed text annotation jumps the playhead to its position (long-press to edit).
- Adding a species at a timestamp now uses the spectrogram's visible center, so the new entry lands where you are looking even after panning.
- Session review now surfaces note and voice-memo indicators directly in species and detection rows.
- Timed voice memos in Session Review now play over the main recording during playback, including memos attached to detections at the detection start time.
- Playback settings now include a voice memo ducking strength control.

### Fixed

- Resuming playback after panning the spectrogram while paused now starts from the position you are viewing instead of jumping back to the pre-pan spot.
- Polished the voice-memo dialog layout and re-record flow for more consistent behavior when replacing an existing memo.
- Voice memo playback now uses the same quiet-recording normalization path as detection clips, and starting a new memo reliably releases any paused playback session first.
- Session Review now configures audio focus for reliable in-app voice memo overlays instead of letting memo playback interrupt the recording.
- Session-level timed voice memos added from the "+" menu now trigger when playback resumes from the memo timestamp.
- Session Review now ducks the main recording while automatic voice memo overlays play so memo commentary remains audible.

## [0.17.15] - 2026-06-23

### Changed

- Refined user and developer documentation across guides, localized pages, and navigation labels.
- Spoken announcements now remain off by default for all users until manually enabled in Settings.

### Fixed

- Fixed imported Survey species lists to use the supported file picker read API.

## [0.17.14] - 2026-06-20

### Changed

- Added a per-format help icon to each export format (Raven, CSV, JSON, GPX) explaining what that file contains, and reworded the Export Format help to describe the new bundle-and-audio-only behavior.
- Replaced the manual Latitude/Longitude sliders in Settings with editable text fields so you can type or paste exact coordinates when GPS is off. Pasting a combined "latitude, longitude" string into either field fills both at once, and out-of-range or invalid entries are flagged inline.

## [0.17.13] - 2026-06-20

### Added

- Added an "Include app metadata" checkbox to Settings > Export, on by default. Turning it off drops the `*.metadata.json` side-file from the export bundle.
- Added an audio-only share path: untick every export format, the HTML report, and the new app metadata box (leaving only "Include audio files") and Share will hand the platform sheet the raw recording instead of a ZIP — useful for sending a session straight into iNaturalist or eBird.

### Changed

- Converted the "Include audio files" and "Include HTML report" settings from toggles to checkboxes so the entire Export section is now a single consistent checklist.

## [0.17.12] - 2026-06-20

### Fixed

- Fixed Survey session durations in the Session Library continuing to grow after the session ended, caused by a stale open recording segment left behind by the final persist.

## [0.17.11] - 2026-06-19

### Changed

- Changed the main menu in landscape to show all six mode tiles in a 3x2 grid with a full-width footer and a smaller side-by-side logo/title header.

### Fixed

- Fixed the Session Library "new session" picker overflowing in landscape by making it scroll when there is not enough vertical space.
- Fixed a crash when leaving the Live screen while a session was still starting, caused by reading providers after the screen was closed.

## [0.17.10] - 2026-06-19

### Added

- Added Plasma, Cividis, Jet, Turbo, and BirdNET choices to the spectrogram color map setting.

### Changed

- Changed Window duration and Inference rate settings from dropdowns to sliders, moved Announcements below Recording, changed Recording mode to a dropdown, and hid advanced score pooling controls from Settings.
- Expanded Window duration to 1, 3, 5, 7, 10, and 15 seconds, and aligned the global Inference rate slider with the Survey and ARU 0.10–1.00 Hz tick grid.
- Removed the duplicate Inferno color map and migrated saved Inferno preferences to Magma.
- Moved ARU onto the main live recording modes page and grouped File Analysis with the file workflows page in the home mode carousel.

### Fixed

- Made Session Review and clip playback spectrograms use the configured color map instead of always rendering Viridis.
- Made Session Review playback overlay previous/next buttons follow the active species sort order while playing all clips for the current species before advancing to the next species.

## [0.17.9] - 2026-06-18

### Changed

- Reduced ARU waiting-state wakeups, unchanged session writes, and redundant foreground notification updates; new ARU deployments also default to 0.33 Hz inference to match Survey while leaving other inference and spectrogram settings unchanged.
- Tightened home footer spacing, shortened Survey tab labels, clarified ARU setup/help wording, refreshed gender-neutral guide wording, simplified ARU ready storage estimates, and aligned Session Library delete confirmations with the swipe action.

### Fixed

- Fixed ARU detection clips so they now capture the moment a species is first heard, instead of grabbing later audio after the bird had already gone quiet — clips again contain the species they are labeled with, and review results are reliable.
- Aligned ARU Smart and Top N clip retention with the Survey approach, keeping the strongest clips per species and spreading them across the deployment instead of clustering them on one repeating bird.

## [0.17.8] - 2026-06-17

### Added

- Added live progress to the ARU foreground notification, showing completed cycles, species, and detections so far for the running deployment.
- Added a "Resume recording at" battery threshold to ARU setup. Recording cycles now pause when the battery falls to the pause level and resume once it charges back to the resume level, while the deployment keeps running in between — useful with an occasional charge source such as a solar panel. Defaults are 10% pause and 20% resume.

### Changed

- Updated the ARU live status display to use the dedicated ARU accent color for the recording and schedule indicators, so it is no longer confused with Live Mode's red or Point Count's blue.
- Changed the ARU low-battery behavior from stopping the whole deployment to pausing and resuming recording cycles, so a deployment can ride out low-battery periods and continue once charged.
- Limited the ARU "Resume recording at" setup slider to 5-55% in 5% increments, with the resume threshold kept at least 5% above the selected pause threshold.
- Moved main menu mode titles higher inside their tiles, tightened tile padding and tile gaps, and reduced wrapped footer spacing so mode descriptions have room for three wrapped lines without making the home screen taller.

### Fixed

- Fixed ARU deployments stalling when the active screen was backgrounded or covered by another screen; the schedule and recording now keep running in the background so cycles fire on time while the phone is in your pocket.
- Hardened ARU audio capture so the microphone has a single owner across a deployment, ensuring it is reliably released when a deployment stops and avoiding rare start/stop races.
- Prevented ARU and Survey from starting their foreground recording service at the same time, so the two modes can no longer contend over the same background service.
- Fixed "one session per cycle" ARU deployments so they no longer leave behind an extra combined session in your history; only the individual per-cycle sessions are kept once the deployment finishes.

## [0.17.7] - 2026-06-17

### Fixed

- Fixed a rare race when a Live session was restarted while the previous one was still starting, so a recording can no longer attach to the wrong session.
- Fixed ARU cycle audio to clear stale buffered audio and start file recording before capture, keeping each cycle's clips aligned to that cycle.
- Fixed ARU Smart clip sampling for combined deployments so retained clips spread across cycles within a single session instead of clustering.
- Fixed clip retention when a detection is updated mid-session so the kept clip stays linked to the correct record.

## [0.17.6] - 2026-06-16

### Added

- Added an ARU schedule option for recording around both sunrise and sunset.
- Added native Android handling for ARU foreground notification actions so Stop and Open work reliably from notification taps.

### Changed

- Refined ARU setup recording-window summaries to show the effective aligned recording ranges for each diel pattern.
- Adjusted the home mode carousel spacing and Live Mode tip height to avoid cramped text at larger accessibility scales.

### Fixed

- Fixed clip-only ARU per-cycle deployments so the completed aggregate session metadata is discarded without deleting cycle recording directories.
- Fixed ARU Smart sampling buckets for combined deployments so retained detections are grouped relative to deployment start.

## [0.17.5] - 2026-06-15

### Added

- Added a new setting "Playback overlay in review" to trigger the modal player sheet with a spectrogram when reviewing clips from clips-only Session reviews.
- Active by default for sessions that have clips only and no full recording/spectrogram, and bypassed (never shown) for sessions with full audio recordings.
- Added support for launching the ARU active screen directly from Android foreground notification actions with optional stop confirmation.
- Added `AruNotificationRoute` to restore unfinished ARU deployments when app launches from notification before routing to active screen or setup.

### Changed

- Updated ARU help and user documentation to reflect current behavior: cycle-level Full Audio or retained detection clips, live inference during active cycles, and Android foreground notification controls.
- Improved ARU setup summaries and storage estimates to consistently show effective recording and sampling modes when combined-session deployments cannot use Full Audio.
- Improved locale-aware time/date formatting helpers to prefer localized `intl` formats with safe fallbacks when locale data is unavailable.
- Optimized ARU schedule evaluation for far-future open-ended deployments by jumping directly to the candidate cycle index instead of scanning from deployment start.
- Refactored Android foreground task notification callbacks to be handled at app root instead of individual screens, enabling route-based navigation on notification action.

### Fixed

- Restored unfinished ARU deployments from persisted sessions after app relaunch and resumed schedule evaluation instead of leaving deployments stranded.
- Serialized ARU detection-sync updates during active deployment and guarded finalization to prevent race conditions while stopping.
- Fixed long-running diel ARU schedules so they continue evaluating correctly beyond large raw interval counts instead of prematurely completing.
- Fixed ARU deployment storage estimates so long, short-interval schedules no longer freeze the setup UI.
- Fixed ARU active deployment cycle progress so date/time-ended schedules show the estimated total cycle count instead of "Until stopped".
- Fixed ARU clip-only storage estimates to use retained clip assumptions, window duration, and clip context instead of prediction-window upper bounds.
- Refined ARU setup review copy by removing duplicate test-run details and shortening Session grouping labels.

## [0.17.4] - 2026-06-15

### Added

- Added an in-app warning card when ARU combined-session mode is configured with Full Audio recording, explaining the automatic fallback to Smart-sampled clips.
- Added background weather backfill so saved sessions with GPS coordinates but no weather data are automatically enriched on the next app launch.

### Changed

- Upgraded the weather cache to a per-observation-hour model supporting sessions up to 90 days old via the Open-Meteo forecast API, and older sessions via the archive API; stale entries (older than 30 days) are pruned on each write.
- Refactor translations for improved readability and maintainability

### Fixed

- Fixed ARU combined-session deployments configured with Full Audio: the session is now saved with Detections Only + Smart sampling instead of an unsupported Full Audio mode.
- Clear state-change callbacks on dispose to prevent updates on disposed widgets.

## [0.17.3] - 2026-06-15

### Changed

- Refined ARU active deployment dashboards with compact status metrics, clearer tab labels, localized species summaries, and shared destructive confirmation behavior.
- Reused the latest ARU/station ID in ARU setup, included it in ARU session names, and kept ARU deployment metadata with shared exports.
- Expanded session export provenance to include session-retained runtime settings and type-specific metadata while limiting export preference snapshots to relevant keys.
- Updated session, ARU, and Point Count time displays to follow the device 12-hour or 24-hour clock preference consistently.

## [0.17.2] - 2026-06-15

### Changed

- Refined ARU Mode deployment setup, schedule previews, active status tabs, per-cycle recording options, and localized user documentation.
- Updated ARU scheduling options so short test cycles can run immediately without overlapping regular clock-aligned cycles.
- Reused the latest Survey, Point Count, or ARU observer name across field-session setup screens.

### Fixed

- Fixed ARU deployment completion so natural schedule endings open Session Review like manual and low-battery stops.
- Fixed ARU recording cleanup so empty full-cycle audio files are discarded instead of being kept as review artifacts.
- Fixed ARU per-cycle sessions so cycle recordings remain attached for review and names include both deployment and cycle numbers.

## [0.17.1] - 2026-06-11

### Added

- Added broader ARU mode setup and active-deployment localization coverage across all supported locales.

### Changed

- Refined ARU setup, scheduling, notification, and active-state behavior to better align with long-running fixed-site deployments.
- Improved ARU storage estimation and deployment flow ergonomics, including active status visibility and schedule handling polish.
- Updated ARU and live detection list presentation details for clearer in-session monitoring.

### Fixed

- Fixed ARU deployment edge cases around stop/finalization handling, schedule transitions, and retained detection clip behavior.

## [0.17.0] - 2026-06-11

### Added

- Added ARU Mode as a scheduled fixed-site recorder with localized setup, persisted deployment state, cycle metadata, schedule-aware storage estimates, active deployment status, Android foreground notification controls, documentation, and focused tests.
- Added ARU site setup with GPS, manual/map-picked coordinates, skip-location handling, shared weather context, WAV/FLAC format selection, and JSON/ZIP export support for deployment metadata, segments, and cycle recordings.

### Changed

- Refined ARU setup and ready-state UX with Survey-style field tips, compact review cards, consolidated site/weather context, clearer deployment-end summaries, and schedule controls for manual stop, fixed cycles, fixed date/time, cycle duration, repeat interval, and recording windows.
- Reworked active ARU deployment screens toward the Survey live layout with clearer recording/waiting state, live spectrogram and detections tabs, persistent detection feed, stats, and shared microphone handling.
- Streamlined the active ARU deployment dashboard with a full-width spectrogram-first layout, persistent recent detections, and a consolidated runtime summary of recording, sampling, grouping, schedule, and battery settings.
- Updated ARU scheduling so regular cycles align to wall-clock interval boundaries and a default-on one-minute immediate test run can run as a deployment sanity check.
- Updated ARU detection sampling and session grouping so Smart/Top N retention distributes clips across cycles or time buckets instead of clustering retained clips in one short span.

### Fixed

- Fixed ARU stop handling, scheduled cycle recording, live inference, and detection-clip retention so deployments stop cleanly, record only at schedule boundaries, and save detections during active cycles.
- Fixed ARU low-battery stop so the deployment now ends when the configured battery threshold is reached.
- Fixed ARU stop navigation and full-audio review handoff so stopping opens Session Review for the combined deployment or latest per-cycle session with its recording path attached.

## [0.16.11] - 2026-06-10

### Added

- Added dedicated in-app Help entries for Batch Analysis across all supported locales.
- Added AGENTS.md with concise repository guidance for coding agents, including localization, documentation, style, and safety rules.

### Changed

- Restored the iOS app icon style to the bird-in-circle on a white background while keeping Android icon behavior unchanged.
- Updated Batch Analysis accent color from copper to a darker yellow tone for better visual alignment with File Analysis.
- Updated mode subtitles: Point Count now reads "Record at a fixed point for a set duration" and Survey now emphasizes background recording with shorter wording.
- Updated locale strings and added missing metadata

## [0.16.10] - 2026-06-09

### Added

- Added iOS-only Open in Apple Maps actions in Session Map and full-screen Survey Review map flows while keeping the in-app survey map overlays.
- Added localized iOS permission CTA and Apple Maps action labels across all supported app locales.

### Changed

- Updated onboarding permission CTA wording on iOS from Grant to Continue to align with App Review guidance, while keeping Android wording unchanged.
- Updated survey GPS tracking to use platform-aware geolocator settings and enable iOS background location updates with indicator support.
- Minimum OS version for iOS updated to 16.0

### Fixed

- Fixed iOS App Review compliance gaps for permission pre-prompt wording and native map handoff availability.
- Fixed survey session screen updates on iOS by reliably watching live detections

## [0.16.9] - 2026-06-09

### Added

- Added placeholder entry points for Batch Analysis and ARU Mode on the home screen with localized Coming Soon behavior.
- Added localized documentation pages for Batch Analysis and ARU Mode across all supported docs locales, including site navigation links.
- Added new session type labels and numbered session title/card strings for Batch Analysis and ARU sessions across all app locales.

### Changed

- Reworked the Home mode selector from a single static grid to a paged carousel with indicator dots, keeping active modes on page one and upcoming modes on page two.
- Refined shared session-type icon/color mappings so upcoming modes use consistent visual semantics in navigation and session metadata surfaces.
- Updated upcoming mode accent colors to distinct hues: Batch Analysis now uses copper and ARU Mode now uses violet.

### Fixed

- Fixed Live session elapsed-time and recording-size progression after app background pause and resume, so resumed sessions continue updating instead of showing a static elapsed value.

## [0.16.8] - 2026-06-08

### Added

- Added a sensitivity control to Point Count setup and active Point Count screens so species detection tuning matches Live Mode.

### Fixed

- Fixed Session Review timestamp formatting, seek alignment, and spectrogram time labels for sessions with pause and resume gaps, keeping review playback aligned with the actual recorded audio timeline.
- Fixed Live and Point Count screens to clear stale session state and old detections when reopening a fresh run, preventing previous-session cards from flashing on load.

### Changed

- Updated and unified app icon for consistent visuals across platforms

## [0.16.7] - 2026-06-04

### Fixed

- Fixed Session Review spectrogram loading and playback alignment for long MP3 and other compressed File Analysis recordings.
- Fixed lazy spectrogram gaps near chunk boundaries and long recording tails.

## [0.16.6] - 2026-06-04

### Fixed

- Updated session library title translations for Czech, Spanish, Italian, and Portuguese.
- Updated footer button icon and text sizes for better visibility on tablet and mobile.

### Optimized

- Updated audio decoding logic to improve performance for native formats.

## [0.16.5] - 2026-06-04

### Added

- Added support for compiling experimental Windows builds.
- Added Windows support for app launcher icons.
- Implemented Windows Inno Setup installer and Windows MSIX signing support.
- Configured CI workflows to automatically generate Windows MSIX packages, Inno Setup installers, and Winget manifests.

## [0.16.4] - 2026-06-04

### Fixed

- Made File Analysis keep an app-managed copy of the uploaded audio in its original format, avoiding unnecessary MP3/AAC-to-WAV/FLAC conversion before Session Review.
- Enabled Session Review spectrograms for copied compressed uploads by loading long review audio through native range decoding instead of hiding the spectrogram when full PCM would be too large.

### Optimized

- Reworked compressed File Analysis inputs such as long MP3, AAC, and OGG recordings to inspect metadata without full decode, analyze bounded native decode chunks, and cancel active native decoding promptly instead of expanding the whole file into memory.
- Reduced the initial lazy spectrogram bootstrap window for long recordings to keep first review paint responsive while additional chunks load on demand.

## [0.16.3] - 2026-06-03

### Fixed

- Corrected localized documentation homepage screenshot paths and renamed the German documentation navigation entry from "Heim" to "Start".

### Optimized

- Decoupled real-time audio playback position tracking from parent state updates in the Session Review screen by introducing a `ValueNotifier<Duration>` listener interface for spectrogram scrolling and local active status updates on `_SpeciesTile` widgets, completely eliminating full-screen and map component redraw stutters.
- Localized Point Count countdown updates and active Survey elapsed-time/stat updates into small listenable widgets, preventing full dashboard rebuilds once per second during recording.

## [0.16.2] - 2026-06-03

### Added

- Wired the spectrogram quality setting ('low', 'medium', 'high') to all screens displaying spectrograms, including Live Mode, Point Count Mode, Survey Mode, and Session Review components (Timeline player and Trim editor).

### Changed

- Reverted all non-spectrogram overrides, restoring original UI/UX behaviors (such as inline maps, map markers, and unmounted map overlays) and default/user configured background settings.

### Optimized

- Pre-allocated the Hann window scratch buffer inside `FftProcessor` to prevent repetitive 16KB array heap allocations on every single FFT window calculation, drastically reducing garbage collection overhead and stuttering on budget devices (such as the Samsung A17).
- Optimized input preparation and output array parsing in `ClassifierModel` by reusing the time-domain sample buffer directly when lengths match (bypassing a redundant 96,000-iteration clamp copy loop and 384KB list allocation) and returning native `Float32List` instances directly without copying to a new list, preventing UI thread stutters when inference runs.

## [0.16.1] - 2026-06-03

### Added

- Integrated dynamic privacy consent toggles (Map, Reverse Geocoding, Weather) directly into the interactive Permissions onboarding page to let users opt into capabilities upfront.
- Embedded mandatory photo library and camera description purpose strings into iOS `Info.plist` to satisfy Apple App Store submission conditions (`ITMS-90683`).
- Added native iPad screenshot layout support (`2048 x 2732px`) to the automated mockup workspace in `dev/mockups/` using `empty_ipad_frame.png` as a container backdrop.

### Changed

- Enhanced onboarding screens with responsive maximum-width boundaries (`ContentWidthConstraint`) to prevent horizontal layout stretching, significantly improving native tablet/iPad readability.
- Enhanced the on-device HTML/CSS mockup canvas scaling rules to render tablet screens using proportional, undistorted top-alignment instead of stretching them.
- Updated the export filename configuration to prefix all iPad mockups and screenshots with `ipad_` (e.g., `ipad_en-01-menu.png`) and generated them across all localizations.

## [0.16.0] - 2026-06-02

### Added

- Introduced comprehensive iOS platform support configurations and configurations.
- Integrated standard Darwin-specific local notifications and alert configurations into active survey sequences.
- Added adaptive fallback to standard PCM16 WAV (.wav) voice memo recording formats specifically on iOS, overcoming Apple CoreAudio AAC compression collisions while maintaining full file-sharing and packaging compatibility.

### Changed

- Reconstructed custom on-device custom FLAC audio encoder stream headers to explicitly restrict min and max block sizes to match nominal values exactly, preventing freezing/stalling bugs with strict decoders like Apple CoreAudio and external soundscape systems (e.g. Raven Pro).
- Paused active audio playbacks dynamically when launching recording panels to prevent speaker acoustic feedback loops.
- Avoided cross-thread UI hangs on async dialogue overlays by reinforcing BuildContext safety gates.

## [0.15.9] - 2026-06-02

### Added

- Added manual tap-to-load weather fetching to the Session Review / Summary headers, gated on privacy preferences, and localized for all seven languages.

### Changed

- Optimized session list numbering with a header-only JSON stream parser that scans only the first 1024 bytes of saved files, preventing UI blocking and high memory overhead when dealing with very large recording session files.
- Deferred weather pre-fetching away from saving/closing processes into localized, user-initiated visual action.
- Retained startup geographic coordinates correctly during active Live and Point Count session launches.

## [0.15.8] - 2026-06-02

### Added

- Implemented comprehensive multi-session selection, packaging, sharing, and deletion capabilities to resolve Issue #81 in the Session Library.
- Added multi-session bulk export to aggregate, package, and compress selected sessions into a standalone ZIP archive (`BirdNET_Live_Bulk_Export_<timestamp>.zip`).
- Added robust multi-selection state, adaptive tile checkboxes, select-all toggles, and contextual actions (share and delete bulk buttons) to the Session Library.
- Included full multi-lingual localization for all bulk-selection messages and counts across seven supported locales.

### Changed

- Automatically deselect all selected sessions after sharing complete.

## [0.15.7] - 2026-06-01

### Added

- Embedded the Explore screen tool inside the active Survey dashboard as a fourth tab, allowing real-time species discovery in the field.

### Changed

- Expanded both the Explore and Summary tabs to utilize full vertical screenspace when focused in active surveys, hiding the running stats and recent detections lists.
- Disabled horizontal swiping on the active survey dashboard's TabBarView to prevent interaction conflicts with the nested map, spectrogram, and list views.
- Reordered external links on the About screen to place documentation, privacy, and terms higher, keeping developer resources, the BirdNET website, and donation links below them.

### Fixed

- Resolved an issue on devices with active background accessibility services (such as password managers, live caption, or custom search gesture services on Pixel devices) where undo SnackBars containing actions could remain on screen indefinitely, by adding a timer-backed safety dismiss fallback on all interactive SnackBar overlays.

## [0.15.6] - 2026-06-01

### Added

- Added a 10-second timeout gate to all temporal score pooling modes (including Log-Mean-Exp) to discard context older than 10 seconds.

### Changed

- Aligned offline file analysis to adhere to user-configured temporal pooling settings and use window-based timestamps.

## [0.15.5] - 2026-06-01

### Changed

- Separated opening species information from expanding detections in Session Review. A normal click or tap on the species row now consistently opens the species information overlay, matching live sessions.
- Replaced the species card's compact chevron icon with a generous, accessible touch target spanning the entire right side of the card, improving discoverability and ease of use for expanding or collapsing detections on mobile devices.
- Redesigned on-map review clip playback panel to remove bulky slider bars, duration readouts, and close buttons in favor of an interactive, seekable spectrogram.
- Added lightweight tick marks with numbered seconds directly beneath the map reviewer spectrogram to indicate the exact length of the playback clip.

## [0.15.4] - 2026-05-24

### Changed

- Tuned LME score pooling to require repeated raw-window support before a new species appears while keeping supported high-confidence calls close to their strongest recent raw score.
- Made highest confidence the default species sort in Session Review so review starts with the strongest detections first.
- In Session Review, the highest-confidence sort now also orders detections inside each species, preferring detections with playable audio clips before clipless detections.
- Raised the default confidence threshold setting from 25% to 35%.

### Fixed

- Unsupported device languages now fall back to English instead of the first generated locale.

## [0.15.3] - 2026-05-22

### Added

- Enabled the Settings Danger Zone Clear All Data action to wipe sessions, recordings, voice memos, custom species lists, preferences, OpenStreetMap tile cache, and temporary playback/review/share caches, then close the app so the next launch starts clean.

### Changed

- Updated localized Clear All Data confirmations, user settings documentation, and privacy policy text to describe the in-app full local wipe.
- Limited rotating empty-state hints to Live sessions so Point Count and Survey screens stay focused on their protocol-specific UI.

## [0.15.2] - 2026-05-22

### Added

- Added screen-reader labels and tooltips across key controls, detection actions, Explore score badges, wizard steps, and Survey map markers and clusters.
- Added a screen-reader-aware default that enables spoken detection announcements for users with accessibility navigation active, while preserving explicit user choices.
- Added widget tests covering Survey map marker and cluster semantics.

### Changed

- Improved localized accessibility strings for capture controls, confidence and likelihood percentages, Survey map marker states, settings help, and announcement templates.

## [0.15.1] - 2026-05-21

### Added

- Added a Donate link to the bottom of the About screen, pointing to the BirdNET donation page.

### Changed

- Expanded weather condition icons so partly cloudy, overcast, drizzle, rain, and snow use more specific symbols in setup and session context views.

## [0.15.0] - 2026-05-20

### Changed

- Hid the offline map download setting while the app uses public OpenStreetMap tiles, centralized a contactable BirdNET Live user agent for map tile, place-name, and weather requests, and extended interactive map tile caching to six months with a 6000-tile storage cap.

## [0.14.12] - 2026-05-20

### Changed

- Replaced the `material_design_icons_flutter` dependency with `material_symbols_icons` for the app's shared icon set.
- Refactored feature and shared UI code to use centralized `AppIcons` mappings instead of direct package icon references, improving icon consistency across Live, Survey, Point Count, File Analysis, History, Explore, Settings, Help, and onboarding views.
- Refined centralized app icon choices for species, detections, map actions, filled map pins, stop controls, and survey start/end flags so review and map views read more consistently.

## [0.14.11] - 2026-05-20

### Changed

- Added a concise, scrollable Explore header explaining that the list shows BirdNET geomodel species predictions for the user's location, with a tap hint for opening species details.
- Improved Explore list scrolling by using fixed-height lazy species rows, reducing per-card widget/provider work, and lowering bundled thumbnail decode sizes.
- Reworked Explore species cards to keep the 48-week seasonal bars while drawing them with a lightweight painter instead of many per-week widgets.

## [0.14.10] - 2026-05-20

### Changed

- Allowing OpenStreetMap map tiles now also enables place-name lookup automatically, while keeping the place-name lookup setting separately revocable from Settings.

### Fixed

- Prevented the Survey map consent placeholder from overflowing in short embedded map previews by switching to a compact layout when space is limited.

## [0.14.9] - 2026-05-20

### Fixed

- Disabled Flutter Impeller on Android so devices affected by rare Adreno Vulkan driver crashes during offscreen image cleanup fall back to the Skia renderer.

## [0.14.8] - 2026-05-20

### Changed

- Updated Flutter package constraints for improved stability and compatibility, including Riverpod, recording, permissions, foreground tasks, notifications, location, map, sharing, package-info, and ONNX runtime dependencies.

### Fixed

- Verified the updated dependency set with static analysis, the full Flutter test suite, and Android integration tests covering ONNX model output, geo-model soundscape behavior, and memory stress scenarios.

## [0.14.7] - 2026-05-19

### Changed

- Removed the Session Review on-demand-spectrogram hint banner. With lazy loading now smooth, the explanatory card is no longer needed.

### Fixed

- Session Review no longer gets stuck on a perpetual loading spinner after an apply-trim / undo cycle on long lazy-loaded recordings. A failing chunk load now no longer leaves its reservation pinned in the pending set, and clip changes invalidate any in-flight lazy chunk requests so the follow-up viewport request can schedule fresh loads instead of being short-circuited by a stale `_decoding=true` flag.
- Trim mode in Session Review now works for long lazy-loaded recordings. The trim handles default to the strip's currently visible window and are clamped to it — zoom and scroll to the region of interest first, then drag the handles inward to refine. Previously the trim editor required a full-file spectrogram thumbnail that long recordings never produce, so trim mode silently rendered an empty editor.
- Stopped Session Review from freezing for several seconds when opening a session with a very long (≥30 MB on disk) recording. Playback normalization is now skipped for large source files instead of decoding the entire file on the calling isolate.
- Long FLAC recordings now actually show a spectrogram in Session Review. A one-time sequential FLAC → temp-WAV transcode runs in a background isolate the first time a long FLAC session is opened, after which lazy spectrogram chunks use true file-seek range reads instead of an O(N²) re-decode of the full FLAC for every chunk.
- FLAC range and sequential-window decoding now use a buffered streaming bit reader instead of loading the entire compressed FLAC into memory before walking frames, keeping File Analysis and long-recording review paths bounded by the requested window/cache size.
- File Analysis now refuses native compressed files whose decoded PCM would exceed the current full-decode memory guard, and also blocks large native files when the platform cannot report duration. Long recordings should be converted to WAV or FLAC so analysis can proceed in bounded chunks.
- Session Review lazy-spectrogram cache eviction now keeps chunks nearest the active viewport instead of evicting the earliest chunk by timestamp, preventing freshly loaded visible chunks from being discarded when revisiting another part of a long recording.
- Session Review now defers lazy spectrogram chunk scheduling until after the current frame, preventing a `setState() or markNeedsBuild() called during build` crash when the strip reports a refreshed viewport from `didUpdateWidget`.
- iOS native audio decoding now explicitly cancels AVAssetReader work on early exit or failure so native buffers are released promptly after large decode errors.

## [0.14.6] - 2026-05-19

### Changed

- Shortened the Session Review on-demand-spectrogram hint to a single sentence and added a close button so the banner can be dismissed.

### Fixed

- Hardened File Analysis and Session Review for long recordings. File inspection now reads metadata without decoding entire audio files, WAV/FLAC analysis reads bounded windows where possible, large decoded-audio footprints are surfaced before analysis, long-session spectrogram detail loads on demand during playback, panning, or zooming, and review/export metadata warns when a recording is shorter than its session events.
- Added decoder coverage for LPC-encoded FLAC subframes and a sequential FLAC window decoder so real-world recorder files, including hour-long FLAC fixtures, can feed File Analysis without failing on the first window or restarting decoding for every window.
- Stopped the Session Review spectrogram from getting stuck in a loading state during aggressive pinch-zoom: viewport requests now cap the number of in-flight chunks against the cache size, prioritize chunks nearest the playhead, and bail when a newer viewport supersedes them.
- Moved on-demand spectrogram chunk decoding (FLAC/WAV range decode + STFT) onto a background isolate so pinch-zoom on long recordings no longer skips frames on the UI thread.
- Long Session Review recordings now open at a duration-aware default zoom (≈10 % of clip length, clamped) instead of the 10 s detail view, and the on-demand spectrogram renders fewer FFT columns and caps frequency bins to what the strip can actually paint as distinct pixels. Short clips (≤ 5 min) honor your live-spectrogram duration setting as the initial view width, and the lazy loader now refreshes its viewport request the moment a long file's true duration arrives so chunks beyond the first 10 s actually start decoding.

## [0.14.5] - 2026-05-19

### Added

- Added two new hints to the Live Mode carousel explaining that confidence scores are not probabilities and that distance affects detection.
- Implemented an auto-retry mechanism for GPS location fetching to improve resilience on devices with spotty location reception.

## [0.14.4] - 2026-05-18

### Added

- **Weather lookup can now be enabled from setup.** Point Count and Survey setup both show a compact weather card near the location controls. If weather access is off, the card asks for **Allow weather lookup** consent; once enabled, it previews the selected site with the same condition icon used in Session Review plus temperature and wind only. The lookup uses the same weather cache as session saving, so setup preview, ready preview, and the eventual session save reuse one fetch instead of repeatedly calling Open-Meteo.
- **Dynamic Color translations completed for all locales.** The Dynamic Color setting added in 0.14.3 is now translated in Czech, Spanish, French, Italian, and Portuguese as well as English and German.

### Changed

- **Live hints now live before recording starts.** The idle Live detection panel now shows the rotating hint carousel instead of the old “Detections / Start a session…” placeholder. Once recording starts, the panel keeps the calmer “Listening… / Species will appear here” empty state until detections arrive.
- **Setup GPS refresh is more forgiving.** Point Count and Survey setup refresh the GPS fix when the app resumes, so newly granted location permission or a recovered GPS signal can update the coordinates without restarting the wizard. Survey’s unavailable-location copy is now neutral (“Location unavailable”) instead of implying permission is missing when the real issue may be a stale or unavailable fix.

### Documentation

- Documented setup-screen weather consent, setup GPS refresh behavior, and the four-step Point Count setup flow.

## [0.14.3] - 2026-05-18

### Added

- **Dynamic Color (Material You) toggle in Settings.** A new switch under Settings → Appearance lets you opt into your Android device's dynamic color palette instead of the BirdNET brand theme. On Android 12+ the app's surfaces, primary accents, and chrome rebuild against the wallpaper-derived palette so BirdNET visually matches the rest of your launcher. No effect on iPhone or iPad (kept off by default everywhere so first-launch users still see the brand theme).

### Changed

- **Semantic UI colors routed through the theme.** Success greens, the "confirmed" checkmark, and the four session-mode accents (Live red, Point Count blue, Survey green, File Analysis orange) are no longer hardcoded across widgets. They now live in a single `AppSemanticColors` theme extension that provides the brand hues under the default theme and harmonizes them against the active palette in dynamic-color mode. Survey map markers, the audio-quality bars, the onboarding permission checks, the live and clip-player confirmed toggles, and the session review cluster checkmarks all read from this token set, so the same widgets stay legible whether you're on the brand theme, a light dynamic palette, or a dark one. No behavioral changes — purely a visual consistency pass.

## [0.14.2] - 2026-05-15

### Changed

- **Live empty-state tips polish.** The "DID YOU KNOW?" carousel under the "Listening…" placeholder now: (a) uses the same faint gray as the rest of the empty-state copy so it reads as supporting text instead of competing with the headline, (b) cycles every 15 s instead of 10 s so there's enough time to actually read each tip, and (c) sits a bit further below "Listening…" for breathing room.
- **"Listening…" stays put.** The tip card now has a fixed height, so the "Listening…" headline above it no longer jumps around as longer or shorter tips rotate in.

### Added

- **Five more live tips.** The carousel now includes guidance on using an external Bluetooth or wired microphone for surveys, the foreground-service notification that keeps surveys recording in the background, keeping study design consistent across sessions at a site, the fact that AI detections can be wrong (especially for rare species — review the spectrogram), and bringing a power bank for long surveys with GPS active.

## [0.14.1] - 2026-05-15

### Fixed

- **Session review playback no longer stops every few seconds when you tap a cluster.** The cluster auto-pause was originally intended as a "preview" — start at the first detection, pause once playback walked past the cluster's last detection (typically 3–6 s in). In practice it just made the player feel broken: users almost always want to keep listening for the call to repeat or for context. Tapping a cluster now seeks to the cluster start and lets playback continue until you pause it or the recording ends.
- **Quiet recordings are boosted on playback in session review too.** Both the full session recording (live / point-count / survey) and the per-cluster fallback clip player now run through `PlaybackNormalizer` before being handed to `just_audio`, matching the behavior of the clip-player sheet that is opened from the survey map. Distant or low-gain clips become audible without modifying anything on disk — original FLAC files keep their lossless compression and bit-exact dynamics.

## [0.14.0] - 2026-05-15

### Added

- **Tips carousel on the live empty state.** When a session is recording but no detections have come in yet, the otherwise-empty detection panel now rotates through ten short, localized hints — *"Hear it called out"* (announcements), *"Mind the wind"* (mic placement), *"Filter by your location"* (geo filter), *"Watch the sound"* (spectrogram), *"Tune the threshold"*, *"Star your targets"* (watchlists), *"Got a recording?"* (file analysis) and others. A new tip appears every 10 s with a soft fade; tapping the card jumps to the next one. Tips are randomized per build so opening a fresh session does not always start at #1. Helps newcomers discover features they would otherwise miss while waiting for the first detection.

## [0.13.14] - 2026-05-15

### Added

- **Wind speed shown next to temperature on weather chips.** Both the live site-context card and the per-session weather chip in session review now read e.g. *"☀ 18.4 °C · 3.2 m/s SW"* instead of just the temperature. With an icon as the prefix the line stays compact, and wind is the second most useful field for assessing how much wind noise to expect in the recording at a glance — the same value already appears in the long-form weather formatter and detail dialog.
- **Reset all settings (Danger zone).** New tile in the Settings → Danger zone section restores every preference to its default. Sessions, recordings, voice memos and downloaded map tiles are kept untouched — only the SharedPreferences store is cleared. The app closes after confirmation so the new defaults take effect on next launch. Useful for recovering from an accidental misconfiguration without losing data.
- **Quiet detection clips are boosted on playback.** When a clip's peak amplitude falls below ~0.5 (e.g. distant birds, low-gain mics, FLAC-compressed clips that preserved the original dynamics) the clip player writes a peak-normalized temporary copy under the OS temp folder and plays that instead. Original recordings on disk are never modified — keeping their bit-exact dynamics matters for analysis and means FLAC compression is not defeated. The cache is bounded (≤32 entries) and pruned LRU-style on each access; the OS reclaims it on uninstall or temp purge.

### Fixed

- **Modal sheets no longer render under the system navigation bar / gesture inset on edge-to-edge displays.** Help sheets, the new-session picker, the device picker, the settings preset sheet, the survey/library "add" menus and the clip player all gained `useSafeArea: true`, so their bottom controls land above the navigation bar on devices that still draw a 3-button bar. Sheets that already wrapped their bodies in a `SafeArea` continue to work; this just brings the rest in line.

## [0.13.13] - 2026-05-14

### Fixed

- **Spoken species name now matches the name shown on the detection card.** The on-screen detection list resolves each species through the bundled taxonomy and the user's species-name language (so users see *Fox Sparrow*, *Mangrove Warbler* or *Amsel* depending on locale), but the announcement pipeline was forwarding the raw audio-classifier label instead. The two label sources sometimes disagree on English wording — for example the classifier emits *"Red Fox Sparrow"* while the taxonomy entry is *"Fox Sparrow"* — which is why TTS occasionally said something different from what the screen showed. The announcements sink now applies the same taxonomy + species-locale lookup the UI uses, so speech and screen always agree (and non-English UIs hear the localized common name instead of the English classifier label).

## [0.13.12] - 2026-05-14

### Changed

- **Announcement chatty phrasing dialed back from comically over-the-top to just informal.** Lines like *"{name} is on a roll."*, *"{name} really doesn't want to stop."*, *"Quite the performance from {name}."*, *"Petit récital de {name}."*, *"Pequeño concierto de {name}."*, *"Beeindruckende Ausdauer von {name}."* and *"Hier singt halb der Wald …"* read as a stage announcer rather than a birding companion when they fired in real surveys. Replaced with shorter, neutral observations (*"{name} is keeping it up."*, *"Sustained calling from {name}."*, *"Activité soutenue de {name}."*, *"Atividade sustentada de {name}."*, *"Anhaltend aktiv: {name}."*) across all seven UI languages. Also dropped the very British *"That'll be a {name}, I reckon."* in favor of *"Looks like {name} from here."*.
- **A bit more variety in chatty bucket A** (clean first detections, the most-heard bucket) and chatty bucket C (sustained calling), with two new neutral variants per locale so the same handful of phrases doesn't loop within a single session. Gender-neutral phrasing rules are preserved (no inflected articles in front of `{name}` placeholders for DE/FR/ES/IT/PT/CS).

## [0.13.11] - 2026-05-14

### Fixed

- **Announcement voice now follows the species-name language, not just the UI locale.** When the app was set to English UI but German species names, the controller still loaded the English voice and English template bundle and tried to pronounce names like *Amsel* or *Rotkehlchen* through an English synthesizer — the result sounded garbled. The resolution order is now: explicit voice override → species-name language → UI locale → platform locale, so the spoken language matches the names being read out. Changing either the species language or the voice override at runtime reconfigures the TTS engine and reloads the matching template bundle on the next detection batch, without resetting throttling state.

## [0.13.10] - 2026-05-14

### Changed

- **"Mute capture during speech" now defaults to off.** On Android, briefly muting the active `AudioRecord` stream while the phone speaks shows up as a visible flat band in the live spectrogram. TTS audio is quiet enough that bleed-back into the built-in mic doesn't trigger spurious detections in practice, so we no longer pay the visual cost by default. Users who notice false positives during long announcements can still opt in from Advanced.

### Fixed

- **Spectrogram no longer hiccups at the start of every announcement.** The routing service used to call `session.setActive(true)` immediately before each utterance, which on Android transiently re-routes the live capture stream and creates a visible gap or wobble. Removed the per-utterance focus toggle — the session is already configured at init time, and `flutter_tts` requests its own audio focus (with the `assistanceAccessibility` usage we set) when it actually speaks, so the OS still ducks other audio without us perturbing the recording.

## [0.13.9] - 2026-05-14

### Fixed

- **Announcements no longer go silent (and the spectrogram no longer hiccups) when a Bluetooth earbud is paired but the internal mic is in use.** The pre-speech HFP-downgrade check was reading the *available* input device list and unconditionally treating any listed `bluetoothSco` mic as proof that the OS had forced HFP — but paired BT earbuds always advertise an SCO input alongside their A2DP sink, regardless of which mic is actually recording. Every announcement therefore aborted with a routing failure, and the audio session was left active (jolting the record stream). The check now only flags a true downgrade when *no* non-BT input is available (no built-in mic, no wired headset mic), and aborted-routing paths deactivate the session before returning.

## [0.13.8] - 2026-05-14

### Changed

- **Startup grace is now a uniform 5 seconds across every frequency preset.** Previously *Rare* held back announcements for 2 minutes and *Sparse* for 1 minute — by the time the app finally spoke, users were unsure whether anything was working. Five seconds is enough for the audio session to settle while still giving immediate feedback on the first detection.
- **Speaker output is allowed by default.** The setting used to ship off (it was a wizard-set flag, but no wizard exists in the current build), which meant the app silently skipped every announcement when nothing was plugged in. The toggle still lives in *Advanced* for headphones-only setups.

### Fixed

- **The four advanced announcement toggles now actually do something.** *Allow speaker output*, *Mute capture during speech*, *Lower other audio*, and *Cue tone before speaking* were UI-only — flipping them had no effect on runtime behavior. They are now threaded all the way through the controller, routing service, and TTS engine: speaker mode is gated, ring-buffer muting is conditional, audio focus is requested with or without ducking, and a short system alert tone plays before each utterance when the cue is enabled.

### Removed

- **"What to announce" trigger-mode picker.** The picker offered *Every detection / First time per session / Watchlist only* but the controller never consulted the value — it was dead UI. Removed to keep the settings surface honest; first-in-session and watchlist filtering will return when the underlying logic exists.

## [0.13.7] - 2026-05-14

### Fixed

- **Two-bird announcements no longer drop the framing phrase.** A coalesced batch of exactly two species used to fall back to a bare comma list ("Robin, Wren.") because the existing multi-species templates hard-coded three name slots. Added a dedicated `H_two` template bucket with balanced and chatty variants in all seven languages (e.g. "Two at once: Robin and Wren.", "Nice duet — Robin and Wren both in the mix."), so the engine now has natural framing for two, three, and four-plus bird batches.

## [0.13.6] - 2026-05-14

### Changed

- **Announcement settings consolidated.** Removed the five "Advanced" numeric sliders (startup grace, minimum gap, max per minute, streak silence, recency reset) — these are now bundled into the **Frequency** slider, which stamps the right values for each preset. The Advanced disclosure now only holds the four audio-routing switches and the trigger-mode picker, so there is a single, obvious place to adjust cadence. Defaults unchanged: *Lower other audio* and *Cue tone before speaking* are both on out of the box.

## [0.13.5] - 2026-05-14

### Changed

- **Announcement phrasing is livelier and more varied across all seven languages.** Bumped each bucket from 3-5 phrases to 6-8, gave Chatty mode more personality (small asides, conversational comments), and dropped the apologetic "Hard to tell" / "I'm not at all sure" tone on low-confidence detections — the user already sees the score, so phrasing now leans on lighter hedges like *"Possibly a {bird}"*, *"Sounds a bit like a {bird}"*, *"My best guess on this one"*. Multi-bird Chatty announcements (three or more species at once) now feel like a real birding companion rather than a list dump (*"Quite a chorus — Robin, Wren, and Blackbird all at once"*). The commonness phrase pool also grew from 3 to 5 variants per bin.
- **Settings: announcement frequency is now a slider** (Rare ↔ Constant) instead of a five-button segmented control. The five labels — *Rare, Sparse, Normal, Frequent, Constant* — used to wrap and sometimes broke across multiple lines on narrower screens (one report had *"frequent"* rendering as *"fre / qu / ent"*, one letter per row). The slider is always one row, with the active preset name shown above it.

## [0.13.4] - 2026-05-14

### Added

- **Chatty announcements now mention how common a species is in your area, the first time it's heard each session.** Phrases like *"A common bird around here"*, *"Not super common in your area"*, or *"A bit of a rarity around here — nice catch!"* are appended to the first announcement of each new species. For migrants caught well outside their annual peak at your location, a short seasonal hint follows (*"Though they're not usually around this time of year."*). All driven by the existing on-device geo-model, so it works fully offline — no extra network call, no extra battery cost. Translated for all seven UI languages.

## [0.13.3] - 2026-05-14

### Changed

- **Announcements now pick the peak-confidence call for each species, not the first marginal detection.** Live, Point Count, and Survey submit the full per-cycle detection list to the announcement controller, which dedups by species and keeps the highest score. Streak silence and the global min-interval gate continue to do all the throttling, so this only affects *which* call is voiced when a species fires, not *how often*.
- **Frequency presets expanded from 3 to 5 levels.** Added **Rare** (very long gaps, ~1/min cap, for multi-hour surveys) and **Constant** (zero startup grace, ~20/min cap, for demos and accessibility). Constant directly addresses the field complaint that even *Frequent* could take a while to start talking after a session began.
- **Removed the planned first-run announcements setup wizard.** The verbosity × frequency pickers are the entire setup — five frequency steps and three verbosity steps mean users can experiment with segments and find their sweet spot without leaving the screen.
- **Announcements section moved up in Settings**, now directly after Spectrogram (was below Privacy). It is the only setting users typically revisit mid-session, so discoverability matters more than category alphabetization.

### Fixed

- **Two-species announcement no longer drops the third slot.** A batch of exactly two species used to render through a `{name1}, {name2}, and {name3}` template with `name3` silently empty (e.g. *"Robin, Jay, and ."*). The phrasing engine now early-returns a plain comma list (*"Robin, Jay."*) for two-name batches, locale-agnostic.

## [0.13.2] - 2026-05-14

### Added

- **Spoken detections now fire from Live, Point Count, and Survey.** With the master toggle in **Settings → Announcements** on, the announcement pipeline (verbosity / frequency presets, throttling, anti-repeat, ring-buffer mute) is wired into all three live capture modes. Each mode emits an announcement batch only for species that just appeared in the on-screen detection list, and resets per-session throttling state when a new session starts. The alert sink is lazy: no TTS plugin or audio-session work happens at app start, only on the first batch while the feature is enabled, so users who never opt in pay zero startup cost.

## [0.13.0] - 2026-05-14

Internal scaffolding for spoken detection announcements (TTS) shipping
later in this version. No user-visible changes yet — the master toggle
defaults to off and the feature has no UI surface in this commit.

### Added

- **Foundations for spoken detection announcements.** Pure-Dart
  phrasing engine (bucket router for confidence × recency × streak,
  3-slot anti-repeat memory, locale fallback chain), JSON template
  bundles for English and German under `assets/announcements/`,
  preference keys, verbosity / frequency preset enums, and Riverpod
  providers. Setting a frequency preset stamps the matching numeric
  profile (startup grace, min interval, max-per-minute, streak
  silence, recency reset, session reset, coalesce window) into the
  Advanced prefs in one transaction so the engine and the UI can
  never disagree.
- **Gender-safe German phrasing rule.** Bird names in German (and
  several other locales) are gendered (`der Zaunkönig`, `die Amsel`,
  `das Rotkehlchen`) and we do not carry a gender field per species.
  All German announcement templates have been authored without a
  determiner directly in front of `{name}`; a unit test fails the
  build if a regression slips one in. The rule and safe phrasing
  patterns are documented in `dev/announcements.md` §3.8.1 for
  future translators.

## [0.12.3] - 2026-05-14

### Changed

- **Inline consent prompts on the wizard site-context card.** When the place-name or weather privacy toggle is still off and you reach the "Ready" step of the survey or point-count wizard, the corresponding row now shows a tap-to-allow link instead of being hidden. Tapping flips the privacy toggle on, runs the lookup, and replaces itself with the result — no detour through Settings.
- **Offline note when a site-context lookup fails.** If you have consent on but the network is unreachable (no signal in the field, service down), the wizard card now shows a small "Offline — you can add place name and weather later from the session review" hint instead of silently dropping the row. Both lookups already retry on session-review open, so the data isn't lost.

## [0.12.2] - 2026-05-14

### Changed

- **Setup wizard pre-fetches site context.** The "Ready" step in the survey and point-count wizards now resolves the place name and current weather as soon as GPS coordinates are known and shows them in a small card under the parameter summary, so you can confirm what will be recorded with the session before tapping Start. Both lookups go through the same persistent caches as everything else (no network spam).
- **Weather retry on session review open.** If the original end-of-session weather fetch failed (no consent at the time, no internet, Open-Meteo unreachable), opening the session in Review now tries once more and persists the result — mirroring the existing reverse-geocode retry behavior. Already-captured snapshots are left untouched.

## [0.12.1] - 2026-05-13

### Changed

- **Compact weather chip on the session review header.** The temperature and condition icon now sit inline with the date row instead of taking their own line, saving vertical space on small phones. Tapping the chip still opens the full weather details sheet (now with an explicit "Condition" row).
- **Weather snapshot included when sharing from the session library.** The per-row Share action now bundles the same `metadata.json` (with the embedded weather block, app version, model config, and prefs snapshot) that the session review screen produces. When weather data exists and the user picked a non-JSON format (CSV, Raven, GPX), the export is automatically packaged as a ZIP so the metadata sidecar travels with it.
- **6 h persistent weather cache.** Weather snapshots are now persisted across app launches and reused for any session started within 6 hours at the same 0.1° cell. Multiple short sessions at the same site no longer hit the Open-Meteo API repeatedly.
- **Persistent reverse-geocode cache + library backfill.** Place names returned by Nominatim are cached on a 0.1° lat/lon grid (no expiry — place names don't change on a birding-trip timescale), so a second session at the same site never re-hits the network. The session library also auto-backfills its location chip from this cache on every list load and writes the resolved name back into each session's `locationName`, making the label permanent for that session.

## [0.12.0] - 2026-05-13

### Added

- **Three-toggle privacy gate for third-party services.** A new **Settings → Privacy** section replaces the single "show map tiles" consent with three independent switches that match the three external services the app can talk to: **Allow map tiles** (OpenStreetMap raster servers — used by every map widget), **Allow place name lookup** (OpenStreetMap Nominatim — turns recorded coordinates into a short human-readable place name shown next to the session), and **Allow weather lookup** (Open-Meteo — see below). All three default to **off** so a fresh install never reaches out without you saying so; existing installs that had agreed to the previous map-tile consent are auto-migrated into both the map-tile and place-name gates so nothing silently goes dark. Each toggle ships an in-context help sheet explaining what data is sent, to whom, and what happens when it is off.
- **Per-session weather snapshot via Open-Meteo.** When **Allow weather lookup** is on, every saved session captures a one-shot weather observation (temperature, precipitation, wind speed and direction, cloud cover, WMO weather code) at the recording coordinates and end time. The snapshot lands in **Session Review** as a tappable row under the location chip — tap to expand into a small sheet with all fields and the Open-Meteo attribution. The same snapshot is mirrored into the JSON export, the per-session metadata block, and a dedicated weather card in the HTML report. Open-Meteo is a free service and requires neither an account nor an API key. When the gate is off, sessions store no weather data and no network call is made.
- **Multi-format export selection.** The export-format setting that used to let you pick a single output format (Raven Selection Table, CSV, JSON, or GPX) is now a checklist — tick any combination and every save / share action bundles all selected formats together. When you pick a single format with no audio clips and no HTML report, the share still hands you a single raw file (e.g. `session.csv`) for backwards compatibility; any other combination produces a ZIP with all selected docs at the root next to the audio, memos, metadata, annotations, and HTML report. The previous single-format setting is auto-migrated on first launch so your existing preference is preserved.

### Changed

- **All user-facing strings translated into all 7 supported locales.** New strings introduced by the privacy gate, weather snapshot, and multi-format export are shipped with full translations in English, German, Czech, Spanish, French, Italian, and Portuguese — no en-US fallbacks visible in the new surfaces.
- **User guide refreshed.** `docs/user/settings.md` gains intuition notes for the three new privacy toggles and the multi-format export checklist; `docs/user/session-review.md` documents the new weather row; `docs/user/exports.md` covers the multi-format ZIP layout; and the privacy notice in all 7 locales now lists OpenStreetMap, Nominatim, and Open-Meteo with retention and revocation guidance.

## [0.11.5] - 2026-05-13

### Added

- **HTML report inside every export ZIP.** Sharing or saving a session now drops a self-contained `report.html` next to the CSV, JSON, audio clips, and GPX. Open it in any browser and you get a print-ready summary: header card with date, location, observer, transect length and totals; an interactive Leaflet map of the GPS track and detection markers (online); a card per detection with the Cornell taxonomy thumbnail, common and scientific names, the score as a coloured pill, both wallclock and relative time, your confirmation, any note you typed, and the original audio clip inline as a `<audio>` player; and a settings card showing the analysis parameters used. Species thumbnails and map tiles need a connection the first time the file is opened, but everything else — layout, audio, text, links to species pages — works fully offline. Toggle in **Settings → Export → Include HTML report** (on by default).
- **Offline map tile download.** A new **Settings → Location → Download offline maps** action pre-caches OpenStreetMap tiles around your current GPS fix at 1 / 5 / 10 / 25 km radius for zoom levels 12–16. Useful before heading into surveys without signal: the Survey live map and the exported HTML report both read from the same on-disk cache, so what you download here is what you see in the field. Pre-download size estimate is shown before you commit, with a 50 MB ceiling to keep us a polite OSM citizen, and the downloader paces requests under the 2 req/s tile-usage policy with a Cancel button always available.



### Added

- **Prev / Next on the fullscreen Survey clip player.** The audio overlay that opens when you tap a marker on the fullscreen Survey map now has skip-previous and skip-next buttons flanking the play control, so you can step through detections without dismissing the sheet and hunting for the next pin. Both buttons walk only the *currently filtered-in* detections (whatever species, confidence floor, or mode chip you have active), so flipping through a single species' calls is a one-tap operation. The buttons grey out at the ends so you always know when you've reached the first or last detection in the current view.
- **Sessions render in your phone's local time.** Every timestamp in Session Library and Session Review — list rows, header dates, detection times, exported filenames — is now rendered in the device's current local time zone, derived on the fly from the UTC timestamps stored in the session. Travel across time zones with an in-progress session and the clock simply follows the phone; nothing on disk changes. Existing sessions are unaffected: the underlying UTC values are unchanged, only the rendered time follows the device clock.

### Changed

- **Export bundles now carry the settings the session actually ran with.** The `settings` block inside a session JSON export used to include only the four user-visible defaults (window duration, confidence threshold, inference rate, species filter mode). It now serializes the full per-session settings snapshot, including sensitivity, score-pooling mode/windows, applied microphone gain, and the high-pass cutoff that was active when the session ran. Reproducing a result from an export — or comparing two surveys — no longer requires you to remember which sliders were where.
- **Race-safe "last 3 species" in the Survey foreground notification.** The persistent notification's rolling list of the three most recent species could occasionally render a stale or out-of-order view because it iterated the live detections list while inference might be inserting a new record. The notification now reads from an immutable snapshot that is rebuilt whenever the list mutates, so the lock-screen view is always a coherent picture of the latest detections.
- **Session Library: collapse arrow now follows the kebab.** The grouped-by-day section headers in Session Library used to put the expand/collapse chevron *before* the kebab overflow, which read as "this is the menu's icon". The chevron is now the trailing affordance, after the kebab, matching every other expandable list in the app.

### Fixed

- **Survey resume now respects current notification settings.** Resuming an in-progress survey from Session Library re-reads every species-alert preference (mode, watchlist, confidence floor, throttling, sound, vibrate) from Settings before re-arming the alert pipeline, so toggling alerts off between stop and resume actually silences notifications instead of inheriting the start-time configuration. Verified the alert coordinator is fully replaced (and the prior one shut down) on every resume, so no stale snapshot survives the round-trip.

## [0.11.3] - 2026-05-12

### Added

- **Microphone gain and high-pass filter actually shape the audio now.** The "Mic gain" and "High-pass filter" sliders under Settings → Audio used to be cosmetic — they updated stored values but nothing in the capture pipeline read them. Both now apply to the live signal feeding inference, the spectrogram, and any session recording, with mid-session hot-apply: drag the slider while a Live, Point Count, or Survey session is running and the next captured chunk reflects the change. Gain is a linear multiplier with peak saturation; the high-pass is a 2nd-order Butterworth biquad whose cutoff (in Hz) is exactly what the slider shows.
- **Sensitivity setting is wired into inference.** The Sensitivity slider under Settings → Detection (BirdNET's logit-shift parameter) is now passed to the audio classifier on every inference call across Live, Point Count, and Survey, with the same mid-session hot-apply pattern as the other tunables. Previously the slider only persisted a value that no detection path ever read.
- **Microphone selection persists across launches.** The chosen input device under Settings → Audio (and the same picker on the Survey setup screen) is now stored in `SharedPreferences` instead of resetting to "System default" on every cold start. Picking a USB or Bluetooth mic once is enough — the app remembers it next time you open Live, Point Count, or Survey.
- **Score-pooling mode actually does something now.** The "Score pooling" dropdown under Settings → Detection (off / average / max / LME) used to update a stored preference that no inference path ever read — every session ran log-mean-exp regardless of the choice. The mode is now plumbed through to the audio classifier in Live, Point Count, and Survey, with the same mid-session hot-apply behavior as the other tunables. *Off* skips pooling entirely (raw single-window probabilities); *average* arithmetic-means recent windows for smoother detections; *max* keeps the loudest peak (most reactive, noisier); *LME* (default) is the soft-maximum that has always been BirdNET's reference.
- **Add notes to a survey while it's running.** The `+` button on the Survey live screen now opens a small menu with *Add species* and *Add note* — text annotations get attached to the active session immediately and are persisted on the next flush, so you can capture context (weather change, observer notes, "stopped to listen at the bridge") without waiting for the survey to end. Voice memos remain a Session Review feature since the capture mic is busy during a live survey.

## [0.11.2] - 2026-05-12

### Added

- **Per-detection text notes.** Every detection in Session Review now has an "Add note" / "Edit note" entry in the overflow menu (also surfaced in the clip-player sheet). Notes accept short free-form text — e.g. "juvenile, distant, behind tree" — and a small note glyph appears inline on the detection row when one is set, with the note text as a long-press tooltip. Notes round-trip through JSON sessions so they survive export/re-import.
- **Voice memos on detections.** A new "Record voice memo" / "Replace voice memo" entry in the detection overflow menu lets reviewers attach a short spoken note to any detection. Memos are recorded in AAC/M4A (mono 16 kHz, ~8 KB/s) and stored alongside the session's clips. Rows with a memo show an inline mic glyph that opens the memo for playback or replacement on tap. Memos are bundled into ZIP exports under `memos/` and referenced from a new CSV "Voice Memo" column.
- **"Other (specify)" species in Session Review.** The Add Species / Replace Detection overlay now distinguishes a generic *Unknown / Other* placeholder from *Other (specify)* — picking the latter opens a small text dialog for free-text labels (e.g. "dog", "frog", "helicopter") that aren't taxonomy species. Custom labels are stored as the common name with an empty scientific name and tagged `DetectionSource.userSpecified`, so they round-trip through JSON sessions and exports and stay easy to filter alongside other manual entries.

### Changed

- **Live tunables apply mid-session.** Changing the confidence threshold or score-pooling-window count from Settings while a Live, Point Count, or Survey session is running now pushes the new value straight into the running pipeline — the next inference cycle picks it up without restarting the session. Previously these settings were captured once at session start and silently ignored until restart.

### Fixed

- **Map tiles now cache to disk.** OpenStreetMap tiles used by the survey map, session map, and location pickers are persisted in a dedicated on-disk cache (90-day retention, 4000-tile cap) instead of being re-downloaded from scratch on every cold start. Repeated panning, zooming, and revisits to previously viewed areas are now instant, and maps remain usable when signal drops mid-survey.
- **FLAC files now open in strict decoders.** Recorded `.flac` files now carry a real MD5 signature of the unencoded PCM in their STREAMINFO header, and the reported `min_block_size` is clamped to the spec-required minimum of 16 samples even when a session ends on a tiny tail frame. Both changes let strict, libsndfile-based tools — most notably Raven Pro — open and verify our recordings; previously they rejected the files at the metadata-validation step.

## [0.11.1] - 2026-05-12

### Added

- **Sort sessions by recording duration.** The Session Library sort sheet now offers "Longest first" and "Shortest first" alongside the existing date and name orderings, so finding the longest survey or the shortest test recording in a large library is a single tap instead of a manual scan. (#33)
- **Three-dot menu on session rows.** The trash icon on each session card has been replaced by a `more_vert` overflow menu offering Open, Share, and Delete. Share routes through the user's saved export-format and include-audio preferences and opens the platform share sheet directly — no need to open the review screen first to share a session. (#33)
- **Swipe-to-delete on session cards.** Each row in the Session Library can now be swiped in either direction to delete the session, matching the swipe gesture already used on the Session Review species list. The same destructive-confirmation dialog is shown before the session is removed, so an accidental swipe is still recoverable. (#33)
- **Auto-start Live recording.** A new switch in Settings → Recording (visible when Settings is opened from Live mode) makes Live mode begin recording as soon as the screen opens and the model is ready. Useful for kiosk-style installations and hands-free use. The auto-start fires only once per screen visit, so a manual stop-and-restart still works as expected. Disabled by default so an accidental tap on the Live tile from the home screen does not silently start a session. (#33)
- **Manual "Refresh GPS now" tile in Settings → Location.** When GPS is enabled, a new tile shows the current cached coordinates and lets you force a fresh fix on demand — useful when you have moved between sessions and want the geo-filter to reflect *here*, not where the app last looked. The tile shows a spinner while the receiver acquires a fix and a snackbar when the result is ready. (#33)

### Changed

- **Compact view rows expand in place.** In the compact Session Library view, the trailing trash icon has been replaced by an expand affordance. Tapping it expands the row in-place to the full detailed-view card body — top species, duration, species count, detection count, size — without leaving the list or losing scroll position. The same overflow menu and swipe-to-delete gesture are available on the expanded card. (#33)
- **Pinch-to-zoom on the Session Review spectrogram.** The playback spectrogram strip now responds to pinch gestures: spread to zoom in for fine timing inspection, pinch to zoom back out to the 10-second overview. Single-finger pan still scrubs the timeline, tap-to-seek still works, and the time-axis labels automatically retighten as you zoom so they stay legible. (#33)
- **Survey map filter applies live.** The fullscreen survey map's filter sheet now updates the map immediately when you tap a mode chip, drag the confidence slider, or pick a species — no more hunting for an Apply button. Slider drags are debounced so the map stays smooth, the **Reset** button still wipes filters in one tap, and the new **Done** button just dismisses the sheet (you can also swipe it down). (#33)
- **Tap species in map clip player to open Species Info.** Tapping the species avatar or the species name in the map's clip-player sheet now opens the same Species Info overlay used elsewhere in the app, so reviewers can jump from a marker callout straight to the full species page (Wikipedia excerpt, eBird / iNaturalist links, image credit) without backing out of the player. (#33)
- **Home menu order tuned for frequency of use.** The home-screen footer now puts Sessions first (it's the second-most-tapped destination after starting a recording), then Explore, with Settings and Help moved toward the end where infrequent destinations belong. Result: the most-used buttons now sit on the leftmost edge where the thumb naturally lands. (#33)
- **Higher-accuracy GPS fix at session start.** Live, Point Count, and Survey now request a high-accuracy GPS fix (instead of medium) when starting a session, and force a fresh fix instead of reusing the FutureProvider-cached value. The 10-second timeout still falls back to the OS-cached last-known position if no satellite fix is available — but the app now warns you with a snackbar when that happens, so you know the location is approximate. (#33)

### Fixed

- **Species play button no longer hides when the first cluster lacks audio.** The play button on a species header was previously gated on the very first cluster having an audio clip. In sessions where the earliest detection happened to lack a clip but later detections had one, the play button incorrectly disappeared. It now appears whenever any cluster has audio, and seeks to the first playable cluster. (#33)
- **Snackbar lifetimes capped and de-duplicated.** Undo snackbars in Session Review (single-detection delete, whole-species delete) now display for up to 6 s — long enough to react, short enough not to linger across screens. The species-alert snackbar in survey mode now dismisses any prior snackbar before showing the next one, so a flurry of new species no longer queues up overlapping notifications. (#33)

## [0.10.4] - 2026-05-12

### Added

- **Species search and sort on the Session Review screen.** A sticky search field above the species list filters by common or scientific name (locale-aware), so finding a specific species in a 100-species session is a few keystrokes instead of a long scroll. A new sort menu offers four orderings: A → Z (the new default — first-detection order becomes hard to scan once a session has lots of species), Most detections, Highest confidence, and First detected (the historical default, kept for users who want it). The chosen sort persists across sessions via `SharedPreferences`. Manual swipe-to-delete on the live survey detection list is unchanged. (#33)
- **Manual-detection indicator on detection rows.** Detection rows in Session Review whose records were all added by hand now display the same edit-note glyph already used on species headers in place of the play button, so reviewers can tell at a glance which rows came from a tap rather than from the model. (#33)
- **Swipe-to-delete on species headers.** Swiping a species header row in Session Review (left or right) now deletes every detection of that species at once, with the same undo SnackBar as the existing per-detection swipe. Triaging a session full of misidentified noise no longer requires expanding each species first. (#33)

### Changed

- Default species sort on the Session Review screen is now alphabetical (was first-detection time). Switch back via the new sort menu if you preferred the old order.

## [0.10.3] - 2026-05-12

### Added

- **Manual species entry during a live survey.** A small `edit_note` floating action button on the live survey screen opens the same species picker used in session review, so surveyors can log birds they saw or heard but BirdNET didn't pick up (or species that called before/after the inference window). Manual entries get `DetectionSource.manual`, are timestamped to the moment of confirmation, are GPS-tagged from the current track, and appear immediately in the live detection list, on the map, in the summary tab, and in every export format. They render with a small `edit_note` icon + "Manual" label everywhere they appear so they're never mistaken for an inference result. (#33)

## [0.10.2] - 2026-05-11

### Changed

- **Unified per-detection actions.** Confirm, share, replace, and delete now look and behave the same everywhere a detection appears — the session review species list, the clip player sheet (review and live survey), the live survey detection list, and the survey map markers. Confirm stays inline as a one-tap checkmark; share/replace/delete live behind a single `more_vert` overflow rendered by a new shared widget. The platform-neutral share icon (`Icons.share`) replaces the iOS-specific glyph that was used in some places. (#33)
- **Faster cleanup of false positives.** Deleting a detection in session review no longer requires confirming a modal dialog. Rows can be swiped horizontally or removed via the overflow menu; an undo SnackBar appears for a few seconds so misfires are reversible. The same undo affordance is available when deleting from the live survey list or a live survey map marker. (#33)
- **Distinct swipe shortcuts on session review rows.** Swiping a detection row to the right deletes it (with undo); swiping to the left opens the replace-species overlay. The two backgrounds are color-coded (error red vs primary blue) so the gesture's effect is obvious before the user commits. (#33)
- **Hierarchy-emphasizing inset.** Cluster rows under an expanded species are now indented so the parent species card is visually distinct from its children. (#33)
- **Friendlier filename for shared clips.** Sharing a single detection now uses the same `BirdNET_Live_<timestamp>_<species>.<ext>` naming scheme as the ZIP export, instead of the internal `clip_<ms>` filename. (#33)
- **Share works mid-survey for full recordings.** When a session records one continuous file (instead of per-detection clips), sharing a detection now slices the relevant audio window out of the recording on the fly, so the recipient still gets a clip rather than a text-only message. Both WAV and FLAC continuous recordings are supported, and the slice ships in the same container as the source (WAV in → WAV out, FLAC in → FLAC out). Sessions without any recording still share text with location and timestamp. (#33)

### Added

- **Live survey detection actions.** Detection rows during a survey now show inline confirm + a share/delete overflow so reviewers can validate, share, or remove a detection mid-capture instead of waiting for review. (#33)
- **Live survey map markers open the clip player.** Tapping a detection marker on the live survey map opens the same review sheet (confirm + share + delete) used elsewhere, closing the gap between the live and post-session map experience. (#33)
- **Delete from the survey review map.** The clip player sheet now exposes a `Delete detection` entry when opened from the post-session fullscreen survey map, fixing a dead-end where the only review action available there was confirm. (#33)
- **Delete species from the overflow menu.** The per-detection `more_vert` menu now offers a `Delete species` entry that removes every detection of that species from the session in one shot, with the same SnackBar undo as a single delete. Useful for sweeping out a misidentified noise source without expanding the species and deleting clusters one by one. (#33)

## [0.10.1] - 2026-05-06

### Changed

- **Session review polish.** The map overlay player now shows a confirm checkmark in the upper-right corner so reviewers can validate detections while listening, and its transport row was tightened so the play button sits inline with the scrubber, leaving only the close button at the bottom. Detection rows in the species list extend further to the left for more readable text. The persistent map filter chip was relabeled "All detections" to better reflect what's shown when no species filter is active, and its translation was added to the remaining locales (cs/es/fr/it/pt) (#33).

### Added

- **Share individual detections.** Reviewers (and field users mid-survey) can now share a single notable detection without exporting the whole session. The clip player sheet header gains a small share icon next to the confirm checkmark, and a long-press anywhere on a detection row in the species list pops a context menu with the same Share action. Both paths emit a terse, field-tool-friendly payload — common + scientific name, confidence, ISO 8601 UTC timestamp, and a `geo:` URI when the detection has GPS — and attach the audio clip via the platform share sheet whenever one is on disk (#33).
- **Confirmed-detection flag.** Reviewers can now mark detections as visually or acoustically confirmed during session review. Each detection row in the species list has a tap-to-toggle check button; confirmed clusters get a small green check next to the species name and confirmed map markers gain a green check badge in the upper-left corner so they stand out at a glance. The confirmed state persists with the session and travels with every export format (#33).
  - **Raven `.selections.txt`** and **CSV** add `Confirmed` (true/false) and `Confirmed At (UTC)` columns.
  - **JSON** detections always emit `confirmed`; `confirmedAt` is included only when set.
  - **GPX** waypoints for confirmed detections gain `<sym>confirmed</sym>` and a `<cmt>` note carrying the confirmation timestamp, making the flag survive trips through QGIS, GPSBabel, and Garmin tooling.

## [0.10.0] - 2026-05-06

### Added

- **Absolute timestamp display toggle.** Settings → General now lets you switch per-detection times in session review between **Relative** (offset from recording start, e.g. `00:12:34`) and **Absolute** (local clock time, e.g. `08:42:17`). Overnight surveys that cross midnight gain a `+1d` suffix so reviewers don't accidentally read tomorrow's dawn chorus as today's. Defaults to relative for backwards compatibility (#33).
- **Show seconds toggle for absolute timestamps.** When the timestamp display is set to **Absolute**, an additional **Show seconds in timestamps** switch lets you collapse `08:42:17` to the more compact `08:42` for easier scanning of long detection lists. Relative offsets always show seconds because reviewers need sub-minute precision to align with the spectrogram playhead, and exports always include seconds regardless (#33).
- **Survey Time column always present in Raven and CSV exports.** Previously the `Survey Time (s)` column only appeared when detection clips were bundled. It is now always emitted so downstream tooling sees a stable schema. When the in-app timestamp display is set to **Absolute**, the column header becomes `Survey Time (UTC)` and carries an ISO-8601 wall-clock timestamp instead of a session-relative offset, making it straightforward to correlate detections across surveys, devices, or external data sources (#33).
- **Session block in export metadata.** `<prefix>.metadata.json` (and the `meta` block in JSON exports) now carries a `session` object with the session id, type, UTC start/end times, custom name, session number, observer, transect id, and detection count, so exported bundles are self-describing without needing the original session JSON (#33).

### Changed

- **All persisted and exported timestamps are now UTC-normalized.** Detection timestamps, session start/end, GPS track points, and annotation `createdAt` values are now serialized with the `Z` suffix in JSON sessions, CSV/JSON exports, and Audacity label headers. Previous releases emitted local-time-without-zone strings, which silently shifted to the wrong instant when re-opened on a device in a different timezone. The CSV header is now `Timestamp (UTC)` to make the encoding self-documenting. Existing on-disk sessions still load correctly and continue to render with the same wall-clock values they had at capture time (#33).

### Fixed

- **Duplicate `metadata.json` entry in ZIP bundles.** A copy-paste glitch caused the metadata file to be added twice to every ZIP export. Bundles now contain a single `<prefix>.metadata.json` entry (#33).

## [0.9.9] - 2026-05-06

### Changed

- **Survey map now z-orders overlapping markers by importance.** When two detections share a spot, the more important one is now drawn on top: the highlighted detection wins outright, then audio-bearing markers cover silent ones, then higher-confidence covers lower. Previously the draw order was effectively the iteration order of the location-keyed map, so a low-confidence silent marker could obscure a high-confidence audio detection at the same position (#33).
- **Expanding the inline survey map preserves the focused detection.** When you tap a detection in the review list, the inline map centers on it; opening the fullscreen map from there now lands you on the same detection at zoom 18 instead of fitting the whole track and forcing you to find the marker again (#33).

## [0.9.8] - 2026-05-02

### Changed

- **Survey map now clusters overlapping detections.** Dense surveys used to render as an unreadable pile of pins on top of each other; species markers are now grouped into count bubbles below zoom 15, with a polygon overlay on tap so the cluster's footprint is visible. Start-flag and current-position markers stay outside the cluster layer so they're never folded into a count (#33).
- **Zoom-aware species markers.** Below zoom 14.5 the silhouette image collapses to a few unreadable pixels — markers now switch to a solid colored dot whose size and outline weight encode the confidence bucket. Zooming in past the threshold restores the full silhouette + audio play badge form.
- **Persistent map filter chip.** Added a chip overlay anchored top-right of the fullscreen survey map that shows the active filter ("All species", "≥ 50%", a species name) and opens the existing filter sheet on tap. Solves the discoverability problem in #33 where users were missing the AppBar filter icon entirely. The redundant AppBar filter icon was removed in favor of the chip.
- **Removed the blue accent ring around audio-bearing map markers.** The ring sat on top of the avatar's confidence-colored border and masked the CVD-safe ramp, so two equally-confident detections looked identical when one had audio. Audio is now signaled solely by the corner play badge, leaving the confidence color fully visible.
- **Uniform, slightly larger species markers on the map.** Audio and silent markers used to render at different bounding-box sizes (44 vs 32 px), making the map look uneven. Both now share the same box and the silhouette form is bumped 28 → 36 px (40 → 48 px when highlighted) so species photos stay legible when zoomed in.
- **Silent (no-audio) markers are now grayscale and slightly smaller (30 px vs 36 px).** Desaturating the photo lets the user tell at a glance which detections have audio without hunting for the small corner play badge, and the size offset compensates for the play-badge overhang on audio markers so audio detections no longer look visually larger inside the same bounding box.
- **Clip player sheet now uses the same `ScoreColors` ramp as the map markers.** The sheet's avatar border was still using the old hardcoded red/amber/green ramp, so the same detection looked like a different confidence level depending on whether you saw it on the map or in the playback overlay. Both surfaces now share one source of truth.
- **Silent map markers are smaller (24 px) and faded to 60 % opacity.** Shrinking them clarifies the visual hierarchy — audio detections are the primary content, silent ones are context. The opacity fade also guarantees that silent markers read as "muted" regardless of the species photo's natural hue, so a grey-plumaged bird with audio can never be mistaken for a silent marker.

## [0.9.7] - 2026-05-02

### Changed

- **Score & confidence color ramp redesigned for color-vision-deficient viewers.** Replaced the Material red/orange/amber/green palette (whose buckets all sat at similar lightness) with a CVD-safe ramp where lightness changes monotonically across buckets — light → dark on light theme, dim → bright on dark theme. The ramp now stays unambiguous when simulated for protan/deutan/tritan vision because the lightness gradient survives even when hue collapses (#33, thanks @LimitlessGreen).
- **Survey map markers now scale outline weight with confidence** (1.5 px for very-low up to 3.5 px for very-high), so the strength of a detection is readable from the marker geometry alone in monochrome or in CVD simulation.
- **Eliminated the duplicate Explore color ramp.** `probabilityCategoryColor` now routes through the unified `ScoreColors` theme extension, so every confidence/likelihood badge across Live, Survey, Explore, and File Analysis shares the same palette and any future tweak lands in one place.

## [0.9.6] - 2026-05-02

### Changed

- **Grayscale spectrogram colormap inverted: white now means quiet, black means loud.** Matches Audacity, Raven, Sonic Visualiser, matplotlib's `gray_r`, and printed sonograms in field guides. Quiet background reads as paper-white instead of a black wall, so the spectrogram is legible on light themes and exports cleanly to print (#33).

## [0.9.5] - 2026-05-02

### Fixed

- **External link chips (eBird, iNaturalist, Wikipedia, About-screen links) now open reliably on Android 11+** (#34). Under Android 11+ package-visibility rules, `canLaunchUrl` returns `false` for an `https`/`mailto` intent unless the app's manifest declares an `<intent>` query for `ACTION_VIEW` with that scheme. The previous `if (await canLaunchUrl(uri)) launchUrl(uri)` pattern silently no-op'd on devices where Android hid the user's browser from the visibility query (reported on a Pixel 9 Pro running Android 16). The manifest now declares `ACTION_VIEW` queries for `http`, `https`, and `mailto`, and the call sites use a new `openExternalUrl` helper that drops the `canLaunchUrl` probe entirely and falls back to copying the URL to the clipboard with a SnackBar message if launching genuinely fails (no browser installed at all).

## [0.9.4] - 2026-05-02

### Fixed

- **Wikipedia link now always appears on species cards.** Previously the Wikipedia chip in the species info overlay was hidden when the bundled `taxonomy.csv` had no entry for the user's locale, leaving non-English users without a link even though an English page almost always exists. The chip now follows a three-step fallback: locale-specific bundled URL → English bundled URL → constructed `https://en.wikipedia.org/wiki/<Genus_species>` from the scientific name. The chip is now always visible whenever species details load (part of #33).

## [0.9.3] - 2026-05-02

### Fixed

- **Play Store installs failed to load the audio model.** The 0.9.2 AAB published to Google Play shipped the ONNX models in an install-time Play Asset Delivery pack (`models_pack`) and the runtime resolver looked them up via `AssetPackManager.getPackLocation()`. That API returns `null` for install-time packs by design — install-time packs are merged into the app's standard `AssetManager` namespace instead. The base module had its `.onnx` files stripped to keep the upload under Play's 200 MB limit, so the rootBundle fallback also failed and Live Mode showed "Model loading failed. Check assets." Resolution now extracts the model bytes via the platform `AssetManager` (which surfaces install-time pack files) and only falls back to `rootBundle` for true sideload APK installs. Sideload APK behavior is unchanged.

## [0.9.2] - 2026-05-02

### Fixed

- **Survey notifications now show common names.** The foreground notification's recent-detections list previously rendered scientific binomials (e.g. *Turdus merula*); it now always shows localized common names in the user's species locale, regardless of the in-app "show scientific names" toggle. Latin names are hard to read at-a-glance on a lock screen.
- **Audio watchdog no longer fights other apps for the microphone.** When another app (e.g. an audiobook player or voice recorder) holds the mic, the watchdog used to restart capture every 2 seconds, interrupting the other app's audio. After three failed restart attempts the watchdog now backs off for 30 seconds and surfaces a "⚠ Microphone in use by another app — audio paused" status line in the survey foreground notification, so users understand why audio appears frozen (fixes #29).
- **Exit Survey modal pile-up.** Tapping the foreground-notification "Stop" button multiple times while the app was in the background pushed a new "Exit Survey" confirmation dialog onto the route stack each time. The screen now guards against duplicate dialogs (fixes #29).

## [0.9.1] - 2026-05-01

### Added

- **CI/CD Workflow Improvements.** Added build workflow, including manual triggers, non-fatal info reporting, and specifying the `l10n` output path to improve CI stability.

### Changed

- **Survey map species filter floor lowered.** The minimum confidence slider in the fullscreen survey trace map now starts at 10% instead of 50%. The map again renders all detections by default when set to "All species".
- **Compact session review header.** Survey track ID is now displayed on the same row as distance and observer name to free up vertical screen space.
- Unspecified Flutter version constraints to improve compatibility and updated Gradle configurations.

### Fixed

- **Audio recording freezes.** Implemented a watchdog timer to detect audio stream stalls (e.g., when an external app takes microphone focus on Android) and automatically restarts the microphone, fixing silent audio and spectrogram freezes (fixes #29).
- **Species filter hidden by keyboard.** The fullscreen survey map filter sheet now safely pads itself from the bottom so the search bar and species suggestions are not concealed by the on-screen keyboard.
- Various build and CI fixes including Android signing config guard for release builds, GitHub actions paths, secrets checks, and deprecated API usages.
- Radio buttons fix and test configuration refactoring.

## [0.9.0] - 2026-04-29

### Changed

- **ONNX runtime swapped for Play Store 16 KB page-size compliance.** Replaced the unmaintained `onnxruntime ^1.4.1` package (gtbluesky, FFI-based, ships ORT 1.15 with 4 KB-aligned `libonnxruntime.so`) with the actively-maintained `flutter_onnxruntime ^1.7.0` package (masicai, MethodChannel-based, ships ORT 1.22 with 16 KB-aligned native libraries since 1.5.1). Verified `libonnxruntime.so` and `libonnxruntime4j_jni.so` in the release App Bundle now report `p_align = 0x4000` (16 KB) in their ELF LOAD program headers, satisfying Google Play's 16 KB memory-page-size requirement on Android 15+ devices.
- **Inference architecture simplified.** The audio classifier no longer runs in a Dart background isolate. The new runtime plugin uses a Kotlin/Java `BackgroundTaskQueue` to run native ONNX inference off the platform thread, so the UI stays responsive without an isolate hop. The `InferenceIsolate` wrapper preserves its public API (`start`, `stop`, `infer`, `resetPooling`, `setMaxPoolWindows`, `isRunning`) but now delegates to `InferenceService` directly on the root isolate. This removes a class of message-passing bugs and reduces memory overhead.
- **Flutter SDK upgraded to 3.41.8 (Dart 3.11.5)** to satisfy the new runtime plugin's Dart 3.7 minimum. Kotlin Gradle plugin bumped from 1.9.22 to 2.1.0.
- All `GeoModel.predict`, `GeoModel.predictAllWeeks`, `GeoModel.expectedSpecies`, and `GeoModel.geoScoresForFilter` calls are now `async` (the new runtime exposes only async APIs). All call sites updated.

## [0.8.3] - 2026-04-30

### Added

- **Background-location privacy notice in Survey setup.** When the user selects **GPS** as the location source on the Survey Details step *and* has already granted the background-location permission, a green disclosure card now appears under the GPS coordinates explaining that "during the survey, your GPS location is tracked in the background to map species detections along your path. No location data is shared — everything stays on your device." This satisfies Google Play's policy requirement to disclose background-location usage prominently in the in-app flow that triggers it. The existing tertiary-container "permission not yet granted" prompt is unchanged and continues to be shown when the permission is missing; the green notice only appears once the user has opted in. Translated to all seven supported locales (en, de, es, fr, it, pt, cs).

## [0.8.2] - 2026-04-30

### Fixed

- **Explore taxonomic group filter (Birds / Mammals / Amphibians / Insects) was a silent no-op.** The chips in the combined sort & filter bottom sheet appeared to do nothing when toggled. Root cause was a closure-reuse bug in the sheet's local `update(fn)` helper, which invoked the same mutation closure twice (once on the sheet's `setState` and once on the host screen's `setState`) — for a toggle pattern like `if (!_groups.add(g)) _groups.remove(g)`, the first call added the value and the second immediately removed it, leaving the set unchanged. The toggle and clear actions now mutate the set exactly once and trigger both rebuilds via an empty `update(() {})` call.

### Changed

- **Onboarding screens — better screen-space distribution.** The 5-page first-run wizard now follows established onboarding-UX patterns instead of stretching content edge-to-edge:
  - **Reading width is capped at 520 dp** on every page via `ContentWidthConstraint`, so paragraphs stay scannable on tablets and in landscape rather than spanning the full screen width.
  - **Hero icons are larger and more prominent.** The Welcome page's app icon grew from 72 → 112 dp; "How It Works", "Features", "Permissions", and "Terms" pages now use an 88 dp hero icon container (up from 44 dp) with the icon scaled proportionally.
  - **Type scale bumped one step.** Page titles use `headlineSmall` / `headlineMedium` (was `titleLarge` / `headlineSmall`) and body copy uses `bodyLarge` with `height: 1.5` line spacing (was `bodyMedium`), making the text noticeably easier to read on phones and tablets alike.
  - **More generous vertical rhythm** between hero, title, body, and lists; the Welcome page is vertically centered with weighted spacers so it doesn't feel top-heavy.
  - The bottom controls bar now uses a 50 dp primary button with slightly larger page-indicator dots and is also constrained to the same reading width, so the call-to-action doesn't stretch across the full width on tablets.

## [0.8.1] - 2026-04-30

### Fixed

- **Consistent spacing between dark and light themes.** The light theme was missing several component-level theme overrides (`ListTileThemeData`, `DialogThemeData`, `SwitchThemeData`, `SliderThemeData`, `TextButtonThemeData`, `DividerThemeData`, `SnackBarThemeData`) that the dark theme defined, so toggling brightness caused those widgets to fall back to Material 3 defaults with different padding — most visibly on Settings, Session Library, and Session Review where ListTile rows changed height. The structural (non-color) `ListTile` theme is now factored into a shared helper applied by both themes, and the remaining missing component themes have been mirrored into the light theme with light-appropriate colors.

## [0.8.0] - 2026-04-30

### Added

- **Combined sort & filter overlay on Explore.** The AppBar's filter button now opens a bottom sheet (matching the pattern used in the session library) that combines three independent controls: a **sort mode** (Likelihood here / A–Z / Z–A), a **detection-status filter** (All species / Already detected / Not yet detected), and the existing **multi-select taxonomic group filter** (Birds, Mammals, Amphibians, Insects). Group filtering is now multi-select rather than a single chip, and the AppBar shows a small primary-color dot whenever any non-default option is active.
- **Help screen — narrative reorganization.** The Help screen has been restructured to follow a top-to-bottom usage narrative with three new section headers: **What you can do** (Live → Point Count → Survey → File Analysis), **Discover & revisit** (Explore, Sessions), and **Common Controls** (Settings, Help, About). The previous duplicate listing of Explore and Sessions as both control-cards and full sections has been removed.

### Changed

- **Explore: help and refresh icon positions swapped.** The AppBar now exposes the **help** action (where refresh used to live), since the Explore screen has the most context-specific help content of any screen in the app. The **refresh** action moved into the location header, immediately next to the location indicator — that is what it actually re-queries (the user's GPS fix and derived geo-model species list), so co-locating the two is more discoverable.

### Fixed

- **Audio trim no longer drops detections that span trim boundaries.** Previously, applying a trim in Session Review removed any detection whose `timestamp` fell outside the trim window — so a 3-second detection that started 1 second before the trim end would disappear entirely. The trim logic now keeps any detection whose `[start, end]` interval overlaps the trim window and clamps partial-overlap intervals to the visible range, preserving detections that span the cut points.
- **Session library file size now reflects the active trim.** The size chip on session cards used to always report the raw audio file's on-disk bytes, which was misleading after the user trimmed a long recording down to a few seconds. The displayed size is now scaled by the trim ratio `(trimEnd − trimStart) / fullDuration` so it reflects what would actually be exported. The audio file itself is left untouched on disk so the trim remains fully reversible.

### Removed

- **"Developer preview" labels.** The "(Developer preview)" subtitle on the Home screen, the warning card on the About screen, and the equivalent note in the README have been removed now that the app is stable enough for general use. The note in the README now points users toward the issue tracker for any rough edges they encounter.

### Internal

- **Verified the Play Asset Delivery refactor is iOS / desktop safe.** `AssetPackService` short-circuits the Android-only platform-channel path on every other platform and falls through to the existing `rootBundle.load` extraction, so Xcode iOS / macOS builds and the desktop sideload paths bundle the ONNX models from `assets/models/` exactly as before. The Play Asset Delivery split only affects Android Play Store builds.

## [0.7.15] - 2026-04-29

### Changed

- **Play Asset Delivery for ONNX models on Android.** The two large `.onnx` model files (~152 MB audio classifier + ~6 MB geo model) are now shipped via an install-time Play Asset Delivery pack (`models_pack`) instead of being bundled inside the base module. This keeps the base AAB comfortably under Google Play's 200 MB compressed download limit while still being fully offline — the pack is downloaded together with the app at install time and unpacked to disk. Sideload APK builds (GitHub releases) are unaffected: the models continue to live in `flutter_assets` and are extracted to the app documents directory on first launch exactly as before.
- **Centralized model file resolution.** A new `AssetPackService` transparently resolves each model file from either the asset pack (Play Store builds) or `rootBundle` extraction (sideload builds). All four model-loading call sites (Live, Survey, File Analysis, Explore geo-model) now go through this single resolver, removing duplicated extraction logic.

## [0.7.14] - 2026-04-27

### Fixed

- **"Detected" checkmark badges in Explore now reflect every saved session.** The previous fix made the badge provider reactive but it was still reading from the wrong store: `GlobalSpeciesHistory` is only mutated by the Survey alert engine, so detections from Live, Point Count, and File Analysis sessions never produced a checkmark. The Explore badges (both the corner check on thumbnails and the larger badge over the species photo in the info overlay) now derive their "already detected" set directly from the saved session list, so any detection from any mode lights up the badge — and the badges refresh automatically when sessions are saved or deleted.

## [0.7.13] - 2026-04-27

### Fixed

- **"Detected" checkmark badges in Explore now appear immediately.** The corner checkmark on species cards and the larger badge on the species photo in the info overlay used to lag behind reality — newly logged species would only show their badge after navigating away from Explore and back, sometimes requiring multiple refreshes. The underlying `GlobalSpeciesHistory` is now a `ChangeNotifier` exposed via `ChangeNotifierProvider`, so any widget watching it rebuilds the moment a species is added (or the one-time backfill seed completes on first launch of v0.7.0+).

## [0.7.12] - 2026-04-27

### Added

- **"New session" shortcut in the Session Library.** A floating action button in the lower-right of the Session Library lets you start a new session in one tap without going back to the home screen — handy right after closing a session review when you want to keep recording. The button defaults to Live mode; tap the small chevron (or long-press the button) to open a sheet listing all four modes (Live, Point Count, Survey, File analysis) with their descriptions. Picking a different mode both starts that session immediately and remembers it as the new default for next time, so frequent users converge on a single-tap workflow.

## [0.7.11] - 2026-04-27

### Added

- **Score-pooling window count is now configurable.** A new slider under *Settings → Inference → Score pooling* (1–10, default 5) controls how many recent inference windows the temporal pooling buffer averages over before declaring a detection. Lower values react faster to fleeting calls; higher values smooth out spurious noise spikes at the cost of a slightly delayed first-detection. The setting is plumbed all the way through to the inference isolate (`InferenceIsolate.setMaxPoolWindows`) and applied at the start of every Live, Point Count, and Survey session — including resumed Surveys.
- **"You have detected this species" stats in the species info overlay.** Tapping a species card in Explore now shows, alongside the photo and 48-week probability chart, a personal summary aggregated from your saved sessions: how many times you've logged the species, across how many sessions, and the date of your most recent detection. The summary is hidden for species you've never recorded so the overlay stays uncluttered for unfamiliar birds.
- **Checkmark badge on previously detected species.** Species you've detected at least once in any saved session now show a small primary-colored check badge in the corner of the photo — both on Explore cards and on the larger image inside the species info overlay. Makes it easy to skim Explore and spot which birds are new to your personal life list versus already logged.
- **A–Z (and Z–A) sort in Session Library by-species view.** The by-species grouping now respects the *Sort* selector: choosing *Name (A–Z)* or *Name (Z–A)* alphabetizes species rows by their localized display name (with scientific-name tiebreak); the date sort modes preserve the existing "most-detected first" ordering. The species search field also now filters the by-species view, with an empty-state message when no species match the query.
- **Help icons on Session Library filter sections.** Each labeled section (*Sort*, *View*, *Filter*) in the filter sheet now has a small help icon explaining what that section does.

### Changed

- **Application ID changed to `de.tu_chemnitz.mi.kahst.birdnet_live`.** The Android `applicationId` was bumped from the placeholder `com.birdnet.birdnet_live` to a stable, namespaced identifier suitable for Play Store publication. The Kotlin `namespace` is unchanged so existing builds keep compiling.
- **Sort / view / filter selectors in the Session Library are now combinable.** Picking a sort order no longer resets the view mode or active filters, and vice versa — the three controls are independent.
- **Session Library view-mode chip now highlights immediately.** Tapping *Compact*, *Detailed*, or *By species* updates the chip selection synchronously in the bottom sheet instead of waiting for the SharedPreferences write to complete, so the highlight follows the tap with no perceived lag.

### Fixed

- **Segment label overflow in Session Library filter sheet.** Long localized labels (e.g. *By species* in some locales) no longer push the segmented control out of its container.
- **Recording format / size selector hidden when audio recording is off.** When *Save full recording* is disabled in settings, the format and size sliders are now hidden instead of grayed-out, removing dead UI from the screen.
- **Session size estimation in the home screen.** The "estimated size" label on the live mode card now reflects the active recording format and bitrate.

## [0.7.10] - 2026-04-26

### Fixed

- **Explore species cards no longer crop the edges of the photo.** The card's row was stretching every tile to a uniform height, which made the thumbnail box slightly taller than its native 3:2 ratio. With `BoxFit.cover` the image was being scaled up to fill that extra height and a slice was getting cut off the sides. The thumbnail is now sized to its natural 3:2 ratio (96×64) and centered vertically in the row, so the whole bird is visible while the card's rounded corners on the left still hug the photo.

## [0.7.9] - 2026-04-26

### Added

- **Inference Parameters step in the Point Count setup wizard.** Point Count now has a fourth setup step — between *Duration & Context* and *Field Tips* — that lets you tweak window duration (3 / 5 / 10 s), inference rate (0.25–4 Hz), confidence threshold (1–99 %) and species filter mode just for that one count, without touching your global defaults. Values are seeded from your global settings so the default behavior is unchanged; tweaking them only affects the count you're about to start. Mirrors the same parameters page that File Analysis already exposes, but with an *inference rate* slider instead of *overlap* (since live inference is rate-driven, not overlap-driven).
- **Per-mode icon colors throughout the app.** Each mode now has its own accent color applied to its icon — red for Live (recording), blue for Point Count (a fixed pin), green for Survey (a route), and amber for File Analysis (an archived file). The color shows up everywhere the mode icon appears: the home menu cards, the Help screen sections, and Session Library cards / list rows / species-grouped sub-rows. Tile and card backgrounds are deliberately untouched — only the glyph itself is tinted, so the surrounding layout stays calm and you can recognize a mode at a glance without the screen feeling busier. Centralized in `shared/utils/session_type_visuals.dart` so the home, help, and history surfaces can never drift apart again.

### Changed

- **Session Library: three-dot menu replaced with a single, well-organized filter sheet.** The cluttered toolbar dropdown is gone — there's now a single :material-filter-list-outlined: button that opens a clean modal bottom sheet with three labeled sections (*Sort*, *View*, *Filter*) using chip selectors. Same options as before, but the relationship between sort order, view mode, and filter is finally visible at a glance, and the sheet opens in the natural place for a touch (bottom of the screen) instead of cascading off the right edge.
- **Session Library view mode (Compact / Detailed / By species) now persists across app restarts.** Picking *By species* once will keep the library in that view the next time you open it, instead of snapping back to *Compact* on every cold start.
- **Bundled species photos now show the full, un-distorted bird.** Auditing the BirdNET taxonomy API turned up that *both* the `medium` (480×320) and `thumb` (150×100) responses are 3:2 — not 4:3 as we'd assumed. Our build pipeline was resizing every photo to 320×240 (4:3), which silently squashed every bird vertically. The bundle is now built at 360×240 (true 3:2) at higher WebP quality (`82` instead of `75`, with `method=6` for best compression effort), and `process_image()` letterboxes any non-3:2 source instead of stretching it. Every in-app species frame (Explore card, info overlay, Live detection list, Session Review thumbnail, Session Library species rows) was switched to a matching 3:2 box so what you see in the app is now exactly the photo the BirdNET team curated. The species-image asset bundle grows from ~44 MB to ~60 MB; the release APK gains a few MB but the photos finally look right.

## [0.7.8] - 2026-04-26

### Changed

- **About screen: audio model and geo-model now share a single card.** Each model still gets its own labeled section (display name only), with the species count printed once at the bottom — it's the same 5,250-species intersection for both. The narrative description under the geo-model is gone; the section header already conveys what it is.

## [0.7.7] - 2026-04-26

### Added

- **Tap a species thumbnail in Session Review to open its info overlay.** The 48 dp thumbnail next to each species row in Session Review is now its own tap target — long-pressing the row still works, but the photo itself is the more discoverable shortcut to the full species sheet (description, photo credit, links).

### Fixed

- **Species photos no longer cropped vertically in the info overlay.** The overlay was rendering bundled photos in a 3:2 frame with `BoxFit.cover`, which sliced off the top and bottom of every 320×240 thumbnail. The frame is now 4:3 and uses `BoxFit.contain`, so the full photo — the same crop the BirdNET team curated — is always visible.
- **Inline species thumbnails now match the bundled photo aspect ratio.** Session Review (48×36) and the live detection list (60×45) used 3:2 boxes that quietly cropped a slice off every photo. Both are now 4:3, matching the 320×240 source files, so each photo is shown in full without distortion. The Explore species cards switched to the same 4:3 frame for consistency.

## [0.7.6] - 2026-04-26

### Fixed

- **Survey track map filter now localizes species names.** The species picker in the fullscreen map's filter sheet was showing the raw English common name baked into each detection record and always italicized the scientific name underneath, ignoring both the *Species names* language setting and the *Show scientific names* toggle. Names now go through the taxonomy lookup like everywhere else in the app, so they appear in your chosen species locale, and scientific names only show when you've turned them on in Settings.
- **High-confidence filter is now an actual slider.** The previous "High confidence (≥80 %)" preset did nothing for sessions whose detection threshold was already at or above 80 %. The filter sheet now has a *Minimum confidence* slider (50 % – 99 %) that you can drag to whatever floor makes sense for the session, with a live percentage readout.

### Changed

- **Cleaner species picker in the map filter sheet.** The long radio-list of species has been replaced with a search field plus a tap-to-select list using check-circle icons. Typing into the search field filters the list against both the localized common name and the scientific name, and an *All species* row at the top makes clearing the species filter a single tap.

## [0.7.5] - 2026-04-26

### Added

- **Filter button on the fullscreen survey track map.** The map's app bar now has a :material-filter-list-outlined: button that opens a filter sheet for restricting which detection markers are drawn. Filter modes are *All detections*, *With audio clip* (only markers whose clip is still on disk), *High confidence* (≥80 %), and *Manual additions* (only the ones you added in Session Review). A *Limit to species* picker lets you collapse the map to a single species — useful for asking "where exactly along the route did I hear the wood thrush?". The two filters combine, an active filter shows a dot on the icon and a match-count subtitle in the app bar, and an *Empty filter* card appears at the bottom of the map when nothing matches.
- **Funding card on the About screen.** Acknowledges support for BirdNET Live development by the Deutsche Bundesstiftung Umwelt through the project RangerSound (project 39263/01).

### Changed

- **Onboarding screens use vertical space more carefully.** The icon-only top half is gone — every page now starts its body copy near the top of the safe area instead of at the vertical center, so the Terms-Of-Use page no longer overflows on smaller phones. Hero icons are smaller (44 dp instead of 56 dp), spacings are tighter, and the bottom controls bar is more compact.
- **The "Credits" card on the About screen is now titled "Developed by"** in every locale, since the card just names the BirdNET development team and never actually thanked anyone.

## [0.7.4] - 2026-04-25

### Changed

- **Survey notification is now fully translated.** The recent-detections list, stats footer (elapsed time / detections / species / distance), and notification title now all honor the user's selected app locale instead of mixing English fragments. Species names are also resolved lazily on each notification refresh, so they start translating as soon as the taxonomy service finishes loading even if it loads after survey start.
- **Recent-detections list deduplicates by species.** A chatty bird no longer fills all three slots — the list now shows the three most-recent *unique* species instead.
- **Recent detections appear above the stats footer**, separated by a blank line, so the most actionable information (what was just heard) sits at the top of the expanded notification.

### Added

- `surveyNotificationStats` ARB key with `{elapsed}` / `{detections}` / `{species}` / `{distanceKm}` placeholders so each locale can adjust unit ordering, abbreviations, and pluralization for the stats footer.

## [0.7.3] - 2026-04-25

### Changed

- **The persistent survey notification now lists the three most recent detections**, each on its own line with the localized common name, confidence percentage, and a short relative timestamp (`just now`, `42s ago`, `5m ago`, `2h ago`). On Android the lines are visible as soon as the notification is expanded thanks to the underlying BigTextStyle, so you can glance at the lock screen mid-survey and see what's been heard most recently without unlocking the phone. Species names honor the user's species locale and the *Show scientific names* toggle, identical to the in-app cards.

### Added

- New ARB keys `surveySecondsAgo` and `surveyHoursAgo` (paired with the existing `surveyJustNow` / `surveyMinutesAgo`) so the relative timestamps in the notification render naturally in every supported language (en/de/cs/es/fr/it/pt).

## [0.7.2] - 2026-04-25

### Changed

- **Watchlist editor is now a real species picker.** Replaced the cramped paste-the-scientific-names dialog with a full-screen editor: a search field on top scans the entire taxonomy (matches scientific name, English common name, and every localized common name) and shows tappable checkbox results, while an *Import from file* button reads any `.txt`/`.csv` plain-text list of scientific names from device storage. The selected-species pane stays visible when you clear the search so it's obvious what's already in the list, and selections survive locale switches because friendly labels are cached at pick time.
- **Survey alert notifications now use a monochrome blue-jay icon** instead of a white square. Switched both `SpeciesAlertNotifier.init` and `requestPermission` to the existing `ic_notification` drawable that the foreground-service notification already uses, so the heads-up alert visually matches the persistent recording notification.
- **Cleaner alert text.** Notifications no longer repeat the species name twice (title and body both said it). The body is now just the reason — *"First detection of this survey"*, *"On your watchlist"*, *"Detected at this location with under 4% likelihood"*, etc. — keeping the species name in the bold notification title where Android renders it largest.
- **Localized notifications work end-to-end.** When the app delivers a species alert it now uses the user's selected species locale (and respects the *Show scientific names* toggle), so a German user sees *Kohlmeise* in the notification instead of *Great Tit*. The localizer plumbs through `SurveyAlertCoordinator` so it stays correct across coalesced summary alerts too.
- **German wording fix.** *Erkennung* in the alert bodies is now *Detektion*, matching the term used everywhere else in the German UI.

## [0.7.1] - 2026-04-25

### Changed

- **Species-alerts wizard step is now a real, finished UX.** The setup screen for the new push alerts has been rebuilt: a *Minimum confidence* slider sits below the mode picker and is automatically floored to your session confidence threshold (alerts can never be more sensitive than the detections themselves). The advanced *Frequency control* section now uses one-tap chip selectors for startup grace (Off / 30 s / 1 m / 2 m / 5 m), minimum interval (Off / 5 / 15 / 30 / 60 s) and per-minute cap (1 / 3 / 5 / 10 / Unlimited) instead of free-form integer text fields. The rare-species slider gained a live readout — *"Alerts on species with under 5 % likelihood at this location."* — so you understand what the slider position will actually do before you start the survey. A help button in the step header opens an in-context bottom sheet explaining the alert modes and the throttling rules.
- **Watchlist creation and management directly in the wizard.** Previously the Watchlist alert mode was a dead end if you hadn't already created a list — and there was no way *anywhere* in the app to create one. The wizard now lists all saved watchlists as selectable tiles with a species count, lets you delete lists with a confirmation dialog, and exposes a *New watchlist* button that opens an inline editor for naming a list and pasting a block of scientific names (one per line) straight from your clipboard. Picking Watchlist mode without selecting a list now blocks the Next button with a clear inline error.

### Added

- **Notification-permission prompt on mode change.** Picking any non-Off alert mode in the wizard now triggers the Android notification-permission request the first time it's needed, so you don't have to remember to grant it from system settings before alerts can fire.

## [0.7.0] - 2026-04-25

### Added

- **Push-style species alerts during surveys.** A new step in the survey setup wizard lets you choose when to receive a heads-up notification mid-survey: *Off* (default), *First in session* (one alert the first time each species is heard), *First ever* (alert only when the app encounters a species for the very first time across all your sessions — a "lifer" alert), *Rare for this location* (alert when the geo-model probability for the current location is below a configurable threshold, so a Black-throated Sparrow showing up in Bavaria gets your attention), or *Watchlist* (alert only on species you've added to a saved custom list). Alerts respect a configurable confidence floor and fire on a separate Android notification channel so you can mute them independently of the silent ongoing survey-recording notification.
- **Smart frequency control for alerts.** Real surveys often see a flurry of new species in the first few minutes — without throttling, the device would buzz constantly. The pipeline now applies three layered limits: a startup grace window (default 60 s) that suppresses *first-in-session* alerts at the start of a survey while still letting rare/watchlist alerts fire immediately, a hard minimum interval between any two alerts (default 15 s), and a sliding per-minute cap (default 3) with optional coalescing — over-cap alerts queue into a single summary notification ("3 more new species: ...") instead of being dropped. All limits are user-configurable from an *Advanced* section in the wizard.
- **Lifetime species history**, persisted in app preferences, powers the *First ever* mode. On first launch after upgrading, the app backfills the history from your existing session records so the very first survey under 0.7.0 doesn't fire a "lifer" for every common species you've already recorded.

## [0.6.9] - 2026-04-24

### Added

- **Every session export now ships with full provenance metadata.** ZIP bundles always include a `<prefix>.metadata.json` side-file alongside the audio and selection table, and JSON exports gain a top-level `meta` block. The metadata captures the app version and build number, the audio and geo model names/versions from `model_config.json`, the species locale used to localize labels, the export timestamp (UTC), and a verbatim snapshot of every SharedPreferences setting at the moment of export. This makes exports self-describing — an analyst opening a survey ZIP months later (or receiving one from another recordist) can answer exactly which app version, which model, and which user settings produced the detections without having to ask. Critical for scientific reproducibility, especially when sharing survey data between researchers.

## [0.6.8] - 2026-04-24

### Fixed

- **Survey selection-table exports for sessions started before 0.6.7 now report correct in-clip detection times.** Those sessions were saved without a `clipContextSeconds` value (the field didn't exist yet), so the exporter assumed 0 seconds of pre-roll and printed `Begin Time = 0.000 / End Time = 3.000` for every clip — placing the Raven selection box at the very start of each clip even when the actual call sat 1–2 seconds in. The exporter now falls back to the device's current Survey “Clip Context” setting whenever a session has clip files but no recorded context value, so legacy bundles produce the same selections as freshly recorded ones.

## [0.6.7] - 2026-04-24

### Changed

- **Session exports now use localized common names everywhere they're rendered as text.** Clip filenames inside the ZIP bundle (e.g. `…_clip_001_Amsel.flac` for a German user instead of `…_clip_001_Eurasian_Blackbird.flac`), the `Common Name` column in Raven selection tables, and the `Common Name` column in CSV exports all use the user's species locale. Scientific Name columns are always emitted regardless of the "Show scientific names" UI toggle so exports remain scientifically authoritative.
- **Survey selection tables now report in-clip detection times.** Previously, `Begin Time (s)` / `End Time (s)` were session-relative offsets even for rows referencing per-detection clip files — which made Raven Pro draw the selection box at the wrong place inside the clip (or off the end entirely). Now those columns describe the detection's offset *within the clip file* (i.e. they bracket the model's window after the pre-roll context). A new `Survey Time (s)` column carries the original session-relative offset so analysts can still cross-reference detections against the survey timeline. The CSV export gains the same `Survey Time (s)` column when clip files are present. For sessions exporting a single continuous recording, behavior is unchanged.

## [0.6.6] - 2026-04-24

### Added

- **Session library cards now show on-disk audio size** as a fourth stat chip. The value is the total of the continuous recording (live, point count, file analysis) plus all per-detection clips (survey), so you can spot heavy sessions at a glance before exporting or deleting. Sessions with no audio on disk silently omit the chip.

### Fixed

- **Species names are now localized and respect the "Show scientific names" setting in every place a detection is rendered.** The fullscreen survey-map clip-player sheet showed the English common name and always the sci name; the survey live-screen summary species list, the session library's grouped-by-species view subtitles, and the add/replace-species overlay banner + result tiles had the same gaps. All of them now go through the taxonomy lookup with the active species locale and hide the sci name when the setting is off.

## [0.6.5] - 2026-04-24

### Fixed

- **Detections recorded before the audio recorder fully spun up no longer have broken "00:-1" timestamps.** Session-relative offsets are now clamped to `[00:00, audio duration]` both at storage time (in `LiveSession.addDetection(s)`) and at render/seek time, so these detections display sensibly and play back from a valid position instead of silently failing.

## [0.6.4] - 2026-04-23

### Changed

- **Onboarding flow rewritten end-to-end.** Replaced the `introduction_screen` package + separate Terms-Of-Use gate (which prompted for ToU twice) with a single custom PageView wizard. Pages now use a compact icon badge instead of an oversized centered icon, giving body text the screen real estate it deserves. The Permissions page is now interactive — tapping Grant on Microphone or Location triggers the actual OS prompt (via `record` and `geolocator`) and shows a green check on success. Terms & Privacy is the final page with an inline "I agree" checkbox; Get Started is disabled until checked, and on finish both `onboardingComplete` and `termsAccepted` are persisted in one shot. Skip jumps directly to the Terms page rather than bypassing acceptance.

### Removed

- `introduction_screen` dependency (no longer needed) and the standalone `TermsGateScreen` (its role is folded into the onboarding flow).

## [0.6.3] - 2026-04-23

### Changed

- **Explore screen header decluttered** — the search bar and group-filter chip row are now hidden by default. Tap the AppBar lens icon to slide in the search field, or the filter icon to reveal the chip row. A small dot on the filter icon indicates when a non-default group filter is active. Toggling one collapses the other so only one control is visible at a time.

## [0.6.2] - 2026-04-23

### Added

- **Explore screen species search** — search field at the top of the Explore screen runs over the full audio-model species list, not only the geo-filtered subset. Matches are split into "At your location" and "Other species" sections so distant species (e.g. Blue Jay or Gray Wolf in Europe) can still be opened to view their info card.
- **Explore taxonomic group filter** — horizontal chip row to restrict the list to All / Birds / Mammals / Amphibians / Insects. Filter applies to both the geo-likely list and the search results.

## [0.6.1] - 2026-04-23

### Fixed

- **Session review species search** — search now matches localized common names (German, French, Spanish, Czech, Italian, Portuguese), not only English. Results are ranked by text relevance: full-string prefix > word prefix > substring, with observation count as a tie-breaker. Geo-likely species are softly boosted but never demoted from a strong text match.
- **Multi-token search** — typing multiple words (e.g. "barn owl") now correctly matches species containing all tokens in any order.

### Changed

- **Add/Replace species overlay redesign** — when invoked from "Replace this detection" on a specific cluster, the picker now shows a banner with the detection being replaced (thumbnail, common name, scientific name) and skips the redundant mode selector and dropdown — the user only chooses the new species.
- **Add species (FAB)** — defaults to "Insert at playback position" (the more useful mode) and drops the unused "Replace" segment from this entry path.
- **Result tiles** include a 48×48 species thumbnail.
- **Empty / no-result states** — clear hint when the search field is empty (with "Unknown / Other" surfaced as a quick action) and a friendly "no results" message when nothing matches.

## [0.6.0] - 2026-04-23

### Added
- Spectrogram render quality is now user-configurable (Low / Medium / High) under Settings → Spectrogram, with High as the default for sharp live spectrograms and Low as a fallback for older phones
- Survey foreground notification now uses a monochrome blue jay silhouette as the status-bar small icon instead of a generic circle
- Species info overlay opens to the user's locale Wikipedia page when bundled (interface locales: en, de, fr, es, cs, pt, it), falling back to English

### Changed
- Default visible spectrogram duration raised from 15 s to 20 s for a wider live view
- Live and Point Count spectrograms render with the configured filter quality (was hardcoded low) for noticeably crisper detail when upscaled
- Session review spectrogram now uses FFT 2048 + high filter quality for sharper detection-clip previews
- Live mode keeps the recording running across pause so audio and detection timestamps remain continuous; detections are now timestamped at the start of the analyzed window for accurate review playback
- Recording capture uses a unified clip-context setting and now captures true pre+post audio around each detection
- Survey detection markers only show the play badge when the audio clip actually exists on disk; markers gain a stronger audio affordance (accent ring, larger badge, gray border for silent markers)
- Tapping the active play button in session review now pauses playback (works for both Live and Survey clips)
- Species info overlay now uses fully bundled taxonomy data — eBird link is shown only when an `ebird_code` exists (insects and other non-birds correctly hide it), iNaturalist only when an `inat_id` exists, and Wikipedia only when a bundled URL exists for the active locale
- eBird link chip uses the Cornell Lab sapsucker silhouette as its icon
- German UI uses "Detektion" / "Detektionen" instead of "Erkennung" / "Erkennungen" throughout for clearer detection terminology

### Fixed
- Survey detection clip player honors the pause toggle (previously kept playing when tapping the active play button)

### Privacy / Hardening
- Verified the app makes no network calls beyond OSM map tiles and OSM Nominatim reverse geocoding (both gated by a single one-time consent); no taxonomy API, no analytics, no telemetry
- Removed the unused `cached_network_image` dependency and dead taxonomy-API URL helpers (`thumbUrl` / `mediumUrl` getters and the static API base URL) so future code cannot accidentally reintroduce taxonomy-API fetches

## [0.5.4] - 2026-04-22

### Added
- Survey map markers now show a small play badge on detections whose audio clip was retained, making it visually obvious which icons can be played back
- Tapping a marker with audio opens a modal player overlay with a spectrogram preview, scrubber, and play/pause controls (replaces the old silent in-place playback)

### Changed
- Smart sampling: same-spot distance threshold reduced from 500 m to 250 m and a per-species minimum of 3 retained clips is always honored — the first three high-confidence detections of a species always survive, even when they share a spot
- Survey foreground notification now refreshes about once per second so the lock-screen timer matches actual recording time (session disk persistence stays on its 30 s cadence)
- Survey "elapsed" / total recorded time now excludes pause/resume gaps. `LiveSession` persists `recordedDurationSeconds`; resumed sessions accumulate active time across segments instead of measuring wall-clock from the original start
- Detection map widget prefers audio-bearing detections when collapsing duplicates at the same location so the play badge is accurate
- "Smart" sampling label kept untranslated across all locales (was "Intelligent" / "Inteligente" / etc.) to prevent layout overflow on narrow devices

## [0.5.3] - 2026-04-22

### Changed
- Onboarding pages use a more compact layout (smaller icons, smaller title, tighter padding) so the Terms & Privacy page — including the Privacy Policy link — fits on one screen on compact devices

## [0.5.2] - 2026-04-22

### Fixed
- Onboarding dots indicator no longer overflows on narrow displays now that the carousel has 6 pages (smaller dot size, tighter spacing, narrower active dot)

## [0.5.1] - 2026-04-22

### Changed
- Onboarding screens now use smaller icons and reduced top padding to prevent overflow on compact displays
- Terms of Use and Privacy Policy text (onboarding gate and Terms step) updated to reflect that both map tiles and reverse geocoding share a single one-time consent
- User-facing copy made taxonomically agnostic across all 7 locales — replaced "bird species", "bird identification", "bird detection", and "bird calls" with "species", "species identification", "detection", and "animal calls" respectively (the app supports more than birds)
- Terms gate now also explicitly forbids use for poaching, illegal wildlife trade, and military purposes, matching the published Terms of Use

## [0.5.0] - 2026-04-22

### Added
- Point Count setup now collects a custom name and observer name (parity with Survey); observer is remembered across sessions
- Onboarding gained a dedicated Terms & Privacy step with deep links to the full Terms of Use and Privacy Policy
- Session auto-stop reasons (manual, duration, battery, storage) and ETA hints during long-running sessions
- Loading skeleton for species info while taxonomy data resolves
- Accessibility labels for live capture controls and confidence metrics; haptic feedback on selection changes
- Session review now tracks playback position and highlights the active detection window
- New shared `WizardScaffold` for multi-step setup wizards (Live, Point Count, Survey, File Analysis)
- Shared loading, error, empty-state, and confirmation-dialog widgets across the app
- `ScoreColors` theme extension providing a consistent five-step confidence color scale
- Settings help tooltips and expanded UI tooltips throughout the app
- JSON export now includes full session metadata (custom name, session number, observer, transect ID, distance, stop reason)
- Detection windows now record end timestamps (live and survey) for accurate review and export

### Changed
- Reverse geocoding is now gated by the same one-time consent prompt as map tiles (no requests to OpenStreetMap until the user approves)
- Detection sampling for surveys reworked with clearer logic, expanded test coverage, and improved documentation
- Map handling and location services hardened (permission flow, lifecycle, and error states)
- Survey finalization flow hardened against edge cases during cleanup
- Documentation updated to use Material Design icon names consistently

### Fixed
- Runtime cleanup edge cases on session stop and screen disposal
- Integration test warnings cleaned up

## [0.4.0] - 2026-04-22

### Added
- Direct User Guide access from the Help screen
- A File Analysis app bar shortcut to the relevant settings panel
- Expanded the User Guide with workflow pages for Live, Explore, Session Library, Session Review, Point Count, Survey, File Analysis, icons and controls, and settings
- Added screen-level help overlays across operational workflows, including a common help-sheet layout and icon explanations that match the current UI

### Changed
- Localized remaining user-facing strings in file analysis, explore, settings, and survey notifications across all supported locales
- Updated Help guidance to point users to the User Guide from both Help and About
- Reworked Help and Explore guidance to explain app navigation and screen behavior rather than field methodology
- Localized the new help-overlay copy across all supported locales

## [0.3.4] - 2026-04-22

### Added
- Tracked species bundle tooling under `tools/`, including a public taxonomy JSON download helper
- Developer documentation for reproducing bundled species images and metadata through mkdocs

### Changed
- Bundled species images now rebuild at 480x320 WebP with slightly lower quality for better full-size detail rendering

## [0.3.3] - 2026-08-05

### Added
- "(Developer preview)" badge natively shown next to version info on Home Screen and About Screen
- Expanded user guide to cover all settings with the *intuition/rationale* behind changing them
- Updated in-app Help Screen: Replaced dawn chorus tip with explanations of basic mechanics and links to the user guide
- Ensure full translation of UI elements across all 7 supported locales

## [0.3.2] â€” 2025-07-28

### Added
- Confidence threshold slider in survey setup (Parameters step)
- Clip context controls (pre/post buffer seconds) in survey setup when recording mode is detections
- Clip context controls in global settings when recording mode is detections
- Tap species marker on fullscreen survey map to play detection clip with highlight

### Changed
- File analysis step indicator now uses simple progress bars (matching point count and survey setup)
- Smart detection sampling reworked: uses distance (>500 m) and time (>2 min) thresholds instead of fixed spatial bins; keeps only the highest-scoring detection per species at each spot

## [0.3.1] â€” 2026-04-15

### Changed
- Privacy policy updated to reflect offline species data bundle and current data handling
- Terms of use now hosted on the documentation site (was GitHub markdown)

### Added
- Terms of Use page in mkdocs documentation
- User Guide link on the About screen

## [0.3.0] â€” 2025-07-28

### Added
- `Begin File` column in Raven selection tables for multi-file compatibility
- `File` column in CSV exports referencing the audio source
- Latitude / Longitude columns in Raven and CSV exports when detections have coordinates
- GPX file auto-included in survey ZIP bundles
- Species common name in detection clip filenames (e.g. `_clip_001_Eurasian_Blackbird.flac`)
- Custom session name included in export filenames
- JSON export now includes session type, location, and per-detection coordinates
- Export prefix `BirdNET_Live_YYYY-MM-DD_HH-MM-SS` for all exported files (display names unchanged)

### Fixed
- Detection timestamps in exports are always session-relative (no more 0-based times for clips)
- Survey share now correctly produces ZIP bundles with individual detection clips
- `manualGlobal` detection end time in CSV uses session duration (consistent with Raven builder)
- Removed unused local variable in `live_controller.dart`

### Changed
- Session display names no longer use `BirdNET_Live` prefix (cleaner in-app display)

## [0.2.10] â€” 2025-07-27

### Added
- Recording mode setting (Full / Detections only / Off) restored to settings screen as segmented button
- Detection clip playback in session review: when only detection clips were recorded (no full recording), play buttons play individual clips

### Fixed
- Survey sessions with "detections only" recording mode now surface audio clips correctly in session review
- Play buttons hidden in session review when no audio exists (recording mode was off)

## [0.2.9] â€” 2025-07-27

### Added
- Share/export button now available for survey sessions (CSV, JSON, GPX, Raven â€” audio optional)

### Fixed
- Survey sessions now always record full audio (like live sessions) so playback and trim work in review
- Recording mode default changed from "off" to "full" for live sessions (live controller already recorded full regardless)

### Changed
- Recording mode setting removed from general settings screen (only exposed in survey setup where it applies)
- Observer name and track distance shown in a single row in session review header
- Survey map in session review reduced from 25% to 18% of screen height

## [0.2.8] â€” 2025-07-27

### Added
- Offline species data bundle: 5,241 species images (240Ã—160 WebP) and descriptions in 7 languages bundled into the APK
- `tools/build_species_bundle.py` â€” re-runnable Python build script to download, resize, and package species assets
- `SpeciesDescriptionService` â€” lazy gzip JSON loader with per-locale caching and English fallback
- Italian (`it`) and Korean (`ko`) common name columns added to `taxonomy.csv`

### Changed
- All species images now load from bundled assets instead of network (CachedNetworkImage â†’ Image.asset)
- Species detail overlay uses bundled descriptions instead of taxonomy API fetch
- `TaxonomyService` is now fully offline â€” removed `fetchDetail()` and API cache

## [0.2.7] â€” 2025-07-27

### Added
- French (fr), Spanish (es), Czech (cs), Brazilian Portuguese (pt), and Italian (it) translations (~290 keys each)
- Language picker in settings expanded from 3 to 8 options (System, English, Deutsch, FranÃ§ais, EspaÃ±ol, ÄŒeÅ¡tina, PortuguÃªs, Italiano)
- Landscape layouts for Home, Live, Point Count, Survey Live, and Session Review screens
- Tablet max-width constraint (600 dp) applied to 8 screens via shared `ContentWidthConstraint` widget
- Comprehensive localization: ~40 new l10n keys covering settings labels, live screen status texts, detection list states, color map names, recording mode options, and microphone settings (English + German)
- German technical term consistency: Point Count, Survey, and Session kept in English across the German UI

### Changed
- Home screen footer: single `Wrap` with all 5 buttons replacing two-row layout
- Mode card descriptions rewritten as action-oriented phrases (English + German)
- Help text updated to be taxonomically agnostic ("species" instead of "bird species", "animal sounds" instead of "birdsong")

## [0.2.6] â€” 2026-04-13

### Fixed
- GPS jitter filtering: reject fixes with >30 m horizontal accuracy, speed gate (>30 km/h) discards teleport jumps, jitter threshold raised from 3 m to 5 m

### Changed
- Survey notification now shows species count alongside detections (â€œ42 det Â· 12 sppâ€)

## [0.2.5] â€” 2026-04-13

### Added
- Microphone input selector in survey setup wizard (Parameters step) â€” pick input device before starting a survey
- Survey summary tab now shows rank numbers and sorts species by detection count then max confidence as tiebreaker

## [0.2.4] â€” 2026-04-13

### Added
- Help screen accessible from the home screen footer â€” comprehensive guide clustered by mode (Live, Point Count, Survey, File Analysis, Explore, Sessions) with expandable sections and general tips
- Home screen footer reorganized: 5 items in two rows (3 + 2) replacing the horizontal scroll

### Changed
- Inline survey map in session review is now interactive (pinch-zoom, pan, double-tap zoom) instead of static
- Deferred map `fitCamera` to post-frame callback to fix tiles not rendering until first touch

### Fixed
- Survey live help overlay with signal quality bar explanation and dashboard icons

## [0.2.3] â€” 2026-04-13

### Added
- Project foundation: Flutter project setup, folder structure, dependencies
- Dark theme with teal accent (field-optimized)
- Navigation scaffold with four mode tabs (Live, Survey, Point Count, File Analysis)
- Settings screen with categorized preferences (Audio, Inference, Spectrogram, Recording, Export, General)
- Onboarding carousel (welcome, features, permissions, ready)
- Terms of Use and Privacy Policy acceptance gate
- About screen with version info, model details, credits, and legal links
- Localization support (English, German)
- Permission handling service (microphone, location, storage, notifications)
- External resource consent system (map tiles, API sync)
- Settings infrastructure with Riverpod + SharedPreferences
- Repository documentation (README, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG)
- MkDocs documentation site structure
- Audio capture service with 32kHz mono PCM streaming
- Ring buffer for audio sample storage
- Audio level meter widget with peak-hold indicator
- Spectrogram visualization (FFT, color maps, scrolling painter)
- ONNX inference integration (classifier model, label parser, post-processor)
- Inference isolate for background processing
- Geo-model for location-based species filtering (dummy implementation)
- Species filter with four modes (off, geo-exclude, geo-merge, custom list)
- Custom species list import and persistence
- Model-agnostic inference configuration (JSON-driven model, label, and pipeline settings)
- Live Mode end-to-end pipeline (audio â†’ spectrogram â†’ inference â†’ detection list)
- LiveController orchestrator (model loading, inference timer loop, session management)
- Detection list widget with confidence bars, time-ago display, and playback icons
- WAV writer (streaming and one-shot modes, 16-bit PCM, RIFF header)
- Recording service (off, full, detections-only modes)
- Session repository (JSON file persistence, save/load/list/delete)
- LiveSession data model with settings snapshot and detection records
- Audio playback for detection clips (just_audio integration)
- Session info bar showing species and detection counts during active sessions

