# SignTalk

**Bridging communication through speech, text, and Indian Sign Language.**

SignTalk is an assistive communication application designed to help Indian Sign Language (ISL) users and non-signers communicate more easily. Built with Flutter, the project brings together speech recognition, text-to-speech, text-based assistance, and real-time video communication in a single interface.

## Key Features

- **Speech-to-Text:** Convert spoken input into editable text where browser speech recognition is supported.
- **Text-to-Speech:** Read typed text aloud.
- **Conversation Assistance:** Compose, edit, and share text during communication.
- **Real-Time Video Calling:** WebRTC-based audio/video calling with a lightweight WebSocket signaling server.
- **In-Call Assistance:** Captions and text-to-speech assistance during calls, subject to browser permissions and microphone availability.
- **ISL Integration Architecture:** An adapter-based structure intended to support sign-language recognition as a model becomes available.
- **Responsive Interface:** Flutter Web interface designed for use on desktop and compatible mobile browsers.

## Technology Stack

- Flutter and Dart
- WebRTC (`flutter_webrtc`)
- WebSocket signaling with Node.js
- Browser speech recognition
- Text-to-speech
- Shared preferences for local settings

## Current Development Status

SignTalk is under active development. Speech and text assistance are implemented, and the WebRTC calling workflow has been added. **End-to-end calling still requires validation on two devices** and may require HTTPS, appropriate network configuration, and TURN infrastructure for reliable deployment.

**Live ISL recognition is not connected** to a trained, validated recognition model. The application must not be considered a production-ready accessibility solution until its recognition accuracy, accessibility, privacy, and reliability have been evaluated.

## Getting Started

### Prerequisites

- Flutter SDK compatible with the project
- Dart SDK supplied by Flutter
- Node.js and npm for the signaling server
- Chrome or another supported browser

### Run the Flutter web app

```bash
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

### Run the signaling server (separate terminal)

```bash
cd tools/signaling-server
npm install
npm start
```

Open the URL printed by Flutter in your browser. For two-device testing, use the PC's reachable LAN address on the second device and configure the signaling URL appropriately (default local relay: port `8765`). Camera and microphone access may require HTTPS on mobile browsers.

## Testing

Run static analysis and automated tests:

```bash
flutter analyze
flutter test
```

## Project Layout

| Path | Description |
|------|-------------|
| `lib/` | Flutter application (UI, services, WebRTC integration) |
| `test/` | Unit and widget tests |
| `tools/signaling-server/` | WebSocket room relay for WebRTC signaling |
| `stitch_signtalk_accessible_ui_design/` | Stitch UI design reference assets |

## Roadmap

- Connect and validate an ISL recognition model.
- Improve cross-device WebRTC reliability and configure secure deployment.
- Expand sign-language vocabulary and visual signing support.
- Improve accessibility testing, documentation, and automated test coverage.

## Contributing

Contributions, bug reports, and suggestions are welcome. Please describe the problem, expected behavior, and steps to reproduce issues.

## Disclaimer

SignTalk is an educational and development-stage prototype. Its features and supported environments are subject to testing and validation.
