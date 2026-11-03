# Contributing to BirdNET Live

Thank you for your interest in contributing to BirdNET Live! Bug reports, feature ideas, translations, documentation fixes, and code are all welcome. This guide covers what you need to know to get a contribution merged.

> **Using an AI coding agent?** Point it at this file and at [AGENTS.md](AGENTS.md). Both apply to agent-written changes, and you are responsible for reviewing everything the agent produces before you open a pull request.

## Ways to Contribute

- **Report a bug or request a feature** — open a [GitHub issue](https://github.com/birdnet-team/birdnet-live-app/issues) using the matching template. See [Reporting Issues](#reporting-issues).
- **Translate** — improve an existing language or add a new one. See [Translation Contributions](#translation-contributions) and [Adding a New Language](#adding-a-new-language).
- **Improve the docs** — the user guide lives in `docs/user/`, the developer guide in `docs/developer/`.
- **Write code** — fix a bug or build a feature. For anything larger than a small fix, open an issue first so we can agree on the approach before you invest time.
- **Report a security problem** — do not open a public issue; follow [SECURITY.md](SECURITY.md).

## Development Setup

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.47+ with Dart 3.13+ (CI uses Flutter 3.47.5)
- [Git LFS](https://git-lfs.com/) for the large ONNX model files
- [Android Studio](https://developer.android.com/studio) for the Android SDK and emulator
- [Xcode](https://developer.apple.com/xcode/) (macOS only) for iOS development
- [Visual Studio 2022](https://visualstudio.microsoft.com/) with the "Desktop development with C++" workload (Windows only) for Windows desktop builds

### Getting Started

```bash
# Clone the repository
git clone https://github.com/birdnet-team/birdnet-live-app.git
cd birdnet-live-app

# Fetch the ONNX model files (do not skip on a fresh clone)
git lfs install
git lfs pull

# Install dependencies
flutter pub get

# Generate localization files (they are not checked in)
flutter gen-l10n

# Run the app
flutter run
```

See `docs/developer/getting-started.md` and `docs/developer/building.md` for platform-specific details.

### Running Tests

```bash
# All unit and widget tests
flutter test

# Specific feature
flutter test test/features/audio/

# With coverage
flutter test --coverage
```

The tests in `integration_test/` run on a real device or emulator, need test fixtures pushed to the device, and take a long time. They are not required for a pull request; maintainers run them when a change needs it. Add focused unit or widget tests under `test/` instead.

### Before You Open a Pull Request

CI runs `flutter analyze`, `flutter test`, and a debug build on every pull request. Run these locally first:

```bash
flutter gen-l10n
dart format .
flutter analyze
flutter test
```

## Code Style

- Follow [Effective Dart](https://dart.dev/effective-dart) and keep `flutter analyze` clean.
- Format code with `dart format .`.
- Use dartdoc comments for public APIs, and keep the `// ===...` header block at the top of each Dart file.
- Use American English in code, comments, docs, and user-facing strings.
- Never hardcode user-facing text; use `l10n.keyName` (see [Translation Contributions](#translation-contributions)).
- Do not hardcode thresholds or model settings that already exist as constants or in `assets/models/model_config.json`.
- Use `AppIcons` (`lib/shared/utils/app_icons.dart`) instead of direct `Symbols.*` or `Icons.*` in feature code. Prefer neutral icon names; keep `...Outlined`/`...Rounded` names only when the style distinction is intentional and both variants are used.

### UI and Theme

- Every screen must work in portrait and landscape. Keep tablet layouts within `ContentWidthConstraint` (600 dp).
- Mode colors follow the dynamic color scheme: Live Mode = `error`, Point Count = `primary`, Survey = `secondary`, File Analysis = `tertiary`.
- Score color ramps and spectrogram colormaps are fixed; do not remap them to dynamic color.
- Use the error palette for destructive actions.

### File Structure

Each feature follows this pattern:

```
lib/features/{name}/
  {name}_screen.dart         # UI
  {name}_controller.dart     # Logic (if needed)
  {name}_provider.dart       # State
  widgets/                   # Feature-specific widgets
```

App-wide infrastructure lives in `lib/core/`, shared models, providers, and widgets in `lib/shared/`. See `docs/developer/architecture.md`.

### Dependencies and Privacy

BirdNET Live runs entirely on-device. Prefer a small, purpose-built solution over a third-party package that does much more than the task needs. Only propose a new package after checking that it neither accesses private user data nor communicates with the internet, and explain in the pull request why it is needed.

### Settings

When you add or change a setting:

1. Add or update its key in `PrefKeys` and the related provider and settings UI.
2. Explain what it does and why someone would change it in `docs/user/settings.md`.
3. Note the user-visible change in `CHANGELOG.md`.

### Documentation

Update the relevant docs in the same pull request as a user-facing change. Edit the English page (`docs/user/<page>.md`); if the change makes the translated pages (`docs/user/<page>.<locale>.md`) outdated, update the ones you can and mention the rest in the pull request. The Developer Guide and API Reference are English only.

## Translation Contributions

BirdNET Live is translated in several places, and a language is only complete when all of them are covered. Most translation pull requests touch only the first two:

| Surface | Files | Covers |
|---------|-------|--------|
| UI strings | `lib/l10n/app_<locale>.arb` | Every label, button, help text, and message |
| Spoken phrasing | `assets/announcements/templates_<locale>.json` | The sentences the app speaks aloud on a detection |
| Native platform strings | `android/app/src/main/res/values-<locale>/strings.xml`, `ios/Runner/InfoPlist.xcstrings`, `ios/Runner/Localizable.xcstrings` | The Android home-screen widget, iOS permission prompts, and iOS Shortcuts/Siri action |
| Docs site | `docs/privacy.<locale>.md`, `docs/acceptable-use.<locale>.md`, `docs/index.<locale>.md`, `docs/user/*.<locale>.md` | Policies and the user guide |
| Store listing | `dev/store/store-desc.md`, `dev/mockups/mockups.copy.md` | App store text and screenshot captions |

> **Do not stop at the ARB file.** The announcement templates are not in ARB (they are variant *lists*, which ARB cannot model — see `assets/announcements/README.md` for the reasoning and the full guide). A missing or incomplete template file falls back to English **silently**, so the app can look fully translated while the voice is not.

Species common names and species descriptions are **not** translated in this repository. They come from the [BirdNET taxonomy](https://birdnet.cornell.edu/taxonomy/) and Wikipedia; maintainers bundle them. If a species name is wrong in your language, open an issue rather than editing `assets/models/taxonomy.csv`.

### Supported Locales

| Code | Language | Register |
|------|----------|----------|
| `en` | English | — |
| `de` | German | formal *Sie* |
| `cs` | Czech | formal *vy* |
| `es` | Spanish | informal *tú* |
| `fr` | French | formal *vous* |
| `it` | Italian | informal *tu* |
| `pt` | Portuguese | *você*, Brazilian vocabulary |
| `nl` | Dutch | informal *je/jouw* |
| `nb` | Norwegian Bokmål | informal *du* |
| `pl` | Polish | direct second-person imperative |
| `ru` | Russian | formal *вы* (lowercase) |
| `zh` | Simplified Chinese | polite *您* |
| `ko` | Korean | 합니다체 in UI and docs, 해요체 in spoken announcements |

Keep to the register listed for the locale when you edit it.

### Translation Rules (UI strings)

- Keep these terms in English in every locale: Point Count, Survey, Session, Live Mode, WAV, FLAC, CSV, JSON, GPX, Raven Selection Table, Smart, Gain. Colormap names (Viridis, Plasma, …) and model version strings stay as they are too. In descriptive prose a natural local term is fine.
- Language names in the language picker are written in their own language ("Deutsch", "한국어").
- Write taxonomically agnostic help text: "species" rather than "bird species", "animal sounds" rather than "birdsong".
- Prefer gender-neutral wording where it is natural and idiomatic in the target language.
- Keep placeholders and message syntax intact (`{count}`, `{name}`, ICU `plural`/`select` blocks).
- Add or update the `@key` metadata `description` in `app_en.arb` for new or ambiguous strings so translators have context.
- Do not split one sentence into multiple keys just to compose it in code.
- Do not hardcode UI strings in Dart widgets; always use `l10n.keyName`.
- For wording changes that alter meaning, prefer a new key name instead of silently reusing an old one.
- If you use machine translation, always do a human review before opening a PR. Watch for typical artifacts: stray characters next to placeholders (`{count}_`) and zero-width spaces.

### Translation Rules (spoken announcements)

- **Rewrite, do not translate literally.** These are spoken sentences; what sounds natural in English rarely maps word for word. Variant counts may differ from the English file.
- **Never put an article or demonstrative directly before `{name}`.** Species names carry no grammatical gender in our data, so the app cannot inflect the determiner to agree (*der Zaunkönig* / *die Amsel* / *das Rotkehlchen*). This applies to `ten`/`ta`/`to` and `этот`/`эта`/`это` in Polish and Russian too.
- **Never attach a sound-dependent particle to `{name}`** in languages that have them — in Korean, 이/가, 은/는, 을/를, 와/과, and 이에요/예요 depend on the name's last syllable.
- Keep placeholders intact and untranslated: `{name}`, `{name1}`, `{name2}`, `{name3}`.
- Preserve the confidence gradient across buckets — `A`/`B`/`C` state the species plainly, `D`/`E` hedge slightly, `F`/`G` hedge clearly.
- Keep utterances short (one clause, two at most) and free of abbreviations or symbols the TTS engine will mispronounce.
- Match the register in the table above.

The bucket reference, commonness bins, and full conventions are in `assets/announcements/README.md`.

### Translation Workflow

1. Add or update the source string in `lib/l10n/app_en.arb`.
2. Add matching translations in every other locale ARB file.
3. If the change touches spoken announcements, update `assets/announcements/templates_<locale>.json` for every locale as well.
4. Run `flutter gen-l10n` and check its output: it lists any untranslated messages per locale, and there must be none. The generated `app_localizations*.dart` files are not committed.
5. Run `flutter analyze`.
6. Run focused tests when the string change affects behavior (for example plural/select logic). For announcement templates, run `flutter test test/features/announcements/` — it checks bucket and commonness coverage per locale and lints for gendered determiners before `{name}`.
7. Manually check the changed screens in at least one non-English locale and look for overflow/truncation in both portrait and landscape. For announcements, hear them via **Settings → Announcements → Preview**.

### Pull Request Checklist for Translation Changes

- Include only translation-related edits in a translation PR.
- Mention which locales were updated, and which surfaces the change covers (UI strings, spoken announcements, native strings, docs).
- Call out any intentionally untranslated terms.
- Add screenshots when the change affects layout-sensitive UI text.

For deeper localization conventions, see `docs/developer/localization.md`. For the spoken announcement templates specifically, see `assets/announcements/README.md`.

## Adding a New Language

A new language touches many files outside `lib/l10n/`. An ARB-only pass leaves the app speaking English, showing English permission prompts, and linking to English policies. The list below is the full set; use the "Who" column to see what you are expected to deliver. Maintainers finish the rest before the language ships, so a community PR that covers the contributor rows is complete.

In the paths below, `<loc>` is the language code (for example `ko`). Keep every locale list sorted the way its neighbors are.

### In the app

| # | What | Files | Who |
|---|------|-------|-----|
| 1 | UI strings | Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<loc>.arb`, set `"@@locale": "<loc>"`, translate every value (drop the `@key` metadata). `flutter gen-l10n` registers the locale automatically. | Contributor |
| 2 | Spoken announcements | Copy `assets/announcements/templates_en.json` to `templates_<loc>.json`, set `"locale"`, rewrite every bucket and commonness bin (see `assets/announcements/README.md`). | Contributor |
| 3 | App language picker | Add a `DropdownMenuItem` with the native language name to the app-language dropdown in `lib/features/settings/settings_screen.dart`. | Contributor |
| 4 | Android widget strings | Copy `android/app/src/main/res/values/strings.xml` to `values-<loc>/strings.xml` and translate it. | Contributor |
| 5 | iOS strings | Add a `<loc>` entry to every key in `ios/Runner/InfoPlist.xcstrings` (app name and permission prompts) and `ios/Runner/Localizable.xcstrings` (Shortcuts/Siri action), and add `<loc>` to `knownRegions` in `ios/Runner.xcodeproj/project.pbxproj`. iOS uses Apple's codes, for example `zh-Hans` for `zh`. | Contributor (maintainers can do the project file) |
| 6 | Announcement tests | Add `<loc>` to the locale lists in `test/features/announcements/templates_buckets_test.dart`, `templates_commonness_test.dart`, and `templates_gender_lint_test.dart`. If the language has articles or gendered demonstratives, list them in the gender-lint map. | Contributor |
| 7 | Species-name lookup | If the taxonomy stores the language's species names under a different code than the app locale (Bokmål `nb` → `no`, Chinese `zh` → `zh-CN`), add the alias in `lib/shared/models/taxonomy_species.dart` with a test in `test/shared/models/taxonomy_species_test.dart`. If the language is missing from the species-language picker (`_speciesLanguages` in `settings_screen.dart`) but the taxonomy has names for it, add it there. | Contributor or maintainer |
| 8 | Species descriptions | Build `assets/species_data/descriptions_<loc>.json.gz`, add `<loc>` to `SpeciesDescriptionService.availableLocales` (and its test), and add it to `DESCRIPTION_LOCALES` in the species bundle script. The script is maintainer tooling and not in the repository. | Maintainer |

### On the docs site

| # | What | Files | Who |
|---|------|-------|-----|
| 9 | Policies | `docs/privacy.<loc>.md` and `docs/acceptable-use.<loc>.md`, `<loc>` in `AppConstants.policyDocsLocales` (`lib/core/constants/app_constants.dart`) and `test/core/constants/app_constants_test.dart`, plus a locale block in `mkdocs.yml` (`locale`, `name`, `build: true`, `nav_translations`). | Contributor (policy text reviewed by maintainers) |
| 10 | User guide | `docs/index.<loc>.md` and every `docs/user/*.<loc>.md`, then `<loc>` in `AppConstants.docsLocales` and its test. Until this is done, in-app help links open the English guide, which is acceptable for a first release. | Contributor (optional) |

### Listings and project docs

| # | What | Files | Who |
|---|------|-------|-----|
| 11 | Locale lists in docs | The localization bullet in `README.md`, the language table in `docs/developer/localization.md`, the locale list in `assets/announcements/README.md`, the [Supported Locales](#supported-locales) table above (with the register you used), and the locale lists in `AGENTS.md` and `.github/copilot-instructions.md`. | Contributor |
| 12 | Changelog | One line under `## Unreleased` in `CHANGELOG.md`. | Contributor |
| 13 | Store listing | All five sections of `dev/store/store-desc.md` (both subtitles, promo text, short description, keywords). | Contributor (optional) or maintainer |
| 14 | Store screenshots | Captions in `dev/mockups/mockups.copy.md` (then `node sync-copy.js`); in `dev/mockups/mockups.config.js` the language `name` plus entries in `featureGraphic.taglines` and `featureGraphicHomeSubtitles`; a line-breaking rule in `mockups.css` if the script needs one. Then render. See `dev/mockups/README.md`. | Maintainer |
| 15 | Release notes | Add the store locale tag (for example `ko-KR`) to the locale list in `dev/build_release.dart`. | Maintainer |

Before opening the pull request, run `flutter gen-l10n` (no untranslated messages), `flutter analyze`, and `flutter test`, then switch the app to the new language and walk through every mode in portrait and landscape.

## Pull Request Guidelines

1. **Target branch**: open pull requests against `main`.
2. **Branch naming**: `feat/description`, `fix/description`, `docs/description`, `l10n/description`
3. **Commit messages**: Use one-line [Conventional Commits](https://www.conventionalcommits.org/), with a scope where it helps
   - `feat(spectrogram): add color map selector`
   - `fix(audio): resolve buffer overflow`
   - `docs(user): update survey guide`
4. **Keep PRs focused**: One feature or fix per PR; do not mix unrelated changes.
5. **Tests**: Add tests for new functionality.
6. **Documentation**: Update relevant docs for user-facing changes.
7. **Changelog**: Add user-visible changes to the `Unreleased` section of `CHANGELOG.md`, one or two sentences per bullet.
8. **Versioning**: Do not change the version in `pubspec.yaml`, version badges, or add a new version header to `CHANGELOG.md`. Maintainers handle releases.
9. **Model files**: Do not modify the ONNX models or `assets/models/model_config.json` unless the change is about the models and has been discussed in an issue.

## Reporting Issues

- Use GitHub Issues with the appropriate template (bug report or feature request).
- For bugs, include the app version (Settings → About), device and OS version, and steps to reproduce. If you build from source, include your Flutter version.
- Attach logs if relevant (`flutter logs`), and a screenshot or screen recording for UI problems.
- Report security vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE) that covers this repository. The bundled model weights are covered separately by [MODEL_LICENSE](MODEL_LICENSE).

## Code of Conduct

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.
