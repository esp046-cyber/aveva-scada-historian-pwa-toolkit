// server.js
// Optional custom server: only needed when a deployment target requires a
// real bidirectional WebSocket (e.g. operator "acknowledge alarm" round
// trips) rather than the Edge-deployable SSE route in
// src/app/api/stream/route.ts. Run with `node server.js` instead of
// `next start` -- see package.json "start:ws" script added by the
// scaffold script below.
//
// Broadcasts the same StreamMessage shape consumed by src/lib/websocket.ts.

const { createServer } = require('http');
const { parse } = require('url');
const next = require('next');
const { WebSocketServer } = require('ws');

const dev = process.env.NODE_ENV !== 'production';
const port = Number(process.env.PORT || 3000);
const app = next({ dev });
const handle = app.getRequestHandler();

const WATCHED_TAGS = [
  'AGC.PLANT1.PUMP01.FLOW_PV',
  'AGC.PLANT1.PUMP01.SUCT_PRESS',
  'AGC.PLANT1.TANK04.LEVEL_PV',
];

app.prepare().then(() => {
  const httpServer = createServer((req, res) => {
    const parsedUrl = parse(req.url, true);
    handle(req, res, parsedUrl);
  });

  const wss = new WebSocketServer({ noServer: true });
  const clients = new Set();

  httpServer.on('upgrade', (req, socket, head) => {
    const { pathname } = parse(req.url);
    if (pathname !== '/api/stream') {
      socket.destroy();
      return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => {
      clients.add(ws);
      ws.on('close', () => clients.delete(ws));
      // Operator round-trips (e.g. alarm ack) arrive here:
      ws.on('message', (raw) => {
        try {
          const msg = JSON.parse(raw.toString());
          if (msg.type === 'ack') {
            // TODO: persist ack via AGC_App / Runtime AckTime update, then
            // rebroadcast the resolved alarm state to all clients.
            broadcast({ type: 'alarm', ...msg, state: 'ACK' });
          }
        } catch {
          /* ignore malformed client frames */
        }
      });
    });
  });

  function broadcast(message) {
    const payload = JSON.stringify(message);
    for (const ws of clients) {
      if (ws.readyState === ws.OPEN) ws.send(payload);
    }
  }

  // Replace this synthetic tick with a real Historian OPC-UA/REST
  // subscription bridge in production.
  setInterval(() => {
    for (const tagName of WATCHED_TAGS) {
      broadcast({
        type: 'telemetry',
        tagName,
        value: Number((Math.random() * 100).toFixed(2)),
        quality: 192,
        timestamp: new Date().toISOString(),
      });
    }
  }, 1000);

  httpServer.listen(port, () => {
    console.log(`[AGC SCADA PWA] ready on http://localhost:${port} (WebSocket bridge active on /api/stream)`);
  });
});
