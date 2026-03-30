# Code Style

Coding conventions and style guide.

## Language

All code, comments, documentation, and user-facing strings use **American English**.

## File Headers

Each Dart file has a `// ===...` block comment explaining purpose, usage, and design rationale.

## Formatting

- Use `dart format` (enforced by `flutter analyze`).
- Line length: default Dart (80 characters).
- Follow [Effective Dart](https://dart.dev/effective-dart) guidelines.

## Naming

- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/functions: `camelCase`
- Constants: `camelCase` (Dart convention)
- Private members: `_prefixed`

## Localization

- All user-facing strings go in `lib/l10n/app_en.arb` (English) and `app_de.arb` (German).
- Use `l10n.keyName` in widgets.
- Run `flutter gen-l10n` to regenerate (automatic on build).

## Settings

- All `SharedPreferences` keys are centralized in `PrefKeys` (`core/constants/app_constants.dart`).
- New settings: add a `PrefKeys` constant + provider in `settings_providers.dart` + UI in `settings_screen.dart`.

## No Hardcoded Values

Model parameters, API URLs, and thresholds come from config files or constants — never inline.
