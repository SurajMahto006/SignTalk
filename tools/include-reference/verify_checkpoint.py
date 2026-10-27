"""
Verify INCLUDE-50 transformer checkpoint load + forward (no Flutter).
Usage (from tools/include-reference):
  pip install torch transformers timm tqdm scikit-learn pandas numpy
  python verify_checkpoint.py --checkpoint path/to/include50_no_cnn_transformer_small.pth
If --checkpoint omitted, downloads the official W&B weights to ./include50_no_cnn_transformer_small.pth
"""
from __future__ import annotations

import argparse
import json
import sys

import torch
import torch.nn.functional as F

from configs import TransformerConfig
from models.transformer import Transformer
from utils import load_json


def build_model(n_classes: int = 50) -> Transformer:
    config = TransformerConfig(size="small", max_position_embeddings=256)
    return Transformer(config=config, n_classes=n_classes)


def load_ckpt(path: str, model: Transformer) -> dict:
    ckpt = torch.load(path, map_location="cpu")
    if isinstance(ckpt, dict) and "model" in ckpt:
        model.load_state_dict(ckpt["model"])
        return ckpt
    raise ValueError("Unexpected checkpoint format — expected dict with 'model' key.")


def forward_batch(model: Transformer, seq_len: int = 169) -> torch.Tensor:
    x = torch.zeros(1, seq_len, 134, dtype=torch.float32)
    with torch.no_grad():
        return model(x)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", default="include50_no_cnn_transformer_small.pth")
    parser.add_argument("--seq-len", type=int, default=169)
    parser.add_argument("--download-official", action="store_true")
    args = parser.parse_args()

    import transformers

    print(f"torch={torch.__version__} transformers={transformers.__version__}")

    path = args.checkpoint
    if args.download_official or not __import__("os").path.isfile(path):
        links = load_json("pretrained_links.json")
        url = links["include50_no_cnn_transformer_small.pth"]
        print(f"Downloading official weights to {path} …")
        torch.hub.download_url_to_file(url, path, progress=True)

    label_map = json.load(open("label_maps/label_map_include50.json"))
    inv_labels = {v: k for k, v in label_map.items()}

    model = build_model()
    ckpt = load_ckpt(path, model)
    print(f"Checkpoint keys: {list(ckpt.keys())}")
    print(f"Loaded state entries: {len(ckpt['model'])}")
    score = ckpt.get("score")
    if score is not None:
        print(f"Stored validation score: {score}")

    model.eval()
    try:
        logits = forward_batch(model, seq_len=args.seq_len)
    except Exception as e:
        print(f"FORWARD FAILED: {type(e).__name__}: {e}")
        return 1

    probs = F.softmax(logits, dim=-1)
    conf, idx = torch.max(probs, dim=-1)
    idx_i = int(idx.item())
    print(f"Output shape: {tuple(logits.shape)} (expected [1, 50])")
    print(f"Argmax index: {idx_i} label={inv_labels.get(idx_i, '?')} confidence={conf.item():.4f}")
    print("NOTE: zeros input is a smoke test only — not a valid sign clip.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
