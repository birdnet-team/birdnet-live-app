<!-- TRANSLATION TODO (fr) -->

# Localization

Internationalization with ARB files and spoken announcement templates.

## Overview

BirdNET Live has **two translation surfaces**, and a complete localization covers both:

| Surface | Location | Covers |
|---------|----------|--------|
| UI strings | `lib/l10n/app_<locale>.arb` | Every label, button, help text, and message in the interface |
| Spoken phrasing | `assets/announcements/templates_<locale>.json` | The sentences the app speaks aloud when it detects a species |

UI strings use Flutter's built-in localization system with ARB (Application Resource Bundle) files. No hardcoded English in widgets.

The spoken announcement phrasing is deliberately **not** in ARB — see [Spoken Announcement Phrasing](#spoken-announcement-phrasing) below. A translation pass that covers only the ARB file leaves the app speaking English out loud, because an incomplete template file silently falls back to `templates_en.json`.

## Supported Languages

Both surfaces are complete for all 11 locales, and both must stay complete when a language is added.

| Language | UI strings | Spoken phrasing |
|----------|-----------|-----------------|
| English | `lib/l10n/app_en.arb` | `assets/announcements/templates_en.json` |
| German | `lib/l10n/app_de.arb` | `assets/announcements/templates_de.json` |
| Czech | `lib/l10n/app_cs.arb` | `assets/announcements/templates_cs.json` |
| Spanish | `lib/l10n/app_es.arb` | `assets/announcements/templates_es.json` |
| French | `lib/l10n/app_fr.arb` | `assets/announcements/templates_fr.json` |
| Italian | `lib/l10n/app_it.arb` | `assets/announcements/templates_it.json` |
| Portuguese | `lib/l10n/app_pt.arb` | `assets/announcements/templates_pt.json` |
| Dutch | `lib/l10n/app_nl.arb` | `assets/announcements/templates_nl.json` |
| Norwegian Bokmål | `lib/l10n/app_nb.arb` | `assets/announcements/templates_nb.json` |
| Polish | `lib/l10n/app_pl.arb` | `assets/announcements/templates_pl.json` |
| Russian | `lib/l10n/app_ru.arb` | `assets/announcements/templates_ru.json` |

## Translation Conventions

- **Technical terms kept in English**: Point Count, Survey, Session, Live Mode, Raven Selection Table, Smart, Gain — these are established field terms and stay in English in every locale.
- **Format identifiers kept as-is**: WAV, FLAC, CSV, JSON, GPX.
- **Prefer gender-neutral wording**: Use gender-neutral forms where they are natural and idiomatic in the target language.
- **Keep register consistent**: Within each locale, use either formal or informal phrasing consistently; do not mix styles.
- **Language names untranslated**: "English", "Deutsch", "System" appear as-is in the language picker.
- **Gain**: Kept as "Gain" in every locale (universal audio term).
- **Settings labels**: All setting titles, mode names, color map names, and status messages are localized.
- **Help text**: Written to be taxonomically agnostic ("species" not "bird species", "animal sounds" not "birdsong").

## Adding a String

1. Add the key and value to `app_en.arb`:

    ```json
    "myNewString": "Hello world",
    "@myNewString": {
      "description": "Greeting shown on the home screen"
    }
    ```

2. Add translations to every other ARB file: `app_de.arb`, `app_cs.arb`, `app_es.arb`, `app_fr.arb`, `app_it.arb`, `app_pt.arb`, `app_nl.arb`, `app_nb.arb`, `app_pl.arb`, and `app_ru.arb`:

    ```json
    "myNewString": "Hallo Welt"
    ```

3. Regenerate (automatic on build, or manually):

    ```bash
    flutter gen-l10n
    ```

4. If adding a new language, include it in the app language selector and supported locale configuration — **and add `assets/announcements/templates_<locale>.json`**, or the app will speak English in that language.

5. Use in a widget:

    ```dart
    final l10n = AppLocalizations.of(context)!;
    Text(l10n.myNewString);
    ```

## Spoken Announcement Phrasing

When announcements are enabled, the app speaks detected species aloud. Those sentences live in `assets/announcements/templates_<locale>.json`, one file per locale.

### Why not ARB

ARB models *one key → one string per locale*. An announcement bucket is a *list of interchangeable variants* that the phrasing engine picks between using an anti-repeat ring buffer, so the app does not sound like a robot repeating one sentence. Representing that in ARB would mean inventing keys like `annBucketAChatty3`, and the natural number of variants differs per language. Keeping them as JSON also lets phrasing be tuned in a PR without regenerating l10n or touching Dart.

Translators are expected to **rewrite** for their locale rather than translate line by line — these are spoken sentences, and what sounds natural in English rarely maps word for word.

### File shape

```json
{
  "locale": "de",
  "version": 4,
  "buckets": {
    "A": {
      "balanced": ["Da: {name}.", "{name}, ganz klar."],
      "chatty":   ["Da ruft {name} ganz in der Nähe."]
    }
  },
  "commonness": {
    "rare": ["Eine ziemliche Rarität bei euch — gut gehört!"],
    "seasonalAddendum": ["Und etwas außerhalb der Saison."]
  }
}
```

`balanced` is required for every bucket; `chatty` is optional and falls back to `balanced` when absent. The `minimal` verbosity level uses no templates — it speaks the bare species name.

### The ten buckets

All ten must be present in every locale. The engine selects one from detection confidence, recency, and how many species arrived at once.

| Bucket | When it is spoken | Placeholders |
|---|---|---|
| `A` | High confidence, first time / not heard recently | `{name}` |
| `B` | High confidence, heard again after a gap | `{name}` |
| `C` | High confidence, still calling (streak) | `{name}` |
| `D` | Medium confidence, fresh detection | `{name}` |
| `E` | Medium confidence, heard again after a gap | `{name}` |
| `F` | Low confidence, fresh detection | `{name}` |
| `G` | Low confidence, heard again after a gap | `{name}` |
| `H_two` | Two species at once | `{name1}`, `{name2}` |
| `H_three` | Three species at once | `{name1}`, `{name2}`, `{name3}` |
| `H_many` | Four or more at once | `{name1}`, `{name2}`, `{name3}` |

Confidence must come through in the wording: `A`/`B`/`C` state the species plainly, `D`/`E` hedge slightly, `F`/`G` hedge clearly. Flattening that gradient makes the app sound overconfident about weak detections.

### Commonness phrases

Appended on a species' first announcement of the session in Chatty mode, when location-based commonness is known. The six bins mirror the Explore screen's tiers exactly: `rare`, `scarce`, `uncommon`, `frequent`, `common`, `abundant`. The optional `seasonalAddendum` list is a tail added when the species is below its annual peak — ship an empty list to opt out.

### Rule: no article or demonstrative before `{name}`

Species names carry no grammatical gender in our data, so the app cannot inflect a determiner to agree with them — *der Zaunkönig* / *die Amsel* / *das Rotkehlchen*, *un merle* / *une mésange*, *de roodborst* / *het roodborstje*. Write around it:

```text
✗ "Das ist ein {name}."    ✓ "Da: {name}."
✗ "C'est un {name}."       ✓ "On dirait {name}."
✗ "To jest ten {name}."    ✓ "Słychać: {name}."
```

Slavic locales have no articles, but a demonstrative (`ten`/`ta`/`to`, `этот`/`эта`/`это`) forces the same agreement. Case government and past-tense verb agreement have the same problem and cannot be caught automatically.

### Locale resolution

`TemplateLibrary` resolves exact tag (`de_DE`) → language only (`de`) → `en`. The fallback is silent by design so a malformed file never crashes the runtime — which is also why a missing or incomplete file produces English speech rather than an error.

### Guard tests

```bash
flutter test test/features/announcements/
```

- `templates_buckets_test.dart` — every locale defines all ten buckets with non-empty `balanced`, and placeholders match each bucket's slots.
- `templates_commonness_test.dart` — every locale defines all six commonness bins plus `seasonalAddendum`.
- `templates_gender_lint_test.dart` — scans for gendered determiners before `{name}`. Regex-based, so it is a backstop, not a substitute for native-speaker review.

Full detail lives in `assets/announcements/README.md` and `dev/announcements.md` §3.

## Configuration

Localization is configured in `l10n.yaml` at the project root. Generated files go to `lib/l10n/`. The announcement templates need no build step — they are bundled as assets via the `assets/announcements/` entry in `pubspec.yaml`.

## Language Settings

The app supports separate UI language and species language settings, stored via `SharedPreferences`.
