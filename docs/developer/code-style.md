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

## Icons

- Use `AppIcons` from `lib/shared/utils/app_icons.dart` in app code. Avoid direct `Symbols.*` or `Icons.*` usage in feature widgets unless a local prototype requires it.
- Prefer neutral/base names for single-style icons (example: `cloud`, `travelExplore`, `timerOff`).
- Keep style-explicit names (`...Outlined`, `...Rounded`) only when style selection is intentional and both variants are part of the app API (example: `routeOutlined` + `routeRounded`).
- When renaming icon constants, use a two-step migration: add the new constant and migrate call sites first, then remove temporary aliases after usage reaches zero.

## Localization

- All user-facing strings go in every UI locale ARB file: `app_en.arb`, `app_de.arb`, `app_cs.arb`, `app_es.arb`, `app_fr.arb`, `app_it.arb`, and `app_pt.arb`.
- Use `l10n.keyName` in widgets.
- Run `flutter gen-l10n` to regenerate (automatic on build).

## Settings

- All `SharedPreferences` keys are centralized in `PrefKeys` (`core/constants/app_constants.dart`).
- New settings: add a `PrefKeys` constant + provider in `settings_providers.dart` + UI in `settings_screen.dart`.

## No Hardcoded Values

Model parameters, API URLs, and thresholds come from config files or constants — never inline.
