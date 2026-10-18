"""Offline ablation of the frozen 263-class INCLUDE LSTM.

Compares three uses of the same checkpoint, class list, shoulder normalization,
and argmax prediction. Nothing is trained and no threshold is tuned.

A. Full pose sequence. This is the sequence length the valid pipeline uses:
   PoseTemporalSubsample is commented out in config.yaml, and nn.LSTM accepts
   any T >= 1.
B. That same normalized sequence uniformly reduced to 9 frames, using the
   index rule in OpenHands PoseUniformSubsampling (linspace, then clamp).
   Nine is the frame count from the BISINDO motion-grid paper. This is not
   that paper's 3x3 pixel grid, and it is not how the checkpoint was trained.
C. One frame: the temporal mean of the normalized sequence. A length-1 LSTM
   step is valid PyTorch. If that forward fails, C is reported as unsupported
   and is not replaced with another head.

Limitations: test_include.csv has no signer id, so this is not signer-held-out.
Pose files are not in the SignTalk repo. Metrics are computed only when every
test pose file loads. The live call is not modified.
"""

from __future__ import annotations

import csv
import json
import os
import pickle
import sys
import time
from pathlib import Path

import numpy as np

SCRIPT_DIR = Path(__file__).resolve().parent
SIDECAR_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

from export_include_lstm import glosses, load_state, torch_forward  # noqa: E402

import torch

# OpenHands PoseSelect preset mediapipe_holistic_minimal_27, applied to the
# 75-point body+hands array (33 pose, 21 left hand, 21 right hand).
POSE_INDEXES = (
    0, 2, 5, 11, 12, 13, 14,
    33, 37, 38, 41, 42, 45, 46, 49, 50, 53,
    54, 58, 59, 62, 63, 66, 67, 70, 71, 74,
)
# After that selection, CenterAndScaleNormalize shoulders are indexes 3 and 4.
SHOULDER_A = 3
SHOULDER_B = 4
NINE_FRAMES = 9

# Linux path recorded in config.yaml. It is not a path on this machine.
CONFIG_POSE_ROOT = "/home/gokulnc/data-disk/datasets/Indian/INCLUDE/Pose_Signs"
TEST_CSV = (
    SIDECAR_ROOT
    / "openhands_assets"
    / "include_metadata"
    / "Train_Test_Split"
    / "test_include.csv"
)
RESULTS_DIR = SIDECAR_ROOT / "experiment-results"


def pose_root() -> str:
    override = os.environ.get("INCLUDE_POSE_ROOT", "").strip()
    return override or CONFIG_POSE_ROOT


def gloss_key(word: str) -> str:
    """Train rows store '1.loud'; test rows store '1. loud'. Same gloss, same index."""
    return "".join(word.split())


def read_test_rows() -> list[dict[str, str]]:
    with TEST_CSV.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def pose_file(root: str, file_path: str) -> Path:
    return Path(root) / Path(file_path).with_suffix(".pkl")


def verify_tensors(weights: dict[str, torch.Tensor], class_count: int) -> dict[str, object]:
    """Required frozen tensors. A wrong shape means this checkpoint is not the 263-class LSTM."""
    expected = {
        "decoder.rnn.weight_ih_l0": (512, 54),
        "decoder.attn_block.fc1.weight": (256, 256),
        "decoder.attn_block.fc2.weight": (256, 512),
        "decoder.fc.weight": (class_count, 256),
        "decoder.fc.bias": (class_count,),
    }
    found = {}
    missing = []
    for name, shape in expected.items():
        tensor = weights.get(name)
        if tensor is None or tuple(tensor.shape) != shape:
            missing.append(f"{name} expected {shape}, got {None if tensor is None else tuple(tensor.shape)}")
        else:
            found[name] = list(shape)
    return {"ok": not missing, "checked": found, "errors": missing}


def load_keypoints(path: Path) -> np.ndarray:
    with path.open("rb") as handle:
        blob = pickle.load(handle)
    if isinstance(blob, dict):
        if "keypoints" not in blob:
            raise ValueError(f"{path.name} has no 'keypoints' array")
        array = np.asarray(blob["keypoints"])
    else:
        array = np.asarray(blob)
    if array.ndim != 3 or array.shape[-1] < 2 or array.shape[1] <= max(POSE_INDEXES):
        raise ValueError(f"{path.name} shape {tuple(array.shape)} is not (T, V>=75, C>=2)")
    return array


