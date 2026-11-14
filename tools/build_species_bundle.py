#!/usr/bin/env python3
"""Build the offline species bundle for BirdNET Live.

Downloads species images, extracts descriptions per locale, and rebuilds
taxonomy.csv with all needed common-name columns.

The bundle covers two groups of taxonomy entries:

* every class of the audio model (joined to the taxonomy by `birdnet_id`), and
* the species in `tools/legacy_species.csv`: species an earlier release could
  detect and the current model cannot. They get full rows, images and
  descriptions so sessions recorded with an older model keep their names,
  translations and pictures.

Re-runnable: cached downloads are reused across runs. Output directories
are wiped and rebuilt each run (except the download cache).

Usage:
    python tools/download_taxonomy_json.py
    python tools/build_species_bundle.py
    python tools/build_species_bundle.py --quality 65
"""

import argparse
import csv
import gzip
import hashlib
import io
import json
import shutil
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required: pip install Pillow")

# Ensure console output can't crash on non-ASCII (species names, arrows) on
# Windows code pages like cp1252.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

# ---------------------------------------------------------------------------
# Defaults (overridable via CLI)
# ---------------------------------------------------------------------------
ROOT = Path(__file__).resolve().parent.parent
TOOLS_DIR = ROOT / "tools"
# The taxonomy version the shipped models were built against. The audio
# labels join the taxonomy by birdnet_id, so the bundle must be built from
# this version (or a later one that keeps the ids); the build stops if an id
# resolves to a different scientific name.
TAXONOMY_VERSION = "0.5-Nov2026"
DEFAULT_TAXONOMY_JSON = TOOLS_DIR / "data" / f"birdnet_taxonomy_{TAXONOMY_VERSION}.json"
LEGACY_TAXONOMY_JSON = ROOT / "dev" / f"birdnet_taxonomy_{TAXONOMY_VERSION}.json"
TAXONOMY_DOWNLOAD_URL = "https://birdnet.tu-chemnitz.de/taxonomy/api/download/json"
LEGACY_SPECIES_CSV = TOOLS_DIR / "legacy_species.csv"
SOUND_CLASS_NAMES_JSON = TOOLS_DIR / "sound_class_names.json"
# Hand-maintained (the two files above are written by the model build):
# translations of the sound class descriptions, and the full records and
# pictures of species no taxonomy export carries any more.
SOUND_CLASS_DESCRIPTIONS_JSON = TOOLS_DIR / "sound_class_descriptions.json"
RETIRED_SPECIES_JSON = TOOLS_DIR / "retired_species.json"
RETIRED_IMAGE_DIR = TOOLS_DIR / "retired_species_images"
# The API names its export after the taxonomy version, e.g.
# BirdNET_Taxonomy_v0.5-Nov2026.json; match the prefix case-insensitively so
# the lookup behaves the same on Linux CI and on Windows.
TAXONOMY_JSON_PREFIX = "birdnet_taxonomy"
TAXONOMY_JSON_GLOB = f"{TAXONOMY_JSON_PREFIX}*.json"


MODELS_DIR = ROOT / "assets" / "models"


def load_labels_config() -> dict:
    """The `audioModel.labels` block of model_config.json."""
    with open(MODELS_DIR / "model_config.json", encoding="utf-8") as f:
        return json.load(f)["audioModel"]["labels"]


DEFAULT_LABELS_CSV = MODELS_DIR / load_labels_config()["file"]
DEFAULT_IMAGE_WIDTH = 480
DEFAULT_IMAGE_HEIGHT = 320
DEFAULT_WEBP_QUALITY = 70
DEFAULT_DOWNLOAD_WORKERS = 50

# App interface languages with species descriptions — one gzip file per
# locale. Must stay in sync with SpeciesDescriptionService.availableLocales.
DESCRIPTION_LOCALES = [
    "en", "de", "fr", "es", "cs", "pt", "it", "nl", "pl", "ru", "zh", "ko",
]

# Wikipedia URL locales — emitted as wikipedia_url_{locale} columns in
# taxonomy.csv and consumed by the app (taxonomy_species.dart).
WIKIPEDIA_URL_LOCALES = DESCRIPTION_LOCALES

# Top-20 species-language picker locales.  Must all appear as
# common_name_{locale} columns in the rebuilt taxonomy.csv.
NAME_LOCALES = [
    "en", "de", "es", "fr", "pt", "nl", "pl", "ru", "ja", "cs",
    "tr", "sv", "da", "fi", "it", "ko", "zh-CN", "no", "uk", "sr",
]

