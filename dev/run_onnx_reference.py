#!/usr/bin/env python3
"""
Reference ONNX inference script — ground truth for Flutter test validation.

Loads the same ONNX model used by the Flutter app, runs it on dev/soundscape.wav
(resampled to 32 kHz to match the model's expected input), and prints the top
detections for each 3-second window.  The output JSON file is consumed by the
Flutter integration test to verify that the Dart inference pipeline produces
matching results.

Usage:
    python dev/run_onnx_reference.py

Writes dev/reference_detections.json (every window) and refreshes the
integration-test fixtures in assets/test_fixtures/ (soundscape_32k.raw,
test_windows.bin, test_windows_meta.json).  Run it after every model change,
then push the fixtures to the device as described in docs/developer/testing.md.
"""

import csv
import json
import os
import sys

import numpy as np

try:
    import onnxruntime as ort
except ImportError:
    sys.exit("Install onnxruntime:  pip install onnxruntime")

try:
    import librosa
except ImportError:
    sys.exit("Install librosa:  pip install librosa")


# ---------------------------------------------------------------------------
# Paths (relative to repo root) — model/labels read from model_config.json so
# this always tracks whatever audio model the app currently ships.
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)

_MODELS_DIR = os.path.join(REPO_ROOT, "assets", "models")
with open(os.path.join(_MODELS_DIR, "model_config.json"), encoding="utf-8") as _f:
    _cfg = json.load(_f)
_audio_cfg = _cfg["audioModel"]

MODEL_PATH = os.path.join(_MODELS_DIR, _audio_cfg["onnx"]["modelFile"])
LABELS_PATH = os.path.join(_MODELS_DIR, _audio_cfg["labels"]["file"])
SOUNDSCAPE_PATH = os.path.join(SCRIPT_DIR, "soundscape.wav")
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "reference_detections.json")
FIXTURES_DIR = os.path.join(REPO_ROOT, "assets", "test_fixtures")

# Model parameters (from assets/models/model_config.json)
SAMPLE_RATE = 32_000
WINDOW_SEC = 3
WINDOW_SAMPLES = SAMPLE_RATE * WINDOW_SEC  # 96 000
HOP_SEC = 1  # 1-second hop between windows (non-overlapping would be 3)
CONFIDENCE_THRESHOLD = 0.10  # low threshold to capture all meaningful preds
TOP_K = 10


def load_labels(path: str) -> list[dict]:
    """Parse the labels CSV the way the app does: delimiter and column names
    from model_config.json, no quoting."""
    cfg = _audio_cfg["labels"]
    cols = cfg["columns"]
    labels = []
    with open(path, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f, delimiter=cfg["delimiter"], quoting=csv.QUOTE_NONE)
        for row in reader:
            labels.append({
                "index": int(row[cols["index"]]),
                "scientificName": row[cols["scientificName"]],
                "commonName": row[cols["commonName"]],
            })
    labels.sort(key=lambda label: label["index"])
    if [label["index"] for label in labels] != list(range(len(labels))):
        sys.exit("Label indices are not 0..N-1")
    return labels


