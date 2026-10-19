"""Train a new sign LSTM for call captions.

Uses INCLUDE pose clips and the Indian letter/number pose clips.
Saves a new checkpoint. Does not overwrite the OpenHands checkpoint
or change the browser recognizer.
"""

from __future__ import annotations

import csv
import json
import os
import random
import sys
from pathlib import Path

import numpy as np
import torch
from torch import nn

SCRIPT_DIR = Path(__file__).resolve().parent
SIDECAR_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

from evaluate_temporal_ablation import (  # noqa: E402
    gloss_key,
    load_keypoints,
    normalize_sequence,
    pose_file,
    relative_pose_path,
)

TRAIN_CSV = (
    SIDECAR_ROOT
    / "openhands_assets"
    / "include_metadata"
    / "Train_Test_Split"
    / "train_include.csv"
)
TEST_CSV = (
    SIDECAR_ROOT
    / "openhands_assets"
    / "include_metadata"
    / "Train_Test_Split"
    / "test_include.csv"
)
OUT_DIR = SIDECAR_ROOT / "experiment-results" / "combined_call_lstm"
MAX_FRAMES = 32
EPOCHS = 8
BATCH = 4
LR = 1e-3


def include_root() -> Path:
    raw = os.environ.get(
        "INCLUDE_POSE_ROOT",
        r"C:\Users\Lenovo\Downloads\INCLUDE\Pose_Signs\Pose_Signs",
    ).strip()
    return Path(raw)


def indian_root() -> Path:
    raw = os.environ.get(
        "INDIAN_POSE_ROOT",
        r"C:\Users\Lenovo\Downloads\Indian\pkl_poses",
    ).strip()
    return Path(raw)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def cap_frames(sequence: torch.Tensor) -> torch.Tensor:
    length = int(sequence.shape[0])
    if length <= MAX_FRAMES:
        return sequence
    index = torch.linspace(0, length - 1, MAX_FRAMES).round().long()
    return sequence.index_select(0, index)


def load_clip(path: Path) -> torch.Tensor:
    return cap_frames(normalize_sequence(load_keypoints(path)))


class Example:
    def __init__(self, features: torch.Tensor, label: int, source: str):
        self.features = features
        self.label = label
        self.source = source


def collect_include(root: Path, rows: list[dict[str, str]], source: str) -> tuple[list[tuple[Path, str]], list[str]]:
    items: list[tuple[Path, str]] = []
    skipped: list[str] = []
    for row in rows:
        rel = relative_pose_path(row["FilePath"])
        path = pose_file(str(root), row["FilePath"])
        if not path.is_file():
            skipped.append(rel)
            continue
        items.append((path, gloss_key(row["Word"])))
    if len(skipped) > 30:
        preview = "\n".join(skipped[:10])
        raise SystemExit(f"Too many missing INCLUDE poses ({len(skipped)}). First ones:\n{preview}")
    return items, skipped


def collect_indian(root: Path, split: str) -> list[tuple[Path, str]]:
    folder = root / split
    if not folder.is_dir():
        raise SystemExit(f"Indian pose folder not found: {folder}")
    items: list[tuple[Path, str]] = []
    for path in sorted(folder.rglob("*.pkl")):
        items.append((path, path.parent.name.strip().lower()))
    if not items:
        raise SystemExit(f"No Indian pose files in {folder}")
    return items


def load_split(pairs: list[tuple[Path, str]], labels: dict[str, int], source: str) -> tuple[list[Example], int]:
    loaded: list[Example] = []
    bad = 0
    for index, (path, name) in enumerate(pairs, start=1):
        try:
            features = load_clip(path)
        except Exception as exc:
            bad += 1
            print(f"skip {path.name}: {exc}")
            continue
        if features.ndim != 2 or features.shape[1] != 54 or features.shape[0] < 1:
            bad += 1
            print(f"skip {path.name}: shape {tuple(features.shape)}")
            continue
        if name not in labels:
            raise SystemExit(f"Label {name} was not in the training list")
        loaded.append(Example(features, labels[name], source))
        if index % 400 == 0:
            print(f"  loaded {index}/{len(pairs)} {source}")
    return loaded, bad


