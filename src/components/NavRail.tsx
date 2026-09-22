// src/components/NavRail.tsx
'use client';

import { useState } from 'react';
import { TelemetryIcon, AlarmIcon, DatabaseIcon, SettingsIcon } from './icons/ScadaIcons';

const NAV_ITEMS = [
  { id: 'telemetry', label: 'Telemetry', Icon: TelemetryIcon },
  { id: 'alarms', label: 'Alarms', Icon: AlarmIcon },
  { id: 'historian', label: 'Historian', Icon: DatabaseIcon },
  { id: 'settings', label: 'Settings', Icon: SettingsIcon },
] as const;

export default function NavRail({
  active,
  onChange,
}: {
  active: string;
  onChange: (id: string) => void;
}) {
  return (
    <nav className="hidden md:flex w-16 shrink-0 flex-col items-center gap-1 border-r border-steelline bg-graphite/60 py-4">
      {NAV_ITEMS.map(({ id, label, Icon }) => {
        const isActive = active === id;
        return (
          <button
            key={id}
            onClick={() => onChange(id)}
            aria-label={label}
            aria-current={isActive}
            className={`group relative flex h-12 w-12 flex-col items-center justify-center rounded-md transition-colors ${
              isActive ? 'bg-cyan/10 text-cyan' : 'text-text-dim hover:text-offwhite hover:bg-white/5'
            }`}
          >
            {isActive && <span className="absolute left-0 h-6 w-0.5 rounded-r bg-cyan" />}
            <Icon className="h-5 w-5" />
            <span className="mt-1 text-[9px] leading-none">{label}</span>
          </button>
        );
      })}
    </nav>
  );
}
