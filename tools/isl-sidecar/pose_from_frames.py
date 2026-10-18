"""Extract hand/pose features from JPEG bytes (MediaPipe)."""

from __future__ import annotations

import io
from typing import List

import numpy as np
from PIL import Image

try:
    import mediapipe as mp
except ImportError:  # pragma: no cover
    mp = None


class PoseExtractor:
    """Lightweight sequential pose vectors for INCLUDE-style classifiers."""

    def __init__(self) -> None:
        if mp is None:
            raise RuntimeError("mediapipe is required: pip install mediapipe")
        self._hands = mp.solutions.hands.Hands(
            static_image_mode=True,
            max_num_hands=2,
            min_detection_confidence=0.45,
        )

    def close(self) -> None:
        self._hands.close()

    def sequence_from_jpegs(self, jpeg_list: List[bytes]) -> np.ndarray:
        """Returns float32 array shape (T, 126) — both hands xyz (21*3*2)."""
        rows: List[np.ndarray] = []
        for blob in jpeg_list:
            img = Image.open(io.BytesIO(blob)).convert("RGB")
            arr = np.asarray(img)
            result = self._hands.process(arr)
            rows.append(self._hands_to_vec(result))
        if not rows:
            return np.zeros((0, 126), dtype=np.float32)
        return np.stack(rows, axis=0)

    @staticmethod
    def _hands_to_vec(result) -> np.ndarray:
        vec = np.zeros(126, dtype=np.float32)
        if not result.multi_hand_landmarks:
            return vec
        for idx, hand in enumerate(result.multi_hand_landmarks[:2]):
            offset = idx * 63
            for i, lm in enumerate(hand.landmark):
                base = offset + i * 3
                vec[base : base + 3] = (lm.x, lm.y, lm.z)
        return vec
