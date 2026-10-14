# SignTalk signaling server (local)

WebRTC needs a **signaling** channel to exchange SDP offers/answers and ICE candidates. This tiny server **relays JSON messages** between clients in the same **room ID**. It does not handle media.

## Setup (once)

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk\tools\signaling-server
npm install ws
npm start
```

Default URL: `ws://YOUR_PC_LAN_IP:8765` (find IP with `ipconfig` → IPv4 on Wi‑Fi).

## Cross-device demo

1. PC: run this server + `flutter run -d chrome --web-hostname 0.0.0.0 --web-port 8080`
2. Phone (same Wi‑Fi): open `http://YOUR_PC_LAN_IP:8080` in **Chrome**
3. Both users enter the **same room ID** and signaling URL `ws://YOUR_PC_LAN_IP:8765`
4. One taps **Start call (host)**, the other **Join call**

## Limitations

- **STUN only** (Google public STUN) is configured in the app. Some mobile networks need a **TURN** relay; if video never connects, try same Wi‑Fi or add TURN later.
- **HTTPS**: Phone browsers may restrict camera/mic on plain `http://` LAN URLs. If permissions fail, use `flutter run` with a tunnel (ngrok/cloudflare) or serve web over HTTPS.
- This is **not** production signaling (no auth, no persistence).
