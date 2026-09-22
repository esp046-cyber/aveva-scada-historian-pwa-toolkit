// src/app/api/historian/alarms/route.ts
// GET /api/historian/alarms?startTime=...&endTime=...&minPriority=500&activeOnly=true
// Bridges the PWA's Alarm Panel to database/02_sp_get_alarms_events.sql.

import { NextRequest, NextResponse } from 'next/server';
import { getRuntimePool, sql } from '@/lib/db';

export const runtime = 'nodejs';

export async function GET(req: NextRequest) {
  const params = req.nextUrl.searchParams;

  const startTime = params.get('startTime');
  const endTime = params.get('endTime');
  const areaFilter = params.get('areaFilter');
  const minPriority = Number(params.get('minPriority') ?? '500');
  const activeOnly = params.get('activeOnly') === 'true';

  if (!startTime || !endTime) {
    return NextResponse.json({ error: 'startTime and endTime are required.' }, { status: 400 });
  }

  try {
    const pool = await getRuntimePool();
    const request = pool.request();
    request.input('StartTime', sql.DateTime2, new Date(startTime));
    request.input('EndTime', sql.DateTime2, new Date(endTime));
    request.input('AreaFilter', sql.NVarChar(256), areaFilter ?? null);
    request.input('MinPriority', sql.Int, minPriority);
    request.input('IncludeAckd', sql.Bit, true);
    request.input('ActiveOnly', sql.Bit, activeOnly);

    const result = await request.execute('dbo.usp_GetAlarmsAndEvents');

    const rows = result.recordset.map((r: Record<string, unknown>) => ({
      sourceType: r.SourceType,
      tagName: r.TagName,
      areaName: r.AreaName,
      alarmName: r.AlarmName,
      alarmComment: r.AlarmComment,
      priority: r.Priority,
      severityBand: r.SeverityBand,
      eventTime: r.EventTime,
      isAcknowledged: r.IsAcknowledged,
    }));

    return NextResponse.json(rows, {
      headers: { 'Cache-Control': 'private, max-age=2' },
    });
  } catch (err) {
    console.error('[api/historian/alarms]', err);
    return NextResponse.json({ error: 'Alarm/event query failed.' }, { status: 502 });
  }
}
