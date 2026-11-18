# Updating the Models

How to replace the audio classifier, the geo-model, and the taxonomy, and what
the app guarantees to users across such an update. The steps below were used
for the November 2026 update (BirdNET+ V3.0 audio model, the V3.0.5
geo-model, taxonomy v0.5-Nov2026); the scripts are in
`dev/models/november2026/` and the model inputs in its `fp16-fix/` folder.
The resulting files carry the tag `BNL` (BirdNET
Live build) and are also published as a
[standalone release](#standalone-release).

## What an update must not break

Sessions store the scientific and English common name each species had when
it was detected. They store no label index and no BirdNET ID, and an update
never rewrites them. Everything else is resolved when a Session is shown or
exported, so the taxonomy the app ships has to cover every name a release has
ever stored:

| Case | What the app does | Where |
| ---- | ----------------- | ----- |
| Species still in the model, same name | Resolves directly. | `TaxonomyService.lookup` |
| Species renamed by the taxonomy (genus split, spelling, lump) | The old name is an alias of the current row, so the detection shows the current name, picture, translation, and links. | `scientific_name_aliases` column of `taxonomy.csv` |
| Species the new model no longer detects | The row stays in `taxonomy.csv` with `in_model = 0`. It resolves for existing Sessions but is not counted and not offered in species pickers. | `tools/legacy_species.csv` |
| Species the taxonomy has dropped altogether | The last record an export had for it, and its picture, are kept in the repository and bundled as a legacy row. | `tools/retired_species.json`, `tools/retired_species_images/` |
| Name the taxonomy does not know at all | The detection keeps the names stored with it and the placeholder picture. Nothing is hidden or dropped. | every `lookup` call site falls back to the stored names |

Species are compared across Sessions by
`TaxonomyService.canonicalScientificName`, not by the stored string. That
keeps one species from splitting in two in the Session Library's species view,
the Explore "detected" badges, Survey watchlists, and the lifetime species
history behind "first ever" alerts.

`test/shared/services/taxonomy_continuity_test.dart` enforces this. It reads
`test/fixtures/released_species_names.txt`, the scientific names of every
label file in a tagged release, and fails if one of them stops resolving.
There are no exceptions. When a taxonomy version drops a name without leaving
an alias (the Island Thrush, *Turdus poliocephalus*, was split and its
umbrella name retired in v0.5), copy the species' record from the last export
that had it into `tools/retired_species.json` and its bundled picture into
`tools/retired_species_images/<birdnet_id>.webp`; the image service no longer
serves it. The bundle build stops if a retired species reappears in the
taxonomy, so the stand-in cannot shadow a real record.

Known limits of resolving at display time:

- **Splits.** When the taxonomy narrows a species without renaming it, an
  older detection shows the narrower English name. *Cistothorus palustris*
  was "Marsh Wren" and is now "Eastern Marsh Wren", which is wrong for a
  Session from the western United States. The stored name is untouched and
  exports still carry the scientific name; only the displayed common name
  changes. Review the list of such species when a taxonomy update splits
  widely recorded ones.
- **Counts inside one Session.** `LiveSession.uniqueSpeciesCount` counts
  stored names. A Survey that was paused before an update and resumed after
  it can count a renamed species twice, and sound classes a user opted into
  are included in the count.
- **Species pickers** offer only species the current model detects. A legacy
  species still resolves wherever it is already stored, but cannot be newly
  added by hand.

BirdNET IDs are stable between the audio model's labels and the taxonomy from
v0.5 on. They were renumbered between earlier taxonomy versions, which is why
the app never stores them: exports resolve the ID from the scientific name at
export time, so Sessions of any age get the ID of the current taxonomy.

## Species selection

`build_november2026.py` decides which classes ship:

1. Audio classes and geo-model classes both join the taxonomy by
   `birdnet_id`. (Geo-model labels up to V3.0.4 had no BirdNET ID and were
   resolved by scientific name and alias. That gave the Eastern Barn Owl,
   *Tyto javanica*, the range of the Sulawesi Masked Owl; the V3.0.5
   geo-model has no class for it, so it is not in the app.)
2. A species is kept when the geo-model predicts it at 0.03 or more in at
   least one cell of a global scan (every integer latitude and longitude, all
   48 weeks; `scan_geomodel_global.py`). A species the geo-model can never
   place anywhere would be filtered out for every user anyway.
3. Non-animal sound classes (taxonomy `record_type` = `sound_class`) have no
   range. They stay in the audio model only, the location filters leave them
   alone, and the app reports them only when the user turns on
   **Non-animal sounds**.
4. *Homo sapiens* ("Human") is kept like any other species the geo-model
   knows. Its purpose is to flag recordings that contain human voices. The
   app currently treats it as an ordinary mammal; the geo-model gives it a
   flat score of about 0.56 everywhere, so it is on every location's list.
5. Every kept species must be in one of the four classes the app has an
   ignore toggle for (Aves, Mammalia, Amphibia, Insecta). The build stops
   otherwise, because the app treats any other class as a sound class.

The audio labels use the taxonomy's canonical names. Sound classes are the
exception: they carry the model's own label (`Aircraft` where the taxonomy
says `Airplane`) and its translations, recorded in
`tools/sound_class_names.json`, because the taxonomy's names for them are
incomplete.

