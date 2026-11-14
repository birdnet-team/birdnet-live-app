# BirdNET+ V{AUDIO_VERSION} Global 10K (BNL)

The models the [BirdNET Live](https://github.com/birdnet-team/birdnet-live-app)
app runs on-device, packaged for use in other applications.

| File | What it is |
| ---- | ---------- |
| `{AUDIO_FILE}` | Audio classifier, {CLASSES} classes |
| `{GEO_FILE}` | Geo-model (V{GEO_VERSION}): which species to expect at a place and time of year, {SPECIES} species |
| `{LABELS_FILE}` | One labels file for both models |
| `MODEL_LICENSE.md` | Apache License 2.0, for the models and the labels |
| `ACCEPTABLE_USE.md` | How we expect the models to be used |
| `SHA256SUMS` | Checksums of the files above |

## What "BNL" means

Both models are built from the BirdNET+ V{AUDIO_VERSION} Global 12K audio model
([birdnet-V3.0-dev](https://github.com/birdnet-team/birdnet-V3.0-dev)) and the
V{GEO_VERSION} geo-model. BNL marks the BirdNET Live build:

- **Shared species set.** The audio model keeps a species only if the
  geo-model can predict it at {GEO_CUTOFF} or more somewhere on a global
  1-degree grid over all 48 weeks. The result is {SPECIES} species: birds,
  amphibians, mammals, and insects.
- **Sound classes.** The audio model additionally has {SOUND_CLASSES}
  non-animal sound classes (aircraft, chainsaw, engine, gun, music, siren, …).
  The geo-model has no output for them.
- **Human.** *Homo sapiens* ("Human") is a regular class of both models. Its
  purpose is to flag recordings that contain human voices, for example so an
  application can discard or blank that audio.
- **Rewritten for on-device speed.** The audio graph computes its spectrogram
  with `MatMul` instead of the `STFT` operator and runs the convolutions in
  half precision with full-precision activations. On x86-64, where ONNX
  Runtime runs those convolutions in full precision, scores match a
  full-precision build of the same weights; on arm64 they differ slightly.

Names follow BirdNET+ Taxonomy v{TAXONOMY_VERSION}.

## Labels

`{LABELS_FILE}` is comma-separated UTF-8 with a header and one row per audio
class.

| Column | Meaning |
| ------ | ------- |
| `ix` | Index of the class in the audio model's `predictions` output |
| `birdnet_id` | BirdNET taxonomy ID, e.g. `BN07148` |
| `scientific_name` | Scientific name; the class name for sound classes |
| `common_name` | English common name |
| `taxon_group` | `Aves`, `Mammalia`, `Amphibia`, `Insecta`, or the group of a sound class (`Anthropogenic`, `Geophony`, `Music`) |
| `inat_id`, `ebird_code` | iNaturalist taxon ID and eBird species code, where available |
| `record_type` | `species` or `sound_class` |
| `geo_ix` | Index of the species in the geo-model's `probabilities` output; empty for sound classes |
| `common_name_<locale>` | Common name in 36 languages; empty where no translation exists |

## Audio model

- Input `input`: float32, shape `[batch, samples]`, mono audio at 32 kHz with
  samples in [-1, 1]. The model was trained on 3-second windows (96,000
  samples); 5 and 10 seconds also work.
- Output `predictions`: float32, shape `[batch, {CLASSES}]`. These are
  probabilities; the sigmoid is part of the graph.
- Output `embeddings_out`: float32, shape `[batch, 1280]`.

## Geo-model

- Input `input`: float32, shape `[batch, 3]` with latitude in degrees,
  longitude in degrees, and week of the year from 1 to 48 (four per month).
- Output `probabilities`: float32, shape `[batch, {SPECIES}]`.

BirdNET Live treats a species as expected at a location when its probability
is {GEO_CUTOFF} or more.

## Example

```python
import csv

import librosa
import numpy as np
import onnxruntime as ort

with open("{LABELS_FILE}", encoding="utf-8", newline="") as f:
    labels = list(csv.DictReader(f))

audio = ort.InferenceSession("{AUDIO_FILE}")
geo = ort.InferenceSession("{GEO_FILE}")

# Species expected near Ithaca, NY, in the first week of June (week 21).
expected = geo.run(["probabilities"], {"input": np.array([[42.44, -76.50, 21]], dtype=np.float32)})[0][0]

# Classify the first three seconds of a recording.
samples, _ = librosa.load("recording.wav", sr=32000, mono=True)
window = samples[:96000].astype(np.float32)[np.newaxis, :]
scores = audio.run(["predictions"], {"input": window})[0][0]

for ix in np.argsort(scores)[::-1][:5]:
    label = labels[ix]
    where = f"{expected[int(label['geo_ix'])]:.2f}" if label["geo_ix"] else "n/a"
    print(f"{scores[ix]:.2f}  {label['common_name']} ({label['scientific_name']}), geo {where}")
```

## License and citation

The model weights and the labels file are licensed under the
[Apache License, Version 2.0](MODEL_LICENSE.md).

BirdNET is built to support biodiversity research and conservation. See
[ACCEPTABLE_USE.md](ACCEPTABLE_USE.md) for how we expect the models to be
used, including uses we consider unacceptable.

If you use the models in scientific work, please cite:

```bibtex
@software{BirdNET_Live_2026,
  author = {Kahl, Stefan and Börner, Andy and Mauermann, Max and Seifert, Raja Charlotte and Lasseck, Mario and Verdon, Simon and Wilhelm-Stein, Thomas and Wood, Connor M. and Eibl, Maximilian and Müller, Jörg and Klinck, Holger},
  title = {{BirdNET Live app - Professional bioacoustics in your pocket}},
  url = {https://github.com/birdnet-team/birdnet-live-app},
  year = {2026}
}
```