# Additional locale columns already in the current CSV that we keep.
EXTRA_NAME_LOCALES = [
    "ca", "bg", "sk", "es_ES", "es_MX", "es_EC", "pt_PT",
    "hr", "lt", "fa", "cy", "et",
]

# Directories
IMAGE_CACHE_DIR = TOOLS_DIR / ".cache" / "species_images"
IMAGE_OUTPUT_DIR = ROOT / "assets" / "species_images"
DATA_OUTPUT_DIR = ROOT / "assets" / "species_data"
TAXONOMY_CSV_PATH = ROOT / "assets" / "models" / "taxonomy.csv"
PRESERVED_OUTPUT_FILES = ("dummy.webp",)

# All common-name locale columns (top-20 + extras), deduplicated, stable order
ALL_NAME_LOCALES = list(dict.fromkeys(NAME_LOCALES + EXTRA_NAME_LOCALES))

# ---------------------------------------------------------------------------
# Bundle entries
# ---------------------------------------------------------------------------
#
# Each bundle entry pairs the name the app looks a species up by with its
# taxonomy record:
#
#   key        taxonomy.csv `scientific_name`. For model classes this is the
#              label's scientific name, for legacy species the taxonomy name.
#   entry      the taxonomy JSON record.
#   in_model   True for classes of the current audio model.
#
# Audio labels carry the taxonomy's birdnet_id, so the join is by id. The
# scientific names must agree as well. Sound classes are the exception: their
# names come from sound_class_names.json, the model's own labels, which name
# what each class was trained on (for example "Aircraft" for the taxonomy's
# "Airplane") and are complete in every language. The taxonomy describes sound
# classes in English only; sound_class_descriptions.json adds the other
# description languages.
#
# A species the taxonomy has dropped altogether (a split whose umbrella name
# was retired) has no record to join. retired_species.json keeps the last
# record an export had for it, and retired_species_images/ its picture, so
# sessions that stored the name keep resolving.


def load_sound_class_names() -> dict[str, dict]:
    if not SOUND_CLASS_NAMES_JSON.exists():
        return {}
    with open(SOUND_CLASS_NAMES_JSON, encoding="utf-8") as f:
        names = json.load(f)
    if SOUND_CLASS_DESCRIPTIONS_JSON.exists():
        with open(SOUND_CLASS_DESCRIPTIONS_JSON, encoding="utf-8") as f:
            for birdnet_id, descriptions in json.load(f).items():
                if birdnet_id not in names:
                    sys.exit(
                        f"{SOUND_CLASS_DESCRIPTIONS_JSON.name}: {birdnet_id} "
                        "is not a sound class of the model")
                names[birdnet_id]["descriptions"] = descriptions
    return names


def load_retired_species() -> list[dict]:
    """Taxonomy records of species no export carries any more."""
    if not RETIRED_SPECIES_JSON.exists():
        return []
    with open(RETIRED_SPECIES_JSON, encoding="utf-8") as f:
        return json.load(f)


