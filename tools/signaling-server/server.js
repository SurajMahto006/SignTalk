/**
 * SignTalk signaling server — relays SDP + ICE between peers in a room.
 * Run: cd tools/signaling-server && npm install && npm start
 */
const fs = require('fs');
const http = require('http');
const path = require('path');
const WebSocket = require('ws');
const room = require('./signaling-room');

const port = Number(process.env.PORT || process.env.SIGNALING_PORT || 8765);
const staticDir = path.resolve(
  process.env.STATIC_DIR || path.join(__dirname, '..', '..', 'build', 'web'),
);
const staticEnabled = fs.existsSync(path.join(staticDir, 'index.html'));
const rooms = new Map();

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.wav': 'audio/wav',
  '.mp3': 'audio/mpeg',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.map': 'application/json',
  '.bin': 'application/octet-stream',
  '.txt': 'text/plain; charset=utf-8',
};

function insideRoot(root, filePath) {
  const rootWithSep = root.endsWith(path.sep) ? root : root + path.sep;
  return filePath === root || filePath.startsWith(rootWithSep);
}

function serveStatic(req, res) {
  if (!staticEnabled || (req.method !== 'GET' && req.method !== 'HEAD')) return false;
  let urlPath = '/';
  try {
    urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
  } catch (_) {
    res.writeHead(400);
    res.end('Bad request');
    return true;
  }
  if (urlPath.includes('\0')) {
    res.writeHead(400);
    res.end('Bad request');
    return true;
  }
  if (!urlPath.startsWith('/')) urlPath = `/${urlPath}`;
  let filePath = path.resolve(staticDir, `.${urlPath}`);
  if (!insideRoot(staticDir, filePath)) {
    res.writeHead(403);
    res.end('Forbidden');
    return true;
  }
  let exists = fs.existsSync(filePath) && fs.statSync(filePath).isFile();
  if (!exists && fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
    filePath = path.join(filePath, 'index.html');
    exists = fs.existsSync(filePath);
  }
  if (!exists) {
    if (path.extname(urlPath)) {
      res.writeHead(404);
      res.end('Not found');
      return true;
    }
    filePath = path.join(staticDir, 'index.html');
    if (!fs.existsSync(filePath)) return false;
  }
  const type = MIME[path.extname(filePath).toLowerCase()] || 'application/octet-stream';
  const cache = path.extname(filePath).toLowerCase() === '.html' ? 'no-cache' : 'public, max-age=3600';
  res.writeHead(200, { 'Content-Type': type, 'Cache-Control': cache });
  if (req.method === 'HEAD') {
    res.end();
    return true;
  }
  fs.createReadStream(filePath).pipe(res);
  return true;
}

const server = http.createServer((req, res) => {
  const pathOnly = (req.url || '/').split('?')[0];
  if (req.method === 'GET' && (pathOnly === '/health' || pathOnly === '/healthz')) {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('SignTalk signaling server OK\n');
    return;
  }
  if (!serveStatic(req, res)) {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('SignTalk signaling server OK\n');
  }
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
