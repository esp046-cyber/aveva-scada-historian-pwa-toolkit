// src/app/api/health/route.ts
// GET /api/health -- powers the top status strip's DB/Historian indicators.
// Reads the most recent row per step from AGC_App.dbo.MaintenanceLog
// (see database/04_sql_maintenance.sql) so the engineer can see, at a
// glance, whether last night's maintenance job succeeded.

import { NextResponse } from 'next/server';
import { getAppPool } from '@/lib/db';

export const runtime = 'nodejs';

export async function GET() {
  try {
    const pool = await getAppPool();
    const result = await pool.request().query(`
      SELECT TOP 5 StepName, StatusText, Success, RunEndUtc
      FROM dbo.MaintenanceLog
      ORDER BY RunEndUtc DESC
    `);

    return NextResponse.json({
      status: 'ok',
      lastMaintenanceRuns: result.recordset,
      checkedAt: new Date().toISOString(),
    });
  } catch (err) {
    console.error('[api/health]', err);
    return NextResponse.json(
      { status: 'degraded', error: 'Could not reach AGC_App.dbo.MaintenanceLog' },
      { status: 200 }
    );
  }
}
