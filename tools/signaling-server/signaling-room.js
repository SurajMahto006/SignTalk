/**
 * Room logic for SignTalk signaling (testable without opening sockets).
 */

const MAX_PEERS_PER_ROOM = 2;
const ROOM_ID_PATTERN = /^[a-zA-Z0-9_-]{2,64}$/;

function validateRoomId(room) {
  if (typeof room !== 'string' || !ROOM_ID_PATTERN.test(room.trim())) {
    return { ok: false, message: 'Invalid room ID (use 2–64 chars: letters, numbers, _ -).' };
  }
  return { ok: true, room: room.trim() };
}

function peersInRoom(rooms, roomId, except) {
  const set = rooms.get(roomId);
  if (!set) return [];
  return [...set].filter((ws) => ws !== except && ws.readyState === 1);
}

function handleJoin(rooms, ws, msg) {
  const validated = validateRoomId(msg.room);
  if (!validated.ok) {
    return { error: validated.message };
  }
  const room = validated.room;
  if (!rooms.has(room)) rooms.set(room, new Set());
  const set = rooms.get(room);
  if (set.has(ws)) {
    return { joined: room, peers: peersInRoom(rooms, room, ws).length };
  }
  const others = peersInRoom(rooms, room, ws);
  if (others.length >= MAX_PEERS_PER_ROOM) {
    return { error: 'Room is full (maximum 2 participants).' };
  }
  const role = others.length === 0 ? 'host' : 'guest';
  ws.room = room;
  ws.participantId = msg.participantId ?? null;
  ws.role = role;
  set.add(ws);
  return {
    joined: room,
    peers: others.length,
    role,
  };
}

function handleLeave(rooms, ws) {
  if (!ws.room || !rooms.has(ws.room)) {
    return { notifyPeers: false, peers: 0, room: null };
  }
  const roomId = ws.room;
  const hadPeers = peersInRoom(rooms, roomId, ws).length > 0;
  rooms.get(roomId).delete(ws);
  const remaining = rooms.get(roomId).size;
  if (remaining === 0) rooms.delete(roomId);
  return { notifyPeers: hadPeers, peers: remaining, room: roomId };
}

function parseMessage(raw) {
  try {
    return JSON.parse(raw.toString());
  } catch {
    return null;
  }
}

const ALLOWED_RELAY_TYPES = new Set([
  'offer',
  'answer',
  'candidate',
  'gesture_caption',
  'isl_caption',
  'speech_caption',
]);

function canRelay(msg) {
  return ALLOWED_RELAY_TYPES.has(msg.type);
}

module.exports = {
  MAX_PEERS_PER_ROOM,
  validateRoomId,
  peersInRoom,
  handleJoin,
  handleLeave,
  parseMessage,
  canRelay,
};
