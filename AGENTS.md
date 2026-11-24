# BirdNET Live Agent Guide

This file is for coding agents working in this repository.

## Contributions

- When helping someone prepare a contribution (pull request, translation, new language, docs fix), read [CONTRIBUTING.md](CONTRIBUTING.md) first and follow it: code style, settings/docs/changelog rules, translation rules and per-locale register, the new-language checklist, and the PR guidelines all apply to agent-written changes.
- If this file and CONTRIBUTING.md disagree, flag it to the user and keep both in sync rather than silently picking one.

## Mission

- Keep changes small, safe, and easy to review.
- Prefer behavior-preserving updates unless a behavior change is requested.
- Validate changes with focused checks, then run flutter analyze before finishing.
- Prefer small, purpose-built solutions over third-party packages that provide much more than the task needs. Add a package only after verifying that it neither accesses private user data nor communicates with the internet.

## Communication Style

- Be brief and high-signal.
- Use American English in code, comments, docs, and user-facing strings.
- Avoid long restatements; reference exact files and functions.

## Product Snapshot

- Flutter app for on-device wildlife sound identification with live spectrogram.
- Platforms: Android, iOS, Windows.
- Main modes: Live Mode, Point Count, Survey, File Analysis.
- Additional modes present in UX: Batch Analysis, ARU Mode.

## Project Structure

- lib/core: app-wide constants, services, theme, and infrastructure.
- lib/shared: shared models, providers, utilities, and widgets.
- lib/features: feature modules (about, announcements, aru, audio, explore, file_analysis, history, home, inference, live, onboarding, point_count, recording, settings, spectrogram, survey, upload).
- lib/l10n: ARB localization source files and generated localization outputs.
- docs: user/developer documentation.
- dev and tools: maintenance scripts, model pipelines, and release helpers.

## Core Rules

- Always keep user-facing strings translated in all 13 locales: en, de, cs, es, fr, it, pt, nl, nb, pl, ru, zh (Simplified Chinese), ko.
- After ARB edits, run flutter gen-l10n and verify no missing keys.
- Use l10n keys in UI; do not hardcode user-facing text.
- Keep these technical terms in English across locales: Point Count, Survey, Session, Live Mode, WAV, FLAC, CSV, JSON, GPX, Raven Selection Table, Smart.
- Keep each locale's register (formal/informal) as listed in the Supported Locales table in CONTRIBUTING.md.
- A locale is not "added" until every surface below carries it — an ARB-only pass leaves the app speaking English in half the product. The contributor-facing version with who-does-what is "Adding a New Language" in CONTRIBUTING.md; keep the two lists in sync:
  - `lib/l10n/app_<loc>.arb` (UI strings)
  - `assets/announcements/templates_<loc>.json` (spoken announcements; a missing file falls back to English silently)
  - `assets/species_data/descriptions_<loc>.json.gz` + `SpeciesDescriptionService.availableLocales` + `DESCRIPTION_LOCALES` in `tools/build_species_bundle.py` + the 16 sound class descriptions in `tools/sound_class_descriptions.json` (the taxonomy has them in English only). After adding to `DESCRIPTION_LOCALES`, re-run the whole bundle script — it is also what writes the `wikipedia_url_<loc>` column into `assets/models/taxonomy.csv`, and a partial run leaves descriptions updated but that column absent. No taxonomy API pull is needed; the taxonomy JSON in `tools/data/` already carries the URLs.
  - the app-language dropdown in `lib/features/settings/settings_screen.dart`
  - `android/app/src/main/res/values-<loc>/strings.xml` (Quick Listen widget labels)
  - iOS: a `<loc>` entry for every key in `ios/Runner/InfoPlist.xcstrings` (permission prompts) and `ios/Runner/Localizable.xcstrings` (Shortcuts/Siri), plus `knownRegions` in `ios/Runner.xcodeproj/project.pbxproj` (Apple codes, e.g. `zh-Hans`)
  - species names: an alias in `TaxonomySpecies` (`lib/shared/models/taxonomy_species.dart`) when the taxonomy column code differs from the app locale (`nb` → `no`, `zh` → `zh-CN`), and the `_speciesLanguages` map in `settings_screen.dart`
  - `AppConstants.policyDocsLocales` + `docs/privacy.<loc>.md` + `docs/acceptable-use.<loc>.md` + the `mkdocs.yml` locale block + `test/core/constants/app_constants_test.dart`
  - `docs/index.<loc>.md` + `docs/user/*.<loc>.md` (the MkDocs user guide) + `AppConstants.docsLocales` + the locale's `nav_translations` block in `mkdocs.yml`. The Developer Guide and API Reference stay English.
  - `dev/store/store-desc.md` (all five sections: both subtitles, promo text, short description, keywords)
  - `dev/mockups/`: slide titles/subtitles belong in `mockups.copy.md` (then run `node sync-copy.js`), not inline in `mockups.config.js` — copy.md is the source of truth and only overlays languages it defines. In `mockups.config.js` add the language's `name` plus an entry in both `featureGraphic.taglines` and `featureGraphicHomeSubtitles`; the feature graphic falls back to English silently when either is missing. Render with `node render-mockups.js --lang <loc>`, then again with `--ipad`, then `--feature-graphic --lang <loc>` (13 images per locale).
  - the locale list in `dev/build_release.dart` so stubbed Play/App Store release notes include it
  - the locale lists in `test/features/announcements/templates_*_test.dart` (plus determiners in the gender-lint map if the language has them) and `test/shared/services/species_description_service_test.dart`
  - locale lists in docs: `README.md` localization bullet, `docs/developer/localization.md`, `assets/announcements/README.md`, the CONTRIBUTING.md Supported Locales table, this file, and `.github/copilot-instructions.md`
