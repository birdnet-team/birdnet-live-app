# BirdNET Live Agent Guide

This file is for coding agents working in this repository.

## Mission

- Keep changes small, safe, and easy to review.
- Prefer behavior-preserving updates unless a behavior change is requested.
- Validate changes with focused checks, then run flutter analyze before finishing.

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
- lib/features: feature modules (live, point_count, survey, file_analysis, history, settings, home, about, explore).
- lib/l10n: ARB localization source files and generated localization outputs.
- docs: user/developer documentation.
- dev and tools: maintenance scripts, model pipelines, and release helpers.

## Core Rules

- Always keep user-facing strings translated in all 7 locales: en, de, cs, es, fr, it, pt.
- After ARB edits, run flutter gen-l10n and verify no missing keys.
- Use l10n keys in UI; do not hardcode user-facing text.
- Keep these technical terms in English across locales: Point Count, Survey, Session, Live Mode, WAV, FLAC, CSV, JSON, GPX, Smart.
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
- Document rationale in docs/user/settings.md.
- Document user-visible behavior changes in CHANGELOG.md.
- Prefer frequent, small documentation updates over large delayed updates.

## Dev Folder Sync Rule

- Do not sync or copy broad content from dev by default.
- Only sync items from dev when the user explicitly requests it and names the specific files/folders.
- Treat dev as tooling/working area; avoid accidental release/docs spillover from dev artifacts.

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

## Build and Release

- Typical commands:
- flutter pub get
- flutter gen-l10n
- flutter analyze
- flutter test
- Version source of truth is pubspec.yaml.
- For release bumps, increment patch and build together, then run dart dev/sync_version.dart.

## Version Bumping Checklist

- Update version in pubspec.yaml as patch+build (example: 0.16.10+178 -> 0.16.11+179).
- Add/update release notes in CHANGELOG.md under the matching version header.
- Run dart dev/sync_version.dart to sync README/docs version badges.
- If strings changed, run flutter gen-l10n and verify locale completeness.
- Run flutter analyze (and flutter test when relevant) before committing.
- Keep release commits focused and use a conventional commit message.

## Git Workflow

- Use conventional one-line commit messages, for example:
- feat(scope): ...
- fix(scope): ...
- docs(scope): ...
- Group related changes; avoid mixed-purpose commits.
- Never push unless explicitly requested in the current task.
- Never run git push without explicit user consent in the current conversation.
