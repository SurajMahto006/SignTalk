"""
INCLUDE-50 inference engine.

Primary path: OpenHands pretrained checkpoint (evaluate / inference — no training in SignTalk).
Fallback path: prototype nearest-centroid classifier loaded from `checkpoints/prototype_clf.npz`
(optional — generate later via fine-tuning or export script).
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

from pose_from_frames import PoseExtractor

ROOT = Path(__file__).resolve().parent
LABELS_PATH = ROOT / "data" / "include50_glosses.json"


class IncludeEngine:
    def __init__(self) -> None:
        self._labels = self._load_labels()
        self._pose: Optional[PoseExtractor] = None
        self._openhands_model = None
        self._prototype_clf: Optional[Dict[str, Any]] = None
        self._detail = "not initialized"
        self._mode = "none"

    @property
    def model_loaded(self) -> bool:
        return self._mode != "none"

    @property
    def detail(self) -> str:
        return self._detail

    @property
    def mode(self) -> str:
        return self._mode

    def initialize(self) -> None:
        self._pose = PoseExtractor()
        if self._try_openhands():
            return
        if self._try_prototype_clf():
            return
        self._mode = "none"
        self._detail = (
            "No model loaded. Download OpenHands INCLUDE checkpoint — see tools/isl-sidecar/README.md"
        )

    def _load_labels(self) -> List[str]:
        if not LABELS_PATH.exists():
            return [f"class_{i}" for i in range(50)]
        data = json.loads(LABELS_PATH.read_text(encoding="utf-8"))
        labels = data.get("labels") or []
        return [str(x) for x in labels]

    def _try_openhands(self) -> bool:
        cfg = os.environ.get("OPENHANDS_CONFIG", "").strip()
        ckpt = os.environ.get("OPENHANDS_CHECKPOINT", "").strip()
        if not cfg or not ckpt:
            return False
        if not Path(cfg).exists() or not Path(ckpt).exists():
            self._detail = "OPENHANDS_CONFIG or OPENHANDS_CHECKPOINT path missing"
            return False
        try:
            import omegaconf  # type: ignore
            from openhands.apis.inference import InferenceModel  # type: ignore

            omega_cfg = omegaconf.OmegaConf.load(cfg)
            omega_cfg.pretrained = ckpt
            model = InferenceModel(cfg=omega_cfg)
            model.init_from_checkpoint_if_available()
            self._openhands_model = model
            self._mode = "openhands"
            self._detail = f"OpenHands checkpoint {Path(ckpt).name}"
            return True
        except Exception as exc:  # pragma: no cover
            self._detail = f"OpenHands load failed: {exc}"
            return False

    def _try_prototype_clf(self) -> bool:
        path = ROOT / "checkpoints" / "prototype_clf.npz"
        if not path.exists():
            return False
        try:
            bundle = np.load(path, allow_pickle=True)
            self._prototype_clf = {
                "centroids": bundle["centroids"],
                "labels": bundle["labels"].tolist(),
            }
            self._mode = "prototype"
            self._detail = f"prototype classifier ({path.name})"
            return True
        except Exception as exc:
            self._detail = f"prototype load failed: {exc}"
            return False

    def predict_from_jpegs(self, jpeg_list: List[bytes]) -> Tuple[str, float, Dict[str, Any]]:
        if not self.model_loaded or self._pose is None:
            raise RuntimeError(self._detail)

        seq = self._pose.sequence_from_jpegs(jpeg_list)
        if seq.shape[0] == 0:
            return "", 0.0, {"reason": "no_frames"}

        if self._mode == "prototype" and self._prototype_clf is not None:
            return self._predict_prototype(seq)

        if self._mode == "openhands":
            return self._predict_openhands_placeholder(seq)

        return "", 0.0, {"reason": "no_model"}

    def _predict_prototype(self, seq: np.ndarray) -> Tuple[str, float, Dict[str, Any]]:
        clf = self._prototype_clf
        assert clf is not None
        centroids = clf["centroids"]
        labels = clf["labels"]
        feat = seq.mean(axis=0)
        dists = np.linalg.norm(centroids - feat, axis=1)
        idx = int(np.argmin(dists))
        # Convert distance to pseudo-confidence
        conf = float(1.0 / (1.0 + dists[idx]))
        label = str(labels[idx])
        return label, conf, {"class_index": idx, "engine": "prototype"}

    def _predict_openhands_placeholder(self, seq: np.ndarray) -> Tuple[str, float, Dict[str, Any]]:
        """
        OpenHands expects dataset pipeline inputs. For live clips we use pose mean + label map
        until clip export to temp video is wired. Users with full OpenHands should prefer
        batch evaluate on INCLUDE videos; live path uses prototype if exported.
        """
        _ = seq
        return "", 0.0, {
            "reason": "openhands_live_clip_pending",
            "hint": "Export prototype_clf.npz or use evaluate.py on recorded clips",
        }