def normalize_sequence(keypoints: np.ndarray) -> torch.Tensor:
    """Match valid_pipeline: xy only, 27 joints, clip-level shoulder norm, (T, 54)."""
    selected = keypoints[:, POSE_INDEXES, :2].astype(np.float32)
    left = selected[:, SHOULDER_A, :]
    right = selected[:, SHOULDER_B, :]
    center = ((left + right) / 2.0).mean(axis=0)
    distance = np.sqrt(((left - right) ** 2).sum(axis=-1)).mean()
    if not np.isfinite(distance) or distance == 0:
        center = np.zeros(2, dtype=np.float32)
        scale = np.float32(1.0)
    else:
        scale = np.float32(1.0 / distance)
    normalized = (selected - center) * scale
    features = np.concatenate([normalized[:, :, 0], normalized[:, :, 1]], axis=1)
    return torch.from_numpy(np.ascontiguousarray(features))


def uniform_nine(sequence: torch.Tensor) -> torch.Tensor:
    length = sequence.shape[0]
    indexes = torch.linspace(0, length - 1, NINE_FRAMES)
    indexes = torch.clamp(indexes, 0, length - 1).long()
    return sequence.index_select(0, indexes)


def temporal_mean(sequence: torch.Tensor) -> torch.Tensor:
    return sequence.mean(dim=0, keepdim=True)


def verify_sequence_lengths(weights: dict[str, torch.Tensor]) -> dict[str, object]:
    """Confirm the frozen LSTM returns 263 logits for T=1, T=9, and a longer T."""
    report: dict[str, object] = {}
    for name, length in (("one_frame", 1), ("nine_frames", 9), ("variable", 17)):
        sample = torch.zeros(length, 54)
        try:
            with torch.no_grad():
                logits = torch_forward(sample, weights)
            report[name] = {
                "supported": True,
                "input_frames": length,
                "logits": int(logits.shape[0]),
            }
        except Exception as exc:  # architecture limitation, not a metric
            report[name] = {"supported": False, "input_frames": length, "error": str(exc)}
    return report


def macro_f1(confusion: np.ndarray) -> tuple[float, list[dict[str, float]]]:
    per_class = []
    scores = []
    for label in range(confusion.shape[0]):
        tp = float(confusion[label, label])
        support = float(confusion[label, :].sum())
        predicted = float(confusion[:, label].sum())
        precision = tp / predicted if predicted else 0.0
        recall = tp / support if support else 0.0
        f1 = (2 * precision * recall / (precision + recall)) if (precision + recall) else 0.0
        scores.append(f1)
        per_class.append(
            {
                "support": int(support),
                "precision": precision,
                "recall": recall,
                "f1": f1,
            }
        )
    return float(np.mean(scores)), per_class


def score_variant(
    name: str,
    confusion: np.ndarray,
    correct: int,
    total: int,
    seconds: list[float],
    labels: list[str],
) -> dict[str, object]:
    accuracy = correct / total if total else 0.0
    f1, per_class = macro_f1(confusion)
    for index, row in enumerate(per_class):
        row["label"] = labels[index]
    return {
        "variant": name,
        "samples": total,
        "top1_accuracy": accuracy,
        "macro_f1": f1,
        "inference_seconds_per_clip_mean": float(np.mean(seconds)) if seconds else None,
        "inference_seconds_per_clip_median": float(np.median(seconds)) if seconds else None,
        "per_class": per_class,
        "confusion_matrix": confusion.astype(int).tolist(),
    }


def write_report(payload: dict[str, object]) -> Path:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    target = RESULTS_DIR / "temporal_ablation_report.json"
    if target.exists():
        stamp = time.strftime("%Y%m%d-%H%M%S")
        target = RESULTS_DIR / f"temporal_ablation_report-{stamp}.json"
        if target.exists():
            raise SystemExit(f"Refusing to overwrite {target}")
    target.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return target


def fail(payload: dict[str, object], code: int) -> int:
    payload["metrics_computed"] = False
    path = write_report(payload)
    print(payload["reason"])
    print(f"Metrics were not computed. Diagnostic written to {path}")
    return code


