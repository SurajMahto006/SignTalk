# OpenHands INCLUDE assets (Phase A)

Official release: [checkpoints_v1](https://github.com/AI4Bharat/OpenHands/releases/tag/checkpoints_v1)

## Downloaded files (local)

| File | Size | Purpose |
|------|------|---------|
| `../downloads/include_lstm.zip` | ~17.9 MB | Pretrained LSTM on INCLUDE |
| `../downloads/include_metadata.zip` | ~46 KB | Train/test CSV splits |

## Extracted layout

| Path | Contents |
|------|----------|
| `include_lstm/include/lstm/config.yaml` | Training/inference config |
| `include_lstm/include/lstm/epoch=294-step=63719.ckpt` | PyTorch Lightning checkpoint |
| `include_metadata/Train_Test_Split/*.csv` | Split files (point config paths here for evaluate) |

## Environment variables (for `engine.py` / verify script)

```powershell
$env:OPENHANDS_CONFIG = "C:\Users\Lenovo\Desktop\SignTalk\tools\isl-sidecar\openhands_assets\include_lstm\include\lstm\config.yaml"
$env:OPENHANDS_CHECKPOINT = "C:\Users\Lenovo\Desktop\SignTalk\tools\isl-sidecar\openhands_assets\include_lstm\include\lstm\epoch=294-step=63719.ckpt"
```

For batch evaluate, edit `config.yaml` `split_file` and `root_dir` to local paths (pose keypoints — not bundled in SignTalk).

## Python 3.9 venv (required)

OpenHands pins old dependencies; use **Python 3.9** only:

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk\tools\isl-sidecar
py -3.9 -m venv .venv-openhands-py39
.\.venv-openhands-py39\Scripts\Activate.ps1
pip install -r requirements-openhands.txt
python scripts/verify_openhands_load.py
```

Do not commit `.venv-openhands-py39/` or large zips if using git LFS limits.
