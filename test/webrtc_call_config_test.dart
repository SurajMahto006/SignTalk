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
}
