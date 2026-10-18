"""Read-only check that a local INCLUDE pose tree can feed the ablation.

The evaluation script joins each test_include.csv FilePath onto INCLUDE_POSE_ROOT
and swaps the video extension for .pkl. This checker counts those files, counts
raw videos at the same paths, and opens one pickle per category. It does not
load the checkpoint or compute accuracy.

Downloaded pickles are read with an allowlist of numpy array constructors.
Any other global is rejected, so the file cannot run its own code.
"""

from __future__ import annotations

import csv
import os
import pickle
import sys
from pathlib import Path

import numpy as np

SCRIPT_DIR = Path(__file__).resolve().parent
SIDECAR_ROOT = SCRIPT_DIR.parent
TEST_CSV = (
    SIDECAR_ROOT
    / "openhands_assets"
    / "include_metadata"
    / "Train_Test_Split"
    / "test_include.csv"
)
# Same Linux root recorded in config.yaml. It is not a Windows path.
CONFIG_POSE_ROOT = "/home/gokulnc/data-disk/datasets/Indian/INCLUDE/Pose_Signs"
EXPECTED_ROWS = 817
MISSING_SAMPLE = 8
MAX_PICKLE_BYTES = 64 * 1024 * 1024
VIDEO_SUFFIXES = (".MOV", ".mov", ".mp4", ".MP4")
# Globals numpy uses to rebuild an ndarray. Nothing else may be imported.
ALLOWED_GLOBALS = {
    "numpy._core.multiarray._reconstruct",
    "numpy.core.multiarray._reconstruct",
    "numpy._core.multiarray.scalar",
    "numpy.core.multiarray.scalar",
    "numpy.ndarray",
    "numpy.dtype",
}


class RestrictedUnpickler(pickle.Unpickler):
    def find_class(self, module: str, name: str):
        key = f"{module}.{name}"
        if key not in ALLOWED_GLOBALS:
            raise pickle.UnpicklingError(f"refusing to load global {key}")
        return super().find_class(module, name)

    def persistent_load(self, pid):
        raise pickle.UnpicklingError("refusing a persistent pickle id")


def read_test_rows() -> list[dict[str, str]]:
    with TEST_CSV.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def pose_file(root: str, file_path: str) -> Path:
    return Path(root) / Path(file_path).with_suffix(".pkl")


def inside_root(root: Path, candidate: Path) -> bool:
    resolved_root = root.resolve()
    resolved = candidate.resolve()
    return resolved == resolved_root or resolved.is_relative_to(resolved_root)


def video_file(root: str, file_path: str) -> Path | None:
    base = Path(root) / Path(file_path)
    stem = base.with_suffix("")
    seen: set[Path] = set()
    for candidate in (base, *(stem.with_suffix(suffix) for suffix in VIDEO_SUFFIXES)):
        if candidate in seen:
            continue
        seen.add(candidate)
        if candidate.is_file() and inside_root(Path(root), candidate):
            return candidate
    return None


def load_pose(path: Path) -> dict:
    size = path.stat().st_size
    if size <= 0 or size > MAX_PICKLE_BYTES:
        raise ValueError(f"{path.name} is {size} bytes; expected a pose pickle under {MAX_PICKLE_BYTES} bytes")
    with path.open("rb") as handle:
        blob = RestrictedUnpickler(handle).load()
    if not isinstance(blob, dict):
        raise ValueError(f"{path.name} is {type(blob).__name__}, not a dict")
    return blob


def shape_error(path: Path, blob: dict) -> str | None:
    if "keypoints" not in blob or "confidences" not in blob:
        return f"{path} is missing keypoints or confidences"
    keypoints = np.asarray(blob["keypoints"])
    confidences = np.asarray(blob["confidences"])
    if keypoints.ndim != 3:
        return f"{path} keypoints shape {tuple(keypoints.shape)} is not (T, V, C)"
    frames, points, channels = (int(part) for part in keypoints.shape)
    if frames < 1 or points < 75 or channels < 2:
        return (
            f"{path} keypoints shape {(frames, points, channels)} "
            "needs T >= 1, V >= 75, C >= 2"
        )
    if confidences.shape != (frames, points):
        return (
            f"{path} confidences shape {tuple(confidences.shape)} "
            f"does not match keypoints (T, V) = {(frames, points)}"
        )
    return None


def category_of(file_path: str) -> str:
    parts = Path(file_path).parts
    return parts[0] if parts else "(no category)"


def main() -> int:
    root = os.environ.get("INCLUDE_POSE_ROOT", "").strip()
    if not root:
        print("FAIL")
        print("INCLUDE_POSE_ROOT is not set.")
        print(
            f"config.yaml records {CONFIG_POSE_ROOT}. "
            "That Linux path may not exist on Windows, and this check does not use it."
        )
        print("Set INCLUDE_POSE_ROOT to the local Pose_Signs directory and run this script again.")
        return 2

    root_path = Path(root)
    print(f"INCLUDE_POSE_ROOT={root}")
    if not root_path.is_dir():
        print("FAIL")
        print(f"{root} is not a directory. Point INCLUDE_POSE_ROOT at the folder that contains Adjectives.")
        return 2
    if not TEST_CSV.is_file():
        print("FAIL")
        print(f"test_include.csv is missing: {TEST_CSV}")
        return 2

    rows = read_test_rows()
    print(f"test rows: {len(rows)}")
    if len(rows) != EXPECTED_ROWS:
        print("FAIL")
        print(f"Expected {EXPECTED_ROWS} test rows, found {len(rows)}.")
        return 2

    missing: list[str] = []
    found = 0
    videos = 0
    by_category: dict[str, list[Path]] = {}
    for row in rows:
        file_path = row["FilePath"]
        category = category_of(file_path)
        pkl_path = pose_file(root, file_path)
        by_category.setdefault(category, [])
        if pkl_path.is_file() and inside_root(root_path, pkl_path):
            found += 1
            by_category[category].append(pkl_path)
        else:
            missing.append(str(pkl_path))
        if video_file(root, file_path) is not None:
            videos += 1

    print(f"pkl found: {found}")
    print(f"pkl missing: {len(missing)}")
    print(f"matching video files (.MOV or .mp4): {videos}")
    if videos and found == 0:
        print("Video files are present and pose pickles are not. This looks like a raw-video archive.")
    if missing:
        print(f"missing sample ({min(MISSING_SAMPLE, len(missing))} of {len(missing)}):")
        for path in missing[:MISSING_SAMPLE]:
            print(f"  {path}")

    category_failures: list[str] = []
    print("category shape checks:")
    for category, paths in by_category.items():
        if not paths:
            message = f"  {category}: MISSING no pickle in this category"
            print(message)
            category_failures.append(message.strip())
            continue
        sample = paths[0]
        try:
            blob = load_pose(sample)
            error = shape_error(sample, blob)
        except (OSError, pickle.UnpicklingError, ValueError, TypeError, EOFError) as exc:
            error = f"{sample} could not be read: {exc}"
        finally:
            blob = None
        if error:
            print(f"  {category}: FAIL {error}")
            category_failures.append(error)
        else:
            print(f"  {category}: PASS {sample.name}")

    if missing or category_failures:
        print("FAIL")
        if missing:
            print(f"{len(missing)} expected pose files are missing under {root}.")
        if category_failures:
            print(f"{len(category_failures)} category checks failed.")
        print("The dataset is not ready for evaluate_temporal_ablation.py.")
        return 2

    print("PASS")
    print(f"All {EXPECTED_ROWS} pose files exist and each test category has a compatible pickle.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
