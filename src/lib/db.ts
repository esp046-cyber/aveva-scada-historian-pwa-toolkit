// src/lib/db.ts
// Server-only. Connection pool to the Historian Runtime DB / AGC_App DB.
// Credentials are read from environment variables (.env.local, or Azure/K8s
// secrets in production) -- never bundled into client code, since this file
// is only ever imported from route handlers under src/app/api/**.

import sql, { ConnectionPool, config as SqlConfig } from 'mssql';

const runtimeConfig: SqlConfig = {
  server: process.env.HISTORIAN_SQL_HOST ?? 'localhost',
  port: Number(process.env.HISTORIAN_SQL_PORT ?? 1433),
  database: process.env.HISTORIAN_SQL_DB ?? 'Runtime',
  user: process.env.HISTORIAN_SQL_USER,
  password: process.env.HISTORIAN_SQL_PASSWORD,
  options: {
    encrypt: process.env.HISTORIAN_SQL_ENCRYPT !== 'false',
    trustServerCertificate: process.env.NODE_ENV !== 'production',
  },
  pool: { max: 10, min: 0, idleTimeoutMillis: 30_000 },
};

const appConfig: SqlConfig = {
  ...runtimeConfig,
  database: process.env.AGC_APP_SQL_DB ?? 'AGC_App',
};

let runtimePool: ConnectionPool | null = null;
let appPool: ConnectionPool | null = null;

export async function getRuntimePool(): Promise<ConnectionPool> {
  if (!runtimePool) {
    runtimePool = await new sql.ConnectionPool(runtimeConfig).connect();
  }
  return runtimePool;
}

export async function getAppPool(): Promise<ConnectionPool> {
  if (!appPool) {
    appPool = await new sql.ConnectionPool(appConfig).connect();
  }
  return appPool;
}

export { sql };