def build_bundle_entries(
    model_labels: list[dict],
    legacy_species: list[dict],
    taxonomy_by_id: dict[str, dict],
    sound_class_names: dict[str, dict],
    retired_species: list[dict] | None = None,
) -> list[dict]:
    """Resolve model labels and legacy species to taxonomy records."""
    entries: list[dict] = []
    seen_ids: set[str] = set()
    problems: list[str] = []

    for label in model_labels:
        entry = taxonomy_by_id.get(label["birdnet_id"])
        if entry is None:
            problems.append(
                f"label {label['birdnet_id']} ({label['sci_name']}) is not in the taxonomy")
            continue
        override = sound_class_names.get(label["birdnet_id"])
        expected = override["scientific_name"] if override else entry["scientific_name"]
        if label["sci_name"] != expected:
            problems.append(
                f"label {label['birdnet_id']} is '{label['sci_name']}' but the taxonomy "
                f"says '{entry['scientific_name']}'")
            continue
        seen_ids.add(label["birdnet_id"])
        entries.append({"key": label["sci_name"], "entry": entry, "in_model": True,
                        "override": override})

    for legacy in legacy_species:
        entry = taxonomy_by_id.get(legacy["birdnet_id"])
        if entry is None or entry["scientific_name"] != legacy["scientific_name"]:
            problems.append(
                f"legacy species {legacy['birdnet_id']} ({legacy['scientific_name']}) "
                "does not match the taxonomy")
            continue
        if legacy["birdnet_id"] in seen_ids:
            # The species is back in the model; the label row covers it.
            continue
        seen_ids.add(legacy["birdnet_id"])
        entries.append({"key": entry["scientific_name"], "entry": entry, "in_model": False,
                        "override": None})

    taxonomy_names = {e["scientific_name"] for e in taxonomy_by_id.values()}
    for entry in retired_species or []:
        # A retired record is a stand-in for a missing one. Once the taxonomy
        # knows the ID or the name again, its own record must be used.
        if (entry["birdnet_id"] in taxonomy_by_id
                or entry["scientific_name"] in taxonomy_names):
            problems.append(
                f"retired species {entry['birdnet_id']} ({entry['scientific_name']}) "
                f"is in the taxonomy again; remove it from {RETIRED_SPECIES_JSON.name}")
            continue
        entries.append({"key": entry["scientific_name"], "entry": entry,
                        "in_model": False, "override": None, "retired": True})

    if problems:
        shown = "\n  ".join(problems[:20])
        more = f"\n  ... and {len(problems) - 20} more" if len(problems) > 20 else ""
        sys.exit(
            "The model labels do not match this taxonomy export "
            f"(expected version {TAXONOMY_VERSION}):\n  {shown}{more}")

    keys = [e["key"] for e in entries]
    if len(set(keys)) != len(keys):
        sys.exit("Duplicate scientific names in the bundle entries.")
    return entries


def scientific_name_aliases(item: dict, all_keys: set[str]) -> list[str]:
    """Other scientific names that should resolve to this row.

    For a species these are the taxonomy's synonyms: older names that
    sessions recorded with an earlier model may carry. A sound class gets only
    its taxonomy name where the model label differs; the taxonomy's synonym
    lists for sound classes are search terms ("Motor", "Saw", "Hunting"), not
    names a session could have stored. A name that is itself a row never
    becomes an alias.
    """
    entry = item["entry"]
    is_sound_class = entry.get("record_type") == "sound_class"
    names = [] if is_sound_class else list(entry.get("scientific_name_aliases") or [])
    if entry["scientific_name"] != item["key"]:
        names.append(entry["scientific_name"])
    out: list[str] = []
    for name in names:
        name = name.strip()
        if name and name != item["key"] and name not in all_keys and name not in out:
            if "|" in name:
                sys.exit(f"Alias contains the list separator: {name}")
            out.append(name)
    return out


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def cache_key(scientific_name: str, image_source: str = "") -> str:
    """Deterministic filename-safe hash for the download cache.

    The taxonomy API serves images under a per-species URL that stays the same
    when the picture behind it changes, so the original source URL is part of
    the key: a new picture gets a new cache entry instead of the stale file.
    """
    return hashlib.sha256(f"{scientific_name}|{image_source}".encode()).hexdigest()[:16]


def resolve_taxonomy_json(taxonomy_json: Path) -> Path:
    """Resolve the taxonomy JSON path, supporting downloaded API versions."""
    if taxonomy_json.exists():
        return taxonomy_json

    if taxonomy_json == DEFAULT_TAXONOMY_JSON:
        downloaded_exports = sorted(
            (
                path
                for path in (TOOLS_DIR / "data").glob("*.json")
                if path.name.lower().startswith(TAXONOMY_JSON_PREFIX)
            ),
            key=lambda path: (path.stat().st_mtime, path.name),
            reverse=True,
        )
        if downloaded_exports:
            selected = downloaded_exports[0]
            print(f"Using downloaded taxonomy JSON at {selected} ...")
            return selected

    if taxonomy_json == DEFAULT_TAXONOMY_JSON and LEGACY_TAXONOMY_JSON.exists():
        print(f"Using legacy taxonomy JSON at {LEGACY_TAXONOMY_JSON} ...")
        return LEGACY_TAXONOMY_JSON

    sys.exit(
        "Taxonomy JSON not found. Download it first with\n"
        f"  python tools/download_taxonomy_json.py\n"
        f"or pass --taxonomy-json PATH explicitly. Looked for {taxonomy_json} "
        f"or {TOOLS_DIR / 'data' / TAXONOMY_JSON_GLOB}. "
        f"Source URL: {TAXONOMY_DOWNLOAD_URL}"
    )


