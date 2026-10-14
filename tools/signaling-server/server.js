/**
 * Minimal SignTalk signaling server — relays SDP + ICE between peers in a room.
 * Run: cd tools/signaling-server && npm install ws && npm start
 * Listens on 0.0.0.0:8765 (configure SIGNALING_PORT env to override).
 */
const http = require('http');
const WebSocket = require('ws');

const port = Number(process.env.SIGNALING_PORT || 8765);
const rooms = new Map();

const server = http.createServer((_req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('SignTalk signaling server OK\n');
});

const wss = new WebSocket.Server({ server });

function peersInRoom(roomId, except) {
  const set = rooms.get(roomId);
  if (!set) return [];
  return [...set].filter((ws) => ws !== except && ws.readyState === WebSocket.OPEN);
}

wss.on('connection', (ws, req) => {
  const clientIp = req.socket.remoteAddress;
  console.log(`[signaling] connect from ${clientIp}`);

  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      console.log(`[signaling] ignore non-JSON from ${clientIp}`);
      return;
    }

    const msgType = msg.type ?? 'unknown';

    if (msg.type === 'join' && msg.room) {
      ws.room = msg.room;
      if (!rooms.has(msg.room)) rooms.set(msg.room, new Set());
      rooms.get(msg.room).add(ws);
      const others = peersInRoom(msg.room, ws);
      console.log(
        `[signaling] join room=${msg.room} from=${clientIp} peers=${others.length}`,
      );
      ws.send(JSON.stringify({ type: 'joined', room: msg.room, peers: others.length }));
      for (const peer of others) {
        peer.send(JSON.stringify({ type: 'peer_joined', room: msg.room }));
      }
      return;
    }

    if (!ws.room) {
      console.log(`[signaling] ${msgType} before join from ${clientIp} (ignored)`);
      return;
    }

    console.log(`[signaling] relay ${msgType} room=${ws.room} from=${clientIp}`);
    for (const peer of peersInRoom(ws.room, ws)) {
      peer.send(raw.toString());
    }
  });

  ws.on('close', (code, reason) => {
    const room = ws.room ?? '(none)';
    const reasonText = reason?.toString() || '';
    console.log(
      `[signaling] close from=${clientIp} room=${room} code=${code} reason=${reasonText || '(empty)'}`,
    );
    if (!ws.room || !rooms.has(ws.room)) return;
    rooms.get(ws.room).delete(ws);
    if (rooms.get(ws.room).size === 0) rooms.delete(ws.room);
  });

  ws.on('error', (err) => {
    console.log(`[signaling] socket error from ${clientIp}: ${err.message}`);
  });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`SignTalk signaling on ws://0.0.0.0:${port}`);
});
