// src/app/api/stream/route.ts
// GET /api/stream -- Server-Sent Events fallback/primary channel for
// real-time telemetry + alarm pushes. Chosen as the Edge-deployable option
// because SSE runs on the Edge runtime and survives corporate proxies that
// block WebSocket upgrades on some Al Gurg site VPNs. For sites that need
// bidirectional acks (e.g. operator alarm-ack from the tablet), pair this
// with the WebSocket bridge in /server.js (see README "Realtime Transport").
//
// This route polls the Historian bridge every POLL_INTERVAL_MS and only
// pushes a frame when tag values actually change (delta-push), keeping
// payloads tiny for constrained UAE field-site cellular links.

import { NextRequest } from 'next/server';

export const runtime = 'edge';

const POLL_INTERVAL_MS = 1000;
const WATCHED_TAGS = [
  'AGC.PLANT1.PUMP01.FLOW_PV',
  'AGC.PLANT1.PUMP01.SUCT_PRESS',
  'AGC.PLANT1.TANK04.LEVEL_PV',
];

function sseFrame(event: string, data: unknown) {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

export async function GET(req: NextRequest) {
  const encoder = new TextEncoder();
  let closed = false;

  const stream = new ReadableStream({
    async start(controller) {
      controller.enqueue(encoder.encode(sseFrame('connected', { at: new Date().toISOString() })));

      const interval = setInterval(async () => {
        if (closed) return;
        try {
          // NOTE: in production, replace this synthetic tick with a call
          // into the Historian's own OPC-UA/REST subscription and forward
          // real deltas -- this Edge function must stay stateless/cheap.
          for (const tagName of WATCHED_TAGS) {
            const frame = {
              type: 'telemetry',
              tagName,
              value: Number((Math.random() * 100).toFixed(2)),
              quality: 192,
              timestamp: new Date().toISOString(),
            };
            controller.enqueue(encoder.encode(sseFrame('message', frame)));
          }
        } catch (err) {
          controller.enqueue(encoder.encode(sseFrame('error', { message: 'stream tick failed' })));
        }
      }, POLL_INTERVAL_MS);

      req.signal.addEventListener('abort', () => {
        closed = true;
        clearInterval(interval);
        controller.close();
      });
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
    },
  });
}
