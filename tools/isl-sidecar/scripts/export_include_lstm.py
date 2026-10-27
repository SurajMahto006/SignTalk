"""Export the INCLUDE LSTM checkpoint to a small weight pack the browser can run."""

from __future__ import annotations

import importlib.abc
import importlib.machinery
import json
import struct
import sys
import types
from pathlib import Path

import torch


class _StubLoader(importlib.abc.Loader):
    def create_module(self, spec):
        module = types.ModuleType(spec.name)
        module.__path__ = []

        def __getattr__(name):
            cls = type(
                name,
                (),
                {
                    "__init__": lambda self, *args, **kwargs: None,
                    "__setstate__": lambda self, state: (
                        self.__dict__.update(state)
                        if isinstance(state, dict)
                        else setattr(self, "_state", state)
                    ),
                },
            )
            setattr(module, name, cls)
            return cls

        module.__getattr__ = __getattr__
        return module

    def exec_module(self, module):
        return None


class _StubFinder(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path, target=None):
        if fullname == "pytorch_lightning" or fullname.startswith("pytorch_lightning."):
            return importlib.machinery.ModuleSpec(fullname, _StubLoader(), is_package=True)
        return None


sys.meta_path.insert(0, _StubFinder())

ROOT = Path(__file__).resolve().parents[1]
CKPT = ROOT / "openhands_assets" / "include_lstm" / "include" / "lstm" / "epoch=294-step=63719.ckpt"
CSV = ROOT / "openhands_assets" / "include_metadata" / "Train_Test_Split" / "train_include.csv"
OUT_DIR = ROOT.parents[1] / "web" / "include"


def glosses() -> list[str]:
    words = set()
    for line in CSV.read_text(encoding="utf-8").splitlines()[1:]:
        if not line.strip():
            continue
        word = line.split(",", 2)[1]
        words.add(word)
    return sorted(words)


def load_state() -> dict[str, torch.Tensor]:
    blob = torch.load(CKPT, map_location="cpu", weights_only=False)
    state = blob.get("state_dict", blob)
    cleaned = {}
    for key, value in state.items():
        if not torch.is_tensor(value):
            continue
        name = key
        for prefix in ("model.", "module."):
            if name.startswith(prefix):
                name = name[len(prefix) :]
        cleaned[name] = value.detach().cpu().contiguous()
    return cleaned


def pack_f32(values: list[float]) -> bytes:
    out = bytearray()
    chunk = 8192
    for start in range(0, len(values), chunk):
        part = values[start : start + chunk]
        out.extend(struct.pack("<" + "f" * len(part), *part))
    return bytes(out)


def write_pack(labels: list[str], state: dict[str, torch.Tensor]) -> None:
    needed = []
    for layer in range(4):
        for direction in ("", "_reverse"):
            suffix = f"l{layer}{direction}"
            for part in ("weight_ih", "weight_hh", "bias_ih", "bias_hh"):
                needed.append(f"decoder.rnn.{part}_{suffix}")
    needed += [
        "decoder.attn_block.fc1.weight",
        "decoder.attn_block.fc2.weight",
        "decoder.fc.weight",
        "decoder.fc.bias",
    ]
    missing = [k for k in needed if k not in state]
    if missing:
        raise SystemExit("missing tensors:\n" + "\n".join(missing))

    fc_out = int(state["decoder.fc.weight"].shape[0])
    if fc_out != len(labels):
        raise SystemExit(f"label count {len(labels)} != classifier outputs {fc_out}")

    arrays = {k: state[k].float().cpu().contiguous() for k in needed}
    generator = torch.Generator().manual_seed(0)
    sample = torch.randn(12, 54, generator=generator)
    with torch.no_grad():
        ref = torch_forward(sample, arrays)
    fixture_logits = [float(v) for v in ref[:8].tolist()]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    blob = bytearray()
    tensors = []
    for name in needed:
        flat = arrays[name].reshape(-1).tolist()
        raw = pack_f32(flat)
        tensors.append(
            {
                "name": name,
                "offset": len(blob),
                "length": len(flat),
                "shape": list(arrays[name].shape),
            }
        )
        blob.extend(raw)
    (OUT_DIR / "lstm_weights.bin").write_bytes(blob)
    manifest = {
        "dataset": "INCLUDE",
        "words": len(labels),
        "inputSize": 54,
        "hidden": 128,
        "layers": 4,
        "labels": labels,
        "tensors": tensors,
    }
    (OUT_DIR / "lstm_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    (OUT_DIR / "fixture.json").write_text(
        json.dumps(
            {
                "input": sample.reshape(-1).tolist(),
                "frames": 12,
                "logits": fixture_logits,
            }
        ),
        encoding="utf-8",
    )
    print(f"wrote {OUT_DIR} ({len(blob)} bytes, {len(labels)} words)")


