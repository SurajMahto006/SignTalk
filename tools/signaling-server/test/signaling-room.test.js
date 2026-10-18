const { test } = require('node:test');
const assert = require('node:assert/strict');
const room = require('../signaling-room');

test('validateRoomId rejects invalid ids', () => {
  assert.equal(room.validateRoomId('').ok, false);
  assert.equal(room.validateRoomId('a').ok, false);
  assert.equal(room.validateRoomId('bad room').ok, false);
  assert.equal(room.validateRoomId('valid-room_1').ok, true);
});

test('room full after two peers', () => {
  const rooms = new Map();
  const a = { readyState: 1 };
  const b = { readyState: 1 };
  const c = { readyState: 1 };

  const j1 = room.handleJoin(rooms, a, { room: 'demo', participantId: 'p1' });
  assert.equal(j1.error, undefined);
  const j2 = room.handleJoin(rooms, b, { room: 'demo', participantId: 'p2' });
  assert.equal(j2.error, undefined);
  const j3 = room.handleJoin(rooms, c, { room: 'demo', participantId: 'p3' });
  assert.match(j3.error, /full/i);
});

test('parseMessage rejects non-JSON', () => {
  assert.equal(room.parseMessage('not json'), null);
});

test('canRelay allows offer answer candidate gesture_caption isl_caption', () => {
  assert.equal(room.canRelay({ type: 'offer' }), true);
  assert.equal(room.canRelay({ type: 'gesture_caption' }), true);
  assert.equal(room.canRelay({ type: 'isl_caption' }), true);
  assert.equal(room.canRelay({ type: 'speech_caption' }), true);
  assert.equal(room.canRelay({ type: 'join' }), false);
});