class CallSignModel(nn.Module):
    """Same LSTM and attention shape the browser already runs."""

    def __init__(self, class_count: int):
        super().__init__()
        self.rnn = nn.LSTM(
            input_size=54,
            hidden_size=128,
            num_layers=4,
            batch_first=True,
            bidirectional=True,
        )
        self.attn_fc1 = nn.Linear(256, 256, bias=False)
        self.attn_fc2 = nn.Linear(512, 256, bias=False)
        self.fc = nn.Linear(256, class_count)

    def forward(self, frames: torch.Tensor, lengths: torch.Tensor) -> torch.Tensor:
        packed = nn.utils.rnn.pack_padded_sequence(
            frames, lengths.cpu(), batch_first=True, enforce_sorted=False
        )
        packed_out, _ = self.rnn(packed)
        sequence, _ = nn.utils.rnn.pad_packed_sequence(packed_out, batch_first=True)
        batch, time, _ = sequence.shape
        last = (lengths - 1).clamp(min=0)
        hidden = sequence[torch.arange(batch), last]
        projected = self.attn_fc1(sequence)
        scores = torch.einsum("bth,bh->bt", projected, hidden)
        mask = torch.arange(time)[None, :] >= lengths[:, None]
        scores = scores.masked_fill(mask, -1e9)
        weights = torch.softmax(scores, dim=1)
        context = torch.einsum("bt,bth->bh", weights, sequence)
        joined = torch.cat([context, hidden], dim=1)
        attended = torch.tanh(self.attn_fc2(joined))
        return self.fc(attended)


def batches(data: list[Example], shuffle: bool, batch_size: int, device: torch.device):
    order = list(range(len(data)))
    if shuffle:
        random.shuffle(order)
    for start in range(0, len(order), batch_size):
        pick = [data[i] for i in order[start : start + batch_size]]
        lengths = torch.tensor([item.features.shape[0] for item in pick], dtype=torch.long)
        width = int(lengths.max())
        frames = torch.zeros(len(pick), width, 54)
        targets = torch.tensor([item.label for item in pick], dtype=torch.long)
        for row, item in enumerate(pick):
            frames[row, : item.features.shape[0]] = item.features
        yield frames.to(device), lengths, targets.to(device), [item.source for item in pick]


def accuracy(model: CallSignModel, data: list[Example], batch_size: int, device: torch.device) -> dict[str, float]:
    model.eval()
    correct = {"all": 0, "include": 0, "indian": 0}
    total = {"all": 0, "include": 0, "indian": 0}
    with torch.no_grad():
        for frames, lengths, targets, sources in batches(data, False, batch_size, device):
            pred = model(frames, lengths).argmax(dim=1)
            match = pred.eq(targets)
            for index, source in enumerate(sources):
                hit = int(match[index].item())
                correct["all"] += hit
                total["all"] += 1
                correct[source] += hit
                total[source] += 1
    return {
        name: (correct[name] / total[name] if total[name] else 0.0)
        for name in correct
    }


def apply_include_only(
    train_data: list[Example], test_data: list[Example], names: list[str]
) -> tuple[list[Example], list[Example], list[str]]:
    train_rows = [item for item in train_data if item.source == "include"]
    used = sorted({item.label for item in train_rows})
    mapping = {old: new for new, old in enumerate(used)}
    renamed = [names[old] for old in used]
    for item in train_rows:
        item.label = mapping[item.label]
    test_rows = []
    for item in test_data:
        if item.source != "include" or item.label not in mapping:
            continue
        item.label = mapping[item.label]
        test_rows.append(item)
    return train_rows, test_rows, renamed


