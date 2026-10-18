"""
Load OpenHands INCLUDE LSTM checkpoint (import test only — not live video recognition).

Requires Python 3.9 venv + requirements-openhands.txt.

  set OPENHANDS_CONFIG / OPENHANDS_CHECKPOINT (see openhands_assets/README.md)
  python scripts/verify_openhands_load.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = (
    ROOT / "openhands_assets" / "include_lstm" / "include" / "lstm" / "config.yaml"
)
DEFAULT_CKPT = (
    ROOT
    / "openhands_assets"
    / "include_lstm"
    / "include"
    / "lstm"
    / "epoch=294-step=63719.ckpt"
)


def main() -> int:
    if sys.version_info[:2] != (3, 9):
        print(
            f"WARNING: OpenHands is tested with Python 3.9; you are on {sys.version.split()[0]}"
        )

    cfg_path = Path(os.environ.get("OPENHANDS_CONFIG", str(DEFAULT_CONFIG)))
    ckpt_path = Path(os.environ.get("OPENHANDS_CHECKPOINT", str(DEFAULT_CKPT)))

    print(f"Python: {sys.version}")
    print(f"Config: {cfg_path} (exists={cfg_path.is_file()})")
    print(f"Checkpoint: {ckpt_path} (exists={ckpt_path.is_file()})")

    if not cfg_path.is_file() or not ckpt_path.is_file():
        print("FAIL: config or checkpoint missing")
        return 1

    try:
        import omegaconf  # noqa: F401
        from openhands.apis.inference import InferenceModel
    except ImportError as exc:
        print(f"FAIL: OpenHands not installed in this venv: {exc}")
        return 1

    import omegaconf

    cfg = omegaconf.OmegaConf.load(str(cfg_path))
    cfg.pretrained = str(ckpt_path)
    print("Building InferenceModel and loading weights…")
    model = InferenceModel(cfg=cfg)
    model.init_from_checkpoint_if_available()
    print("OK: checkpoint load completed (batch evaluate path — live sidecar clip infer not wired yet).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
