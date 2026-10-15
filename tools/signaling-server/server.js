/**
 * SignTalk signaling server — relays SDP + ICE between peers in a room.
 * Run: cd tools/signaling-server && npm install && npm start
 */
const http = require('http');
const WebSocket = require('ws');
const room = require('./signaling-room');

const port = Number(process.env.SIGNALING_PORT || 8765);
const rooms = new Map();

const server = http.createServer((_req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('SignTalk signaling server OK\n');
});

const wss = new WebSocket.Server({ server });

wss.on('connection', (ws, req) => {
  const clientIp = req.socket.remoteAddress;
  console.log(`[signaling] connect from ${clientIp}`);

  ws.on('message', (raw) => {
    const msg = room.parseMessage(raw);
    if (!msg || typeof msg.type !== 'string') {
      console.log(`[signaling] ignore invalid JSON from ${clientIp}`);
      return;
    }

    if (msg.type === 'join') {
      const result = room.handleJoin(rooms, ws, msg);
      if (result.error) {
        ws.send(JSON.stringify({ type: 'error', message: result.error }));
        console.log(`[signaling] join rejected from ${clientIp}: ${result.error}`);
        return;
      }
      console.log(`[signaling] join room=${result.joined} peers=${result.peers}`);
      ws.send(
        JSON.stringify({
          type: 'joined',
          room: result.joined,
          peers: result.peers,
          participantId: ws.participantId,
        }),
      );
      for (const peer of room.peersInRoom(rooms, result.joined, ws)) {
        peer.send(
          JSON.stringify({
            type: 'peer_joined',
            room: result.joined,
            peerId: ws.participantId,
          }),
        );
      }
      return;
    }

    if (!ws.room) {
      console.log(`[signaling] ${msg.type} before join from ${clientIp}`);
      return;
    }

    if (!room.canRelay(msg)) {
      console.log(`[signaling] blocked type=${msg.type} from ${clientIp}`);
      return;
    }

    console.log(`[signaling] relay ${msg.type} room=${ws.room}`);
    for (const peer of room.peersInRoom(rooms, ws.room, ws)) {
      peer.send(raw.toString());
    }
  });

  ws.on('close', (code) => {
    const roomId = ws.room;
    const left = room.handleLeave(rooms, ws);
    console.log(`[signaling] close from=${clientIp} room=${roomId ?? '(none)'} code=${code}`);
    if (left.notifyPeers && left.room) {
      for (const peer of room.peersInRoom(rooms, left.room, ws)) {
        peer.send(
          JSON.stringify({ type: 'peer_left', room: left.room, peers: left.peers }),
        );
      }
    }
  });

  ws.on('error', (err) => {
    console.log(`[signaling] socket error from ${clientIp}: ${err.message}`);
  });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`SignTalk signaling on ws://0.0.0.0:${port}`);
});
