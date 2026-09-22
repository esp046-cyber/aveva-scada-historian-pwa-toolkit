// src/components/TelemetryPanel.tsx
'use client';

import { useMemo } from 'react';
import { TelemetryIcon } from './icons/ScadaIcons';

export interface TelemetryTag {
  tagName: string;
  label: string;
  unit: string;
  value: number;
  history: number[]; // recent samples, oldest first, for the sparkline
}

function Sparkline({ points }: { points: number[] }) {
  const path = useMemo(() => {
    if (points.length < 2) return '';
    const w = 120;
    const h = 32;
    const min = Math.min(...points);
    const max = Math.max(...points);
    const range = max - min || 1;
    return points
      .map((p, i) => {
        const x = (i / (points.length - 1)) * w;
        const y = h - ((p - min) / range) * h;
        return `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`;
      })
      .join(' ');
  }, [points]);

  return (
    <svg viewBox="0 0 120 32" className="w-full h-8" preserveAspectRatio="none">
      <path d={path} fill="none" stroke="var(--cyan)" strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}

export default function TelemetryPanel({ tag }: { tag: TelemetryTag }) {
  return (
    <div className="glass-panel p-4 flex flex-col gap-3 min-w-[220px]">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2 text-text-dim">
          <TelemetryIcon className="w-4 h-4 text-cyan" />
          <span className="text-xs">{tag.label}</span>
        </div>
        <span className="status-dot status-dot--live animate-pulse-live" title="Live tag" />
      </div>

      <div className="flex items-baseline gap-1">
        <span className="readout text-3xl font-semibold text-offwhite">{tag.value.toFixed(1)}</span>
        <span className="readout text-xs text-text-dim">{tag.unit}</span>
      </div>

      <Sparkline points={tag.history} />

      <p className="readout text-[10px] text-text-dim truncate" title={tag.tagName}>
        {tag.tagName}
      </p>
    </div>
  );
}
