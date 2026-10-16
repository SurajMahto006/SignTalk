import 'package:flutter_test/flutter_test.dart';
import 'package:signtalk/services/webrtc/webrtc_call_config.dart';

void main() {
  test('iceServers includes STUN by default', () {
    final servers = WebRtcCallConfig.iceServers();
    expect(servers, isNotEmpty);
    expect(servers.first['urls'], contains('stun:'));
  });

  test('signalingUrlForPage returns ws loopback when host empty', () {
    // Uri.base in tests is typically empty or test binding — should not throw.
    final url = WebRtcCallConfig.signalingUrlForPage();
    expect(url.startsWith('ws://'), isTrue);
    expect(url, contains('8765'));
  });

  test('signalingUrlOverride is empty in unit tests by default', () {
    expect(WebRtcCallConfig.signalingUrlOverride, isEmpty);
  });

  test('quick tunnel host does not default to wss on same host port 8765', () {
    final url = WebRtcCallConfig.signalingUrlForContext(
      scheme: 'https',
      host: 'concrete-folks-sql-combine.trycloudflare.com',
    );
    expect(url, isEmpty);
    expect(
      WebRtcCallConfig.hostUsesAppOnlyQuickTunnel('concrete-folks-sql-combine.trycloudflare.com'),
      isTrue,
    );
  });

  test('paired public demo app host uses centralized WSS signaling URL', () {
    final url = WebRtcCallConfig.signalingUrlForContext(
      scheme: 'https',
      host: 'informed-surge-travelling-lighting.trycloudflare.com',
    );
    expect(url, 'wss://angeles-sunny-ice-anybody.trycloudflare.com');
  });

  test('LAN http host still uses ws on same host', () {
    final url = WebRtcCallConfig.signalingUrlForContext(
      scheme: 'http',
      host: '192.168.1.10',
    );
    expect(url, 'ws://192.168.1.10:8765');
  });
}
