// src/lib/historianApi.ts
// Thin, typed client for the Next.js API routes that front the AVEVA
// Historian REST endpoint and the SQL stored procedures in /database.
// Every call here targets our own /api/* route, which in turn holds the
// Historian/SQL Server credentials server-side (never exposed to the PWA).

export type RetrievalMode = 'Cyclic' | 'Delta' | 'Full' | 'Average' | 'Minimum' | 'Maximum' | 'BestFit';

export interface TagHistoryPoint {
  tagName: string;
  dateTime: string;
  value: number;
  quality: number;
}

export interface AlarmEventRow {
  sourceType: 'ALARM' | 'EVENT';
  tagName: string;
  areaName: string;
  alarmName: string;
  alarmComment: string;
  priority: number;
  severityBand: 'CRITICAL' | 'WARNING' | 'INFO';
  eventTime: string;
  isAcknowledged: boolean;
}

async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Historian bridge error ${res.status}: ${body}`);
  }
  return res.json() as Promise<T>;
}

export function getTagHistory(params: {
  tagName?: string;
  tagList?: string[];
  startTime: string;
  endTime: string;
  retrievalMode?: RetrievalMode;
  resolutionMs?: number;
}): Promise<TagHistoryPoint[]> {
  const qs = new URLSearchParams({
    startTime: params.startTime,
    endTime: params.endTime,
    retrievalMode: params.retrievalMode ?? 'Cyclic',
    resolutionMs: String(params.resolutionMs ?? 1000),
    ...(params.tagName ? { tagName: params.tagName } : {}),
    ...(params.tagList ? { tagList: params.tagList.join(',') } : {}),
  });
  return apiFetch<TagHistoryPoint[]>(`/api/historian/history?${qs.toString()}`);
}

export function getAlarmsAndEvents(params: {
  startTime: string;
  endTime: string;
  areaFilter?: string;
  minPriority?: number;
  activeOnly?: boolean;
}): Promise<AlarmEventRow[]> {
  const qs = new URLSearchParams({
    startTime: params.startTime,
    endTime: params.endTime,
    minPriority: String(params.minPriority ?? 500),
    activeOnly: String(params.activeOnly ?? false),
    ...(params.areaFilter ? { areaFilter: params.areaFilter } : {}),
  });
  return apiFetch<AlarmEventRow[]>(`/api/historian/alarms?${qs.toString()}`);
}

export function logCustomTelemetry(entry: {
  tagName: string;
  value: number;
  enteredBy: string;
  dateTime?: string;
}): Promise<{ logId: number }> {
  return apiFetch('/api/telemetry/log', {
    method: 'POST',
    body: JSON.stringify(entry),
  });
}
