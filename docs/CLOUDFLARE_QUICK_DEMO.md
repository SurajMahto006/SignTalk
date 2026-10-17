# Cloudflare public demo (PC + phone) — fast path

## Proven working setup (phone could not reach home Wi‑Fi router)

1. **Laptop mobile hotspot ON** → Android connects to **laptop hotspot** (not only home Wi‑Fi).
2. Run signaling + **Flutter `--release`** + **two** `cloudflared` tunnels (`--edge-ip-version 4`).
3. Phone opens the **HTTPS app** URL from the app tunnel (not `192.168.x.x`).
4. Same **wss://** signaling URL on both devices, same room, Host + Join.

Skip raw LAN IP on home Wi‑Fi when the router uses **client isolation**. Hotspot + HTTPS avoids that and gives camera permission on Android.

---

Skip LAN IP (`192.168.x.x`) on the home router. Many block phone → PC. Use **HTTPS + WSS** below.

## Current paired URLs (update when tunnels restart)

| Role | URL |
|------|-----|
| **App (open on PC and phone)** | https://highway-advisor-starts-provinces.trycloudflare.com |
| **Signaling (auto when app host matches)** | wss://dear-tariff-tulsa-midi.trycloudflare.com |

Edit `lib/services/webrtc/sign_talk_public_demo_config.dart` when Cloudflare prints new hostnames, then **hot restart Flutter (`R`)**.

## Four terminals (PowerShell)

**1 — Signaling**

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk\tools\signaling-server
npm start
```

**2 — Flutter (use `--release` for phone + tunnel; debug is very slow)**

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk
flutter run -d web-server --release --web-hostname 0.0.0.0 --web-port 8080
```

First `--release` build can take several minutes on a 4 GB PC. Wait until the terminal shows the app is being served.

**3 — App tunnel** (after Flutter says “being served”)

```powershell
C:\Users\Lenovo\Downloads\cloudflared-windows-amd64.exe tunnel --edge-ip-version 4 --url http://127.0.0.1:8080
```

**4 — Signaling tunnel**

```powershell
C:\Users\Lenovo\Downloads\cloudflared-windows-amd64.exe tunnel --edge-ip-version 4 --url http://127.0.0.1:8765
```

Copy new `https://….trycloudflare.com` lines into `sign_talk_public_demo_config.dart` (app host + `wss://` for signaling). Press **`R`** in Flutter.

> Do **not** use `--protocol http2` unless QUIC fails; prefer `--edge-ip-version 4`.

## Demo steps

1. PC and phone: open **the same app HTTPS URL** (table above).
2. **Live video call** → confirm signaling shows **wss://…** (or paste from table).
3. Room ID e.g. `demo-live` → **Host** on PC, **Join** on phone (or reverse).
4. Allow camera + microphone on both.
5. Wait for **Connected — remote media active** and live remote video.

## Quick checks

```powershell
curl.exe -s -o NUL -w "app %{http_code}`n" https://highway-advisor-starts-provinces.trycloudflare.com/
```

Signaling: Connection details → **Signaling joined** after Host/Join.

## MediaPipe console messages (not a bug)

In Chrome DevTools you may see from `vision_wasm_internal.js`:

- `Hand Gesture Recognizer contains CPU only ops` / **XNNPACK**
- `Custom gesture classifier is not defined` (we use **built-in** poses, not a custom classifier)
- `Feedback manager requires a model with a single signature`

These are **Google MediaPipe INFO/WARN logs**. If the app shows **Detecting** and **Gesture recognized — HELLO/YES/STOP**, ignore them. SignTalk logs `[SignTalkGesture] Ready…` once for the same reason.
