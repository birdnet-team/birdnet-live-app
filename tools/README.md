# Tools

Tracked helper scripts live here so a fresh clone can reproduce the bundled
species assets without relying on ignored `dev/` files.

## Species Bundle Workflow

1. Install Python dependencies:

   ```bash
   pip install -r tools/requirements-species-bundle.txt
   ```

2. Download the public taxonomy export:

   ```bash
   python tools/download_taxonomy_json.py
   ```

3. Rebuild the bundled species assets:

   ```bash
   python tools/build_species_bundle.py
   ```

Full documentation: `docs/developer/species-bundle.md`.

## User Guide Icons

Guide content uses `:app-<AppIcons member>:` tokens, for example
`:app-libraryMusic:`. The committed SVGs in `docs/overrides/.icons/app/` come
from the app's installed icon fonts, including outlined and rounded variants.
They inherit the surrounding text color; the guide does not assign a fixed
color to controls whose color changes with the app theme.

After changing a documented icon in `lib/shared/utils/app_icons.dart`, run:

```bash
flutter pub get
python -m pip install fonttools
python tools/sync_doc_icons.py
python tools/sync_doc_icons.py --check
```

Fonttools is local build tooling; it is not an app dependency. MkDocs uses the
committed SVGs without downloading fonts or requiring Flutter or fonttools.
