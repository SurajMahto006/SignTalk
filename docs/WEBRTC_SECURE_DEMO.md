# Secure PC ↔ Android WebRTC demo (HTTPS + WSS)

Use this when Android Chrome blocks camera/microphone on plain `http://192.168.x.x`.  
**Do not assume** tunneling port **8080** also secures signaling on **8765** — you need **two endpoints** (or one proxy with two routes).

SignTalk’s Node signaling server speaks plain **HTTP + WebSocket** on `0.0.0.0:8765`. It does **not** terminate TLS itself. **WSS** is provided by putting a **TLS reverse proxy or tunnel** in front of that port.

The Flutter app auto-picks `wss://<page-host>:8765` when the page is `https://`. That only works if **8765 is reachable with TLS on the same host** (uncommon with free tunnels). For **two separate tunnel URLs**, set signaling explicitly (see below).

---

## Architecture (recommended for demo)

| Service | Local bind | Public (example) |
|---------|------------|------------------|
| Flutter web | `http://0.0.0.0:8080` | `https://<APP-TUNNEL-HOST>` |
| Signaling | `http://0.0.0.0:8765` | `wss://<SIGNAL-TUNNEL-HOST>` |

Both devices (PC + phone) open the **same HTTPS app URL**. Signaling URL must be the **WSS tunnel URL** (not `:8765` on the app host unless you configured that).

---

## Step 0 — Start SignTalk locally (same as today)

**PowerShell — signaling:**

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk\tools\signaling-server
npm install
npm start
```

**PowerShell — Flutter web (LAN + localhost):**

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Verify locally: `http://127.0.0.1:8080` (PC) and signaling `ws://127.0.0.1:8765`.

---

## Step 1 — Expose HTTPS and WSS (choose one approach)

Install **one** tunnel/proxy tool only if you accept its terms (not bundled with SignTalk). Examples below assume the tool is on your PATH.

### Option A — Two quick tunnels (simplest mentally)

Run **two** tunnels to **two local ports**:

1. Tunnel → `http://127.0.0.1:8080` → note **`https://…`** app URL  
2. Tunnel → `http://127.0.0.1:8765` → note **`https://…`** URL; use **`wss://…`** (same host, no path) as signaling in the app  

**Cloudflare Tunnel (example — requires `cloudflared` installed):**

```powershell
# Terminal A — app
cloudflared tunnel --url http://127.0.0.1:8080

# Terminal B — signaling (separate tunnel)
cloudflared tunnel --url http://127.0.0.1:8765
```

**ngrok (example — requires `ngrok` installed and authtoken configured):**

```powershell
# Terminal A
ngrok http 8080

# Terminal B
ngrok http 8765
```

Copy the **https** forwarding URLs from each dashboard. For signaling, use **`wss://<host>`** (ngrok/cloudflare use port 443 on the public URL; do not append `:8765`).

### Option B — LAN HTTPS with a reverse proxy (advanced)

Serve TLS on the PC with **mkcert + Caddy/nginx**, proxy:

- `https://<PC_LAN_IP>/` → `http://127.0.0.1:8080`
- `wss://<PC_LAN_IP>/signaling` → `http://127.0.0.1:8765` (WebSocket upgrade)

Then set `--dart-define=SIGNALING_URL=wss://<PC_LAN_IP>/signaling` and trust the CA on the phone. Heavier setup; only use if you already know Caddy/nginx.

---

## Step 2 — Point SignTalk at WSS

### Manual (no rebuild)

1. PC and phone open the **HTTPS app URL** from the app tunnel.  
2. Video call → set **Signaling WebSocket URL** to **`wss://<SIGNAL-TUNNEL-HOST>`** (from the signaling tunnel).  
3. Same **room ID** on both → Host / Join.

### Optional — default via dart-define (same machine you run Flutter on)

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 `
  --dart-define=SIGNALING_URL=wss://YOUR-SIGNAL-TUNNEL-HOST-HERE
```

Replace the host with your **signaling** tunnel hostname only. **Never commit** tunnel URLs or tokens.

---

## Step 3 — Firewall (LAN-only fallback)

If you use **LAN HTTPS** without tunnels, allow **inbound TCP 8080 and 8765** on **Private** profile for the Flutter/Node processes. Tunnels usually avoid opening LAN ports to the phone.

Check PC LAN IP (Wi‑Fi):

```powershell
(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -match 'Wi-Fi|WLAN' } | Select-Object -First 1).IPAddress
```

---

## Reverse proxy / WSS compatibility

The existing `tools/signaling-server/server.js` uses `ws` on a plain Node `http.Server`. This is **compatible** with:

- TLS termination at the proxy/tunnel  
- WebSocket upgrade (`Connection: Upgrade`, `Upgrade: websocket`)

Requirements for the proxy:

- Forward **WebSocket** to `127.0.0.1:8765` (not just HTTP GET health checks)  
- Do **not** buffer WebSocket bodies  
- Use **`wss://`** on the client when the app page is **`https://`**

Health check (local): `curl http://127.0.0.1:8765` → `SignTalk signaling server OK`

---

## Verification checklist

**Automated (on PC):**

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk
flutter analyze
flutter test
cd tools\signaling-server
npm test
```

**Physical (PC + Android — you must run):**

1. App loads over **https://** on the phone (padlock / secure context — SignTalk warning should disappear).  
2. **Check camera & mic** succeeds on the phone.  
3. Status: **Signaling joined** + **Media connected**; track line shows remote **1v/1a** when both send media.  
4. Mute/camera/end call and rejoin once.

Automated tests do **not** replace this call.

---

## What SignTalk does not provide

- Built-in TLS certificates or tunnel binaries  
- Single-port magic (8080 HTTPS does not include 8765 WSS unless you configure routing)  
- TURN server (optional; see `WEBRTC_DEPLOYMENT.md` for `--dart-define=TURN_*`)
