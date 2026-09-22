// src/components/StatusBar.tsx
'use client';

import { useEffect, useState } from 'react';
import { SignalWifiIcon } from './icons/ScadaIcons';
import type { ConnectionState } from '@/lib/websocket';

const STATE_LABEL: Record<ConnectionState, string> = {
  connected: 'Live',
  connecting: 'Connecting',
  reconnecting: 'Reconnecting',
  disconnected: 'Offline',
};

const STATE_DOT: Record<ConnectionState, string> = {
  connected: 'status-dot--live',
  connecting: 'status-dot--warn',
  reconnecting: 'status-dot--warn',
  disconnected: 'status-dot--critical',
};

export default function StatusBar({ connectionState }: { connectionState: ConnectionState }) {
  const [now, setNow] = useState<Date | null>(null);

  useEffect(() => {
    setNow(new Date());
    const t = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(t);
  }, []);

  return (
    <header className="h-14 shrink-0 border-b border-steelline bg-graphite/80 backdrop-blur-md flex items-center justify-between px-4 sm:px-6">
      <div className="flex items-center gap-3">
        <div className="h-7 w-7 rounded-sm border border-cyan/40 flex items-center justify-center">
          <span className="readout text-cyan text-[11px] font-semibold">AGC</span>
        </div>
        <div className="leading-tight">
          <p className="text-sm font-medium">SCADA Ops Console</p>
          <p className="text-[11px] text-text-dim">Plant 1 — Jebel Ali Utilities Corridor</p>
        </div>
      </div>

      <div className="flex items-center gap-5">
        <div className="hidden sm:flex items-center gap-2">
          <span className={`status-dot ${STATE_DOT[connectionState]} ${connectionState === 'connected' ? 'animate-pulse-live' : ''}`} />
          <span className="text-xs text-text-dim">{STATE_LABEL[connectionState]}</span>
          <SignalWifiIcon className="w-4 h-4 text-text-dim" />
        </div>
        <span className="readout text-xs text-text-dim tabular-nums" suppressHydrationWarning>
          {now ? now.toLocaleTimeString('en-GB', { hour12: false, timeZone: 'Asia/Dubai' }) + ' GST' : '--:--:-- GST'}
        </span>
      </div>
    </header>
  );
}