def main() -> None:
    print("starting sign training", flush=True)
    torch.set_num_threads(2)
    random.seed(7)
    np.random.seed(7)
    torch.manual_seed(7)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"device {device}", flush=True)
    include_only = os.environ.get("INCLUDE_ONLY", "0") == "1"
    batch_size = int(os.environ.get("BATCH_SIZE", "32" if device.type == "cuda" else str(BATCH)))
    epoch_count = int(os.environ.get("EPOCH_COUNT", os.environ.get("CONTINUE_EPOCHS", str(EPOCHS))))
    patience = int(os.environ.get("PATIENCE", "30"))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cache_path = OUT_DIR / "features.pt"
    if cache_path.is_file():
        cached = torch.load(cache_path, map_location="cpu", weights_only=False)
        names = list(cached["labels"])
        train_data = [
            Example(row["features"], int(row["label"]), row["source"]) for row in cached["train"]
        ]
        test_data = [
            Example(row["features"], int(row["label"]), row["source"]) for row in cached["test"]
        ]
        print(f"loaded cached features train {len(train_data)} test {len(test_data)}", flush=True)
    else:
        include = include_root()
        indian = indian_root()
        if not include.is_dir():
            raise SystemExit(f"INCLUDE pose folder not found: {include}")
        if not indian.is_dir():
            raise SystemExit(f"Indian pose folder not found: {indian}")
        train_pairs, train_skipped = collect_include(include, read_csv(TRAIN_CSV), "include")
        test_pairs, test_skipped = collect_include(include, read_csv(TEST_CSV), "include")
        indian_train = collect_indian(indian, "train")
        indian_test = collect_indian(indian, "test")
        names = sorted({name for _, name in train_pairs + indian_train})
        labels = {name: index for index, name in enumerate(names)}
        print(
            f"classes {len(labels)} | INCLUDE train {len(train_pairs)} test {len(test_pairs)} "
            f"| Indian train {len(indian_train)} test {len(indian_test)}",
            flush=True,
        )
        if train_skipped or test_skipped:
            print("skipped missing", train_skipped + test_skipped, flush=True)
        print("loading train poses", flush=True)
        train_data, train_bad = load_split(train_pairs, labels, "include")
        extra, extra_bad = load_split(indian_train, labels, "indian")
        train_data.extend(extra)
        print("loading test poses", flush=True)
        test_data, test_bad = load_split(test_pairs, labels, "include")
        extra, more_bad = load_split(indian_test, labels, "indian")
        test_data.extend(extra)
        print(
            f"ready train {len(train_data)} test {len(test_data)} "
            f"skipped_bad {train_bad + extra_bad + test_bad + more_bad}",
            flush=True,
        )
        torch.save(
            {
                "labels": names,
                "train": [
                    {"features": item.features, "label": item.label, "source": item.source}
                    for item in train_data
                ],
                "test": [
                    {"features": item.features, "label": item.label, "source": item.source}
                    for item in test_data
                ],
            },
            cache_path,
        )

    if include_only:
        train_data, test_data, names = apply_include_only(train_data, test_data, names)
        print(f"INCLUDE words only: {len(names)} classes", flush=True)
    elif int(os.environ.get("INDIAN_REPEAT", "1")) > 1:
        repeat = int(os.environ["INDIAN_REPEAT"])
        indian_rows = [item for item in train_data if item.source == "indian"]
        train_data.extend(indian_rows * (repeat - 1))
        print(f"indian train copies {repeat}", flush=True)

    if len(train_data) < 100 or len(test_data) < 10:
        raise SystemExit("Too few clips loaded. Training stopped.")

    model = CallSignModel(len(names)).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=LR)
    loss_fn = nn.CrossEntropyLoss()
    best = -1.0
    stale = 0
    save_name = "include_words_best.pt" if include_only else "best.pt"
    label_name = "include_words_labels.json" if include_only else "labels.json"
    saved_path = OUT_DIR / "best.pt"
    if (not include_only) and int(os.environ.get("CONTINUE_EPOCHS", "0")) and saved_path.is_file():
        saved = torch.load(saved_path, map_location="cpu", weights_only=False)
        if saved.get("labels") != names:
            raise SystemExit("Saved labels do not match this training run")
        model.load_state_dict(saved["state"])
        best = float(saved["val_accuracy"]["all"])
        print(f"resumed from {saved_path} val {best:.3f}", flush=True)

    print(f"epochs {epoch_count} batch {batch_size} patience {patience}", flush=True)
    for epoch in range(1, epoch_count + 1):
        model.train()
        total_loss = 0.0
        seen = 0
        for frames, lengths, targets, _sources in batches(train_data, True, batch_size, device):
            optimizer.zero_grad(set_to_none=True)
            logits = model(frames, lengths)
            loss = loss_fn(logits, targets)
            loss.backward()
            nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            total_loss += float(loss.item()) * len(targets)
            seen += len(targets)
        scores = accuracy(model, test_data, batch_size, device)
        mean_loss = total_loss / max(seen, 1)
        score = scores["include"] if include_only else scores["all"]
        print(
            f"epoch {epoch} loss {mean_loss:.4f} "
            f"val {scores['all']:.3f} include {scores['include']:.3f} indian {scores['indian']:.3f}",
            flush=True,
        )
        if score > best:
            best = score
            stale = 0
            payload = {
                "labels": names,
                "epoch": epoch,
                "val_accuracy": scores,
                "max_frames": MAX_FRAMES,
                "include_only": include_only,
                "state": {key: value.detach().cpu() for key, value in model.state_dict().items()},
            }
            torch.save(payload, OUT_DIR / save_name)
            (OUT_DIR / label_name).write_text(json.dumps(names), encoding="utf-8")
            print(f"saved {OUT_DIR / save_name}", flush=True)
        else:
            stale += 1
            if stale >= patience:
                print(f"stopped early at epoch {epoch}", flush=True)
                break

    print(f"best_val {best:.3f}", flush=True)


if __name__ == "__main__":
    main()