def resolve_labels_csv(labels_csv: Path) -> Path:
    """Validate that the BirdNET labels CSV is available."""
    if labels_csv.exists():
        return labels_csv

    sys.exit(
        "Model labels CSV not found. Ensure the final BirdNET model assets were pulled "
        f"into assets/models/ (current path: {labels_csv})."
    )


def download_image(url: str, cache_path: Path) -> bytes | None:
    """Download an image from *url*, writing to *cache_path*.

    Returns raw bytes on success, None on failure.  Skips download if
    *cache_path* already exists.
    """
    if cache_path.exists():
        return cache_path.read_bytes()
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "BirdNET-Live-Builder/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
        cache_path.write_bytes(data)
        return data
    except Exception as exc:
        print(f"  WARN: download failed for {url}: {exc}")
        return None


def process_image(
    raw_bytes: bytes, target_w: int, target_h: int, quality: int
) -> bytes:
    """Resize a taxonomy API source image to target dimensions as WebP."""
    img = Image.open(io.BytesIO(raw_bytes))
    img = img.convert("RGB")
    img = img.resize((target_w, target_h), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="WEBP", quality=quality)
    return buf.getvalue()


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------


def load_model_labels(labels_csv: Path) -> list[dict]:
    """Load the audio model labels as the app reads them.

    The delimiter and column names come from model_config.json. Returns one
    dict per class with `birdnet_id`, `sci_name`, `com_name` and `class`.
    """
    cfg = load_labels_config()
    cols = cfg["columns"]
    labels = []
    with open(labels_csv, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f, delimiter=cfg.get("delimiter", ";"), quoting=csv.QUOTE_NONE)
        for row in reader:
            labels.append({
                "birdnet_id": row[cols["birdnetId"]],
                "sci_name": row[cols["scientificName"]],
                "com_name": row[cols["commonName"]],
                "class": row[cols["className"]],
            })
    return labels


def load_legacy_species() -> list[dict]:
    """Species earlier releases could detect; see tools/legacy_species.csv."""
    if not LEGACY_SPECIES_CSV.exists():
        return []
    with open(LEGACY_SPECIES_CSV, "r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def load_taxonomy_json(json_path: Path) -> dict[str, dict]:
    """Load taxonomy JSON, indexed by birdnet_id."""
    print(f"Loading taxonomy JSON from {json_path} ...")
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return {entry["birdnet_id"]: entry for entry in data}


def download_and_resize_images(
    entries: list[dict],
    target_w: int,
    target_h: int,
    quality: int,
    workers: int,
) -> dict[str, str]:
    """Download, resize, and save species images.

    Returns {scientific_name: status} where status is
    'ok', 'cached', 'no_url', or 'failed'.
    """
    IMAGE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    IMAGE_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    results: dict[str, str] = {}

    # Build work items: (key, birdnet_id, image_url, cache_path)
    work = []
    for item in entries:
        entry = item["entry"]
        if item.get("retired"):
            # The image service no longer has this species; the picture is
            # kept in the repository, already at the output size.
            stored = RETIRED_IMAGE_DIR / f"{entry['birdnet_id']}.webp"
            if stored.exists():
                shutil.copyfile(stored, IMAGE_OUTPUT_DIR / stored.name)
                results[item["key"]] = "cached"
            else:
                results[item["key"]] = "failed"
            continue
        img_info = entry.get("image") or {}
        url = img_info.get("medium") or img_info.get("thumb")
        if not url:
            results[item["key"]] = "no_url"
            continue
        key = cache_key(entry["scientific_name"], img_info.get("src", ""))
        work.append((item["key"], entry["birdnet_id"], url, IMAGE_CACHE_DIR / f"{key}.dat"))

    print(f"Downloading/processing {len(work)} images ({workers} workers) ...")
    done = 0
    total = len(work)

    def _process(item):
        sci, bid, url, cp = item
        already_cached = cp.exists()
        raw = download_image(url, cp)
        if raw is None:
            return sci, "failed"
        try:
            webp = process_image(raw, target_w, target_h, quality)
        except Exception as exc:
            print(f"  WARN: resize failed for {sci}: {exc}")
            # Do not keep a download that is not an image.
            cp.unlink(missing_ok=True)
            return sci, "failed"
        out_path = IMAGE_OUTPUT_DIR / f"{bid}.webp"
        out_path.write_bytes(webp)
        return sci, "cached" if already_cached else "ok"

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(_process, item): item for item in work}
        for future in as_completed(futures):
            sci, status = future.result()
            results[sci] = status
            done += 1
            if done % 500 == 0 or done == total:
                print(f"  [{done}/{total}] images processed")

    return results


