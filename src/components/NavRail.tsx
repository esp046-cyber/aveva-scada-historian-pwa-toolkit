'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { TelemetryIcon, AlarmIcon, HistorianIcon, SettingsIcon } from './icons/ScadaIcons';

const NAV_ITEMS = [
  { name: 'Telemetry', href: '/', icon: TelemetryIcon },
  { name: 'Alarms', href: '/alarms', icon: AlarmIcon },
  { name: 'Historian', href: '/historian', icon: HistorianIcon },
  { name: 'Settings', href: '/settings', icon: SettingsIcon },
];

export default function NavRail() {
  const pathname = usePathname();

  return (
    <nav className="flex flex-col gap-2 p-3 border-r border-white/10 bg-black/40 backdrop-blur-md w-20 shrink-0 select-none">
      {NAV_ITEMS.map((item) => {
        const Icon = item.icon;
        const isActive = pathname === item.href;
        return (
          <Link
            key={item.name}
            href={item.href}
            className={`flex flex-col items-center justify-center gap-1 py-3 px-1 rounded-lg transition-colors ${
              isActive ? 'bg-white/10 text-cyan' : 'text-text-dim hover:text-white hover:bg-white/5'
            }`}
          >
            <Icon className="w-5 h-5" />
            <span className="text-[10px] font-medium tracking-tight">{item.name}</span>
          </Link>
        );
      })}
    </nav>
  );
}