def main() -> None:
    labels = glosses()
    state = load_state()
    interesting = [k for k in state if "decoder" in k]
    print("decoder tensors:")
    for key in interesting:
        print(f"  {key} {tuple(state[key].shape)}")
    write_pack(labels, state)


def export_call_checkpoint(path: Path) -> None:
    """Pack include_words_best.pt, whose keys are rnn/attn_fc/fc, into the browser names."""
    blob = torch.load(path, map_location="cpu", weights_only=False)
    labels = [str(name) for name in blob["labels"]]
    rename = {
        "attn_fc1.weight": "decoder.attn_block.fc1.weight",
        "attn_fc2.weight": "decoder.attn_block.fc2.weight",
        "fc.weight": "decoder.fc.weight",
        "fc.bias": "decoder.fc.bias",
    }
    state: dict[str, torch.Tensor] = {}
    for key, value in blob["state"].items():
        if not torch.is_tensor(value):
            continue
        if key.startswith("rnn."):
            name = "decoder." + key
        else:
            name = rename.get(key)
        if name is None:
            continue
        state[name] = value.detach().cpu().contiguous()
    print(f"call checkpoint epoch {blob.get('epoch')} labels {len(labels)}")
    write_pack(labels, state)


def torch_forward(seq: torch.Tensor, weights: dict[str, torch.Tensor]) -> torch.Tensor:
    hidden = 128
    for layer in range(4):
        outs = []
        for direction, reverse in (("", False), ("_reverse", True)):
            suffix = f"l{layer}{direction}"
            w_ih = weights[f"decoder.rnn.weight_ih_{suffix}"]
            w_hh = weights[f"decoder.rnn.weight_hh_{suffix}"]
            b_ih = weights[f"decoder.rnn.bias_ih_{suffix}"]
            b_hh = weights[f"decoder.rnn.bias_hh_{suffix}"]
            steps = torch.flip(seq, [0]) if reverse else seq
            h = torch.zeros(hidden)
            c = torch.zeros(hidden)
            hs = []
            for t in range(steps.shape[0]):
                gates = steps[t] @ w_ih.T + b_ih + h @ w_hh.T + b_hh
                i, f, g, o = gates.chunk(4)
                i = torch.sigmoid(i)
                f = torch.sigmoid(f)
                g = torch.tanh(g)
                o = torch.sigmoid(o)
                c = f * c + i * g
                h = o * torch.tanh(c)
                hs.append(h)
            stacked = torch.stack(hs, 0)
            if reverse:
                stacked = torch.flip(stacked, [0])
            outs.append(stacked)
        seq = torch.cat(outs, dim=1)
    h_t = seq[-1]
    score = (seq @ weights["decoder.attn_block.fc1.weight"].T) @ h_t
    attn = torch.softmax(score, dim=0)
    context = seq.T @ attn
    pre = torch.cat([context, h_t])
    attention = torch.tanh(pre @ weights["decoder.attn_block.fc2.weight"].T)
    return attention @ weights["decoder.fc.weight"].T + weights["decoder.fc.bias"]


if __name__ == "__main__":
    if len(sys.argv) > 1:
        export_call_checkpoint(Path(sys.argv[1]))
    else:
        main()
