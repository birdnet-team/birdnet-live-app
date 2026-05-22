<!-- TRANSLATION TODO (it) -->

# Localization

Internationalization with ARB files.

## Overview

BirdNET Live uses Flutter's built-in localization system with ARB (Application Resource Bundle) files. All user-facing strings are localized — no hardcoded English in widgets.

## Supported Languages

| Language | File | Status |
|----------|------|--------|
| English | `lib/l10n/app_en.arb` | Complete |
| German | `lib/l10n/app_de.arb` | Complete |
| Czech | `lib/l10n/app_cs.arb` | Complete |
| Spanish | `lib/l10n/app_es.arb` | Complete |
| French | `lib/l10n/app_fr.arb` | Complete |
| Italian | `lib/l10n/app_it.arb` | Complete |
| Portuguese | `lib/l10n/app_pt.arb` | Complete |

## Translation Conventions

- **Technical terms kept in English**: Point Count, Survey, Session, Live Mode — these are established field terminology and stay in English in every locale.
- **Format identifiers kept as-is**: WAV, FLAC, CSV, JSON, GPX, Raven Selection Table.
- **Language names untranslated**: "English", "Deutsch", "System" appear as-is in the language picker.
- **Gain**: Kept as "Gain" in both languages (universal audio term).
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

2. Add translations to every other ARB file: `app_de.arb`, `app_cs.arb`, `app_es.arb`, `app_fr.arb`, `app_it.arb`, and `app_pt.arb`:

    ```json
    "myNewString": "Hallo Welt"
    ```

3. Regenerate (automatic on build, or manually):

    ```bash
    flutter gen-l10n
    ```

4. Use in a widget:

    ```dart
    final l10n = AppLocalizations.of(context)!;
    Text(l10n.myNewString);
    ```

## Configuration

Localization is configured in `l10n.yaml` at the project root. Generated files go to `lib/l10n/gen/`.

## Language Settings

The app supports separate UI language and species language settings, stored via `SharedPreferences`.
