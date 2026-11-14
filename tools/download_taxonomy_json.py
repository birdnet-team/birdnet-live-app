#!/usr/bin/env python3
"""Download the public BirdNET taxonomy JSON export.

Usage:
    python tools/download_taxonomy_json.py
    python tools/download_taxonomy_json.py --force
"""

import argparse
import shutil
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT_DIR = ROOT / "tools" / "data"
DOWNLOAD_URL = "https://birdnet.tu-chemnitz.de/taxonomy/api/download/json"
USER_AGENT = "BirdNET-Live-Builder/1.0"


def resolve_filename(content_disposition: str | None) -> str:
    """Extract the server-provided filename from the response headers."""
    if not content_disposition:
        return "birdnet_taxonomy.json"

    for part in content_disposition.split(";"):
        part = part.strip()
        if part.startswith("filename="):
            return part.split("=", 1)[1].strip('"')

    return "birdnet_taxonomy.json"


def main() -> None:
    parser = argparse.ArgumentParser(description="Download the BirdNET taxonomy JSON export")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory to write the downloaded taxonomy JSON into",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite an existing file if it is already present",
    )
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)

    request = urllib.request.Request(DOWNLOAD_URL, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        filename = resolve_filename(response.headers.get("Content-Disposition"))
        output_path = args.output_dir / filename

        if output_path.exists() and not args.force:
            print(f"Taxonomy JSON already exists: {output_path}")
            return

        with output_path.open("wb") as output_file:
            shutil.copyfileobj(response, output_file)

    size_mb = output_path.stat().st_size / 1024 / 1024
    print(f"Downloaded taxonomy JSON to {output_path} ({size_mb:.1f} MB)")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit("Download canceled.")