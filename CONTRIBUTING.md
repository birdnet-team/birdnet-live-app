# Contributing to BirdNET Live

Thank you for your interest in contributing to BirdNET Live! This guide will help you get started.

## Development Setup

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.27+)
- [Android Studio](https://developer.android.com/studio) (for Android SDK & emulator)
- [Xcode](https://developer.apple.com/xcode/) (macOS only, for iOS development)

### Getting Started

```bash
# Clone the repository
git clone https://github.com/birdnet-team/birdnet-live-app.git
cd birdnet-live-app

# Install dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run the app
flutter run
```

### Running Tests

```bash
# All tests
flutter test

# Specific feature
flutter test test/features/audio/

# With coverage
flutter test --coverage
```

## Code Style

- Follow [Effective Dart](https://dart.dev/effective-dart) guidelines
- Use `flutter analyze` to check for lint issues
- Format code with `dart format .`
- Use dartdoc comments for public APIs
- Use `AppIcons` (`lib/shared/utils/app_icons.dart`) instead of direct `Symbols.*` or `Icons.*` in feature code
- Prefer neutral icon names; keep `...Outlined`/`...Rounded` names only when the style distinction is intentional and both variants are used

### File Structure

Each feature follows this pattern:

```
lib/features/{name}/
  {name}_screen.dart         # UI
  {name}_controller.dart     # Logic (if needed)
  {name}_provider.dart       # State
  widgets/                   # Feature-specific widgets
```

## Translation Contributions

BirdNET Live uses ARB files in `lib/l10n/` and requires complete coverage for all supported locales.

### Supported Locales

- `en`
- `de`
- `cs`
- `es`
- `fr`
- `it`
- `pt`
- `nl`
- `pl`
- `ru`

### Translation Rules

- Keep technical terms in English across locales: Point Count, Survey, Session, Live Mode, WAV, FLAC, CSV, JSON, GPX, Raven Selection Table, Smart, Gain.
- Prefer gender-neutral wording where it is natural and idiomatic in the target language.
- Keep register consistent within each locale: use either formal or informal phrasing, but do not mix both in the same locale.
- Keep placeholders and message syntax intact (`{count}`, `{name}`, ICU `plural`/`select` blocks).
- Add or update the `@key` metadata `description` for new or ambiguous strings so translators have context.
- Do not split one sentence into multiple keys just to compose it in code.
- Do not hardcode UI strings in Dart widgets; always use `l10n.keyName`.
- For wording changes that alter meaning, prefer a new key name instead of silently reusing an old one.
- If you use machine translation, always do a human review before opening a PR.

### Translation Workflow

1. Add or update the source string in `lib/l10n/app_en.arb`.
2. Add matching translations in every other locale ARB file.
3. If you add a new language, make sure it is included in the app language selector and supported locale configuration.
4. Run `flutter gen-l10n`.
5. Run `flutter analyze`.
6. Run focused tests when the string change affects behavior (for example plural/select logic).
7. Manually check the changed screens in at least one non-English locale and look for overflow/truncation in both portrait and landscape.

### Pull Request Checklist for Translation Changes

- Include only translation-related edits in a translation PR (ARB files and generated localization output).
- Mention which locales were updated.
- Call out any intentionally untranslated terms.
- Add screenshots when the change affects layout-sensitive UI text.

For deeper localization conventions, see `docs/developer/localization.md`.

## Pull Request Guidelines

1. **Branch naming**: `feature/description`, `fix/description`, `docs/description`
2. **Commit messages**: Use [Conventional Commits](https://www.conventionalcommits.org/)
   - `feat: add spectrogram color map selector`
   - `fix: resolve audio buffer overflow`
   - `docs: update API integration guide`
3. **Keep PRs focused**: One feature or fix per PR
4. **Tests**: Add tests for new functionality
5. **Documentation**: Update relevant docs for user-facing changes

## Reporting Issues

- Use GitHub Issues with the appropriate template
- Include device info, Flutter version, and steps to reproduce
- Attach logs if relevant (`flutter logs`)

## Code of Conduct

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.
