# BirdNET Live — Copilot Instructions (Focused)

## Response Style (Token Efficiency)

- Default to concise responses: short summary + only essential details.
- Avoid long restatements of context; reference files/functions directly.
- Use bullets over prose. Prefer <= 6 bullets unless user asks for depth.
- Ask at most one clarifying question only when blocked.
- Minimize tool usage and file reads: read only relevant ranges/files.
- For edits, make minimal diffs; do not reformat unrelated code.

## Project Snapshot

- Flutter app (Android/iOS/Windows) for on-device wildlife sound ID with live spectrogram.
- Main modes: Live, Point Count, Survey, File Analysis.
- Stack: Flutter 3.27+, Dart ^3.7.0, Riverpod, ONNX Runtime, Geolocator, SharedPreferences.

## Structure

- `lib/core`: app constants/services/themes.
- `lib/shared`: shared models/providers/services/widgets.
- `lib/features/*`: feature modules (`live`, `point_count`, `survey`, `explore`, `inference`, `audio`, `file_analysis`, `history`, `settings`, `home`, `about`).
- `lib/l10n`: localization.
- `dev`: build/maintenance scripts.
- `tools`: species bundle pipeline scripts.

## Required Coding Rules

- Use American English in code, comments, docs, and UI strings.
- Keep user-facing strings in all 7 locales: `en`, `de`, `cs`, `es`, `fr`, `it`, `pt`.
- Use `l10n.keyName` in widgets; after ARB edits run `flutter gen-l10n` and ensure 0 untranslated messages.
- Keep technical terms in English across locales: Point Count, Survey, Session, Live Mode, WAV, FLAC, CSV, JSON, GPX, Smart.
- Add/modify settings via `PrefKeys` + settings providers/UI, and update `docs/user/settings.md` with user-facing rationale.
- Use `AppIcons` (`lib/shared/utils/app_icons.dart`) instead of raw `Symbols.*` or `Icons.*` in app code.
- Keep Dart file header block comments (`// ===...`).
- No hardcoded model/API thresholds/config values when constants/config already exist.

## UI/Theming Constraints

- Support portrait + landscape; keep tablet layouts aligned with `ContentWidthConstraint` (600dp).
- Dynamic color mappings: live=`error`, point count=`primary`, survey=`secondary`, file analysis=`tertiary`.
- Keep score ramps and spectrogram colormaps fixed (not dynamic-color remapped).
- Use error palette for destructive actions.
- Prefer `surfaceContainer*` for elevated surfaces.

## Models, Inference, and Data

- ONNX assets in `assets/models` are Git LFS; on fresh clone run `git lfs install` and `git lfs pull`.
- Keep model behavior JSON-driven via `assets/models/model_config.json`.
- Model rebuild pipeline: `python dev/build_models.py` (prune -> fix audio model -> fix geo model). See `dev/MODELS.md`.
- ARM64 precision rule: audio model weights stay FP16 on disk, but sensitive compute must cast to FP32 for stable mobile output.
- Species/taxonomy APIs:
  - `GET /api/image/{sci_name}?size=thumb|medium`
  - `GET /api/species/{sci_name}`

## Build, Test, and Release

- Core commands:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
  - `flutter run`
  - `flutter build apk --release`
  - `flutter build appbundle`
- `pubspec.yaml` is version source of truth. For user-facing release changes, bump patch + build number together and run `dart dev/sync_version.dart`.
- Release notes in `release/V<version>/release_notes.txt`: short, user-facing, non-implementation detail, per-locale <= 500 chars.
- Integration fixture note: `assets/test_fixtures` are not bundled; push to device before integration tests when needed.

## Repo Workflow and Git Rules

- Commit messages: one-line conventional style (`feat(scope): ...`, `fix(scope): ...`, `docs(scope): ...`).
- Do not include internal tracker-like IDs (e.g., `F1`, `Q3`, `I2`) in commit messages.
- Group related changes; avoid mixed-purpose commits.
- Never run `git push` unless the user explicitly asks in the current turn.

## Asset/Ignore Rules

- Keep `/dev/*` broadly ignored, except tracked paths like `dev/sync_version.dart` and `dev/mockups/**`.
- Keep generated `dev/mockups/output/` ignored.
- `assets/species_images/` and `assets/species_data/` are ignored/generated bundle outputs.
- Use `tools/download_taxonomy_json.py` + `tools/build_species_bundle.py` for species bundle regeneration.

## Runtime Safety / Known Pitfalls

- Do not use `Picture.toImageSync()` for spectrogram rendering (GPU leak risk); use async image conversion.
- File Analysis may decode full audio during inspect and analyze; avoid changes that increase peak memory for long files.
- For map tiles, use shared OSM tile layer (`NetworkTileProvider(silenceExceptions: true)`) and avoid custom providers that trigger error screens.
- OSM policy: public `tile.openstreetmap.org` usage must remain interactive only (no offline/bulk/pre-seeded public tile downloads).
- Survey auto-stop/finalization: avoid double-finalization paths; clear controller callbacks on screen dispose.

## Clear-Data Behavior

- "Clear All Data" should wipe sessions, recordings/voice memos, custom species lists, preferences, OSM tile cache, and temp caches, then exit app.
- Do not delete extracted ONNX model files in that action (they are app assets and may be memory-mapped).
