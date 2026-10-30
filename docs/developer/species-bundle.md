# Species Bundle

Use this workflow to reproduce the bundled species images and metadata that ship
with the app.

This tooling is intentionally separate from the ONNX model pipeline. Final
model files are expected to come from GitHub LFS; the only model-side input
used here is the bundled BirdNET labels CSV in `assets/models/`.

## What This Builds

Running the bundle rebuild does three things:

1. Downloads or reuses cached species images.
2. Rebuilds `assets/species_images/` as 480x320 WebP assets.
3. Refreshes `assets/species_data/` and `assets/models/taxonomy.csv` from the
   taxonomy export.

The image output keeps the taxonomy API's 320 px height and re-encodes the
files at WebP quality 70 to keep the bundle size under control.

## Prerequisites

- Python 3.11+ available on your path.
- The audio model labels CSV referenced by `assets/models/model_config.json` (the build script reads `audioModel.labels.file` automatically).
- Python dependencies installed:

```bash
pip install -r tools/requirements-species-bundle.txt
```

## Access The Taxonomy JSON

The taxonomy export is published by Cornell's BirdNET Species Metadata API.

- Docs: `https://birdnet.cornell.edu/taxonomy/docs`
- Direct JSON download: `https://birdnet.cornell.edu/taxonomy/api/download/json`

The easiest way to fetch the current export is:

```bash
python tools/download_taxonomy_json.py
```

That script saves the file into `tools/data/` using the filename returned by
the API, for example `tools/data/birdnet_taxonomy_0.1-Mar2026.json`.

If you prefer to download it manually, this is equivalent:

```bash
curl -L https://birdnet.cornell.edu/taxonomy/api/download/json -o tools/data/birdnet_taxonomy_0.1-Mar2026.json
```

## Rebuild The Bundle

After the taxonomy JSON is present locally, run:

```bash
python tools/build_species_bundle.py
```

Default behavior:

- Taxonomy JSON: `tools/data/birdnet_taxonomy_0.1-Mar2026.json`
- Image cache: `tools/.cache/species_images/`
- Image output: 480x320 WebP at quality 70
- Description locales: `en`, `de`, `fr`, `es`, `cs`, `pt`, `it`

You can override the inputs or encoding settings if needed:

```bash
python tools/build_species_bundle.py --taxonomy-json path/to/custom.json --quality 65
```

## Outputs

The script rewrites these generated assets:

- `assets/species_images/*.webp`
- `assets/species_data/descriptions_*.json.gz` — one gzip JSON map per locale, inflated and parsed in a `compute()` isolate by `SpeciesDescriptionService` the first time a locale is requested
- `assets/models/taxonomy.csv`

The cache in `tools/.cache/species_images/` is local-only and safe to delete.
It is not committed.

## Notes

- The builder can reuse a legacy taxonomy export in `dev/` if one already
  exists locally, but new workflows should use `tools/data/`.
- This workflow does not build ONNX models. Keep using the model pipeline and
  GitHub LFS for final model assets.