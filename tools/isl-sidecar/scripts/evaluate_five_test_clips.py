"""Print frozen INCLUDE LSTM results for five labeled test clips.

Uses the SignTalk checkpoint, preprocessing, and class list. It does not
train, write a report, or change the live recognizer.

Run from the SignTalk repo after setting INCLUDE_POSE_ROOT to the folder
that contains Adjectives.
"""

from __future__ import annotations

import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import evaluate_temporal_ablation as ev  # noqa: E402
from export_include_lstm import glosses, load_state, torch_forward  # noqa: E402

import torch  # noqa: E402

CLIP_COUNT = 5
HELLO_KEY = "48.Hello"


def softmax_confidence(logits: torch.Tensor) -> float:
    """Same top-class probability as web/include/lstm_math.js topPrediction."""
    shifted = logits.detach().float() - logits.detach().float().max()
    probs = torch.exp(shifted)
    return float((probs / probs.sum()).max())


def display_word(label: str) -> str:
    """Same visible word the browser shows after the class number."""
    text = label
    if len(text) > 2 and text[0].isdigit():
        dot = text.find(".")
        if dot > 0 and text[:dot].isdigit():
            text = text[dot + 1 :]
    return text.replace("_", " ").strip()


def stop(message: str, code: int) -> int:
    print(message)
    print("Five-clip evaluation stopped. No metrics file was written.")
    return code


def choose_clips(usable: list[dict[str, str]]) -> list[dict[str, str]] | None:
    hello = [row for row in usable if ev.gloss_key(row["Word"]) == HELLO_KEY]
    others = [row for row in usable if ev.gloss_key(row["Word"]) != HELLO_KEY]
    if hello:
        return [hello[0], *others[: CLIP_COUNT - 1]]
    if len(usable) < CLIP_COUNT:
        return None
    print(f"No test row with gloss key {HELLO_KEY} was available. Using the first {CLIP_COUNT} clips.")
    return usable[:CLIP_COUNT]


def main() -> int:
    root = ev.pose_root()
    root_path = Path(root)
    if not root_path.is_dir():
        return stop(
            f"INCLUDE pose folder was not found at {root}. "
            "Set INCLUDE_POSE_ROOT to the Pose_Signs folder that contains Adjectives.",
            2,
        )

    rows = ev.read_test_rows()
    missing: list[str] = []
    usable: list[dict[str, str]] = []
    for row in rows:
        relative = ev.relative_pose_path(row["FilePath"])
        if ev.pose_file(root, row["FilePath"]).is_file():
            usable.append(row)
        else:
            missing.append(relative)
    unexpected = [path for path in missing if path != ev.ALLOWED_MISSING_POSE]
    if unexpected:
        return stop(
            "A test pose file other than the known missing clip is absent: "
            + ", ".join(unexpected[:8]),
            2,
        )
    if missing == [ev.ALLOWED_MISSING_POSE]:
        print(f"Skipped known missing pose file: {ev.ALLOWED_MISSING_POSE}")

    chosen = choose_clips(usable)
    if chosen is None or len(chosen) != CLIP_COUNT:
        return stop(f"Only {len(usable)} usable test clips were found. Needed {CLIP_COUNT}.", 2)

    try:
        labels = glosses()
        weights = load_state()
    except Exception as exc:
        return stop(f"Checkpoint or class list could not be loaded: {exc}", 1)

    label_to_index = {ev.gloss_key(label): index for index, label in enumerate(labels)}
    if HELLO_KEY not in label_to_index:
        return stop(f"The checkpoint class list has no {HELLO_KEY} label.", 1)
    tensor_report = ev.verify_tensors(weights, len(labels))
    if not tensor_report["ok"]:
        return stop(
            "Checkpoint tensors did not match the SignTalk 263-class LSTM: "
            + "; ".join(tensor_report["errors"]),
            1,
        )

    print(f"classes: {len(labels)}")
    print(f"clips: {CLIP_COUNT}")
    for number, row in enumerate(chosen, start=1):
        relative = ev.relative_pose_path(row["FilePath"])
        path = ev.pose_file(root, row["FilePath"])
        truth_key = ev.gloss_key(row["Word"])
        if truth_key not in label_to_index:
            return stop(f"{relative} has Word {row['Word']!r}, which is not in the checkpoint class list.", 2)
        try:
            sequence = ev.normalize_sequence(ev.load_keypoints(path))
        except (OSError, ValueError, TypeError) as exc:
            return stop(f"{relative} could not be read as an INCLUDE pose: {exc}", 2)
        if sequence.ndim != 2 or sequence.shape[0] < 1 or sequence.shape[1] != 54:
            return stop(f"{relative} produced feature shape {tuple(sequence.shape)}, not (T, 54).", 2)
        with torch.no_grad():
            logits = torch_forward(sequence, weights)
        if tuple(logits.shape) != (len(labels),):
            return stop(f"{relative} produced {tuple(logits.shape)} logits, not ({len(labels)},).", 2)
        predicted_index = int(torch.argmax(logits).item())
        predicted = labels[predicted_index]
        confidence = softmax_confidence(logits)
        print(f"clip: {number}")
        print(f"file: {relative}")
        print(f"true_label: {row['Word']}")
        print(f"predicted_label: {predicted}")
        print(f"display_word: {display_word(predicted)}")
        print(f"confidence: {confidence:.4f}")
        print(f"feature_shape: ({int(sequence.shape[0])}, {int(sequence.shape[1])})")
        del sequence
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
