// src/components/DashboardLayout.tsx
'use client';

import { useEffect, useState } from 'react';
import StatusBar from './StatusBar';
import NavRail from './NavRail';
import Footer from './Footer';
import TelemetryPanel, { type TelemetryTag } from './TelemetryPanel';
import AlarmPanel from './AlarmPanel';
import type { AlarmEventRow } from '@/lib/historianApi';
import { createScadaStream, type ConnectionState, type StreamMessage } from '@/lib/websocket';

const SEED_TAGS: TelemetryTag[] = [
  { tagName: 'AGC.PLANT1.PUMP01.FLOW_PV', label: 'Pump 01 Flow', unit: 'm³/h', value: 42.3, history: [40, 41, 41.5, 42, 42.3] },
  { tagName: 'AGC.PLANT1.PUMP01.SUCT_PRESS', label: 'Suction Pressure', unit: 'bar', value: 3.1, history: [3.0, 3.05, 3.1, 3.08, 3.1] },
  { tagName: 'AGC.PLANT1.TANK04.LEVEL_PV', label: 'Tank 04 Level', unit: '%', value: 68.4, history: [66, 67, 67.5, 68, 68.4] },
];

const SEED_ALARMS: AlarmEventRow[] = [
  {
    sourceType: 'ALARM',
    tagName: 'AGC.PLANT1.PUMP01.FLOW_PV',
    areaName: 'PLANT1.PUMPSTATION',
    alarmName: 'Low Flow Warning',
    alarmComment: 'Flow below 45 m³/h setpoint',
    priority: 400,
    severityBand: 'WARNING',
    eventTime: new Date(Date.now() - 6 * 60_000).toISOString(),
    isAcknowledged: false,
  },
  {
    sourceType: 'ALARM',
    tagName: 'AGC.PLANT1.TANK04.LEVEL_PV',
    areaName: 'PLANT1.STORAGE',
    alarmName: 'High-High Level',
    alarmComment: 'Level exceeded 90% for 2 min',
    priority: 50,
    severityBand: 'CRITICAL',
    eventTime: new Date(Date.now() - 2 * 60_000).toISOString(),
    isAcknowledged: false,
  },
];

export default function DashboardLayout() {
  const [activeNav, setActiveNav] = useState('telemetry');
  const [connectionState, setConnectionState] = useState<ConnectionState>('connecting');
  const [tags, setTags] = useState<TelemetryTag[]>(SEED_TAGS);
  const [alarms] = useState<AlarmEventRow[]>(SEED_ALARMS);

  useEffect(() => {
    const client = createScadaStream('/api/stream');

    const unsubState = client.onConnectionState(setConnectionState);
    const unsubMsg = client.onMessage((msg: StreamMessage) => {
      if (msg.type !== 'telemetry') return;
      setTags((prev) =>
        prev.map((t) =>
          t.tagName === msg.tagName
            ? { ...t, value: msg.value, history: [...t.history.slice(-19), msg.value] }
            : t
        )
      );
    });

    client.connect();
    return () => {
      unsubState();
      unsubMsg();
      client.close();
    };
  }, []);

  return (
    <div className="flex h-screen flex-col">
      <StatusBar connectionState={connectionState} />

      <div className="flex flex-1 min-h-0">
        <NavRail active={activeNav} onChange={setActiveNav} />

        <main className="flex-1 min-w-0 schematic-canvas overflow-y-auto">
          <div className="p-4 sm:p-6 grid grid-cols-1 lg:grid-cols-[1fr_360px] gap-4">
            <section aria-label="Live telemetry" className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4 content-start">
              {tags.map((tag) => (
                <TelemetryPanel key={tag.tagName} tag={tag} />
              ))}
            </section>

            <section aria-label="Alarms and events">
              <AlarmPanel alarms={alarms} />
            </section>
          </div>
        </main>
      </div>

      <Footer />
    </div>
  );
}
