# ISL word recognition (INCLUDE / sidecar)

SignTalk uses a **Python sidecar** for **ISL word recognition** (INCLUDE-50 / OpenHands pretrained — no training inside Flutter).

## Run (3 terminals)

1. **Signaling** (8765): `cd tools/signaling-server && npm start`
2. **ISL sidecar** (8766): see `tools/isl-sidecar/README.md`
3. **Flutter web** (8080): `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`

Default sidecar URL: `http://127.0.0.1:8766` (`ISL_SIDECAR_URL` dart-define to override).

## App behavior

| Surface | Behavior |
|---------|----------|
| **Sign to Text** | Camera + **Live ISL recognition** or one-shot clip |
| **Video call** | While connected, polls local video → sidecar → **sentence composer** (words + pauses) → relay `isl_caption` to partner |

## Improve accuracy later

1. **Prototype:** `python scripts/build_prototype_clf.py --samples samples/` (your JPGs per gloss).
2. **OpenHands:** Python 3.9 venv, download `include_lstm.zip` + metadata, set `OPENHANDS_CONFIG` / `OPENHANDS_CHECKPOINT`.
3. **Fine-tune:** OpenHands `resume_training` on INCLUDE (see AI4Bharat docs).
4. **Sentences:** extend `IncludeGlossPhrases` or add an LLM gloss-to-English step.