def extract_descriptions(entries: list[dict], locales: list[str]) -> dict[str, int]:
    """Extract and write gzip-compressed description JSON files.

    Each file maps a taxonomy.csv `scientific_name` to its description. The
    app resolves older names to that row first, so aliases need no entries.

    Returns {locale: species_count} for species with descriptions.
    """
    DATA_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    coverage: dict[str, int] = {}

    for locale in locales:
        descs: dict[str, str] = {}
        for item in entries:
            override = (item["override"] or {}).get("descriptions") or {}
            text = override.get(locale) or (
                item["entry"].get("descriptions") or {}).get(locale, "")
            if text:
                descs[item["key"]] = text

        coverage[locale] = len(descs)

        # Write gzip JSON
        json_bytes = json.dumps(descs, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        gz_path = DATA_OUTPUT_DIR / f"descriptions_{locale}.json.gz"
        with gzip.open(gz_path, "wb", compresslevel=9) as f:
            f.write(json_bytes)
        raw_kb = len(json_bytes) / 1024
        gz_kb = gz_path.stat().st_size / 1024
        print(f"  {locale}: {len(descs)} descriptions, {raw_kb:.0f} KB raw -> {gz_kb:.0f} KB gzip")

    return coverage


def rebuild_taxonomy_csv(entries: list[dict]) -> int:
    """Rebuild taxonomy.csv: one row per bundle entry.

    Returns number of rows written.
    """
    # Column order: metadata columns, then common_name_{locale} for all locales
    meta_cols = [
        "birdnet_id", "scientific_name", "canonical_scientific_name",
        "scientific_name_aliases", "in_model", "record_type",
        "common_name", "common_name_alt",
        "taxon_group", "inat_id", "ebird_code", "gbif_id", "ncbi_id",
        "avibase_id", "birdlife_id", "ml_taxon_code", "xc_name",
        "observationorg_id", "wikidata_qid", "commonness", "description_source",
        "image_url", "image_author", "image_license", "image_source",
    ]
    name_cols = [f"common_name_{loc}" for loc in ALL_NAME_LOCALES]
    wiki_cols = [f"wikipedia_url_{loc}" for loc in WIKIPEDIA_URL_LOCALES]
    header = meta_cols + name_cols + wiki_cols

    def text(value) -> str:
        return "" if value is None else str(value)

    all_keys = {item["key"] for item in entries}
    alias_owner: dict[str, str] = {}
    rows = []
    for item in sorted(entries, key=lambda e: e["key"]):
        entry = item["entry"]
        override = item["override"] or {}
        cn_map = dict(entry.get("common_names") or {})
        cn_map.update(override.get("common_names") or {})
        img_info = entry.get("image") or {}

        aliases = scientific_name_aliases(item, all_keys)
        for alias in aliases:
            if alias_owner.setdefault(alias, item["key"]) != item["key"]:
                sys.exit(f"Alias '{alias}' belongs to both {alias_owner[alias]} and {item['key']}")

        row = {
            "birdnet_id": entry["birdnet_id"],
            "scientific_name": item["key"],
            # The name shown to the user. Model labels already use the
            # taxonomy's canonical names, so this equals the key.
            "canonical_scientific_name": item["key"],
            "scientific_name_aliases": "|".join(aliases),
            "in_model": "1" if item["in_model"] else "0",
            "record_type": entry.get("record_type", "species"),
            "common_name": override.get("common_name") or entry.get("common_name", ""),
            "common_name_alt": entry.get("common_name_alt", ""),
            "taxon_group": entry.get("taxon_group", ""),
            "inat_id": text(entry.get("inat_id")),
            "ebird_code": text(entry.get("ebird_code")),
            "gbif_id": text(entry.get("gbif_id")),
            "ncbi_id": text(entry.get("ncbi_id")),
            "avibase_id": text(entry.get("avibase_id")),
            "birdlife_id": text(entry.get("birdlife_id")),
            "ml_taxon_code": text(entry.get("ml_taxon_code")),
            "xc_name": text(entry.get("xc_name")),
            "observationorg_id": text(entry.get("observationorg_id")),
            "wikidata_qid": text(entry.get("wikidata_qid")),
            "commonness": text(entry.get("commonness")),
            "description_source": text(entry.get("description_source")),
            "image_url": img_info.get("medium", ""),
            "image_author": text(entry.get("image_author")),
            "image_license": text(entry.get("image_license")),
            "image_source": text(entry.get("image_source")),
        }

        # Common names
        for loc in ALL_NAME_LOCALES:
            row[f"common_name_{loc}"] = cn_map.get(loc, "")

        # Wikipedia URLs
        wiki_map = entry.get("wikipedia_urls") or {}
        for loc in WIKIPEDIA_URL_LOCALES:
            row[f"wikipedia_url_{loc}"] = wiki_map.get(loc, "")

        for col, value in row.items():
            if "\n" in value or "\r" in value:
                sys.exit(
                    f"Line break in {col} of {item['key']}; "
                    "the app reads the file line by line")
        rows.append(row)

    # Write CSV
    with open(TAXONOMY_CSV_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    print(f"  taxonomy.csv: {len(rows)} rows, {len(header)} columns, "
          f"{len(alias_owner)} aliases")
    return len(rows)


def print_report(
    model_count: int,
    legacy_count: int,
    image_results: dict[str, str],
    desc_coverage: dict[str, int],
    csv_rows: int,
) -> None:
    """Print a summary report."""
    print("\n" + "=" * 60)
    print("BUILD SPECIES BUNDLE — SUMMARY")
    print("=" * 60)
    print(f"Model classes:      {model_count}")
    print(f"Legacy species:     {legacy_count}")
    print()

    # Image stats
    ok = sum(1 for s in image_results.values() if s == "ok")
    cached = sum(1 for s in image_results.values() if s == "cached")
    failed = sum(1 for s in image_results.values() if s == "failed")
    no_url = sum(1 for s in image_results.values() if s == "no_url")
    print(f"Images:             {ok} downloaded, {cached} from cache, "
          f"{failed} failed, {no_url} no URL")

    # Output sizes
    img_total = sum(f.stat().st_size for f in IMAGE_OUTPUT_DIR.iterdir() if f.suffix == ".webp")
    data_total = sum(f.stat().st_size for f in DATA_OUTPUT_DIR.iterdir() if f.suffix == ".gz")
    csv_size = TAXONOMY_CSV_PATH.stat().st_size
    print(f"Image output:       {img_total / 1024 / 1024:.1f} MB ({IMAGE_OUTPUT_DIR})")
    print(f"Description output: {data_total / 1024:.0f} KB ({DATA_OUTPUT_DIR})")
    print(f"taxonomy.csv:       {csv_size / 1024:.0f} KB")
    print()

    # Description coverage
    print("Description coverage:")
    total = model_count + legacy_count
    for loc, count in desc_coverage.items():
        pct = count / total * 100
        print(f"  {loc}: {count}/{total} ({pct:.0f}%)")
    print()

    print(f"taxonomy.csv rows:  {csv_rows}")
    print("=" * 60)


def backup_existing_outputs() -> dict[Path, Path]:
    """Move current outputs aside so a failed rebuild can restore them."""
    backups: dict[Path, Path] = {}
    for path in (IMAGE_OUTPUT_DIR, DATA_OUTPUT_DIR):
        backup = path.parent / f".{path.name}.backup"
        if backup.exists():
            shutil.rmtree(backup)
        if path.exists():
            path.replace(backup)
            backups[path] = backup

    csv_backup = TAXONOMY_CSV_PATH.with_suffix(f"{TAXONOMY_CSV_PATH.suffix}.backup")
    if csv_backup.exists():
        csv_backup.unlink()
    if TAXONOMY_CSV_PATH.exists():
        TAXONOMY_CSV_PATH.replace(csv_backup)
        backups[TAXONOMY_CSV_PATH] = csv_backup

    return backups


def restore_backups(backups: dict[Path, Path]) -> None:
    """Restore the last known-good outputs after a failed rebuild."""
    for path in (IMAGE_OUTPUT_DIR, DATA_OUTPUT_DIR):
        if path.exists():
            shutil.rmtree(path)
    if TAXONOMY_CSV_PATH.exists():
        TAXONOMY_CSV_PATH.unlink()

    for target, backup in backups.items():
        if backup.exists():
            backup.replace(target)


def restore_preserved_output_files(backups: dict[Path, Path]) -> None:
    """Keep tracked placeholder assets across a successful rebuild."""
    for output_dir in (IMAGE_OUTPUT_DIR, DATA_OUTPUT_DIR):
        backup = backups.get(output_dir)
        if backup is None or not backup.is_dir():
            continue
        output_dir.mkdir(parents=True, exist_ok=True)
        for filename in PRESERVED_OUTPUT_FILES:
            src = backup / filename
            if src.exists():
                shutil.copy2(src, output_dir / filename)


def discard_backups(backups: dict[Path, Path]) -> None:
    """Delete backups after a successful rebuild."""
    for backup in backups.values():
        if backup.is_dir() and backup.exists():
            shutil.rmtree(backup)
        elif backup.exists():
            backup.unlink()


def main():
    parser = argparse.ArgumentParser(description="Build offline species bundle")
    parser.add_argument(
        "--taxonomy-json", type=Path, default=DEFAULT_TAXONOMY_JSON,
        help="Path to taxonomy JSON file",
    )
    parser.add_argument(
        "--labels-csv", type=Path, default=DEFAULT_LABELS_CSV,
        help="Path to model labels CSV (format from model_config.json)",
    )
    parser.add_argument("--image-width", type=int, default=DEFAULT_IMAGE_WIDTH)
    parser.add_argument("--image-height", type=int, default=DEFAULT_IMAGE_HEIGHT)
    parser.add_argument("--quality", type=int, default=DEFAULT_WEBP_QUALITY)
    parser.add_argument("--workers", type=int, default=DEFAULT_DOWNLOAD_WORKERS)
    parser.add_argument(
        "--allow-missing-images", action="store_true",
        help="Finish even when image downloads fail (the app shows its placeholder)",
    )
    args = parser.parse_args()

    taxonomy_json = resolve_taxonomy_json(args.taxonomy_json)
    labels_csv = resolve_labels_csv(args.labels_csv)

    # 1. Load data
    print("Step 1: Loading species data ...")
    model_labels = load_model_labels(labels_csv)
    legacy_species = load_legacy_species()
    taxonomy = load_taxonomy_json(taxonomy_json)
    entries = build_bundle_entries(
        model_labels, legacy_species, taxonomy, load_sound_class_names(),
        load_retired_species(),
    )
    model_count = sum(1 for e in entries if e["in_model"])
    legacy_count = len(entries) - model_count
    print(f"  Model classes: {model_count}")
    print(f"  Legacy species: {legacy_count}")
    print(f"  Taxonomy entries: {len(taxonomy)}")
    print(
        f"  Image output: {args.image_width}x{args.image_height} WebP @ quality {args.quality}"
    )
    print()

    backups = backup_existing_outputs()
    try:
        # 2. Clean output directories (not the cache).
        # Preserve hand-crafted fallback assets (e.g. dummy.webp) that are
        # not generated by this script and must survive a rebuild.
        _PRESERVED_IMAGES = {"dummy.webp"}
        print("Step 2: Preparing output directories ...")
        for d in (IMAGE_OUTPUT_DIR, DATA_OUTPUT_DIR):
            if d.exists():
                for f in d.iterdir():
                    if f.name not in _PRESERVED_IMAGES:
                        f.unlink()
            d.mkdir(parents=True, exist_ok=True)
        print()

        # 3. Download and resize images
        print("Step 3: Images ...")
        image_results = download_and_resize_images(
            entries, args.image_width, args.image_height, args.quality, args.workers,
        )
        failed = sorted(k for k, v in image_results.items() if v == "failed")
        if failed and not args.allow_missing_images:
            raise RuntimeError(
                f"{len(failed)} image downloads failed (first: {failed[:5]}). "
                "Re-run to retry; cached downloads are reused. Pass "
                "--allow-missing-images to ship the placeholder for them."
            )
        print()

        # 4. Extract descriptions
        print("Step 4: Descriptions ...")
        desc_coverage = extract_descriptions(entries, DESCRIPTION_LOCALES)
        print()

        # 5. Rebuild taxonomy.csv
        print("Step 5: Rebuilding taxonomy.csv ...")
        csv_rows = rebuild_taxonomy_csv(entries)
        print()

        # 6. Report
        print_report(model_count, legacy_count, image_results, desc_coverage, csv_rows)
    except Exception:
        restore_backups(backups)
        print("Build failed; restored previous species bundle outputs.", file=sys.stderr)
        raise
    else:
        restore_preserved_output_files(backups)
        discard_backups(backups)


if __name__ == "__main__":
    main()