- Use AppIcons from lib/shared/utils/app_icons.dart, not raw Icons.* or Symbols.* in app code.
- Do not hardcode thresholds or model config values when constants/config already exist.

## UI and Theme Constraints

- Support portrait and landscape.
- Keep tablet layouts aligned with ContentWidthConstraint (600 dp intent).
- Dynamic color semantics: live=error, point count=primary, survey=secondary, file analysis=tertiary.
- Keep score ramps and spectrogram colormaps fixed; do not remap them to dynamic color.
- Use error palette for destructive actions.

## Settings and Docs Discipline

- For new/changed settings:
- Update PrefKeys and related providers/UI.
- Add the tile's title to `_searchEntries` in `lib/features/settings/settings_screen.dart` so Settings search finds it.
- Document rationale in docs/user/settings.md.
- Document user-visible behavior changes in CHANGELOG.md.
- Prefer frequent, small documentation updates over large delayed updates.

## Dev Folder Sync Rule

- Do not sync or copy broad content from dev by default.
- Only sync items from dev when the user explicitly requests it and names the specific files/folders.
- Treat dev as tooling/working area; avoid accidental release/docs spillover from dev artifacts.

## Species Bundle and Assets

- `assets/species_images/dummy.webp` is the hand-crafted fallback image shown for species with no dedicated taxonomy image. It is NOT generated by the build pipeline and must never be deleted.
- When rebuilding the species bundle (`tools/build_species_bundle.py`), the script clears `assets/species_images/` — `dummy.webp` is explicitly preserved. If you add other hand-crafted assets to that directory, add their filenames to `PRESERVED_OUTPUT_FILES` in the script.
- The bundle must be built from the taxonomy version the shipped models were built against (`TAXONOMY_VERSION` in the script): the audio labels join the taxonomy by BirdNET ID, and the script stops if an ID resolves to a different scientific name. To rebuild:
  1. `python tools/download_taxonomy_json.py` (saves the export from `https://birdnet.tu-chemnitz.de/taxonomy/api/download/json` into `tools/data/`).
  2. `python tools/build_species_bundle.py` from the repo root with the `.venv` active.
- Workflow and file formats: `docs/developer/species-bundle.md`.

## Model and Taxonomy Updates

- Follow `docs/developer/model-update.md`. The build scripts are in `dev/models/<update>/` (tracked; the model inputs next to them are not).
- Sessions store the scientific name a species had when it was detected and are never rewritten. Do not add code that stores a label index or a BirdNET ID with a detection, and do not migrate stored names.
- Every name a release has ever stored must keep resolving: renamed species through `scientific_name_aliases` in `taxonomy.csv`, species the model no longer detects through `tools/legacy_species.csv`, and species the taxonomy has dropped altogether through `tools/retired_species.json` (record) plus `tools/retired_species_images/` (picture). `test/shared/services/taxonomy_continuity_test.dart` enforces this without exceptions; never weaken it to make a model update pass.
- Compare species across Sessions with `TaxonomyService.canonicalScientificName`, not with the stored string.
- Never give two different models the same file name and version: the on-device copy is named `<file name>_v<version>`.
- Do not carry a label correction (such as the old American/Mangrove Yellow Warbler swap) into a new model without testing it against that model with field recordings. The same goes for score blacklist multipliers: a new model starts with every entry at 1.0.
- Non-animal sound classes are opt-in (`includeSoundClasses`), have no geo-model output, and must stay out of the model's species count (About, taxon group counts), the **Ignore species** count, Explore, species pickers, and Survey species alerts. A sound class the user opted into and that was detected is part of that Session: it is listed with its detections and included in the Session's species count.

