import 'package:flutter/foundation.dart';

/// ICE and signaling defaults (override at build/run time via `--dart-define`).
class WebRtcCallConfig {
  WebRtcCallConfig._();

  static const defaultSignalingPort = 8765;

  static const _defaultStun = 'stun:stun.l.google.com:19302';

  /// Build ICE server list from compile-time defines (no secrets in source).
  static List<Map<String, dynamic>> iceServers() {
    const stunUrl = String.fromEnvironment('STUN_URL', defaultValue: _defaultStun);
    const turnUrl = String.fromEnvironment('TURN_URL', defaultValue: '');
    const turnUser = String.fromEnvironment('TURN_USERNAME', defaultValue: '');
    const turnCredential = String.fromEnvironment('TURN_CREDENTIAL', defaultValue: '');

    final servers = <Map<String, dynamic>>[
      {'urls': stunUrl},
    ];

    if (turnUrl.isNotEmpty) {
      final turn = <String, dynamic>{'urls': turnUrl};
      if (turnUser.isNotEmpty) {
        turn['username'] = turnUser;
      }
      if (turnCredential.isNotEmpty) {
        turn['credential'] = turnCredential;
      }
      servers.add(turn);
    } else if (kDebugMode) {
      debugPrint(
        '[SignTalk WebRTC] TURN_URL not set — STUN-only may fail on restrictive networks.',
      );
    }

    return servers;
  }

  /// Optional full WebSocket URL (e.g. second HTTPS tunnel for signaling).
  /// Set at run/build time: `--dart-define=SIGNALING_URL=wss://your-signal-host.example`
  static String get signalingUrlOverride {
    const v = String.fromEnvironment('SIGNALING_URL', defaultValue: '');
    return v.trim();
  }

  /// Public HTTPS tunnels (Cloudflare quick tunnel, ngrok, etc.) expose only the app port.
  /// Signaling on :8765 needs a **second** tunnel — never `wss://<app-host>:8765`.
  static bool hostUsesAppOnlyQuickTunnel(String host) {
    final h = host.toLowerCase();
    if (h.isEmpty) return false;
    return h.endsWith('.trycloudflare.com') ||
        h.endsWith('.trycloudflare.com.') ||
        h.endsWith('.ngrok-free.app') ||
        h.endsWith('.ngrok.io') ||
        h.endsWith('.ngrok.app');
  }

  /// True when the UI should ask for a separate WSS URL (no dart-define override).
  static bool get needsSeparateSignalingTunnel {
    if (signalingUrlOverride.isNotEmpty) return false;
    final host = Uri.base.host;
    if (host.isEmpty) return false;
    return Uri.base.scheme == 'https' && hostUsesAppOnlyQuickTunnel(host);
  }

  static String get tunnelSignalingSetupHint =>
      'Paste the WebSocket URL from your **signaling** Cloudflare/ngrok tunnel (port 8765 → wss://…). '
      'The app tunnel does not include signaling.';

  /// Suggested signaling WebSocket URL from the page origin (LAN-friendly).
  static String signalingUrlForPage({int port = defaultSignalingPort}) {
    return signalingUrlForContext(
      scheme: Uri.base.scheme,
      host: Uri.base.host,
      port: port,
      override: signalingUrlOverride,
    );
  }

  /// Testable signaling default from page scheme/host (and optional override).
  static String signalingUrlForContext({
    required String scheme,
    required String host,
    int port = defaultSignalingPort,
    String override = '',
  }) {
    if (override.trim().isNotEmpty) return override.trim();

    if (host.isEmpty) {
      return 'ws://127.0.0.1:$port';
    }
    final loopback = host == 'localhost' || host == '127.0.0.1';
    if (loopback) {
      return 'ws://127.0.0.1:$port';
    }
    final isHttps = scheme == 'https';
    if (isHttps && hostUsesAppOnlyQuickTunnel(host)) {
      return '';
    }
    final wsScheme = isHttps ? 'wss' : 'ws';
    return '$wsScheme://$host:$port';
  }

  static bool get pageIsSecureContext {
    final host = Uri.base.host;
    if (host == 'localhost' || host == '127.0.0.1') return true;
    return Uri.base.scheme == 'https';
  }

  static String get secureContextHint {
    if (pageIsSecureContext) {
      return 'Secure context — camera and microphone are allowed by the browser when you grant permission.';
    }
    return 'Plain HTTP on a LAN IP may block camera/microphone on Android Chrome. '
        'Use https:// with a trusted certificate, Chrome on localhost for the laptop, '
        'or a development tunnel (e.g. Cloudflare Tunnel / ngrok) for phone testing.';
  }
}
