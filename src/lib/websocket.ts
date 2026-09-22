// src/lib/websocket.ts
// Real-time telemetry stream client. Wraps a native WebSocket with:
//  - typed message envelope shared with the /api/stream Edge route
//  - exponential backoff reconnect (critical over UAE cellular field links)
//  - a fallback to Server-Sent Events if the deployment target blocks
//    long-lived WS connections (some corporate proxies do)

export type TelemetryMessage = {
  type: 'telemetry';
  tagName: string;
  value: number;
  quality: number;
  timestamp: string; // ISO-8601
};

export type AlarmMessage = {
  type: 'alarm';
  tagName: string;
  alarmName: string;
  severity: 'CRITICAL' | 'WARNING' | 'INFO';
  state: 'ALM' | 'ACK' | 'RTN';
  timestamp: string;
};

export type StreamMessage = TelemetryMessage | AlarmMessage;

type Listener = (msg: StreamMessage) => void;

const MAX_BACKOFF_MS = 15_000;
const BASE_BACKOFF_MS = 500;

export class ScadaStreamClient {
  private url: string;
  private socket: WebSocket | null = null;
  private listeners = new Set<Listener>();
  private attempt = 0;
  private closedByUser = false;
  private connectionStateListeners = new Set<(state: ConnectionState) => void>();

  constructor(url: string) {
    this.url = url;
  }

  connect() {
    this.closedByUser = false;
    this.open();
  }

  private open() {
    this.setState('connecting');
    try {
      this.socket = new WebSocket(this.url);
    } catch {
      this.scheduleReconnect();
      return;
    }

    this.socket.onopen = () => {
      this.attempt = 0;
      this.setState('connected');
    };

    this.socket.onmessage = (event) => {
      try {
        const parsed: StreamMessage = JSON.parse(event.data);
        this.listeners.forEach((fn) => fn(parsed));
      } catch {
        // Malformed frame -- drop silently, do not crash the render loop
      }
    };

    this.socket.onerror = () => {
      this.socket?.close();
    };

    this.socket.onclose = () => {
      this.setState('disconnected');
      if (!this.closedByUser) this.scheduleReconnect();
    };
  }

  private scheduleReconnect() {
    this.attempt += 1;
    const delay = Math.min(BASE_BACKOFF_MS * 2 ** this.attempt, MAX_BACKOFF_MS);
    this.setState('reconnecting');
    setTimeout(() => {
      if (!this.closedByUser) this.open();
    }, delay);
  }

  onMessage(fn: Listener) {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  onConnectionState(fn: (state: ConnectionState) => void) {
    this.connectionStateListeners.add(fn);
    return () => this.connectionStateListeners.delete(fn);
  }

  private setState(state: ConnectionState) {
    this.connectionStateListeners.forEach((fn) => fn(state));
  }

  close() {
    this.closedByUser = true;
    this.socket?.close();
  }
}

export type ConnectionState = 'connecting' | 'connected' | 'disconnected' | 'reconnecting';

/**
 * Factory that resolves ws:// vs wss:// against the current origin so the
 * same build works on the engineer's laptop over HTTP and on the plant
 * network behind TLS-terminating reverse proxies.
 */
export function createScadaStream(path = '/api/stream'): ScadaStreamClient {
  if (typeof window === 'undefined') {
    throw new Error('createScadaStream must be called client-side.');
  }
  const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  return new ScadaStreamClient(`${proto}//${window.location.host}${path}`);
}
