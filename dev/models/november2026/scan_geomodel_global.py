#!/usr/bin/env python3
"""
Scan a BirdNET geomodel on a 1-degree global grid.

The script runs every integer latitude/longitude point for all 48 BirdNET
geomodel weeks, then writes the species that ever reach the configured cutoff.
It uses batched ONNX inference and records the max score plus the grid
coordinate/week where that max occurred.

The build (`build_november2026.py`) keeps a species only if the geo model
predicts it at or above the cutoff somewhere in this scan.

Run from the repo root (about 10 minutes on a desktop CPU):

    python dev/models/november2026/scan_geomodel_global.py

Default inputs are the November 2026 geomodel source files in this folder.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
from time import perf_counter

import numpy as np
import onnxruntime as ort


HERE = Path(__file__).resolve().parent
DEFAULT_MODEL = HERE / "BirdNET+_Geomodel_V3.0.4_Global_14K_FP16.onnx"
DEFAULT_LABELS = HERE / "BirdNET+_Geomodel_V3.0.4_Global_14K_Labels.txt"
DEFAULT_OUT = HERE / "BirdNET+_Geomodel_V3.0.4_Global_14K_species_above_3pct.tsv"
DEFAULT_SPECIES_OUT = HERE / "BirdNET+_Geomodel_V3.0.4_Global_14K_species_above_3pct_species.txt"


def load_geo_labels(path: Path) -> list[dict[str, str]]:
    labels: list[dict[str, str]] = []
    with path.open(encoding="utf-8") as f:
        for idx, line in enumerate(f):
            line = line.rstrip("\n")
            if not line.strip():
                continue
            parts = line.split("\t")
            labels.append(
                {
                    "index": str(idx),
                    "id": parts[0].strip(),
                    "scientific_name": parts[1].strip(),
                    "common_name": parts[2].strip() if len(parts) > 2 else parts[1].strip(),
                }
            )
    return labels


def iter_grid_batches(
    *,
    batch_size: int,
    lat_start: int,
    lat_stop: int,
    lon_start: int,
    lon_stop: int,
):
    batch: list[tuple[float, float, float]] = []
    for week in range(1, 49):
        for lat in range(lat_start, lat_stop + 1):
            for lon in range(lon_start, lon_stop + 1):
                batch.append((float(lat), float(lon), float(week)))
                if len(batch) == batch_size:
                    yield np.asarray(batch, dtype=np.float32)
                    batch.clear()
    if batch:
        yield np.asarray(batch, dtype=np.float32)


def scan(
    *,
    model_path: Path,
    labels_path: Path,
    out_path: Path,
    species_out_path: Path,
    cutoff: float,
    batch_size: int,
    lat_start: int,
    lat_stop: int,
    lon_start: int,
    lon_stop: int,
) -> None:
    labels = load_geo_labels(labels_path)

    session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
    input_name = session.get_inputs()[0].name
    output_name = session.get_outputs()[0].name
    output_count = session.get_outputs()[0].shape[-1]

    if output_count != len(labels):
        raise ValueError(
            f"label count mismatch: model output has {output_count}, "
            f"labels file has {len(labels)}"
        )

    max_scores = np.full(len(labels), -np.inf, dtype=np.float32)
    max_lat = np.zeros(len(labels), dtype=np.float32)
    max_lon = np.zeros(len(labels), dtype=np.float32)
    max_week = np.zeros(len(labels), dtype=np.int16)

    location_count = (lat_stop - lat_start + 1) * (lon_stop - lon_start + 1)
    total_rows = location_count * 48
    print(f"model        : {model_path}")
    print(f"labels       : {labels_path}")
    print(f"species      : {len(labels):,}")
    print(f"grid points  : {location_count:,} locations x 48 weeks = {total_rows:,} rows")
    print(f"batch size   : {batch_size:,}")
    print(f"cutoff       : {cutoff:.4f}")

    start = perf_counter()
    processed = 0
    next_report = 0.05

    for inputs in iter_grid_batches(
        batch_size=batch_size,
        lat_start=lat_start,
        lat_stop=lat_stop,
        lon_start=lon_start,
        lon_stop=lon_stop,
    ):
        probs = session.run([output_name], {input_name: inputs})[0]
        probs = np.asarray(probs, dtype=np.float32)

        batch_max = probs.max(axis=0)
        changed = batch_max > max_scores
        if np.any(changed):
            changed_indices = np.flatnonzero(changed)
            row_indices = probs[:, changed_indices].argmax(axis=0)
            max_scores[changed_indices] = batch_max[changed_indices]
            max_lat[changed_indices] = inputs[row_indices, 0]
            max_lon[changed_indices] = inputs[row_indices, 1]
            max_week[changed_indices] = inputs[row_indices, 2].astype(np.int16)

        processed += len(inputs)
        fraction = processed / total_rows
        if fraction >= next_report or processed == total_rows:
            elapsed = perf_counter() - start
            rate = processed / elapsed if elapsed else 0.0
            print(
                f"progress     : {processed:,}/{total_rows:,} "
                f"({fraction:.0%}), {rate:,.0f} rows/s"
            )
            next_report += 0.05

    keep_indices = np.flatnonzero(max_scores >= cutoff)
    keep_indices = keep_indices[np.argsort(max_scores[keep_indices])[::-1]]

    with out_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, delimiter="\t", lineterminator="\n")
        writer.writerow(
            [
                "index",
                "id",
                "scientific_name",
                "common_name",
                "max_score",
                "latitude",
                "longitude",
                "week",
            ]
        )
        for i in keep_indices:
            label = labels[int(i)]
            writer.writerow(
                [
                    label["index"],
                    label["id"],
                    label["scientific_name"],
                    label["common_name"],
                    f"{float(max_scores[i]):.8f}",
                    f"{float(max_lat[i]):.0f}",
                    f"{float(max_lon[i]):.0f}",
                    int(max_week[i]),
                ]
            )

    with species_out_path.open("w", encoding="utf-8", newline="") as f:
        for i in keep_indices:
            label = labels[int(i)]
            f.write(
                f"{label['id']}\t{label['scientific_name']}\t"
                f"{label['common_name']}\n"
            )

    elapsed = perf_counter() - start
    print(f"retained     : {len(keep_indices):,}/{len(labels):,}")
    print(f"written      : {out_path}")
    print(f"species list : {species_out_path}")
    print(f"elapsed      : {elapsed:.1f}s")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--labels", type=Path, default=DEFAULT_LABELS)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--species-out", type=Path, default=DEFAULT_SPECIES_OUT)
    parser.add_argument("--cutoff", type=float, default=0.03)
    parser.add_argument("--batch-size", type=int, default=2048)
    parser.add_argument("--lat-start", type=int, default=-90)
    parser.add_argument("--lat-stop", type=int, default=90)
    parser.add_argument("--lon-start", type=int, default=-180)
    parser.add_argument("--lon-stop", type=int, default=180)
    args = parser.parse_args()

    scan(
        model_path=args.model,
        labels_path=args.labels,
        out_path=args.out,
        species_out_path=args.species_out,
        cutoff=args.cutoff,
        batch_size=args.batch_size,
        lat_start=args.lat_start,
        lat_stop=args.lat_stop,
        lon_start=args.lon_start,
        lon_stop=args.lon_stop,
    )


if __name__ == "__main__":
    main()
