# SignTalk — Judge demo guide (beginner)

This guide walks you through a **real** two-browser demo: WebRTC video/audio, MediaPipe hand gestures → short English captions, and caption relay over the signaling server.

**Honest scope:** Three prototype poses mapped to HELLO / YES / STOP. This is **not** a validated Indian Sign Language (ISL) translator.

---

## 1. Prerequisites

| Check | How |
|--------|-----|
| Flutter SDK | In PowerShell: `flutter --version` |
| Node.js | `node --version` (v18+ recommended) |
| Chrome | On PC; Chrome or similar on phone |
| `cloudflared` | `cloudflared --version` (for public HTTPS demo) |
| Same Wi‑Fi (optional) | PC + phone can use Cloudflare URLs without LAN setup |

**RAM:** Gesture model loads from Google CDN (~few MB) on first use; inference is throttled (~12 fps). On a 4 GB PC, close extra tabs.

**Camera/mic:** Browsers require **HTTPS or localhost**. For phone + PC, use the **public HTTPS app URL** from Cloudflare, not raw `http://LAN-IP:8080`.

---

## 2. One-time: signaling server dependencies

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk\tools\signaling-server
npm install
```

---

## 3. Start services (four terminals)

**Working directory matters.** Do not start duplicate processes if something is already listening on **8765** or **8080**.

Check ports (optional):

```powershell
netstat -ano | findstr ":8765"
netstat -ano | findstr ":8080"
```

### Terminal 1 — Signaling server

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk\tools\signaling-server
npm start
```

Expect: WebSocket on `0.0.0.0:8765`.

### Terminal 2 — Flutter web server

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

- PC browser: `http://127.0.0.1:8080`
- After **Dart/config changes**, press **`R`** in this terminal (hot restart) or **`q`** then run the command again.

### Terminal 3 — App tunnel (HTTPS for phone)

Start **after** Flutter responds to GET on port 8080:

```powershell
cloudflared tunnel --url http://127.0.0.1:8080
```

Copy the printed URL, e.g. `https://something.trycloudflare.com`.

### Terminal 4 — Signaling tunnel (WSS for HTTPS page)

```powershell
cloudflared tunnel --url http://127.0.0.1:8765
```

Copy the printed URL and convert to WebSocket:

- `https://angeles-….trycloudflare.com` → `wss://angeles-….trycloudflare.com`

---

## 4. Configure public URLs when tunnels change

Quick tunnel hostnames **change every time** you restart `cloudflared`.

**Preferred:** Edit one file:

`lib/services/webrtc/sign_talk_public_demo_config.dart`

- `cloudflareAppHost` = app hostname **without** `https://`
- `cloudflareSignalingWss` = `wss://…` signaling hostname

When both devices open the **same public app URL**, the app auto-selects the paired WSS URL.

**Alternative (no file edit):** On each device, expand **Connection details** and paste the signaling URL, or run Flutter with:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define=SIGNALING_URL=wss://YOUR-SIGNALING-HOST.trycloudflare.com
```

**Current values in repo (may be stale until you update):**

- App host: `informed-surge-travelling-lighting.trycloudflare.com`
- Signaling WSS: `wss://angeles-sunny-ice-anybody.trycloudflare.com`

---

## 5. Open the app

| Device | URL |
|--------|-----|
| PC (local test) | `http://127.0.0.1:8080` → signaling defaults to `ws://127.0.0.1:8765` |
| PC or phone (judge demo) | Same **HTTPS** app tunnel URL on **both** devices |

Navigate: **Conversations → Live video call** (or your app’s video-call entry).

---

## 6. Join the same room (two participants)

1. **Participant A (host):** Room ID e.g. `signtalk-demo` → **Host call** → allow camera and microphone.
2. **Participant B (join):** Same room ID → **Join call** → allow camera and microphone.

**Success means real media**, not only “signaling joined”:

- Status should reach **Connected — remote media active** when remote video/audio tracks arrive.
- You see the **other person’s live video** (large) and your **PIP** (small).
- **Connection details:** chips for Signaling joined, Media connected, Permissions OK, Remote audio/video counts.

