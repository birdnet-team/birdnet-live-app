#!/usr/bin/env python3
"""
Build the app-ready November 2026 model set.

Inputs (this folder):
  BirdNET+_V3.0_Global_12K_FP16_pruned.onnx      audio classifier, 11,725 classes
  BirdNET+_V3.0_Global_12K_Labels.csv            ix,birdnet_id,scientific_name,...
  BirdNET+_Geomodel_V3.0.4_Global_14K_FP16.onnx  geo model, 14,082 species
  BirdNET+_Geomodel_V3.0.4_Global_14K_Labels.txt id<TAB>scientific_name<TAB>common_name
  BirdNET+_Geomodel_V3.0.4_Global_14K_species_above_3pct.tsv
                                                 output of scan_geomodel_global.py
  birdnet_taxonomy_0.5-Nov2026.csv               taxonomy export (naming authority)

Species selection:
  1. Audio classes join the taxonomy by `birdnet_id` (stable between the audio
     model and the taxonomy). Geo labels have no stable id and are resolved by
     scientific name, then by the taxonomy's `scientific_name_aliases`.
  2. A species is kept when the geo model predicts it at >= GEO_CUTOFF in at
     least one cell of the global 1-degree x 48-week scan.
  3. Where the taxonomy lumps several geo labels into one species (for example
     six swamphens under Porphyrio porphyrio), the geo model keeps all of those
     rows and the species score is their maximum.
  4. Non-animal sound classes (taxonomy `record_type == sound_class`) have no
     range, so the geo model does not know them. They stay in the audio model
     and the app shows them only when the user opts in.
  5. Homo sapiens ("Human") is kept like any other species the geo model
     knows. Its purpose is to flag recordings that contain human voices.

Outputs:
  assets/models/   pruned + speed-rewritten audio model, pruned geo model,
                   label files, score blacklist, model_config.json
  tools/           legacy_species.csv (species earlier releases could detect
                   that this model cannot) and sound_class_names.json (the
                   model's names of its sound classes), both consumed by
                   tools/build_species_bundle.py when it writes taxonomy.csv
  test/fixtures/   released_species_names.txt: every scientific name a release
                   has ever stored in a session. A unit test checks that each
                   one still resolves in taxonomy.csv.
  release/         (this folder, untracked) the standalone model release: the
                   two ONNX files the app ships, one unified labels file for
                   both, README.md, MODEL_LICENSE.md (Apache 2.0),
                   ACCEPTABLE_USE.md, SHA256SUMS, and a zip of it all. The
                   layout follows birdnet-team/birdnet-V3.0-dev; the model card
                   is RELEASE_README.md.

Run from the repo root with the venv active:

    python dev/models/november2026/scan_geomodel_global.py
    python dev/models/november2026/build_november2026.py
    python tools/build_species_bundle.py
    python dev/run_onnx_reference.py

The full procedure, with the checks to run afterwards, is in
docs/developer/model-update.md.

Requires: onnx, numpy, onnxruntime.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audio_graph_opt import optimize_audio_graph  # noqa: E402

for _stream in (sys.stdout, sys.stderr):
    _stream.reconfigure(encoding="utf-8", errors="replace")
csv.field_size_limit(10**9)

REPO = Path(__file__).resolve().parents[3]
SRC = Path(__file__).resolve().parent
ASSETS = REPO / "assets" / "models"
TOOLS = REPO / "tools"

AUDIO_SRC = SRC / "BirdNET+_V3.0_Global_12K_FP16_pruned.onnx"
AUDIO_LABELS_SRC = SRC / "BirdNET+_V3.0_Global_12K_Labels.csv"
GEO_SRC = SRC / "BirdNET+_Geomodel_V3.0.4_Global_14K_FP16.onnx"
GEO_LABELS_SRC = SRC / "BirdNET+_Geomodel_V3.0.4_Global_14K_Labels.txt"
GEO_SCAN_SRC = SRC / "BirdNET+_Geomodel_V3.0.4_Global_14K_species_above_3pct.tsv"
TAX_SRC = SRC / "birdnet_taxonomy_0.5-Nov2026.csv"

AUDIO_VERSION = "3.0"
# The model team released two different geo models as V3.0.4 (June and
# November 2026). They are told apart by the file name: the June build was
# "..._10K-pruned_FP16.onnx", this one carries the BNL tag below.
GEO_VERSION = "3.0.4"
# Marks the model set as the BirdNET Live build: pruned to the species both
# models share and rewritten for on-device speed.
BUILD_TAG = "BNL"
TAXONOMY_VERSION = "0.5-Nov2026"
GEO_CUTOFF = 0.03

CONFIG_OUT = ASSETS / "model_config.json"
LEGACY_SPECIES_OUT = TOOLS / "legacy_species.csv"
RELEASED_NAMES_OUT = REPO / "test" / "fixtures" / "released_species_names.txt"
SOUND_CLASS_NAMES_OUT = TOOLS / "sound_class_names.json"
RELEASE_ROOT = SRC / "release"
RELEASE_README_SRC = SRC / "RELEASE_README.md"
MODEL_LICENSE_SRC = REPO / "MODEL_LICENSE"
ACCEPTABLE_USE_SRC = REPO / "ACCEPTABLE_USE.md"

AUDIO_HEAD_INITS = ["head.weight", "head.bias"]
GEO_HEAD_INITS = ["model.species_head.head.3.weight", "model.species_head.head.3.bias"]

# Taxonomic classes the app has a per-class toggle for. A kept species must
# belong to one of them; everything else that survives is a sound class.
WILDLIFE_CLASSES = {"Aves", "Mammalia", "Amphibia", "Insecta"}

# Label files the app parses with a plain split, so these characters must not
# occur inside a field.
LABEL_DELIMITER = ";"


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

def load_taxonomy():
    with TAX_SRC.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    by_id = {r["birdnet_id"]: r for r in rows}
    by_name: dict[str, dict] = {r["scientific_name"]: r for r in rows}
    if len(by_id) != len(rows) or len(by_name) != len(rows):
        raise AssertionError("taxonomy has duplicate ids or scientific names")
    canonical = set(by_name)
    for r in rows:
        for alias in split_aliases(r["scientific_name_aliases"]):
            if alias in canonical:
                # A current name always beats a synonym of another taxon.
                continue
            if by_name.setdefault(alias, r) is not r:
                raise AssertionError(f"alias '{alias}' maps to two taxa")
    return rows, by_id, by_name


def split_aliases(value: str | None) -> list[str]:
    return [p.strip() for p in (value or "").replace(";", "|").split("|") if p.strip()]


def load_audio_labels() -> list[dict]:
    with AUDIO_LABELS_SRC.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    if [int(r["ix"]) for r in rows] != list(range(len(rows))):
        raise AssertionError("audio label ix column is not 0..N-1 in file order")
    return rows


def load_geo_labels() -> list[dict]:
    labels = []
    with GEO_LABELS_SRC.open(encoding="utf-8") as f:
        for idx, line in enumerate(f):
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 3:
                raise AssertionError(f"geo label line {idx + 1} is not 3 tab fields")
            labels.append({"idx": idx, "id": parts[0].strip(),
                           "sci_name": parts[1].strip(), "com_name": parts[2].strip()})
    return labels


def load_geo_scan() -> dict[int, float]:
    """Geo row index -> global max score, for rows that reached the cutoff."""
    with GEO_SCAN_SRC.open(encoding="utf-8", newline="") as f:
        return {int(r["index"]): float(r["max_score"])
                for r in csv.DictReader(f, delimiter="\t")
                if float(r["max_score"]) >= GEO_CUTOFF}


# ---------------------------------------------------------------------------
# Species selection
# ---------------------------------------------------------------------------

def select_species(audio, geo, by_id, by_name, scan):
    # Geo rows grouped by the taxon they resolve to.
    geo_rows_by_taxon: dict[str, list[dict]] = {}
    geo_unresolved = []
    for g in geo:
        taxon = by_name.get(g["sci_name"])
        if taxon is None:
            geo_unresolved.append(g["sci_name"])
            continue
        geo_rows_by_taxon.setdefault(taxon["birdnet_id"], []).append(g)

    kept = []
    stats = {"sound_class": 0, "no_geo": 0, "below_cutoff": 0, "other_class": 0}
    for a in audio:
        taxon = by_id.get(a["birdnet_id"])
        if taxon is None:
            raise AssertionError(f"audio class {a['birdnet_id']} missing from taxonomy")
        if taxon["record_type"] == "sound_class":
            stats["sound_class"] += 1
            kept.append({"audio": a, "taxon": taxon, "geo_rows": [], "sound_class": True})
            continue
        rows = geo_rows_by_taxon.get(taxon["birdnet_id"])
        if not rows:
            stats["no_geo"] += 1
            continue
        if not any(r["idx"] in scan for r in rows):
            stats["below_cutoff"] += 1
            continue
        if taxon["taxon_group"] not in WILDLIFE_CLASSES:
            stats["other_class"] += 1
            raise AssertionError(
                f"{taxon['scientific_name']} is in class {taxon['taxon_group']}, "
                "which the app has no toggle for")
        # The row carrying the canonical name leads; alias rows follow.
        rows = sorted(rows, key=lambda r: (r["sci_name"] != taxon["scientific_name"], r["idx"]))
        kept.append({"audio": a, "taxon": taxon, "geo_rows": rows, "sound_class": False})

    kept.sort(key=lambda k: int(k["audio"]["ix"]))
    species = [k for k in kept if not k["sound_class"]]
    sounds = [k for k in kept if k["sound_class"]]
    lumped = [k for k in species if len(k["geo_rows"]) > 1]

    print(f"  audio source classes           : {len(audio):,}")
    print(f"  geo source labels              : {len(geo):,}")
    print(f"  geo labels not in taxonomy     : {len(geo_unresolved):,} {sorted(geo_unresolved)}")
    print(f"  geo rows >= {GEO_CUTOFF} globally      : {len(scan):,}")
    print(f"  audio: no geo counterpart      : {stats['no_geo']:,}")
    print(f"  audio: geo never >= cutoff     : {stats['below_cutoff']:,}")
    print(f"  kept species (audio and geo)   : {len(species):,}")
    print(f"  kept sound classes (audio only): {len(sounds):,}")
    print(f"  species with lumped geo rows   : {len(lumped):,}")
    for k in lumped:
        print(f"      {k['taxon']['scientific_name']}: "
              + ", ".join(r["sci_name"] for r in k["geo_rows"]))

    names = [k["taxon"]["scientific_name"] for k in kept]
    if len(set(names)) != len(names):
        raise AssertionError("duplicate scientific names in the kept set")
    return species, sounds


# ---------------------------------------------------------------------------
# ONNX pruning
# ---------------------------------------------------------------------------

def prune_init(model, name: str, indices: np.ndarray) -> None:
    for init in model.graph.initializer:
        if init.name == name:
            arr = numpy_helper.to_array(init)
            init.CopyFrom(numpy_helper.from_array(np.take(arr, indices, axis=0), name=name))
            return
    raise ValueError(f"initializer not found: {name}")


def update_dims(model, old_count: int, new_count: int) -> None:
    for vi in list(model.graph.output) + list(model.graph.value_info):
        for dim in vi.type.tensor_type.shape.dim:
            if dim.dim_value == old_count:
                dim.dim_value = new_count
    for init in model.graph.initializer:
        if init.data_type != TensorProto.INT64:
            continue
        arr = numpy_helper.to_array(init)
        if (arr == old_count).any():
            init.CopyFrom(numpy_helper.from_array(
                np.where(arr == old_count, new_count, arr), name=init.name))


def store_large_fp32_weights_as_fp16(model, min_elements: int = 1024) -> int:
    """Keep large fp32 weights as fp16 on disk behind a constant Cast.

    The source model ships every weight as fp16, so widening them to fp32 in
    the file adds bytes without adding information. ONNX Runtime folds a Cast
    of an initializer when the session is created, so there is no per-inference
    cost; `verify` checks that the folded graph has no such Cast left.
    """
    g = model.graph
    count = 0
    new_nodes = []
    for init in list(g.initializer):
        if init.data_type != TensorProto.FLOAT or init.name.startswith("fft_"):
            continue
        arr = numpy_helper.to_array(init)
        if arr.size < min_elements:
            continue
        half = arr.astype(np.float16)
        if not np.array_equal(half.astype(np.float32), arr):
            raise AssertionError(f"{init.name} is not exactly representable in fp16")
        stored = f"{init.name}_fp16"
        for n in g.node:
            for i, name in enumerate(n.input):
                if name == init.name:
                    n.input[i] = f"{init.name}_fp32"
        new_nodes.append(helper.make_node(
            "Cast", [stored], [f"{init.name}_fp32"], to=TensorProto.FLOAT,
            name=f"{init.name}_to_fp32"))
        init.CopyFrom(numpy_helper.from_array(half, stored))
        count += 1
    nodes = new_nodes + list(g.node)
    del g.node[:]
    g.node.extend(nodes)
    return count


def build_audio_model(out_path: Path, indices: np.ndarray, old_count: int) -> None:
    model = onnx.load(str(AUDIO_SRC))
    for name in AUDIO_HEAD_INITS:
        prune_init(model, name, indices)
    update_dims(model, old_count, len(indices))
    fp16_convs = optimize_audio_graph(model)
    stored = store_large_fp32_weights_as_fp16(model)
    onnx.checker.check_model(model)
    onnx.save(model, str(out_path))
    print(f"    {out_path.name}: {old_count:,} -> {len(indices):,} classes, "
          f"{fp16_convs} fp16 convolutions, {stored} fp16-stored weights, "
          f"{out_path.stat().st_size / 1e6:.1f} MB")


def build_geo_model(out_path: Path, species: list[dict], old_count: int) -> None:
    """Prune the geo head and fold lumped rows into one output per species."""
    source_rows = sorted({r["idx"] for k in species for r in k["geo_rows"]})
    position = {idx: pos for pos, idx in enumerate(source_rows)}
    model = onnx.load(str(GEO_SRC))
    g = model.graph
    for name in GEO_HEAD_INITS:
        prune_init(model, name, np.asarray(source_rows, dtype=np.int64))
    update_dims(model, old_count, len(source_rows))

    out = g.output[0]
    out_name = out.name
    rows_name = f"{out_name}_rows"
    producer = next(n for n in g.node if out_name in n.output)
    producer.output[list(producer.output).index(out_name)] = rows_name

    width = max(len(k["geo_rows"]) for k in species)
    gathered = []
    for level in range(width):
        idx = np.asarray(
            [position[k["geo_rows"][min(level, len(k["geo_rows"]) - 1)]["idx"]] for k in species],
            dtype=np.int64)
        g.initializer.append(numpy_helper.from_array(idx, f"species_rows_{level}"))
        name = f"{out_name}_level_{level}"
        g.node.append(helper.make_node(
            "Gather", [rows_name, f"species_rows_{level}"], [name], axis=1,
            name=f"species_gather_{level}"))
        gathered.append(name)
    if width == 1:
        g.node.append(helper.make_node("Identity", gathered, [out_name], name="species_max"))
    else:
        g.node.append(helper.make_node("Max", gathered, [out_name], name="species_max"))
    for dim in out.type.tensor_type.shape.dim:
        if dim.dim_value == len(source_rows):
            dim.dim_value = len(species)
    onnx.checker.check_model(model)
    onnx.save(model, str(out_path))
    print(f"    {out_path.name}: {old_count:,} -> {len(species):,} species "
          f"from {len(source_rows):,} rows, {out_path.stat().st_size / 1e6:.1f} MB")


# ---------------------------------------------------------------------------
# Labels, blacklist, sidecar files, config
# ---------------------------------------------------------------------------

def label_names(k: dict) -> tuple[str, str]:
    """Scientific + English common name of a kept class.

    Species use the taxonomy's canonical names. Sound classes use the model's
    own label, which names what the class was trained on.
    """
    if k["sound_class"]:
        return k["audio"]["scientific_name"], k["audio"]["common_name"]
    return k["taxon"]["scientific_name"], k["taxon"]["common_name"]


def write_audio_labels(path: Path, kept: list[dict]) -> None:
    fields = ["idx", "birdnet_id", "sci_name", "com_name", "class"]
    with path.open("w", encoding="utf-8", newline="") as f:
        f.write(LABEL_DELIMITER.join(fields) + "\n")
        for idx, k in enumerate(kept):
            sci, com = label_names(k)
            row = [str(idx), k["taxon"]["birdnet_id"], sci, com, k["taxon"]["taxon_group"]]
            for value in row:
                if LABEL_DELIMITER in value or "\n" in value or not value:
                    raise AssertionError(f"unsafe or empty label field: {row}")
            f.write(LABEL_DELIMITER.join(row) + "\n")


def write_geo_labels(path: Path, species: list[dict]) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        for k in species:
            sci, com = label_names(k)
            row = [k["taxon"]["birdnet_id"], sci, com]
            if any("\t" in v or not v for v in row):
                raise AssertionError(f"unsafe or empty geo label field: {row}")
            f.write("\t".join(row) + "\n")


def carry_blacklist(old_cfg: dict, kept: list[dict], by_name: dict, out_path: Path) -> None:
    """Re-key the hand-curated score blacklist (English common name -> factor)
    onto the new labels by way of the scientific name."""
    old_audio = old_cfg["audioModel"]
    old_blacklist = json.loads((ASSETS / old_audio["scoreBlacklistFile"]).read_text(encoding="utf-8"))
    cols = old_audio["labels"]["columns"]
    old_text = git_show_asset(old_audio["labels"]["file"])
    old_rows = list(csv.DictReader(old_text.splitlines(), delimiter=old_audio["labels"]["delimiter"]))
    old_sci_by_com = {r[cols["commonName"]]: r[cols["scientificName"]] for r in old_rows}
    new_com_by_id = {k["taxon"]["birdnet_id"]: label_names(k)[1] for k in kept}

    out: dict[str, float] = {}
    for com, factor in old_blacklist.items():
        sci = old_sci_by_com.get(com) or next(
            (label_names(k)[0] for k in kept if label_names(k)[1] == com), None)
        taxon = by_name.get(sci) if sci else None
        new_com = new_com_by_id.get(taxon["birdnet_id"]) if taxon else None
        if new_com is None:
            raise AssertionError(f"score blacklist entry '{com}' has no class in the new model")
        if new_com != com:
            print(f"    blacklist: '{com}' -> '{new_com}'")
        out[new_com] = factor
    out_path.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"    score blacklist: {len(out)} entries -> {out_path.name}")


def git_show_asset(name: str) -> str:
    """Read an asset as last committed, so a rebuild does not depend on files
    this script already replaced."""
    path = ASSETS / name
    if path.exists():
        return path.read_text(encoding="utf-8-sig")
    out = subprocess.run(
        ["git", "-C", str(REPO), "log", "--all", "-1", "--format=%H", "--", f"assets/models/{name}"],
        check=True, capture_output=True, text=True).stdout.strip()
    if not out:
        raise FileNotFoundError(name)
    # The commit that last touched the file may be its deletion; use its parent.
    for rev in (out, f"{out}~1"):
        r = subprocess.run(["git", "-C", str(REPO), "show", f"{rev}:assets/models/{name}"],
                           capture_output=True)
        if r.returncode == 0:
            return r.stdout.decode("utf-8-sig")
    raise FileNotFoundError(name)


def historic_label_names() -> dict[str, str]:
    """Every scientific name a released label file has carried, with the
    English common name it was shown under.

    "Released" means present in a tagged version or in the current HEAD.
    Label files that only ever existed between releases (the unpruned 11K/12K
    sets from early development) never reached a user's device.
    """
    revs = subprocess.run(
        ["git", "-C", str(REPO), "tag", "--list"],
        check=True, capture_output=True, text=True).stdout.split() + ["HEAD"]
    seen_blobs: set[str] = set()
    names: dict[str, str] = {}
    for rev in revs:
        tree = subprocess.run(
            ["git", "-C", str(REPO), "ls-tree", "-r", rev, "--", "assets/models"],
            check=True, capture_output=True, text=True).stdout.splitlines()
        for line in tree:
            meta, path = line.split("\t", 1)
            blob = meta.split()[2]
            if "labels" not in path.lower() or blob in seen_blobs:
                continue
            seen_blobs.add(blob)
            text = subprocess.run(["git", "-C", str(REPO), "cat-file", "-p", blob],
                                  check=True, capture_output=True).stdout.decode("utf-8-sig")
            lines = text.splitlines()
            if not lines:
                continue
            if "\t" in lines[0]:
                for l in lines:
                    p = l.split("\t")
                    if len(p) >= 2 and p[1].strip():
                        names.setdefault(p[1].strip(), p[2].strip() if len(p) > 2 else "")
                continue
            header = lines[0].split(";")
            if "sci_name" not in header:
                raise AssertionError(f"unknown historic label format in {path}: {header}")
            si, ci = header.index("sci_name"), header.index("com_name")
            for l in lines[1:]:
                p = l.split(";")
                if len(p) > ci and p[si].strip():
                    names.setdefault(p[si].strip(), p[ci].strip())
    return names


def write_released_names(kept: list[dict]) -> None:
    """Every scientific name a user's stored sessions may contain: the names
    of all released label files plus the ones this build ships."""
    names = set(historic_label_names()) | {label_names(k)[0] for k in kept}
    RELEASED_NAMES_OUT.parent.mkdir(parents=True, exist_ok=True)
    RELEASED_NAMES_OUT.write_text("\n".join(sorted(names)) + "\n", encoding="utf-8")
    print(f"    released species names: {len(names):,} -> {RELEASED_NAMES_OUT.name}")


def write_legacy_species(kept: list[dict], by_name: dict) -> None:
    """Species earlier app releases could store in a session but the current
    model has no class for. tools/build_species_bundle.py adds a taxonomy row
    for each, so their names, translations, images and links keep working."""
    current_ids = {k["taxon"]["birdnet_id"] for k in kept}
    historic = historic_label_names()
    rows: dict[str, dict] = {}
    unresolved = []
    for sci, com in sorted(historic.items()):
        taxon = by_name.get(sci)
        if taxon is None:
            unresolved.append((sci, com))
            continue
        if taxon["birdnet_id"] in current_ids:
            continue
        rows.setdefault(taxon["birdnet_id"], {
            "birdnet_id": taxon["birdnet_id"],
            "scientific_name": taxon["scientific_name"],
            "common_name": taxon["common_name"],
        })
    with LEGACY_SPECIES_OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["birdnet_id", "scientific_name", "common_name"],
                           lineterminator="\n")
        w.writeheader()
        for row in sorted(rows.values(), key=lambda r: r["scientific_name"]):
            w.writerow(row)
    print(f"    legacy species: {len(rows):,} of {len(historic):,} historic names "
          f"-> {LEGACY_SPECIES_OUT.name}")
    print(f"    historic names the taxonomy cannot resolve: {len(unresolved)} "
          "(they keep showing the name stored with the detection)")
    for sci, com in unresolved:
        print(f"        {sci} ({com})")


def write_sound_class_names(sounds: list[dict]) -> None:
    """The model's own names of its sound classes, in every language the
    labels file carries.

    The labels file names each sound class completely and consistently, while
    the taxonomy has gaps for them (no Chinese name for "Siren", a different
    English name for four classes). The species bundle therefore takes sound
    class names from here and everything else from the taxonomy.
    """
    out = {}
    for k in sounds:
        a, t = k["audio"], k["taxon"]
        names = {key[len("common_name_"):]: value for key, value in a.items()
                 if key.startswith("common_name_") and value}
        out[t["birdnet_id"]] = {
            "scientific_name": a["scientific_name"],
            "taxonomy_scientific_name": t["scientific_name"],
            "common_name": a["common_name"],
            "common_names": names,
        }
    SOUND_CLASS_NAMES_OUT.write_text(
        json.dumps(out, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
    print(f"    sound class names: {len(out)} -> {SOUND_CLASS_NAMES_OUT.name}")


def write_release(names: dict, kept: list[dict], species: list[dict], size: str) -> None:
    """Package the standalone model release.

    The ONNX files are copies of the app's assets, so what is released is
    exactly what the app's unit and integration tests exercise. The labels
    file follows the layout of the model team's labels file (one row per
    audio class, every translation) and adds the geo-model index.
    """
    folder_name = f"BirdNET+_V{AUDIO_VERSION}_Global_{size}_{BUILD_TAG}"
    out = RELEASE_ROOT / folder_name
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    for key in ("audio", "geo"):
        shutil.copyfile(ASSETS / names[key], out / names[key])

    # Unified labels: `ix` is the audio output index, `geo_ix` the geo-model
    # output index (empty for sound classes, which have no range).
    geo_ix = {k["taxon"]["birdnet_id"]: i for i, k in enumerate(species)}
    with AUDIO_LABELS_SRC.open(encoding="utf-8-sig", newline="") as f:
        source_fields = list(csv.DictReader(f).fieldnames)
    name_fields = [c for c in source_fields if c.startswith("common_name_")]
    head_fields = [c for c in source_fields if not c.startswith("common_name_")]
    fields = head_fields + ["record_type", "geo_ix"] + name_fields
    labels_path = out / names["release_labels"]
    with labels_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
        w.writeheader()
        for ix, k in enumerate(kept):
            sci, com = label_names(k)
            row = {c: k["audio"].get(c, "") for c in source_fields}
            row.update({
                "ix": ix,
                "birdnet_id": k["taxon"]["birdnet_id"],
                "scientific_name": sci,
                "common_name": com,
                "taxon_group": k["taxon"]["taxon_group"],
                "record_type": k["taxon"]["record_type"],
                "geo_ix": geo_ix.get(k["taxon"]["birdnet_id"], ""),
            })
            w.writerow(row)

    # The release labels must describe the same classes, in the same order,
    # as the label files the app reads.
    with labels_path.open(encoding="utf-8", newline="") as f:
        released = list(csv.DictReader(f))
    app_audio = (ASSETS / names["audio_labels"]).read_text(encoding="utf-8").splitlines()[1:]
    app_geo = (ASSETS / names["geo_labels"]).read_text(encoding="utf-8").splitlines()
    if [r["scientific_name"] for r in released] != [l.split(LABEL_DELIMITER)[2] for l in app_audio]:
        raise AssertionError("release labels and app audio labels disagree")
    released_geo = sorted((int(r["geo_ix"]), r["scientific_name"]) for r in released if r["geo_ix"])
    if [name for _, name in released_geo] != [l.split("\t")[1] for l in app_geo]:
        raise AssertionError("release geo_ix and app geo labels disagree")
    if [i for i, _ in released_geo] != list(range(len(app_geo))):
        raise AssertionError("release geo_ix is not 0..N-1")

    readme = RELEASE_README_SRC.read_text(encoding="utf-8")
    for key, value in {
        "{AUDIO_FILE}": names["audio"],
        "{GEO_FILE}": names["geo"],
        "{LABELS_FILE}": names["release_labels"],
        "{SPECIES}": f"{len(species):,}",
        "{SOUND_CLASSES}": str(len(kept) - len(species)),
        "{CLASSES}": f"{len(kept):,}",
        "{AUDIO_VERSION}": AUDIO_VERSION,
        "{GEO_VERSION}": GEO_VERSION,
        "{TAXONOMY_VERSION}": TAXONOMY_VERSION,
        "{GEO_CUTOFF}": f"{GEO_CUTOFF:.2f}",
    }.items():
        readme = readme.replace(key, value)
    if "{" in readme.split("```")[0]:
        raise AssertionError("unfilled placeholder in the release README")
    (out / "README.md").write_text(readme, encoding="utf-8", newline="\n")

    # License and acceptable-use scaffolding, as in birdnet-V3.0-dev.
    license_text = MODEL_LICENSE_SRC.read_text(encoding="utf-8").replace("\r\n", "\n")
    start = license_text.index("Apache License\nVersion 2.0")
    header = "\n".join([
        "# Apache License 2.0 — Model Weights",
        "",
        "Copyright (c) 2026 The BirdNET Team",
        "",
        f"This license covers the BirdNET+ V{AUDIO_VERSION} {BUILD_TAG} model files in this folder: the",
        "audio model, the geo-model, and the label file.",
        "",
        "Expectations for responsible use of the models are described in",
        "[`ACCEPTABLE_USE.md`](ACCEPTABLE_USE.md); that document is guidance and does not",
        "add conditions to this license.",
        "",
        "---",
        "",
        "```",
        "",
    ])
    (out / "MODEL_LICENSE.md").write_text(
        header + license_text[start:].rstrip("\n") + "\n```\n",
        encoding="utf-8", newline="\n")
    (out / "ACCEPTABLE_USE.md").write_text(
        ACCEPTABLE_USE_SRC.read_text(encoding="utf-8").replace("\r\n", "\n"),
        encoding="utf-8", newline="\n")

    files = sorted(p for p in out.iterdir() if p.name != "SHA256SUMS")
    with (out / "SHA256SUMS").open("w", encoding="utf-8", newline="\n") as f:
        for path in files:
            f.write(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n")

    zip_path = RELEASE_ROOT / f"{folder_name}.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for path in sorted(out.iterdir()):
            z.write(path, f"{folder_name}/{path.name}")
    print(f"    release: {out}")
    for path in sorted(out.iterdir()):
        print(f"      {path.name}  ({path.stat().st_size / 1e6:.2f} MB)")
    print(f"      -> {zip_path.name}  ({zip_path.stat().st_size / 1e6:.1f} MB)")


def write_config(old_cfg: dict, names: dict, n_species: int, n_sounds: int) -> None:
    cfg = json.loads(json.dumps(old_cfg))
    total = n_species + n_sounds
    size = f"{round(n_species / 1000)}K"

    audio = cfg["audioModel"]
    audio["name"] = f"BirdNET+ V{AUDIO_VERSION} Global {size} FP16 {BUILD_TAG}"
    audio["version"] = AUDIO_VERSION
    audio["description"] = (
        f"Global classifier pruned to {n_species:,} species the geo model can "
        f"predict (birds, amphibians, mammals, and insects) plus {n_sounds} "
        "non-animal sound classes.")
    audio.pop("modelFile", None)
    audio["speciesCount"] = n_species
    audio["soundClassCount"] = n_sounds
    audio["classCount"] = total
    audio["onnx"] = {
        "modelFile": names["audio"],
        "inputName": "input",
        "outputNames": {"predictions": "predictions", "embeddings": "embeddings_out"},
    }
    audio["labels"] = {
        "file": names["audio_labels"],
        "delimiter": LABEL_DELIMITER,
        "hasHeader": True,
        "columns": {
            "index": "idx",
            "birdnetId": "birdnet_id",
            "scientificName": "sci_name",
            "commonName": "com_name",
            "className": "class",
        },
    }
    audio["scoreBlacklistFile"] = names["blacklist"]

    geo = cfg["geoModel"]
    geo["name"] = f"BirdNET+ Geomodel V{GEO_VERSION} Global {size} FP16 {BUILD_TAG}"
    geo["version"] = GEO_VERSION
    geo["description"] = (
        f"Location-based species prediction model pruned to the {n_species:,} "
        "species shared with the audio model.")
    geo["modelFile"] = names["geo"]
    geo["labelsFile"] = names["geo_labels"]
    geo["inputName"] = "input"
    geo["outputName"] = "probabilities"
    geo["speciesCount"] = n_species
    geo["defaultThreshold"] = GEO_CUTOFF

    cfg["taxonomy"] = {"name": f"BirdNET+ Taxonomy v{TAXONOMY_VERSION}", "version": TAXONOMY_VERSION}

    CONFIG_OUT.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

def verify(audio_out: Path, geo_out: Path, kept: list[dict], species: list[dict]) -> None:
    import onnxruntime as ort

    print("\nVerifying against the source models")
    rng = np.random.default_rng(0)

    # Audio: the rewritten graph computes in fp32 where the source computes in
    # fp16, so scores differ slightly. Real audio parity is checked separately
    # (dev/run_onnx_reference.py); here random input must stay within 0.1.
    src = ort.InferenceSession(str(AUDIO_SRC), providers=["CPUExecutionProvider"])
    new = ort.InferenceSession(str(audio_out), providers=["CPUExecutionProvider"])
    old_idx = np.asarray([int(k["audio"]["ix"]) for k in kept])
    for samples in (96000, 160000, 320000):
        x = (rng.standard_normal((2, samples)) * 0.05).astype(np.float32)
        ps, es = src.run(["predictions", "embeddings_out"], {"input": x})
        pn, en = new.run(["predictions", "embeddings_out"], {"input": x})
        diff = float(np.abs(ps[:, old_idx] - pn).max())
        cos = float(min(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)) for a, b in zip(es, en)))
        print(f"  audio {samples // 32000:>2}s: {ps.shape} -> {pn.shape}, "
              f"max|diff|={diff:.2e}, min embedding cosine={cos:.6f}")
        if pn.shape != (2, len(kept)) or diff > 0.1 or cos < 0.999:
            raise AssertionError("audio verification failed")

    # Constant casts must be folded away when the session is created.
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        so = ort.SessionOptions()
        so.optimized_model_filepath = str(Path(tmp) / "optimized.onnx")
        ort.InferenceSession(str(audio_out), so, providers=["CPUExecutionProvider"])
        optimized = onnx.load(so.optimized_model_filepath)
        # (On x86 ORT adds casts of its own around fp16 convolutions, which it
        # has no kernel for there; only the casts this script added count.)
        leftover = [n.name for n in optimized.graph.node
                    if n.op_type == "Cast" and n.name.endswith("_to_fp32")]
        print(f"  audio: constant casts left after ORT folding: {len(leftover)}")
        if leftover:
            raise AssertionError(f"ORT did not fold constant casts: {leftover[:5]}")

    # Geo: each species output is the max over its source rows. Pruning the
    # head changes how the Gemm kernel blocks its rows, which moves the odd
    # output by one float32 ulp (<= 1.2e-7 measured); anything larger is a bug.
    geo_tolerance = 1e-6
    src = ort.InferenceSession(str(GEO_SRC), providers=["CPUExecutionProvider"])
    new = ort.InferenceSession(str(geo_out), providers=["CPUExecutionProvider"])
    lat = rng.uniform(-90, 90, 512)
    lon = rng.uniform(-180, 180, 512)
    week = rng.integers(1, 49, 512)
    x = np.stack([lat, lon, week], axis=1).astype(np.float32)
    ps = src.run(["probabilities"], {"input": x})[0]
    pn = new.run(["probabilities"], {"input": x})[0]
    want = np.stack([ps[:, [r["idx"] for r in k["geo_rows"]]].max(axis=1) for k in species], axis=1)
    diff = float(np.abs(want - pn).max())
    print(f"  geo: {ps.shape} -> {pn.shape}, max|diff|={diff:.2e}")
    if pn.shape != (512, len(species)) or diff > geo_tolerance:
        raise AssertionError("geo verification failed")
    # The app runs the geo model one location at a time. (Batched and single
    # runs of the source model already differ by ~2e-5, so each is compared
    # against the source at the same batch size.)
    worst = 0.0
    for i in range(64):
        single_src = src.run(["probabilities"], {"input": x[i:i + 1]})[0]
        single_new = new.run(["probabilities"], {"input": x[i:i + 1]})[0]
        want = np.stack(
            [single_src[:, [r["idx"] for r in k["geo_rows"]]].max(axis=1) for k in species], axis=1)
        worst = max(worst, float(np.abs(want - single_new).max()))
    print(f"  geo: batch-1, 64 locations, max|diff|={worst:.2e}")
    if worst > geo_tolerance:
        raise AssertionError("geo batch-1 verification failed")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-verify", action="store_true")
    args = parser.parse_args()

    print("November 2026 model build")
    _, by_id, by_name = load_taxonomy()
    audio = load_audio_labels()
    geo = load_geo_labels()
    scan = load_geo_scan()

    print("\nSpecies selection")
    species, sounds = select_species(audio, geo, by_id, by_name, scan)
    kept = sorted(species + sounds, key=lambda k: int(k["audio"]["ix"]))

    size = f"{round(len(species) / 1000)}K"
    audio_stem = f"BirdNET+_V{AUDIO_VERSION}_Global_{size}_FP16_{BUILD_TAG}"
    geo_stem = f"BirdNET+_Geomodel_V{GEO_VERSION}_Global_{size}_FP16_{BUILD_TAG}"
    names = {
        # Released as they are.
        "audio": f"{audio_stem}.onnx",
        "geo": f"{geo_stem}.onnx",
        "release_labels": f"BirdNET+_V{AUDIO_VERSION}_Global_{size}_Labels.csv",
        # Read by the app only.
        "audio_labels": f"{audio_stem}_Labels.csv",
        "blacklist": f"{audio_stem}_ScoreBlacklist.json",
        "geo_labels": f"{geo_stem}_Labels.txt",
    }

    old_cfg = json.loads(subprocess.run(
        ["git", "-C", str(REPO), "show", "HEAD:assets/models/model_config.json"],
        check=True, capture_output=True).stdout.decode("utf-8"))
    if CONFIG_OUT.exists():
        current = json.loads(CONFIG_OUT.read_text(encoding="utf-8"))
        if current["audioModel"]["onnx"]["modelFile"] != names["audio"]:
            old_cfg = current
    superseded = {
        old_cfg["audioModel"]["onnx"]["modelFile"],
        old_cfg["audioModel"]["labels"]["file"],
        old_cfg["audioModel"]["scoreBlacklistFile"],
        old_cfg["geoModel"]["modelFile"],
        old_cfg["geoModel"]["labelsFile"],
    } - set(names.values())
    # The old blacklist is read before anything is written; keep its text in
    # case the new one takes the same name.

    print("\nScore blacklist")
    carry_blacklist(old_cfg, kept, by_name, ASSETS / names["blacklist"])

    print("\nModels")
    audio_indices = np.asarray([int(k["audio"]["ix"]) for k in kept], dtype=np.int64)
    build_audio_model(ASSETS / names["audio"], audio_indices, len(audio))
    build_geo_model(ASSETS / names["geo"], species, len(geo))

    print("\nLabels, sidecar files, config")
    write_audio_labels(ASSETS / names["audio_labels"], kept)
    write_geo_labels(ASSETS / names["geo_labels"], species)
    write_legacy_species(kept, by_name)
    write_released_names(kept)
    write_sound_class_names(sounds)
    write_config(old_cfg, names, len(species), len(sounds))

    if not args.no_verify:
        verify(ASSETS / names["audio"], ASSETS / names["geo"], kept, species)

    print("\nRemoving superseded assets")
    for name in sorted(superseded):
        path = ASSETS / name
        if path.exists():
            path.unlink()
            print(f"  removed {name}")

    print("\nStandalone release")
    write_release(names, kept, species, size)

    print(f"\nDone: {len(species):,} species + {len(sounds)} sound classes.")
    print("Next: python tools/build_species_bundle.py")


if __name__ == "__main__":
    main()
