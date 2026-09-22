// src/app/api/historian/history/route.ts
// GET /api/historian/history?tagName=...&startTime=...&endTime=...&retrievalMode=Cyclic&resolutionMs=1000
// Bridges the PWA to database/01_sp_get_tag_history.sql.

import { NextRequest, NextResponse } from 'next/server';
import { getRuntimePool, sql } from '@/lib/db';

export const runtime = 'nodejs'; // mssql needs the Node runtime, not Edge

export async function GET(req: NextRequest) {
  const params = req.nextUrl.searchParams;

  const tagName = params.get('tagName');
  const tagList = params.get('tagList');
  const startTime = params.get('startTime');
  const endTime = params.get('endTime');
  const retrievalMode = params.get('retrievalMode') ?? 'Cyclic';
  const resolutionMs = Number(params.get('resolutionMs') ?? '1000');

  if (!startTime || !endTime || (!tagName && !tagList)) {
    return NextResponse.json(
      { error: 'startTime, endTime, and one of tagName/tagList are required.' },
      { status: 400 }
    );
  }

  try {
    const pool = await getRuntimePool();
    const request = pool.request();
    request.input('TagName', sql.NVarChar(256), tagName ?? null);
    request.input('TagList', sql.NVarChar(sql.MAX), tagList ?? null);
    request.input('StartTime', sql.DateTime2, new Date(startTime));
    request.input('EndTime', sql.DateTime2, new Date(endTime));
    request.input('RetrievalMode', sql.VarChar(20), retrievalMode);
    request.input('ResolutionMs', sql.Int, resolutionMs);

    const result = await request.execute('dbo.usp_GetTagHistory');

    const rows = result.recordset.map((r: Record<string, unknown>) => ({
      tagName: r.TagName,
      dateTime: r.DateTime,
      value: r.Value,
      quality: r.Quality,
    }));

    return NextResponse.json(rows, {
      headers: { 'Cache-Control': 'private, max-age=5' },
    });
  } catch (err) {
    console.error('[api/historian/history]', err);
    return NextResponse.json({ error: 'Historian query failed.' }, { status: 502 });
  }
}