def main():
    # --- Load model ---
    print(f"Loading model: {MODEL_PATH}")
    sess = ort.InferenceSession(MODEL_PATH, providers=["CPUExecutionProvider"])
    input_name = sess.get_inputs()[0].name
    input_shape = sess.get_inputs()[0].shape
    print(f"  Input: name={input_name}, shape={input_shape}")
    for out in sess.get_outputs():
        print(f"  Output: name={out.name}, shape={out.shape}")

    # --- Load labels ---
    labels = load_labels(LABELS_PATH)
    print(f"  Labels: {len(labels)} classes")
    class_count = sess.get_outputs()[0].shape[-1]
    if class_count != len(labels):
        sys.exit(f"Model has {class_count} outputs but the labels file has {len(labels)} rows")

    # --- Load audio (resample to 32 kHz) ---
    print(f"Loading audio: {SOUNDSCAPE_PATH}")
    audio, sr = librosa.load(SOUNDSCAPE_PATH, sr=SAMPLE_RATE, mono=True)
    print(f"  Loaded: {len(audio)} samples @ {sr} Hz "
          f"({len(audio)/sr:.1f}s)")

    # Clip to [-1, 1]
    audio = np.clip(audio, -1.0, 1.0).astype(np.float32)

    # --- Slide windows ---
    hop_samples = HOP_SEC * SAMPLE_RATE
    results = []

    num_windows = max(1, (len(audio) - WINDOW_SAMPLES) // hop_samples + 1)
    print(f"Running inference on {num_windows} windows "
          f"(window={WINDOW_SEC}s, hop={HOP_SEC}s)...")

    for w in range(num_windows):
        start = w * hop_samples
        end = start + WINDOW_SAMPLES
        chunk = audio[start:end]

        # Zero-pad if needed
        if len(chunk) < WINDOW_SAMPLES:
            chunk = np.pad(chunk, (0, WINDOW_SAMPLES - len(chunk)))

        # Shape: [1, WINDOW_SAMPLES]
        inp = chunk.reshape(1, -1).astype(np.float32)

        # Run model
        outputs = sess.run(None, {input_name: inp})

        # Find predictions output (match by name)
        output_names = [o.name for o in sess.get_outputs()]
        pred_idx = output_names.index("predictions") if "predictions" in output_names else 0
        preds = outputs[pred_idx][0]  # shape: [num_classes]

        # Top-K
        top_indices = np.argsort(preds)[::-1][:TOP_K]
        window_detections = []
        for idx in top_indices:
            score = float(preds[idx])
            if score < CONFIDENCE_THRESHOLD:
                continue
            label = labels[idx]
            window_detections.append({
                "speciesIndex": int(idx),
                "scientificName": label["scientificName"],
                "commonName": label["commonName"],
                "confidence": round(score, 6),
            })

        start_sec = round(start / SAMPLE_RATE, 2)
        end_sec = round(end / SAMPLE_RATE, 2)
        results.append({
            "windowIndex": w,
            "startSec": start_sec,
            "endSec": end_sec,
            "detections": window_detections,
        })

        det_str = ", ".join(
            f"{d['commonName']}={d['confidence']:.3f}"
            for d in window_detections[:3]
        )
        print(f"  [{start_sec:6.1f}s - {end_sec:6.1f}s] "
              f"{len(window_detections)} det: {det_str}")

    # --- Write output ---
    output = {
        "modelFile": os.path.basename(MODEL_PATH),
        "sampleRate": SAMPLE_RATE,
        "windowSeconds": WINDOW_SEC,
        "hopSeconds": HOP_SEC,
        "confidenceThreshold": CONFIDENCE_THRESHOLD,
        "topK": TOP_K,
        "soundscapeFile": "soundscape.wav",
        "windows": results,
    }

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2)

    print(f"\nReference detections written to: {OUTPUT_PATH}")
    print(f"Total windows: {len(results)}")
    total_dets = sum(len(w["detections"]) for w in results)
    print(f"Total detections: {total_dets}")

    # --- Save raw 32 kHz audio for Flutter integration test ---
    os.makedirs(FIXTURES_DIR, exist_ok=True)
    raw_path = os.path.join(FIXTURES_DIR, "soundscape_32k.raw")
    audio.tofile(raw_path)
    print(f"Raw 32 kHz audio saved to: {raw_path} ({os.path.getsize(raw_path)} bytes)")

    # --- Generate compact test fixture (selected windows only) ---
    # Pick ~10 diverse windows: high confidence, empty, diverse species.
    selected_indices = [0, 1, 7, 16, 33, 49, 61, 71, 80, 117]
    fixture_windows = []
    fixture_audio = bytearray()
    for sel_i, w_idx in enumerate(selected_indices):
        start = w_idx * hop_samples
        end = start + WINDOW_SAMPLES
        chunk = audio[start:end]
        if len(chunk) < WINDOW_SAMPLES:
            chunk = np.pad(chunk, (0, WINDOW_SAMPLES - len(chunk)))
        fixture_audio.extend(chunk.tobytes())
        fixture_windows.append({
            "fixtureIndex": sel_i,
            "originalWindowIndex": w_idx,
            "startSec": round(start / SAMPLE_RATE, 2),
            "endSec": round(end / SAMPLE_RATE, 2),
            "detections": results[w_idx]["detections"],
        })

    fixture_audio_path = os.path.join(FIXTURES_DIR, "test_windows.bin")
    with open(fixture_audio_path, "wb") as f:
        f.write(fixture_audio)

    fixture_meta = {
        "modelFile": os.path.basename(MODEL_PATH),
        "sampleRate": SAMPLE_RATE,
        "windowSamples": WINDOW_SAMPLES,
        "numWindows": len(selected_indices),
        "confidenceThreshold": CONFIDENCE_THRESHOLD,
        "topK": TOP_K,
        "windows": fixture_windows,
    }
    fixture_meta_path = os.path.join(FIXTURES_DIR, "test_windows_meta.json")
    with open(fixture_meta_path, "w", encoding="utf-8") as f:
        json.dump(fixture_meta, f, indent=2)

    print(f"Test fixture audio: {fixture_audio_path} "
          f"({os.path.getsize(fixture_audio_path)} bytes, "
          f"{len(selected_indices)} windows)")
    print(f"Test fixture metadata: {fixture_meta_path}")


if __name__ == "__main__":
    main()
