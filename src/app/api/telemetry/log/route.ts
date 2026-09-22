// src/app/api/telemetry/log/route.ts
// POST /api/telemetry/log { tagName, value, enteredBy, dateTime? }
// Bridges to database/03_sp_insert_telemetry_log.sql usp_LogCustomTelemetry.
// Rows land in AGC_App.dbo.CustomTelemetryLog and are promoted into
// Historian by the worker described in that script's header comment.

import { NextRequest, NextResponse } from 'next/server';
import { getAppPool, sql } from '@/lib/db';

export const runtime = 'nodejs';

interface LogTelemetryBody {
  tagName: string;
  value: number;
  enteredBy: string;
  dateTime?: string;
}

export async function POST(req: NextRequest) {
  let body: LogTelemetryBody;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body.' }, { status: 400 });
  }

  if (!body.tagName || typeof body.value !== 'number' || !body.enteredBy) {
    return NextResponse.json(
      { error: 'tagName, value (number), and enteredBy are required.' },
      { status: 400 }
    );
  }

  try {
    const pool = await getAppPool();
    const request = pool.request();
    request.input('TagName', sql.NVarChar(256), body.tagName);
    request.input('DateTime', sql.DateTime2, body.dateTime ? new Date(body.dateTime) : null);
    request.input('Value', sql.Float, body.value);
    request.input('Quality', sql.SmallInt, 192);
    request.input('Source', sql.NVarChar(64), 'MANUAL_ENTRY');
    request.input('EnteredBy', sql.NVarChar(128), body.enteredBy);

    const result = await request.execute('dbo.usp_LogCustomTelemetry');
    const logId = result.recordset?.[0]?.LogId ?? null;

    return NextResponse.json({ logId }, { status: 201 });
  } catch (err) {
    console.error('[api/telemetry/log]', err);
    return NextResponse.json({ error: 'Failed to log telemetry entry.' }, { status: 502 });
  }
}
