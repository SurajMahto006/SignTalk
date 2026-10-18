"""
Build checkpoints/prototype_clf.npz from a folder of sample clips (no full training pipeline).

Layout:
  samples/<gloss_name>/*.jpg

Uses the same MediaPipe pose vectors as the live sidecar. Good for bootstrapping before
OpenHands evaluate is wired for streaming clips.

  python scripts/build_prototype_clf.py --samples samples/
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from pose_from_frames import PoseExtractor  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=Path, required=True)
    parser.add_argument(
        "--out",
        type=Path,
        default=ROOT / "checkpoints" / "prototype_clf.npz",
    )
    args = parser.parse_args()

    extractor = PoseExtractor()
    labels: list[str] = []
    centroids: list[np.ndarray] = []

    for class_dir in sorted(args.samples.iterdir()):
        if not class_dir.is_dir():
            continue
        jpegs = list(class_dir.glob("*.jpg")) + list(class_dir.glob("*.jpeg"))
        if not jpegs:
            continue
        blobs = [p.read_bytes() for p in jpegs[:32]]
        seq = extractor.sequence_from_jpegs(blobs)
        if seq.shape[0] == 0:
            continue
        labels.append(class_dir.name.lower())
        centroids.append(seq.mean(axis=0))

    extractor.close()

    if not labels:
        raise SystemExit("No samples found — add JPGs under samples/<gloss>/")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    np.savez(
        args.out,
        centroids=np.stack(centroids, axis=0),
        labels=np.array(labels, dtype=object),
    )
    print(f"Wrote {args.out} with {len(labels)} classes: {', '.join(labels)}")


if __name__ == "__main__":
    main()