November 2026 result: 10,048 species (8,984 birds, 422 amphibians, 329
insects, 313 mammals including Human) plus 16 sound classes. Of the 9,789 species in the
previous release, 9,551 are kept (64 of them under a new scientific name) and
238 are not: 160 have no class in the new audio model, 77 fail the geo-model
rule (19 of them have no geo-model class), and one is not in the taxonomy.
308 species are carried as legacy rows: 307 from `tools/legacy_species.csv`
and the one the taxonomy dropped from `tools/retired_species.json`.

## What the export must bring

The build only prunes the two heads. It relies on the export for the
properties the #76 inference-speed work asked for, described in the
[Model Export Checklist](model-export-checklist.md), and stops if one is
missing:

- The spectrogram is a `MatMul`-based DFT, not an `STFT` node.
- Activations run in fp32 and only convolutions run in fp16, each behind a
  cast.
- The GeM pooling before the head is the fp16-safe form (no `Pow`).

Weights that fp32 operators read are stored as fp16 behind a constant `Cast`,
which ONNX Runtime folds when it creates the session; the build checks that no
such cast survives folding, for both models.

On desktop x86-64 the audio model matches an all-fp32 build of the same
weights to 4e-6 on real and synthetic input. The first November 2026 export
was all-fp16, including constants such as the log-mel floor, and differs from
this one by up to 0.03 on individual scores.

## Procedure

Run everything from the repository root with the Python environment active
(`onnx`, `numpy`, `onnxruntime`, `librosa`, `Pillow`).

1. Put the new model files and label files into a new folder under
   `dev/models/`, download the matching taxonomy CSV into it and the taxonomy
   JSON into `tools/data/` (`python tools/download_taxonomy_json.py`), and
   copy the two scripts from the previous folder. Update the file names and
   versions at the top of the build script. The model inputs are not tracked
   in git; the scripts are.
2. Scan the geo-model: `python dev/models/<folder>/scan_geomodel_global.py`.
3. Build: `python dev/models/<folder>/build_<name>.py`. This writes the
   models, label files, score blacklist, and `model_config.json` into
   `assets/models/`, removes the files they replace, and writes
   `tools/legacy_species.csv`, `tools/sound_class_names.json`, and
   `test/fixtures/released_species_names.txt`. It then verifies the result
   against the source models and stops on any mismatch.
4. Rebuild the species bundle: `python tools/build_species_bundle.py`. See
   [Species Bundle](species-bundle.md).
5. Regenerate the reference detections and test fixtures:
   `python dev/run_onnx_reference.py`.
6. Run `flutter analyze` and `flutter test`.
7. Run the integration tests on a device or emulator; see
   [Testing](testing.md).