## Audio, Maps, and Runtime Safety

- Do not use Picture.toImageSync() for spectrogram rendering.
- Avoid memory-heavy changes for long File Analysis recordings.
- Use shared OSM tile layer settings and keep map behavior consistent.
- OSM public tile policy: interactive use only, no offline/bulk/pre-seeded downloads.
- Avoid Survey double-finalization paths; clear callbacks on dispose.

## Data and Models

- ONNX assets are managed with Git LFS.
- Keep model behavior JSON-driven via assets/models/model_config.json.
- ARM64 rule: sensitive compute may require FP32 casting for stable output.

## Device Testing

- The developer's phones carry real sessions. Never run `adb uninstall`, `pm clear`, or `flutter run --uninstall-first` against them, and never delete or overwrite the app's data.
- Install only builds signed with the key the installed app already has, so the install is an in-place upgrade and the data survives. On the developer machine the installed app is signed with the local debug keystore, so a plain debug build (`flutter build apk --debug` + `adb install -r`) is safe; a release-signed build would be refused as a signature mismatch and must not be forced through a reinstall.
- Never run `flutter test integration_test/...` or `flutter drive` against the developer's phones: both uninstall the app when the run ends (and retry a failed install by uninstalling first). To run an integration test on a phone, build it as a debug APK (`flutter build apk --debug --target-platform android-arm64 --target integration_test/<test>.dart`), `adb install -r` it, start the app, and read the result from `adb logcat -s flutter`. A test installed this way runs inside the real app's data directory, so run only tests that do not write or delete app data (`model_output_test` and `geo_soundscape_test` only read the bundled models). Afterwards build the normal debug APK and `adb install -r` it again.
- Before installing, confirm the signature matches: compare `apksigner verify --print-certs` on the installed `base.apk` (pulled via `adb shell pm path`) against the keystore you are building with.

## Build and Release

- Typical commands:
- flutter pub get
- flutter gen-l10n
- flutter analyze
- flutter test
- Never run integration tests without explicit user approval in the current conversation; they are costly.
- For pure UI changes, use focused widget/unit tests and static analysis. Do not run unrelated integration tests.
- Version source of truth is pubspec.yaml.
- Never bump the version without explicit user consent in the current turn. Do not change pubspec.yaml version/build, version badges, or add a new CHANGELOG version header unless the user explicitly asks. Fold user-facing changes into the current unreleased version section instead.
- For release bumps, increment patch and build together, then run dart dev/sync_version.dart.

## Version Bumping Checklist

- Update version in pubspec.yaml as patch+build (example: 0.16.10+178 -> 0.16.11+179).
- Add/update release notes in CHANGELOG.md under the matching version header and prepare Play/App Store release notes for all 13 app locales: en, de, cs, es, fr, it, pt, nl, nb, pl, ru, zh, ko. Release notes are UTF-8 with `<xx-XX>` tags — write zh-CN in Simplified Chinese characters, never pinyin.
- Run dart dev/sync_version.dart to sync README/docs version badges.
- If strings changed, run flutter gen-l10n and verify locale completeness.
- Run flutter analyze (and flutter test when relevant) before committing.
- Before a release is uploaded or published, run the start-up check in `docs/developer/releasing.md` on both artifacts: the App Bundle installed as split APKs through bundletool (asset pack included) and the release APK, each cold-started on an emulator with no crash and both models loaded. Run it also after any change to Android dependencies, R8/ProGuard rules, the asset pack, or model loading. A release that has not passed it does not ship.
- Keep release commits focused and use a conventional commit message.

## Search for All Affected Call Sites Before Implementing

When a feature touches a shared function, setting, or data path, grep the full codebase for every place that function is called or that path is used — not just the location described in the request. Implement the change at **all** affected locations in the same pass.

- Before writing code, grep for the function name, setting key, and provider name across `lib/`.
- Check every call site and every parallel code path that handles the same data.
- If multiple screens, services, or widgets do "the same thing" independently, update all of them.

## Git Workflow

- Use conventional one-line commit messages, for example:
- feat(scope): ...
- fix(scope): ...
- docs(scope): ...
- Group related changes; avoid mixed-purpose commits.
- Never push unless explicitly requested in the current task.
- Never run git push without explicit user consent in the current conversation.
