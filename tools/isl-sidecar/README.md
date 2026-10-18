# SignTalk ISL sidecar (INCLUDE-50 / OpenHands)

HTTP service for **Indian Sign Language word recognition** using **pretrained** INCLUDE models (evaluate path — you do not train inside Flutter).

Default port: **8766** (WebRTC signaling stays on **8765**).

## Quick start (prototype — fastest)

1. Install Python 3.10+ and create a venv (recommended).

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk\tools\isl-sidecar
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

2. Add a few sample images per gloss (your signs or INCLUDE frames):

```text
samples/hello/*.jpg
samples/thankyou/*.jpg
```

3. Build a lightweight prototype classifier (same pose features as live inference):

```powershell
python scripts/build_prototype_clf.py --samples samples
```

4. Run the server:

```powershell
python server.py
```

5. Flutter (default already points here):

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Open **Sign to Text** → camera → **Live ISL recognition**, or join a **video call** for sentence building.

## Full INCLUDE / OpenHands (pretrained evaluate — recommended for report)

1. Use **Python 3.9** in a separate venv (OpenHands pins old deps).

2. Download from [OpenHands releases](https://github.com/AI4Bharat/OpenHands/releases):

   - `include_metadata.zip`
   - `include_lstm.zip` (or `include_bert.zip`)

3. Extract and set:

```powershell
$env:OPENHANDS_CONFIG = "C:\path\to\extracted\config.yaml"
$env:OPENHANDS_CHECKPOINT = "C:\path\to\checkpoint.ckpt"
pip install OpenHands   # in Python 3.9 venv only
```

4. Sync label order (optional):

```powershell
python scripts/sync_labels_from_metadata.py --metadata C:\path\to\include_metadata
```

5. Run `python server.py` — health should show `model_loaded: true`, `model: openhands`.

> **Note:** Live clip → OpenHands streaming is still being extended; for highest accuracy today, run batch `evaluate.py` on recorded clips (INCLUDE repo) and use the prototype export above for real-time until OpenHands live wiring is complete.

## API

| Method | Path | Body |
|--------|------|------|
| GET | `/health` | — |
| POST | `/v1/recognize` | `{ "frames_base64": ["..."] }` |

## Improve later (your roadmap)

- Fine-tune OpenHands decoder on extra ISL data (`resume_training`).
- Replace prototype with exported centroids from full INCLUDE evaluate.
- Add gloss → sentence step (rules now in `IncludeGlossPhrases`, LLM optional later).
