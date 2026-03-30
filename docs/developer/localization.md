# Localization

Internationalization with ARB files.

## Overview

BirdNET Live uses Flutter's built-in localization system with ARB (Application Resource Bundle) files.

## Supported Languages

| Language | File | Status |
|----------|------|--------|
| English | `lib/l10n/app_en.arb` | Complete |
| German | `lib/l10n/app_de.arb` | Complete |

## Adding a String

1. Add the key and value to `app_en.arb`:

    ```json
    "myNewString": "Hello world",
    "@myNewString": {
      "description": "Greeting shown on the home screen"
    }
    ```

2. Add the translation to `app_de.arb`:

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
