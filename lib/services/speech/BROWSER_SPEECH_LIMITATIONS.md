# Browser speech recognition limitations (SignTalk web)

SignTalk uses the **`speech_to_text`** plugin, which on **Flutter web (Chrome/Edge)** maps to the browser’s **Web Speech API** (`SpeechRecognition` / `webkitSpeechRecognition`).

## Supported environments

- **Chrome / Edge (desktop and Android)**: Generally supported; user must grant microphone permission.
- **Safari (macOS/iOS)**: Limited or inconsistent Web Speech recognition support; the app shows an honest “not available” state.
- **Firefox**: Speech recognition is typically **not** available.

## Behavior notes

- Recognition requires a **secure context** (`https://` or `http://localhost` during `flutter run`).
- Results may include **interim (partial)** text while speaking; SignTalk shows partial text in Live Captions and commits finalized segments where the engine provides them.
- **Continuous listening** depends on the browser; some sessions stop after silence or a maximum duration.
- **Language** follows the locale passed to the engine (e.g. `en_US`); ISL sign recognition is **not** part of this API.

## Privacy

Audio is processed by the **browser vendor’s speech service** when using Web Speech on Chrome (network may be involved). SignTalk does **not** store raw audio in preferences or local storage.