If status stays at **Signaling joined — waiting for WebRTC media…**, see troubleshooting (ICE/firewall/TURN).

---

## 7. Test gestures and captions

Gestures run on **your local camera** during an active call (Chrome / Flutter Web).

1. Expand **Demo gestures (prototype)** for pose help.
2. Supported mappings (MediaPipe → caption):

   | Pose | Caption |
   |------|---------|
   | Open palm toward camera | **HELLO** |
   | Thumb up | **YES** |
   | Closed fist | **STOP** |

3. **Sender:** status **Gesture recognized — …** and chip **You: HELLO** (etc.).
4. **Receiver:** chip **Them: HELLO**; optional spoken “Remote gesture: …” if TTS is enabled in settings.
5. **Repeat rule:** Lower your hand (brief **Detecting** state) before sending the same gesture again; 2 s cooldown also applies.

Other MediaPipe gestures may be detected locally but **are not sent** in this demo.

---

## 8. ICE, STUN, and TURN (honest)

- Default: **Google STUN** (`stun.l.google.com:19302`) via `WebRtcCallConfig`.
- Many home networks work with STUN alone.
- **Symmetric NAT / strict firewalls / some mobile carriers** may block direct peer connection → black remote video, ICE stuck. Fix for production: a **TURN** server (e.g. coturn). SignTalk does not ship TURN credentials; do not commit secrets.
- For demos: try **same public HTTPS app URL**, both on Wi‑Fi, or PC + phone hotspot.

---

## 9. Troubleshooting

| Problem | Things to try |
|---------|----------------|
| Cloudflare **502** | Start Flutter **before** app tunnel; use GET in browser, not only HEAD |
| **Black remote video** | Check ICE in Connection details; try another network; consider TURN for production |
| **Failed join / signaling** | Signaling server running; WSS URL matches HTTPS app; update `sign_talk_public_demo_config.dart` |
| **Captions not on other device** | Both joined same room; signaling joined on both; not holding same gesture without release |
| **Camera denied** | Use HTTPS or localhost; reset site permissions in Chrome |
| **Gesture model failed** | Internet for first CDN/model download; try closing tabs; CPU fallback runs if GPU fails |
| **Gestures idle** | Must be **in call** with camera on; web/Chrome only |

---

## 10. Automated checks (developer)

```powershell
cd C:\Users\Lenovo\Desktop\SignTalk
flutter analyze
flutter test
cd tools\signaling-server
npm test
```

Physical two-device video + gestures must still be verified manually.

---

## 11. Judge script (~60–90 seconds)

> “SignTalk helps people communicate with sign-related assistance. For this prototype we focused on a **live video call** between two browsers using **WebRTC**, with a small **gesture recognition** demo—not full ISL translation.
>
> On my laptop I **host** a room; on my phone we **join** the same room ID over a secure public link. You can see **real camera feeds**—not simulated video.
>
> When I show an **open palm**, the app recognizes it and sends **HELLO** to the other participant through our **signaling server**. **Thumb up** sends **YES**; **closed fist** sends **STOP**. The receiver sees the caption on screen and can hear it with text-to-speech.
>
> Under the hood we use **MediaPipe** in the browser for hands, and **WebRTC** for media. **STUN** helps with NAT; production deployments may need **TURN** on difficult networks.
>
> Limitations: only three demo gestures, English labels, and recognition depends on lighting and camera angle. Future work: richer sign vocabulary, ISL-specific models, and TURN for reliability.”

---

## 12. Working features vs limitations

**Working (when network and permissions allow):**

- Room-based WebRTC audio/video
- WSS signaling when app is on HTTPS (paired config)
- Three-gesture prototype captions + relay + debounce/release
- Connection diagnostics (signaling vs actual remote tracks)

**Limitations:**

- Not ISL-certified signs
- Flutter Web + Chrome oriented; gesture pipeline not on native mobile app
- No bundled TURN
- Cloudflare quick tunnels are temporary and unauthenticated—demo only

**Future work:**

- ISL pose/sentence models, TURN, data channel for captions, mobile clients, accessibility polish
