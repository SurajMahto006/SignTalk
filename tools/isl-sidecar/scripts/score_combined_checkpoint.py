"""Score the new call-caption checkpoint on five INCLUDE clips.

Does not change the app, the datasets, or the OpenHands checkpoint.
"""

from __future__ import annotations

import sys
from pathlib import Path

import torch

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from evaluate_temporal_ablation import gloss_key, pose_file  # noqa: E402
from train_combined_signs import CallSignModel, load_clip  # noqa: E402

ROOT = Path(r"C:\Users\Lenovo\Downloads\INCLUDE\Pose_Signs\Pose_Signs")
CKPT = SCRIPT_DIR.parent / "experiment-results" / "combined_call_lstm" / "snapshot.pt"
CLIPS = [
    ("48.Hello", "Greetings/48. Hello/MVI_0029.MOV"),
    ("1.loud", "Adjectives/1. loud/MVI_9289.MOV"),
    ("1.loud", "Adjectives/1. loud/MVI_5257.MOV"),
    ("1.loud", "Adjectives/1. loud/MVI_9369.MOV"),
    ("1.loud", "Adjectives/1. loud/MVI_9448.MOV"),
]


def main() -> None:
    if not CKPT.is_file():
        raise SystemExit(f"Snapshot not found: {CKPT}")
    saved = torch.load(CKPT, map_location="cpu", weights_only=False)
    labels = list(saved["labels"])
    model = CallSignModel(len(labels))
    model.load_state_dict(saved["state"])
    model.eval()
    print(f"checkpoint val {saved.get('val_accuracy')}")
    for truth, file_path in CLIPS:
        features = load_clip(pose_file(str(ROOT), file_path))
        frames = features.unsqueeze(0)
        lengths = torch.tensor([features.shape[0]])
        with torch.no_grad():
            logits = model(frames, lengths)[0]
        index = int(torch.argmax(logits).item())
        shifted = logits - logits.max()
        confidence = float(torch.exp(shifted).max() / torch.exp(shifted).sum())
        print(
            f"true {gloss_key(truth)} predicted {labels[index]} "
            f"confidence {confidence:.4f} shape {tuple(features.shape)}"
        )


if __name__ == "__main__":
    main()
