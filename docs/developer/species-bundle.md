# Species Bundle

Use this workflow to reproduce the bundled species images and metadata that ship
with the app.

This tooling is separate from the ONNX model pipeline (see
[Updating the Models](model-update.md)). Final model files come from GitHub
LFS; the model-side inputs used here are the audio labels CSV in
`assets/models/` and two small files the model build writes into `tools/`.

## What This Builds

Running the bundle rebuild does three things:

1. Downloads or reuses cached species images.
2. Rebuilds `assets/species_images/` as 480x320 WebP assets.
3. Refreshes `assets/species_data/` and `assets/models/taxonomy.csv` from the
   taxonomy export.

The image output keeps the taxonomy API's 320 px height and re-encodes the
files at WebP quality 70 to keep the bundle size under control.

## Which Entries Are Bundled

The bundle has one entry per:

- **class of the audio model**: every row of the labels CSV, species and
  non-animal sound classes alike, joined to the taxonomy by BirdNET ID;
- **legacy species**: every species in `tools/legacy_species.csv`, which lists
  what earlier releases could detect and the current model cannot. They get a
  full row, an image, and descriptions so that Sessions recorded with an older
  model keep their names, translations, and pictures.

`taxonomy.csv` carries three columns for this on top of the names, IDs, and
links:

| Column | Meaning |
| ------ | ------- |
| `scientific_name_aliases` | `\|`-separated older scientific names that resolve to this row (the taxonomy's synonyms). A name that is itself a row is never an alias. |
| `in_model` | `1` for classes of the current audio model, `0` for legacy species. |
| `record_type` | `species` or `sound_class`. |

`tools/sound_class_names.json` holds the model's own names of its sound
classes in every language of the labels file. Sound class rows take their
names from there, because the taxonomy has gaps for them and names four of
them differently; where the scientific name differs, the taxonomy name becomes
an alias of the row. The taxonomy describes sound classes in English only, so
`tools/sound_class_descriptions.json` carries their descriptions in the other
description languages. It is maintained by hand: add a language there when it
is added to `DESCRIPTION_LOCALES`.

`tools/retired_species.json` holds the taxonomy records of species no export
carries any more, and `tools/retired_species_images/` their pictures at the
bundle's output size. They are bundled as legacy rows. Both are maintained by
hand; see [Updating the Models](model-update.md#what-an-update-must-not-break).

The build stops if a label's BirdNET ID is missing from the taxonomy export or
resolves to a different scientific name. That is what happens when the export
is from a taxonomy version whose IDs do not match the model's labels.

## Prerequisites

- Python 3.11+ available on your path.
- The audio model labels CSV referenced by `assets/models/model_config.json` (the build script reads `audioModel.labels` for the file name, delimiter, and column names).
- Python dependencies installed:

```bash
pip install -r tools/requirements-species-bundle.txt
```

## Access The Taxonomy JSON

The taxonomy export is published by the BirdNET+ Taxonomy service.

- Download page: `https://birdnet.tu-chemnitz.de/taxonomy/download`
- API docs: `https://birdnet.tu-chemnitz.de/taxonomy/docs`
- Direct JSON download: `https://birdnet.tu-chemnitz.de/taxonomy/api/download/json`

The easiest way to fetch the current export is:

```bash
python tools/download_taxonomy_json.py
```

That script saves the file into `tools/data/` using the filename returned by
the API, for example `tools/data/BirdNET_Taxonomy_v0.5-Nov2026.json`. The
bundle script picks up the newest `tools/data/birdnet_taxonomy*.json` without
regard to letter case, so the API may rename its export between versions.

If you prefer to download it manually, this is equivalent:

```bash
curl -L https://birdnet.tu-chemnitz.de/taxonomy/api/download/json -o tools/data/birdnet_taxonomy_0.5-Nov2026.json
```

## Rebuild The Bundle

After the taxonomy JSON is present locally, run:

```bash
python tools/build_species_bundle.py
```

Default behavior:

- Taxonomy JSON: `tools/data/birdnet_taxonomy_0.5-Nov2026.json`, the version
  the shipped models were built against (`TAXONOMY_VERSION` in the script)
- Image cache: `tools/.cache/species_images/`
- Image output: 480x320 WebP at quality 70
- Description locales: `en`, `de`, `fr`, `es`, `cs`, `pt`, `it`, `nl`, `pl`,
  `ru`, `zh`, `ko` (kept in sync with
  `SpeciesDescriptionService.availableLocales`)

You can override the inputs or encoding settings if needed:

```bash
python tools/build_species_bundle.py --taxonomy-json path/to/custom.json --quality 65
```

A failed image download fails the build, so a release never silently ships
placeholders. Re-run to retry (finished downloads are cached), or pass
`--allow-missing-images` to accept the placeholder for the failed ones.

## Outputs

The script rewrites these generated assets:

- `assets/species_images/*.webp`, named by BirdNET ID
- `assets/species_data/descriptions_*.json.gz` — one gzip JSON map per locale, keyed by the `scientific_name` of the `taxonomy.csv` row, inflated and parsed in a `compute()` isolate by `SpeciesDescriptionService` the first time a locale is requested
- `assets/models/taxonomy.csv`

`assets/species_images/dummy.webp` is hand-made and preserved across rebuilds.

The cache in `tools/.cache/species_images/` is local-only and safe to delete.
It is not committed. Cache entries are keyed by the species and the source of
its picture, so a species whose picture changed in the taxonomy is downloaded
again instead of reusing the old file.

## Notes

- The builder can reuse a taxonomy export in `dev/` if one already exists
  locally, but new workflows should use `tools/data/`.
- `taxonomy.csv` is tracked in git. The images and descriptions are not; the
  release workflow runs this script to produce them.
- This workflow does not build ONNX models. Use the model pipeline and GitHub
  LFS for final model assets.
