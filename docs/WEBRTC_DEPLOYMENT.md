# SignTalk WebRTC — development and deployment

## College demo checklist (PC + Android, same Wi‑Fi)

1. Start signaling + Flutter (`0.0.0.0:8765` / `0.0.0.0:8080`) — commands below.
2. **PC Chrome:** `http://localhost:8080` → Video call → **Check camera & mic** → **Host** → room e.g. `demo2025`.
3. **Phone Chrome:** `http://<PC_LAN_IP>:8080` → same room → **Join** (signaling URL should auto-fill `ws://<PC_LAN_IP>:8765`).
4. If the phone never gets camera/mic: use the **HTTPS + WSS** procedure in [`WEBRTC_SECURE_DEMO.md`](WEBRTC_SECURE_DEMO.md) (two tunnels or a proxy — **8080 alone is not enough**).
5. Confirm status chips: **Signaling joined** + **Media connected** and remote/local track counts before presenting as “working.”

## Cloudflare quick tunnel (502 / phone testing)

**Evidence on this project:** Flutter’s `web-server` dev tool answers **GET /** with **200** but **HEAD /** with **404** (Dart `shelf`). Some tunnel edge checks use **HEAD**; that can show as **502 Bad Gateway** even when `http://127.0.0.1:8080` works in the browser. **Fix:** start Flutter first, wait until the terminal shows the app is being served, then start `cloudflared`. If you see 502, refresh once (GET). Keep the Flutter terminal open — stopping it causes 502 until you restart the tunnel or Flutter.

**Three processes (all must stay open):**

| Terminal | Command | Purpose |
|----------|---------|---------|
| 1 | `npm start` in `tools/signaling-server` | WebSocket signaling on **8765** |
| 2 | `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080` | App on **8080** |
| 3 | `cloudflared tunnel --url http://127.0.0.1:8080` | Public **HTTPS** app URL |
| 4 (extra) | `cloudflared tunnel --url http://127.0.0.1:8765` | Public **WSS** for signaling (second URL) |

Tunneling **only 8080** does **not** expose signaling. On the phone, open the **app** `https://….trycloudflare.com` URL, then in Video call paste **`wss://….trycloudflare.com`** from the **signaling** tunnel (no `:8765` on the public URL). For repeat demos, you can pair tunnels in one place: `lib/services/webrtc/sign_talk_public_demo_config.dart` (update app host + WSS when URLs change). Optional: `--dart-define=SIGNALING_URL=wss://YOUR-SIGNAL-TUNNEL-HOST` when starting Flutter.

Verify locally before tunnels:

```powershell
curl.exe -s -o NUL -w "GET %{http_code}`n" http://127.0.0.1:8080/
curl.exe http://127.0.0.1:8765/
```

Expect **GET 200** and signaling text `SignTalk signaling server OK`.

---

## Start locally

**Terminal 1 — signaling (PC):**

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk\tools\signaling-server
npm install
npm start
```

**Terminal 2 — Flutter web (PC, LAN-visible):**

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

- **Laptop browser:** open the printed URL (often `http://localhost:8080`). Signaling URL: `ws://127.0.0.1:8765`.
- **Android Chrome (same Wi‑Fi):** open `http://<PC_LAN_IP>:8080`. Signaling URL should auto-fill `ws://<PC_LAN_IP>:8765`.

Allow **inbound TCP 8765** on **Private** networks in Windows Firewall if the phone cannot reach signaling.

## Secure context (camera / microphone)

Browsers require a [secure context](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts) for `getUserMedia`:

| Context | Camera/mic on Android |
|---------|------------------------|
| `https://` | Allowed when user grants permission |
| `http://localhost` / `http://127.0.0.1` | Allowed on the laptop |
| `http://192.168.x.x` | **Often blocked or unreliable on Android Chrome** |

**Practical Android-on-Wi‑Fi options (development only):**

See **[`WEBRTC_SECURE_DEMO.md`](WEBRTC_SECURE_DEMO.md)** for step-by-step PowerShell (two HTTPS/WSS tunnels, `--dart-define=SIGNALING_URL`, firewall notes).

1. **Two tunnels** — one to `:8080` (app), one to `:8765` (signaling → use `wss://` on the signaling host).
2. **LAN reverse proxy** — TLS in front of both services; optional `SIGNALING_URL` for path-based `wss://`.
3. **Laptop-only** — `http://localhost:8080` to verify logic before securing the phone path.

SignTalk shows a warning in the call UI when the page is not a secure context.

## TURN (production-oriented relay)

STUN alone fails on many mobile/carrier networks. Configure TURN at **build/run time** (never commit credentials):

```powershell
flutter run -d chrome `
  --dart-define=TURN_URL=turn:turn.example.com:3478 `
  --dart-define=TURN_USERNAME=your-user `
  --dart-define=TURN_CREDENTIAL=your-secret
```

Optional: `--dart-define=STUN_URL=stun:stun.l.google.com:19302`

Copy `tools/signaling-server/turn.env.example` to a local `.env` for your own notes; `.env` is gitignored.

## Production checklist (not implemented in-app)

- HTTPS for the web app, **WSS** for signaling
- TURN server with authentication
- Room/auth policy beyond the demo 2-participant limit
- Monitoring and rate limits on signaling

SignTalk remains a **development/demo** stack until you validate two-device calls on your network.
