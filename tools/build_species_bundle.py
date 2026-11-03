#!/usr/bin/env python3
"""Build the offline species bundle for BirdNET Live.

Downloads species images, extracts descriptions per locale, and rebuilds
taxonomy.csv with all needed common-name columns.

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
import re
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
DEFAULT_TAXONOMY_JSON = TOOLS_DIR / "data" / "birdnet_taxonomy_0.2-Jun2026.json"
LEGACY_TAXONOMY_JSON = ROOT / "dev" / "birdnet_taxonomy_0.2-Jun2026.json"
TAXONOMY_DOWNLOAD_URL = "https://birdnet.cornell.edu/taxonomy/api/download/json"
# The API names its export after the taxonomy version, e.g.
# BirdNET_Taxonomy_v0.5-Nov2026.json; match the prefix case-insensitively so
# the lookup behaves the same on Linux CI and on Windows.
TAXONOMY_JSON_PREFIX = "birdnet_taxonomy"
TAXONOMY_JSON_GLOB = f"{TAXONOMY_JSON_PREFIX}*.json"


def _audio_labels_from_config() -> Path:
    """Resolve the audio labels CSV from model_config.json (falls back to 5K)."""
    models_dir = ROOT / "assets" / "models"
    try:
        with open(models_dir / "model_config.json", encoding="utf-8") as f:
            cfg = json.load(f)
        return models_dir / cfg["audioModel"]["labels"]["file"]
    except Exception:
        return models_dir / "BirdNET+_V3.0-preview3_Global_5K-pruned_Labels.csv"


DEFAULT_LABELS_CSV = _audio_labels_from_config()
DEFAULT_IMAGE_WIDTH = 480
DEFAULT_IMAGE_HEIGHT = 320
DEFAULT_WEBP_QUALITY = 70
DEFAULT_DOWNLOAD_WORKERS = 50

# App interface languages — one gzip description file per locale
DESCRIPTION_LOCALES = ["en", "de", "fr", "es", "cs", "pt", "it", "nl", "pl", "ru"]

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
# Model label -> taxonomy mapping
# ---------------------------------------------------------------------------
#
# Some model labels use older genus names or "(Domestic type)" qualifiers that
# are absent from the taxonomy export.  We resolve each label to its canonical
# taxonomy entry so the app can show taxonomy-canonical names, images, and
# descriptions for these species too.  The model label remains the join key
# (taxonomy.csv `scientific_name`); the resolved canonical name is emitted as
# the `canonical_scientific_name` column.
#
# Resolution order (see resolve_taxonomy_entry):
#   1. Exact match on the model label.
#   2. Curated synonym alias (CURATED_LABEL_ALIASES).
#   3. Normalized match: strip "(...)" qualifiers, collapse whitespace,
#      case-insensitive.
#
# Labels that still do not resolve keep their raw model name (no taxonomy data).
#
# Every alias target below was verified to exist in the taxonomy export and to
# be a 1:1 mapping (no two labels share a target, no target is itself a label).
CURATED_LABEL_ALIASES = {
    # Treefrogs: Hypsiboas -> Boana (genus revision)
    "Hypsiboas albomarginatus": "Boana albomarginata",
    "Hypsiboas albopunctatus": "Boana albopunctata",
    "Hypsiboas bischoffi": "Boana bischoffi",
    "Hypsiboas boans": "Boana boans",
    "Hypsiboas cinerascens": "Boana cinerascens",
    "Hypsiboas faber": "Boana faber",
    "Hypsiboas lanciformis": "Boana lanciformis",
    "Hypsiboas pardalis": "Boana pardalis",
    "Hypsiboas pulchellus": "Boana pulchella",
    "Hypsiboas punctatus": "Boana punctata",
    "Hypsiboas raniceps": "Boana raniceps",
    "Hypsiboas riojanus": "Boana riojana",
    "Hypsiboas rosenbergi": "Boana rosenbergi",
    # Woodpeckers: Dryobates -> Leuconotopicus
    "Dryobates villosus": "Leuconotopicus villosus",
    "Dryobates borealis": "Leuconotopicus borealis",
    "Dryobates albolarvatus": "Leuconotopicus albolarvatus",
    "Dryobates arizonae": "Leuconotopicus arizonae",
    "Dryobates stricklandi": "Leuconotopicus stricklandi",
    "Dryobates fumigatus": "Leuconotopicus fumigatus",
    # Ground squirrels: Spermophilus -> Otospermophilus / Urocitellus
    "Spermophilus beecheyi": "Otospermophilus beecheyi",
    "Spermophilus variegatus": "Otospermophilus variegatus",
    "Spermophilus beldingi": "Urocitellus beldingi",
    "Spermophilus columbianus": "Urocitellus columbianus",
    "Spermophilus parryii": "Urocitellus parryii",
    "Spermophilus richardsonii": "Urocitellus richardsonii",
    "Spermophilus armatus": "Urocitellus armatus",
    # Primates and other mammals
    "Callicebus donacophilus": "Plecturocebus donacophilus",
    "Callicebus moloch": "Plecturocebus moloch",
    "Cebus apella": "Sapajus apella",
    "Cebus nigritus": "Sapajus nigritus",
    "Lagothrix lagotricha": "Lagothrix lagothricha",
    "Galago demidoff": "Galagoides demidoff",
    "Bunopithecus hoolock": "Hoolock hoolock",
    "Pteropus giganteus": "Pteropus medius",
    "Physeter catodon": "Physeter macrocephalus",
    # Birds and amphibians
    "Coccothraustes vespertinus": "Hesperiphona vespertina",
    "Coccothraustes abeillei": "Hesperiphona abeillei",
    "Anthropoides virgo": "Grus virgo",
    "Hyliola regilla": "Pseudacris regilla",
    # Curated examples for labels that may return in future model builds
    # (no-ops while the label is absent from the model set).
    "Homo Sapiens": "Homo sapiens",
    "Canis lupus (Domestic type)": "Canis familiaris",
}


def _normalize_sci(name: str) -> str:
    """Lowercase, strip parenthetical qualifiers, and collapse whitespace."""
    name = re.sub(r"\(.*?\)", "", name)
    return re.sub(r"\s+", " ", name).strip().lower()


def build_normalized_index(taxonomy: dict[str, dict]) -> dict[str, dict]:
    """Index taxonomy entries by their normalized scientific name."""
    index: dict[str, dict] = {}
    for sci, entry in taxonomy.items():
        index.setdefault(_normalize_sci(sci), entry)
    return index


def resolve_taxonomy_entry(
    sci_name: str,
    taxonomy: dict[str, dict],
    norm_index: dict[str, dict],
) -> dict | None:
    """Resolve a model label to its taxonomy entry (exact, alias, normalized)."""
    entry = taxonomy.get(sci_name)
    if entry is not None:
        return entry
    alias = CURATED_LABEL_ALIASES.get(sci_name)
    if alias and alias in taxonomy:
        return taxonomy[alias]
    return norm_index.get(_normalize_sci(sci_name))

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def cache_key(scientific_name: str) -> str:
    """Deterministic filename-safe hash for download cache."""
    return hashlib.sha256(scientific_name.encode()).hexdigest()[:16]


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


def load_model_species(labels_csv: Path) -> dict[str, dict]:
    """Load model species from the semicolon-delimited labels CSV.

    Returns {scientific_name: {idx, id, com_name, class, order}}.
    """
    species = {}
    with open(labels_csv, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f, delimiter=";")
        for row in reader:
            species[row["sci_name"]] = {
                "idx": int(row["idx"]),
                "id": int(row["id"]),
                "com_name": row["com_name"],
                "class": row["class"],
                "order": row["order"],
            }
    return species


def load_taxonomy_json(json_path: Path) -> dict[str, dict]:
    """Load taxonomy JSON, indexed by scientific_name."""
    print(f"Loading taxonomy JSON from {json_path} ...")
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return {entry["scientific_name"]: entry for entry in data}


def download_and_resize_images(
    model_species: dict[str, dict],
    taxonomy: dict[str, dict],
    norm_index: dict[str, dict],
    target_w: int,
    target_h: int,
    quality: int,
    workers: int,
) -> dict[str, str]:
    """Download, resize, and save species images.

    Returns {scientific_name: status} where status is
    'ok', 'cached', 'no_entry', or 'failed'.
    """
    IMAGE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    IMAGE_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    results: dict[str, str] = {}

    # Build work items: (scientific_name, birdnet_id, image_url, cache_path)
    work = []
    for sci_name in model_species:
        entry = resolve_taxonomy_entry(sci_name, taxonomy, norm_index)
        if entry is None:
            results[sci_name] = "no_entry"
            continue
        birdnet_id = entry["birdnet_id"]
        img_info = entry.get("image", {})
        url = img_info.get("medium") or img_info.get("thumb")
        if not url:
            results[sci_name] = "no_url"
            continue
        cp = IMAGE_CACHE_DIR / f"{cache_key(sci_name)}.dat"
        work.append((sci_name, birdnet_id, url, cp))

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


def extract_descriptions(
    model_species: dict[str, dict],
    taxonomy: dict[str, dict],
    norm_index: dict[str, dict],
    locales: list[str],
) -> dict[str, int]:
    """Extract and write gzip-compressed description JSON files.

    Returns {locale: species_count} for species with descriptions.
    """
    DATA_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    coverage: dict[str, int] = {}

    for locale in locales:
        descs: dict[str, str] = {}
        for sci_name in model_species:
            entry = resolve_taxonomy_entry(sci_name, taxonomy, norm_index)
            if entry is None:
                continue
            desc_map = entry.get("descriptions", {})
            text = desc_map.get(locale, "")
            if text:
                descs[sci_name] = text

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


def rebuild_taxonomy_csv(
    model_species: dict[str, dict],
    taxonomy: dict[str, dict],
    norm_index: dict[str, dict],
) -> int:
    """Rebuild taxonomy.csv with all needed columns including it+ko.

    Returns number of rows written.
    """
    # Column order: metadata columns, then common_name_{locale} for all locales
    meta_cols = [
        "birdnet_id", "scientific_name", "canonical_scientific_name",
        "common_name", "common_name_alt",
        "taxon_group", "inat_id", "ebird_code", "gbif_id", "ncbi_id",
        "avibase_id", "birdlife_id", "ml_taxon_code", "xc_name",
        "observationorg_id", "observations_count", "description_source",
        "image_url", "image_author", "image_license", "image_source",
    ]
    name_cols = [f"common_name_{loc}" for loc in ALL_NAME_LOCALES]
    wiki_cols = [f"wikipedia_url_{loc}" for loc in WIKIPEDIA_URL_LOCALES]
    header = meta_cols + name_cols + wiki_cols

    rows = []
    for sci_name, model_info in sorted(model_species.items()):
        entry = resolve_taxonomy_entry(sci_name, taxonomy, norm_index)
        if entry is None:
            # Minimal row for species not in taxonomy JSON
            row = {col: "" for col in header}
            # Derive birdnet_id from the labels id field
            row["birdnet_id"] = f"BN{model_info['id']:05d}"
            row["scientific_name"] = sci_name
            row["canonical_scientific_name"] = sci_name
            row["common_name"] = model_info["com_name"]
            row["taxon_group"] = model_info["class"]
            rows.append(row)
            continue

        cn_map = entry.get("common_names", {})
        img_info = entry.get("image", {})

        row = {
            "birdnet_id": entry.get("birdnet_id", ""),
            "scientific_name": sci_name,
            "canonical_scientific_name": entry.get("scientific_name", sci_name),
            "common_name": entry.get("common_name", ""),
            "common_name_alt": entry.get("common_name_alt", ""),
            "taxon_group": entry.get("taxon_group", ""),
            "inat_id": str(entry.get("inat_id", "")),
            "ebird_code": entry.get("ebird_code", ""),
            "gbif_id": str(entry.get("gbif_id", "")),
            "ncbi_id": str(entry.get("ncbi_id", "")),
            "avibase_id": entry.get("avibase_id", ""),
            "birdlife_id": str(entry.get("birdlife_id", "")),
            "ml_taxon_code": entry.get("ml_taxon_code", ""),
            "xc_name": entry.get("xc_name", ""),
            "observationorg_id": str(entry.get("observationorg_id", "")),
            "observations_count": str(entry.get("observations_count", "")),
            "description_source": entry.get("description_source", ""),
            "image_url": img_info.get("medium", ""),
            "image_author": entry.get("image_author", ""),
            "image_license": entry.get("image_license", ""),
            "image_source": entry.get("image_source", ""),
        }

        # Common names
        for loc in ALL_NAME_LOCALES:
            row[f"common_name_{loc}"] = cn_map.get(loc, "")

        # Wikipedia URLs
        wiki_map = entry.get("wikipedia_urls", {})
        for loc in WIKIPEDIA_URL_LOCALES:
            row[f"wikipedia_url_{loc}"] = wiki_map.get(loc, "")

        rows.append(row)

    # Write CSV
    with open(TAXONOMY_CSV_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=header)
        writer.writeheader()
        writer.writerows(rows)

    print(f"  taxonomy.csv: {len(rows)} rows, {len(header)} columns")
    return len(rows)


def print_report(
    model_count: int,
    taxonomy_count: int,
    image_results: dict[str, str],
    desc_coverage: dict[str, int],
    csv_rows: int,
) -> None:
    """Print a summary report."""
    print("\n" + "=" * 60)
    print("BUILD SPECIES BUNDLE — SUMMARY")
    print("=" * 60)
    print(f"Model species:      {model_count}")
    print(f"Resolved entries:   {taxonomy_count} ({model_count - taxonomy_count} unmatched)")
    print()

    # Image stats
    ok = sum(1 for s in image_results.values() if s == "ok")
    cached = sum(1 for s in image_results.values() if s == "cached")
    failed = sum(1 for s in image_results.values() if s == "failed")
    no_entry = sum(1 for s in image_results.values() if s == "no_entry")
    no_url = sum(1 for s in image_results.values() if s == "no_url")
    print(f"Images:             {ok} downloaded, {cached} from cache, "
          f"{failed} failed, {no_entry} no taxonomy entry, {no_url} no URL")

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
    for loc, count in desc_coverage.items():
        pct = count / model_count * 100
        print(f"  {loc}: {count}/{model_count} ({pct:.0f}%)")
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
        help="Path to model labels CSV (semicolon-delimited)",
    )
    parser.add_argument("--image-width", type=int, default=DEFAULT_IMAGE_WIDTH)
    parser.add_argument("--image-height", type=int, default=DEFAULT_IMAGE_HEIGHT)
    parser.add_argument("--quality", type=int, default=DEFAULT_WEBP_QUALITY)
    parser.add_argument("--workers", type=int, default=DEFAULT_DOWNLOAD_WORKERS)
    args = parser.parse_args()

    taxonomy_json = resolve_taxonomy_json(args.taxonomy_json)
    labels_csv = resolve_labels_csv(args.labels_csv)

    # 1. Load data
    print("Step 1: Loading species data ...")
    model_species = load_model_species(labels_csv)
    taxonomy = load_taxonomy_json(taxonomy_json)
    norm_index = build_normalized_index(taxonomy)
    resolved = sum(
        1 for s in model_species
        if resolve_taxonomy_entry(s, taxonomy, norm_index) is not None
    )
    exact = sum(1 for s in model_species if s in taxonomy)
    print(f"  Model species: {len(model_species)}")
    print(f"  Taxonomy entries: {len(taxonomy)}")
    print(f"  Resolved: {resolved} (exact {exact}, aliased {resolved - exact})")
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
            model_species, taxonomy, norm_index,
            args.image_width, args.image_height, args.quality, args.workers,
        )
        print()

        # 4. Extract descriptions
        print("Step 4: Descriptions ...")
        desc_coverage = extract_descriptions(
            model_species, taxonomy, norm_index, DESCRIPTION_LOCALES
        )
        print()

        # 5. Rebuild taxonomy.csv
        print("Step 5: Rebuilding taxonomy.csv ...")
        csv_rows = rebuild_taxonomy_csv(model_species, taxonomy, norm_index)
        print()

        # 6. Report
        print_report(len(model_species), resolved, image_results, desc_coverage, csv_rows)
    except Exception:
        restore_backups(backups)
        print("Build failed; restored previous species bundle outputs.", file=sys.stderr)
        raise
    else:
        restore_preserved_output_files(backups)
        discard_backups(backups)


if __name__ == "__main__":
    main()
