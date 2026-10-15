/// Browser media permission / capture state for the call lobby.
enum CallMediaAccessState {
  idle,
  requesting,
  granted,
  denied,
  unavailable,
  error,
}

/// Signaling vs media path — WebSocket alone is not a connected call.
enum CallSignalingState {
  idle,
  connecting,
  joined,
  disconnected,
  failed,
}

/// ICE / peer connection progress.
enum CallMediaPathState {
  idle,
  preparingLocalMedia,
  negotiating,
  connected,
  reconnecting,
  failed,
}