8. Update the species count in `README.md`, `docs/index*.md`, and
   `docs/user/faq*.md`, and add a changelog entry.

### Checks that need a person

- **Label alignment.** Confirm with field recordings that a well-known species
  activates its own label. Earlier models had the American and Mangrove Yellow
  Warbler outputs swapped; the November 2026 model does not (recordings from
  Canada activate *Setophaga aestiva*, recordings from the Caribbean and
  Galápagos activate *Setophaga petechia*), so no label correction is applied.
  Do not carry a correction forward without testing it against the new model.
- **Score blacklist.** `…_ScoreBlacklist.json` is a hand-curated map from
  English common name to a score multiplier. The build re-keys it onto the new
  labels and fails if an entry has no class left. The multipliers were tuned
  for earlier models, so a new model starts with every entry at 1.0 (no
  effect): the names stay as the list of species to watch, and a multiplier
  below 1.0 goes back in only for a species that field recordings show the
  new model still over-reports.
- **Geo-model score distribution.** The Explore tiers and the adaptive
  location filter are calibrated on the distribution of geo-model scores
  (`lib/features/inference/geo_abundance.dart`,
  `lib/features/inference/species_filter.dart`). Compare the old and new
  model at the calibration locations before trusting the constants. For
  November 2026 the two distributions agree: 59% and 61% exact zeros, the
  same tier floors, and a 0.99 correlation on shared species.
- **A file name or version change.** The extracted model copy on the device is
  named `<file name>_v<version>`. Two different models must never share that
  name. The one exception so far: the audio model was re-exported before the
  first build named `BirdNET+_V3.0_Global_10K_FP16_BNL.onnx` was released, and
  kept that name and version. Android replaces an extracted copy whose size
  differs from the bundled file, so development installs picked it up.

## Standalone release

The build also packages the models for use outside the app, in
`dev/models/<folder>/release/` (not tracked in git):

| File | Content |
| ---- | ------- |
| `BirdNET+_V3.0_Global_10K_FP16_BNL.onnx` | The audio model, byte for byte the app's asset |
| `BirdNET+_Geomodel_V3.0.5_Global_10K_FP16_BNL.onnx` | The geo-model, byte for byte the app's asset |
| `BirdNET+_V3.0_Global_10K_Labels.csv` | One labels file for both models |
| `README.md` | Model card, written from `RELEASE_README.md` next to the build script |
| `MODEL_LICENSE.md` | Apache License 2.0 for the models and the labels |
| `ACCEPTABLE_USE.md` | Copy of the repository's acceptable use policy |
| `SHA256SUMS` | Checksums |

A zip of the folder is written next to it. The layout and file naming follow
[birdnet-V3.0-dev](https://github.com/birdnet-team/birdnet-V3.0-dev): every
file starts with `BirdNET+_V3.0_Global_10K_` and all share one labels file.

The labels file has the layout of the model team's labels file (one row per
audio class in output order, `ix`, `birdnet_id`, names, `taxon_group`,
`inat_id`, `ebird_code`, and a `common_name_<locale>` column for each of 36
languages) plus `record_type` (`species` or `sound_class`) and `geo_ix`, the
species' index in the geo-model output (empty for sound classes). The build
checks that it names the same classes in the same order as the two label
files the app reads.

Because the released ONNX files are copies of the app's assets, the unit and
integration tests of the app are also the tests of the release. Publishing
(a GitHub Release or a Zenodo record) is a manual step.

## What the build verifies

- The pruned audio model against the source on random input for 3, 5, and 10
  second windows (scores and embeddings within 1e-5).
- The pruned geo-model against the source at 512 random locations and weeks,
  batched and one at a time (within 1e-5).
- That ONNX Runtime folds every constant cast of both models.
- That the geo-model scan was made with the labels file the build reads.
- That no label field contains the label delimiter, and that every score
  blacklist entry still names a class.

The unit tests then check the bundled files against each other: label counts
against `model_config.json`, a unique BirdNET ID per class, the geo-model
labels against the audio species, and every label against its `taxonomy.csv`
row.
