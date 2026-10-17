/**
 * Pure helpers for SignTalk signaling (unit-tested).
 */

const MAX_PEERS_PER_ROOM = 2;
const ROOM_ID_PATTERN = /^[a-zA-Z0-9_-]{2,64}$/;

function validateRoomId(room) {
  if (typeof room !== 'string') return { ok: false, error: 'Room ID must be a string.' };
  if (!ROOM_ID_PATTERN.test(room)) {
    return {
      ok: false,
      error: 'Room ID must be 2–64 characters (letters, numbers, _ or -).',
    };
  }
  return { ok: true, room };
}

function validateJoinMessage(msg) {
  if (!msg || msg.type !== 'join') {
    return { ok: false, error: 'Expected join message.' };
  }
  const roomCheck = validateRoomId(msg.room);
  if (!roomCheck.ok) return roomCheck;
  const role = msg.role === 'host' || msg.role === 'guest' ? msg.role : 'guest';
  const participantId =
    typeof msg.participantId === 'string' && msg.participantId.length > 0
      ? msg.participantId
      : `anon-${Date.now()}`;
  return { ok: true, room: roomCheck.room, role, participantId };
}

function peersInRoom(rooms, roomId, exceptWs, openState) {
  const set = rooms.get(roomId);
  if (!set) return [];
  return [...set].filter((ws) => ws !== exceptWs && ws.readyState === openState);
}

function joinRoom(rooms, ws, join, openState) {
  const { room, participantId, role } = join;
  ws.room = room;
  ws.participantId = participantId;
  ws.role = role;
  if (!rooms.has(room)) rooms.set(room, new Set());
  const set = rooms.get(room);
  const othersBefore = peersInRoom(rooms, room, ws, openState);
  if (othersBefore.length >= MAX_PEERS_PER_ROOM) {
    return { ok: false, error: 'Room is full (maximum 2 participants).' };
  }
  set.add(ws);
  const others = peersInRoom(rooms, room, ws, openState);
  return {
    ok: true,
    joined: { type: 'joined', room, peers: others.length, participantId },
    notifyPeers: others.map(() => ({
      type: 'peer_joined',
      room,
      peers: others.length + 1,
      participantId,
    })),
  };
}

function leaveRoom(rooms, ws, openState) {
  const room = ws.room;
  if (!room || !rooms.has(room)) return { peerLeftMessages: [] };
  const set = rooms.get(room);
  set.delete(ws);
  const remaining = peersInRoom(rooms, room, null, openState);
  if (set.size === 0) rooms.delete(room);
  const peerLeftMessages = remaining.map((peer) => ({
    ws: peer,
    payload: JSON.stringify({
      type: 'peer_left',
      room,
      peers: remaining.length - 1,
      participantId: ws.participantId,
    }),
  }));
  return { peerLeftMessages, room };
}

module.exports = {
  MAX_PEERS_PER_ROOM,
  ROOM_ID_PATTERN,
  validateRoomId,
  validateJoinMessage,
  peersInRoom,
  joinRoom,
  leaveRoom,
};
