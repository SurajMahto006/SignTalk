/// Cloudflare **quick tunnel** pairing for public demos.
///
/// When both tunnels are running, update **only this file** (or use
/// `--dart-define=SIGNALING_URL=wss://…` when starting Flutter).
abstract final class SignTalkPublicDemoConfig {
  /// Public HTTPS app host (no scheme), from the app Cloudflare tunnel.
  static const cloudflareAppHost = 'informed-surge-travelling-lighting.trycloudflare.com';

  /// Public signaling WebSocket URL (WSS), from the signaling Cloudflare tunnel.
  static const cloudflareSignalingWss = 'wss://angeles-sunny-ice-anybody.trycloudflare.com';

  /// Returns [cloudflareSignalingWss] when the page is served from [cloudflareAppHost].
  static String? signalingWssForPageHost(String host) {
    if (host.isEmpty) return null;
    if (host.toLowerCase() == cloudflareAppHost.toLowerCase()) {
      return cloudflareSignalingWss;
    }
    return null;
  }
}
