"""
SignTalk ISL sidecar — INCLUDE-50 pretrained inference (evaluate path).

  pip install -r requirements.txt
  python server.py

POST /v1/recognize  { "frames_base64": ["..."] }
GET  /health
"""

from __future__ import annotations

import base64
import os
from typing import List

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from engine import IncludeEngine

app = FastAPI(title="SignTalk ISL Sidecar", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

engine = IncludeEngine()


class RecognizeRequest(BaseModel):
    frames_base64: List[str] = Field(default_factory=list)


@app.on_event("startup")
def _startup() -> None:
    engine.initialize()


@app.get("/health")
def health() -> dict:
    return {
        "ok": True,
        "model_loaded": engine.model_loaded,
        "model": engine.mode,
        "detail": engine.detail,
        "port": int(os.environ.get("ISL_SIDECAR_PORT", "8766")),
    }


@app.post("/v1/recognize")
def recognize(body: RecognizeRequest) -> dict:
    if not engine.model_loaded:
        return {
            "ok": False,
            "error": "model_not_loaded",
            "detail": engine.detail,
        }

    jpegs: List[bytes] = []
    for item in body.frames_base64[:24]:
        try:
            jpegs.append(base64.b64decode(item))
        except Exception:
            continue

    if not jpegs:
        return {"ok": False, "error": "no_valid_frames"}

    try:
        label, confidence, meta = engine.predict_from_jpegs(jpegs)
    except Exception as exc:
        return {"ok": False, "error": str(exc)}

    if not label:
        return {
            "ok": True,
            "label": "",
            "confidence": 0.0,
            "meta": meta,
        }

    return {
        "ok": True,
        "label": label,
        "confidence": confidence,
        "meta": meta,
    }


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("ISL_SIDECAR_PORT", "8766"))
    uvicorn.run(app, host="0.0.0.0", port=port)