def main() -> int:
    if not TEST_CSV.is_file():
        print(f"test_include.csv is missing: {TEST_CSV}")
        print("Metrics were not computed.")
        return 1

    try:
        labels = glosses()
        weights = load_state()
    except Exception as exc:
        print(f"Checkpoint or class list failed to load: {exc}")
        print("Metrics were not computed.")
        return 1

    tensor_report = verify_tensors(weights, len(labels))
    length_report = verify_sequence_lengths(weights) if tensor_report["ok"] else {}
    one_frame_ok = bool(length_report.get("one_frame", {}).get("supported"))
    logits_ok = tensor_report["ok"] and all(
        item.get("supported") and item.get("logits") == len(labels)
        for item in length_report.values()
        if isinstance(item, dict)
    )
    base = {
        "checkpoint_loaded": True,
        "classes": len(labels),
        "tensor_check": tensor_report,
        "sequence_length_check": length_report,
        "one_frame_supported": one_frame_ok,
        "test_csv": str(TEST_CSV),
    }
    if not tensor_report["ok"]:
        base["reason"] = (
            "Checkpoint tensors did not match the frozen 263-class LSTM: "
            + "; ".join(tensor_report["errors"])
        )
        return fail(base, 1)
    if not logits_ok:
        base["reason"] = (
            "The frozen LSTM did not return one logit vector per class "
            "for every sequence length that was checked."
        )
        return fail(base, 1)

    rows = read_test_rows()
    train_keys = {gloss_key(label): label for label in labels}
    if len(train_keys) != len(labels):
        base["reason"] = "Training glosses are not unique after the space difference is removed."
        return fail(base, 2)
    missing_labels = sorted(
        {row["Word"] for row in rows if gloss_key(row["Word"]) not in train_keys}
    )
    root = pose_root()
    base["pose_root"] = root
    base["pose_root_exists"] = Path(root).is_dir()
    base["test_rows"] = len(rows)
    if missing_labels:
        base["reason"] = (
            "test_include.csv contains words that are not in the training class list "
            f"used by the checkpoint: {missing_labels[:8]}"
        )
        return fail(base, 2)
    if not Path(root).is_dir():
        base["reason"] = (
            "INCLUDE pose files are not available. "
            f"Looked for Pose_Signs at {root}. "
            "The split CSV is present, but keypoints were not bundled. "
            "Set INCLUDE_POSE_ROOT to a local Pose_Signs directory and rerun. "
            "No predictions were invented."
        )
        return fail(base, 2)

    missing_files = []
    for row in rows:
        path = pose_file(root, row["FilePath"])
        if not path.is_file():
            missing_files.append(str(path))
            if len(missing_files) >= 5:
                break
    if missing_files:
        base["reason"] = (
            f"{len(missing_files)} or more test pose files are missing under {root}. "
            f"Examples: {missing_files}. Metrics were not computed."
        )
        return fail(base, 2)

    label_to_index = {gloss_key(label): index for index, label in enumerate(labels)}
    variants = ["full_sequence", "uniform_9", "temporal_mean_1"]
    if not one_frame_ok:
        variants = ["full_sequence", "uniform_9"]
    confusion = {name: np.zeros((len(labels), len(labels)), dtype=np.int32) for name in variants}
    correct = {name: 0 for name in variants}
    elapsed = {name: [] for name in variants}

    for row in rows:
        path = pose_file(root, row["FilePath"])
        sequence = normalize_sequence(load_keypoints(path))
        if sequence.shape[0] < 1 or sequence.shape[1] != 54:
            base["reason"] = f"{path} produced an empty or wrong feature shape {tuple(sequence.shape)}."
            return fail(base, 2)
        prepared = {
            "full_sequence": sequence,
            "uniform_9": uniform_nine(sequence),
        }
        if one_frame_ok:
            prepared["temporal_mean_1"] = temporal_mean(sequence)
        truth = label_to_index[gloss_key(row["Word"])]
        for name, features in prepared.items():
            started = time.perf_counter()
            with torch.no_grad():
                logits = torch_forward(features, weights)
            elapsed[name].append(time.perf_counter() - started)
            predicted = int(torch.argmax(logits).item())
            confusion[name][truth, predicted] += 1
            correct[name] += int(predicted == truth)
        del sequence

    total = len(rows)
    results = [
        score_variant(name, confusion[name], correct[name], total, elapsed[name], labels)
        for name in variants
    ]
    payload = {
        **base,
        "metrics_computed": True,
        "samples": total,
        "variants_omitted": [] if one_frame_ok else ["temporal_mean_1"],
        "omission_reason": None
        if one_frame_ok
        else "Length-1 LSTM forward failed, so the one-frame variant was not scored.",
        "results": results,
    }
    path = write_report(payload)
    print(f"Evaluated {total} test clips. Report: {path}")
    for item in results:
        print(
            f"{item['variant']}: accuracy={item['top1_accuracy']:.4f} "
            f"macro_f1={item['macro_f1']:.4f} "
            f"seconds_per_clip={item['inference_seconds_per_clip_mean']:.4f}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
