// src/components/AlarmPanel.tsx
'use client';

import { AlarmIcon } from './icons/ScadaIcons';
import type { AlarmEventRow } from '@/lib/historianApi';

const SEVERITY_STYLES: Record<AlarmEventRow['severityBand'], { dot: string; text: string; border: string }> = {
  CRITICAL: { dot: 'status-dot--critical', text: 'text-crimson', border: 'border-l-crimson' },
  WARNING: { dot: 'status-dot--warn', text: 'text-amber', border: 'border-l-amber' },
  INFO: { dot: 'status-dot--live', text: 'text-cyan', border: 'border-l-cyan' },
};

function formatTime(iso: string) {
  try {
    return new Date(iso).toLocaleTimeString('en-GB', { hour12: false, timeZone: 'Asia/Dubai' });
  } catch {
    return iso;
  }
}

export default function AlarmPanel({ alarms }: { alarms: AlarmEventRow[] }) {
  const activeCritical = alarms.filter((a) => a.severityBand === 'CRITICAL' && !a.isAcknowledged).length;

  return (
    <div className="glass-panel p-4 flex flex-col gap-3 h-full">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <AlarmIcon className="w-4 h-4 text-crimson" />
          <h2 className="text-sm font-medium">Active Alarms</h2>
        </div>
        {activeCritical > 0 && (
          <span className="readout text-[11px] px-2 py-0.5 rounded-full bg-crimson/15 text-crimson border border-crimson/40">
            {activeCritical} critical
          </span>
        )}
      </div>

      <div className="flex flex-col gap-2 overflow-y-auto rail-scroll pr-1" style={{ maxHeight: '360px' }}>
        {alarms.length === 0 && (
          <p className="text-xs text-text-dim py-6 text-center">No alarms in the selected window.</p>
        )}
        {alarms.map((a, i) => {
          const style = SEVERITY_STYLES[a.severityBand];
          return (
            <div
              key={`${a.tagName}-${a.eventTime}-${i}`}
              className={`border-l-2 ${style.border} bg-white/[0.02] rounded-r px-3 py-2 flex items-start justify-between gap-2`}
            >
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <span className={`status-dot ${style.dot}`} />
                  <p className="text-xs font-medium truncate">{a.alarmName}</p>
                </div>
                <p className="text-[11px] text-text-dim truncate mt-0.5">{a.areaName} · {a.tagName}</p>
              </div>
              {/* FIX: suppressHydrationWarning added here */}
              <span suppressHydrationWarning className="readout text-[11px] text-text-dim shrink-0">
                {formatTime(a.eventTime)}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
