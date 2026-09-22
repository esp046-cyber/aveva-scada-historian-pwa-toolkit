#!/usr/bin/env bash
# scripts/build_project.sh
# =============================================================================
# Al Gurg Automation & Controls | AGC SCADA Ops PWA — Project Scaffolder
#
# Running this script regenerates the ENTIRE aveva-algurg-pwa/ project from
# scratch (directory tree + every source file), then packages it into
# aveva-algurg-pwa.zip, ready to push to GitHub.
#
# Usage:
#   chmod +x build_project.sh
#   ./build_project.sh
# =============================================================================
set -euo pipefail

PROJECT_DIR="aveva-algurg-pwa"
echo ">> Scaffolding ${PROJECT_DIR} ..."
rm -rf "${PROJECT_DIR}"
mkdir -p "${PROJECT_DIR}"

mkdir -p "${PROJECT_DIR}/database"
mkdir -p "${PROJECT_DIR}/public"
mkdir -p "${PROJECT_DIR}/public/icons"
mkdir -p "${PROJECT_DIR}/src/app"
mkdir -p "${PROJECT_DIR}/src/app/api/health"
mkdir -p "${PROJECT_DIR}/src/app/api/historian/alarms"
mkdir -p "${PROJECT_DIR}/src/app/api/historian/history"
mkdir -p "${PROJECT_DIR}/src/app/api/stream"
mkdir -p "${PROJECT_DIR}/src/app/api/telemetry/log"
mkdir -p "${PROJECT_DIR}/src/components"
mkdir -p "${PROJECT_DIR}/src/components/icons"
mkdir -p "${PROJECT_DIR}/src/lib"

echo "   writing .env.example"
cat > "${PROJECT_DIR}/.env.example" << 'AGC_SCAFFOLD_EOF'
# .env.example
# Copy to .env.local and fill in for your environment. Never commit .env.local.

# Historian / System Platform Runtime DB
HISTORIAN_SQL_HOST=historian01.algurg.local
HISTORIAN_SQL_PORT=1433
HISTORIAN_SQL_DB=Runtime
HISTORIAN_SQL_USER=agc_pwa_svc
HISTORIAN_SQL_PASSWORD=change-me
HISTORIAN_SQL_ENCRYPT=true

# Application DB (staging tables, maintenance log)
AGC_APP_SQL_DB=AGC_App

NODE_ENV=development
PORT=3000
AGC_SCAFFOLD_EOF

echo "   writing .gitignore"
cat > "${PROJECT_DIR}/.gitignore" << 'AGC_SCAFFOLD_EOF'
# .gitignore
node_modules/
.next/
out/
.env
.env.local
.env*.local
npm-debug.log*
.DS_Store
*.pem
dist/
coverage/
AGC_SCAFFOLD_EOF

echo "   writing README.md"
cat > "${PROJECT_DIR}/README.md" << 'AGC_SCAFFOLD_EOF'
# AGC SCADA Ops — AVEVA Companion PWA

Field-ready companion dashboard and toolkit for AVEVA SCADA, System Platform, and AVEVA
Historian, built for **Al Gurg Automation & Controls**, Dubai, UAE.

---

## 1. What's in this repo

| Area | Location | Purpose |
|---|---|---|
| Historian SQL scripts | `database/` | Retrieval, alarms/events, manual telemetry insert, daily maintenance |
| PWA architecture | `src/app/api/**`, `src/lib/` | Next.js Edge/Node bridge between Historian SQL/REST and the browser |
| Frontend (Industrial Glassmorphism) | `src/app`, `src/components` | Dark-mode SCADA dashboard shell |
| Icons | `src/components/icons` | Inline SVG SCADA + social icon sets |
| Offline-first | `public/sw.js`, `public/manifest.json` | Service worker, IndexedDB outbox, installable manifest |
| Realtime transport | `src/app/api/stream/route.ts`, `server.js` | SSE (Edge) + optional WebSocket bridge |

## 2. Architecture — Edge to Cloud

```
┌────────────────────┐        ┌──────────────────────────┐        ┌────────────────────┐
│ AVEVA System        │  OPC/  │ SQL Server + AVEVA         │  TDS   │ Next.js API routes   │
│ Platform / SCADA     │ DAS    │ Historian (Runtime DB)      │  1433  │ (Node runtime, mssql) │
│ field controllers    │───────▶│ + AGC_App staging DB        │───────▶│ /api/historian/*      │
└────────────────────┘        │ + database/*.sql procs      │        │ /api/telemetry/log     │
                                └──────────────────────────┘        └─────────┬──────────────┘
                                                                                │
                                                            SSE (Edge runtime) │ WebSocket (server.js)
                                                                                ▼
                                                                    ┌────────────────────┐
                                                                    │ Next.js App Router    │
                                                                    │ PWA — Service Worker,  │
                                                                    │ IndexedDB outbox,       │
                                                                    │ offline-first caching   │
                                                                    └────────────────────┘
                                                                                │
                                                                     installed on field
                                                                     tablets / desktops
```

- **Retrieval path**: browser → `/api/historian/history` or `/api/historian/alarms` (Node
  runtime, since `mssql` needs Node sockets) → stored procedures in `database/`.
- **Realtime path**: `/api/stream` runs on the **Edge runtime** as Server-Sent Events so it
  survives corporate proxies on remote UAE site VPNs that block WebSocket upgrades. For sites
  that need bidirectional operator actions (alarm ack round-trips), run `npm run start:ws`
  instead of `npm start` to use the WebSocket bridge in `server.js`.
- **Offline-first**: `public/sw.js` applies cache-first to the app shell and
  stale-while-revalidate to `/api/historian/*` reads, so the dashboard still renders the last
  known telemetry with zero signal at a remote pump station. Manual telemetry POSTs that fail
  offline are queued in IndexedDB and flushed via Background Sync on reconnect.
- **Recommended stack**: Next.js 15 (App Router), TypeScript, Tailwind CSS, `mssql` driver
  direct to the Historian Runtime DB, Vercel Edge Functions (or any Node 20+ host) for the
  read/write API routes, and a small Node worker (or SQL Agent + `server.js`) for Historian
  promotion of staged rows.

## 3. Database setup

Run these against your SQL Server instance, in order:

```sql
:r database/04_sql_maintenance.sql   -- creates AGC_App + usp_RunDailyMaintenance
:r database/01_sp_get_tag_history.sql
:r database/02_sp_get_alarms_events.sql
:r database/03_sp_insert_telemetry_log.sql
```

Then register the daily maintenance job (uncomment the `sp_add_job` block at the bottom of
`04_sql_maintenance.sql`).

## 4. Running the app

```bash
npm install
cp .env.example .env.local     # fill in your Historian SQL credentials
npm run dev                    # http://localhost:3000, SSE realtime
# or, for the WebSocket bridge with operator ack round-trips:
npm run build && npm run start:ws
```

## 5. Design system — Industrial Glassmorphism

- **Palette**: gunmetal `#0A0E12` canvas, graphite `#131A21` panels, steel-line `#1F2A33`
  borders, cyan `#2DE1E8` (live telemetry), amber `#FFB020` (warning), crimson `#FF3B4E`
  (critical alarm).
- **Type**: IBM Plex Sans for UI chrome, IBM Plex Mono for every numeric readout — the two
  faces let an operator tell "label" from "live value" at a glance, the way a real HMI does.
- **Layout**: fixed top status strip, left icon nav rail, and a schematic-grid canvas
  (subtle blueprint gridlines) carrying frosted glass panels — deliberately modeled on a
  control-room HMI client rather than a generic SaaS card grid.

## 6. Directory tree

```
aveva-algurg-pwa/
├── database/
│   ├── 01_sp_get_tag_history.sql
│   ├── 02_sp_get_alarms_events.sql
│   ├── 03_sp_insert_telemetry_log.sql
│   └── 04_sql_maintenance.sql
├── public/
│   ├── manifest.json
│   └── sw.js
├── src/
│   ├── app/
│   │   ├── api/
│   │   │   ├── health/route.ts
│   │   │   ├── historian/alarms/route.ts
│   │   │   ├── historian/history/route.ts
│   │   │   ├── stream/route.ts
│   │   │   └── telemetry/log/route.ts
│   │   ├── globals.css
│   │   ├── layout.tsx
│   │   └── page.tsx
│   ├── components/
│   │   ├── icons/ScadaIcons.tsx
│   │   ├── icons/SocialIcons.tsx
│   │   ├── AlarmPanel.tsx
│   │   ├── DashboardLayout.tsx
│   │   ├── Footer.tsx
│   │   ├── NavRail.tsx
│   │   ├── StatusBar.tsx
│   │   └── TelemetryPanel.tsx
│   └── lib/
│       ├── db.ts
│       ├── historianApi.ts
│       └── websocket.ts
├── .env.example
├── .gitignore
├── next.config.js
├── package.json
├── postcss.config.js
├── server.js
├── tailwind.config.js
└── tsconfig.json
```

## 7. Deploying to GitHub

```bash
cd aveva-algurg-pwa
git init
git add .
git commit -m "Initial commit: AGC SCADA Ops PWA"
git branch -M main
git remote add origin https://github.com/<your-org>/aveva-algurg-pwa.git
git push -u origin main
```

---
Internal engineering tool — Al Gurg Automation & Controls, Dubai, UAE.
AGC_SCAFFOLD_EOF

echo "   writing database/01_sp_get_tag_history.sql"
cat > "${PROJECT_DIR}/database/01_sp_get_tag_history.sql" << 'AGC_SCAFFOLD_EOF'
-- database/01_sp_get_tag_history.sql
-- =============================================================================
-- Al Gurg Automation & Controls | AVEVA Historian Retrieval Procedure
-- Target: AVEVA Historian (Wonderware IndustrialSQL Server) 2023 R2 / SQL Server 2019+
-- Purpose: Parametrized, injection-safe retrieval of tag history using the
--          Historian's native History table and wwRetrievalMode/wwResolution
--          query extensions (Cyclic / Delta / Full / Average / BestFit).
-- Run against: Runtime database (default Historian runtime DB), via the
--              Historian ODBC/OLE DB provider or a linked SQL login with
--              SELECT on dbo.History.
-- =============================================================================

USE Runtime;
GO

IF OBJECT_ID('dbo.usp_GetTagHistory', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetTagHistory;
GO

CREATE PROCEDURE dbo.usp_GetTagHistory
    @TagName        NVARCHAR(256),          -- single tag, e.g. 'AGC.PLANT1.PUMP01.FLOW_PV'
    @TagList        NVARCHAR(MAX) = NULL,    -- optional comma-separated list, overrides @TagName if supplied
    @StartTime      DATETIME2(3),
    @EndTime        DATETIME2(3),
    @RetrievalMode  VARCHAR(20)  = 'Cyclic', -- Cyclic | Delta | Full | Average | Minimum | Maximum | BestFit
    @ResolutionMs   INT          = 1000,     -- sample resolution in ms, only used by Cyclic/Average/Min/Max
    @QualityRule    VARCHAR(20)  = 'Extend'  -- Extend | Interpolate | Good  (wwQualityRule)
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------------
    -- Guard rails: Historian retrieval windows on Cyclic/BestFit against
    -- wide time ranges can be extremely expensive. Cap to 31 days by default.
    ----------------------------------------------------------------------
    IF @StartTime >= @EndTime
    BEGIN
        RAISERROR('StartTime must be earlier than EndTime.', 16, 1);
        RETURN;
    END

    IF DATEDIFF(DAY, @StartTime, @EndTime) > 31
    BEGIN
        RAISERROR('Query window exceeds 31 days. Narrow the range or use the Delta mode for sparse tags.', 16, 1);
        RETURN;
    END

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @tagFilter NVARCHAR(MAX);

    -- Build a safe, parametrized IN-list for multi-tag pulls (dashboard trend widgets)
    IF @TagList IS NOT NULL
        SET @tagFilter = N'TagName IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@TagListParam, '','') )';
    ELSE
        SET @tagFilter = N'TagName = @TagNameParam';

    ----------------------------------------------------------------------
    -- Historian's query extensions are appended as literal keywords, NOT as
    -- bind parameters (the OLE DB provider parses these at the SQL layer),
    -- so we whitelist @RetrievalMode/@QualityRule against a fixed set below
    -- to prevent injection through those two fields.
    ----------------------------------------------------------------------
    IF @RetrievalMode NOT IN ('Cyclic','Delta','Full','Average','Minimum','Maximum','BestFit')
    BEGIN
        RAISERROR('Invalid @RetrievalMode.', 16, 1);
        RETURN;
    END

    IF @QualityRule NOT IN ('Extend','Interpolate','Good')
    BEGIN
        RAISERROR('Invalid @QualityRule.', 16, 1);
        RETURN;
    END

    SET @sql = N'
        SELECT
            TagName,
            DateTime,
            Value,
            Quality,
            QualityDetail,
            vValue        = CONVERT(NVARCHAR(64), Value)
        FROM History
        WHERE ' + @tagFilter + N'
          AND wwRetrievalMode = @RetrievalModeParam
          AND wwResolution    = @ResolutionMsParam
          AND wwQualityRule   = @QualityRuleParam
          AND DateTime BETWEEN @StartTimeParam AND @EndTimeParam
        ORDER BY TagName, DateTime ASC
        OPTION (RECOMPILE);';

    EXEC sp_executesql
        @sql,
        N'@TagNameParam NVARCHAR(256), @TagListParam NVARCHAR(MAX),
          @RetrievalModeParam VARCHAR(20), @ResolutionMsParam INT, @QualityRuleParam VARCHAR(20),
          @StartTimeParam DATETIME2(3), @EndTimeParam DATETIME2(3)',
        @TagNameParam       = @TagName,
        @TagListParam       = @TagList,
        @RetrievalModeParam = @RetrievalMode,
        @ResolutionMsParam  = @ResolutionMs,
        @QualityRuleParam   = @QualityRule,
        @StartTimeParam     = @StartTime,
        @EndTimeParam       = @EndTime;
END
GO

-- -----------------------------------------------------------------------------
-- Usage examples
-- -----------------------------------------------------------------------------
-- 1) Trend chart feed, 1s cyclic resample, last hour:
-- EXEC dbo.usp_GetTagHistory
--      @TagName = 'AGC.PLANT1.PUMP01.FLOW_PV',
--      @StartTime = '2026-09-22 06:00:00', @EndTime = '2026-09-22 07:00:00',
--      @RetrievalMode = 'Cyclic', @ResolutionMs = 1000;
--
-- 2) Delta (compressed, only real value changes) for a multi-tag panel:
-- EXEC dbo.usp_GetTagHistory
--      @TagList = 'AGC.PLANT1.PUMP01.FLOW_PV,AGC.PLANT1.PUMP01.SUCT_PRESS',
--      @StartTime = '2026-09-21', @EndTime = '2026-09-22',
--      @RetrievalMode = 'Delta';
-- -----------------------------------------------------------------------------
AGC_SCAFFOLD_EOF

echo "   writing database/02_sp_get_alarms_events.sql"
cat > "${PROJECT_DIR}/database/02_sp_get_alarms_events.sql" << 'AGC_SCAFFOLD_EOF'
-- database/02_sp_get_alarms_events.sql
-- =============================================================================
-- Al Gurg Automation & Controls | AVEVA Historian Alarm & Event Retrieval
-- Target: Runtime database, dbo.AlarmHistory / dbo.EventHistory (System Platform
--         WWAlarm + Historian Alarm & Event subsystem tables).
-- Purpose: Unified feed for the dashboard's Alarm Panel — active + historical,
--          with priority banding mapped to the front-end's Amber/Crimson scheme.
-- =============================================================================

USE Runtime;
GO

IF OBJECT_ID('dbo.usp_GetAlarmsAndEvents', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetAlarmsAndEvents;
GO

CREATE PROCEDURE dbo.usp_GetAlarmsAndEvents
    @StartTime      DATETIME2(3),
    @EndTime        DATETIME2(3),
    @AreaFilter     NVARCHAR(256) = NULL,   -- e.g. 'PLANT1.PUMPSTATION' -- NULL = all areas
    @MinPriority    INT           = 1,      -- 1 (highest/critical) .. 999 (lowest)
    @IncludeAckd    BIT           = 1,      -- include already-acknowledged alarms
    @ActiveOnly     BIT           = 0       -- 1 = only currently unacknowledged/active
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartTime >= @EndTime
    BEGIN
        RAISERROR('StartTime must be earlier than EndTime.', 16, 1);
        RETURN;
    END

    ;WITH AlarmFeed AS
    (
        SELECT
            SourceType      = 'ALARM',
            TagName         = a.TagName,
            AreaName        = a.AreaName,
            AlarmName       = a.AlarmName,
            AlarmComment    = a.AlarmComment,
            Priority        = a.Priority,
            SeverityBand    = CASE
                                   WHEN a.Priority <= 100 THEN 'CRITICAL'   -- maps to Crimson #FF3B4E
                                   WHEN a.Priority <= 500 THEN 'WARNING'    -- maps to Amber   #FFB020
                                   ELSE 'INFO'                              -- maps to Cyan    #2DE1E8
                               END,
            EventTime       = a.DateTime,
            AckTime         = a.AckTime,
            AckedBy         = a.AckUserName,
            IsAcknowledged  = CAST(CASE WHEN a.AckTime IS NULL THEN 0 ELSE 1 END AS BIT),
            NewState        = a.NewState,           -- e.g. ALM/RTN/ACK
            Value           = a.Value,
            Limit           = a.Limit
        FROM dbo.AlarmHistory a WITH (NOLOCK)
        WHERE a.DateTime BETWEEN @StartTime AND @EndTime
          AND a.Priority >= 1 AND a.Priority <= @MinPriority
          AND (@AreaFilter IS NULL OR a.AreaName LIKE @AreaFilter + '%')
          AND (@IncludeAckd = 1 OR a.AckTime IS NULL)
          AND (@ActiveOnly = 0 OR (a.NewState IN ('ALM','UNACK') AND a.AckTime IS NULL))
    ),
    OperatorEvents AS
    (
        SELECT
            SourceType      = 'EVENT',
            TagName         = e.TagName,
            AreaName        = e.AreaName,
            AlarmName       = e.EventCategory,
            AlarmComment    = e.EventDescription,
            Priority        = 999,
            SeverityBand    = 'INFO',
            EventTime       = e.DateTime,
            AckTime         = NULL,
            AckedBy         = e.UserName,
            IsAcknowledged  = CAST(1 AS BIT),
            NewState        = e.EventType,
            Value           = NULL,
            Limit           = NULL
        FROM dbo.EventHistory e WITH (NOLOCK)
        WHERE e.DateTime BETWEEN @StartTime AND @EndTime
          AND (@AreaFilter IS NULL OR e.AreaName LIKE @AreaFilter + '%')
    )
    SELECT * FROM AlarmFeed
    UNION ALL
    SELECT * FROM OperatorEvents
    ORDER BY EventTime DESC;
END
GO

-- -----------------------------------------------------------------------------
-- Usage: last 4 hours, plant-wide, critical + warning only, unacknowledged only
-- EXEC dbo.usp_GetAlarmsAndEvents
--      @StartTime = DATEADD(HOUR,-4,SYSDATETIME()), @EndTime = SYSDATETIME(),
--      @MinPriority = 500, @ActiveOnly = 1;
-- -----------------------------------------------------------------------------
AGC_SCAFFOLD_EOF

echo "   writing database/03_sp_insert_telemetry_log.sql"
cat > "${PROJECT_DIR}/database/03_sp_insert_telemetry_log.sql" << 'AGC_SCAFFOLD_EOF'
-- database/03_sp_insert_telemetry_log.sql
-- =============================================================================
-- Al Gurg Automation & Controls | Manual / Derived Telemetry Insert
--
-- IMPORTANT (Historian architecture note): dbo.History is a Historian-managed
-- virtual table served by the Storage Subsystem, not a directly writable SQL
-- table. AVEVA Historian DOES support manual inserts through the Historian
-- ODBC/OLE DB provider's special INSERT INTO History syntax (routed through
-- the a2hInsertServer / IndustrialSQL Insert Server), commonly used for
-- back-filling lab samples or manually-entered field readings. That INSERT
-- must be executed through the Historian client provider (InsertHistorian /
-- ODBC DSN pointed at the Historian node) -- NOT through a plain SSMS
-- connection to the Runtime DB, which will reject writes to dbo.History.
--
-- For app-side "custom telemetry" (derived KPIs, manually keyed field
-- readings, or values you want to journal before they are promoted into
-- Historian), this script creates a proper staging table in a dedicated
-- application database (AGC_App) plus a promotion procedure that performs
-- the Historian INSERT INTO History call from the staged rows.
-- =============================================================================

----------------------------------------------------------------------
-- 1) Staging table lives in the application DB, never in Runtime.
----------------------------------------------------------------------
IF DB_ID('AGC_App') IS NULL
BEGIN
    RAISERROR('Create the AGC_App database first (see database/04_sql_maintenance.sql header).', 16, 1);
    RETURN;
END
GO

USE AGC_App;
GO

IF OBJECT_ID('dbo.CustomTelemetryLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CustomTelemetryLog
    (
        LogId           BIGINT IDENTITY(1,1) PRIMARY KEY,
        TagName         NVARCHAR(256)   NOT NULL,
        [DateTime]      DATETIME2(3)    NOT NULL,
        Value           FLOAT           NOT NULL,
        Quality         SMALLINT        NOT NULL DEFAULT 192,  -- 192 = OPC "Good"
        Source          NVARCHAR(64)    NOT NULL DEFAULT 'MANUAL_ENTRY',
        EnteredBy       NVARCHAR(128)   NOT NULL,
        EnteredAtUtc    DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
        PromotedToHistorian BIT         NOT NULL DEFAULT 0,
        PromotedAtUtc   DATETIME2(3)    NULL
    );

    CREATE INDEX IX_CustomTelemetryLog_Promoted ON dbo.CustomTelemetryLog (PromotedToHistorian, [DateTime]);
END
GO

----------------------------------------------------------------------
-- 2) usp_LogCustomTelemetry — called by the PWA's /api/telemetry/log route
--    for manual field readings (e.g. a technician keying in a gauge value
--    from an unmonitored asset).
----------------------------------------------------------------------
IF OBJECT_ID('dbo.usp_LogCustomTelemetry', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_LogCustomTelemetry;
GO

CREATE PROCEDURE dbo.usp_LogCustomTelemetry
    @TagName    NVARCHAR(256),
    @DateTime   DATETIME2(3) = NULL,     -- defaults to now
    @Value      FLOAT,
    @Quality    SMALLINT     = 192,
    @Source     NVARCHAR(64) = 'MANUAL_ENTRY',
    @EnteredBy  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    IF @DateTime IS NULL
        SET @DateTime = SYSUTCDATETIME();

    INSERT INTO dbo.CustomTelemetryLog (TagName, [DateTime], Value, Quality, Source, EnteredBy)
    VALUES (@TagName, @DateTime, @Value, @Quality, @Source, @EnteredBy);

    SELECT LogId = SCOPE_IDENTITY();
END
GO

----------------------------------------------------------------------
-- 3) usp_PromoteTelemetryToHistorian — run on a schedule (SQL Agent, every
--    60s) FROM a session connected through the Historian ODBC/OLE DB
--    provider. This block is intentionally written as a template: the
--    literal INSERT INTO History statement only succeeds over the Historian
--    provider connection, so this procedure should live in a small worker
--    (see src/lib/historianApi.ts promoteTelemetry()) rather than a plain
--    T-SQL job step against AGC_App.
----------------------------------------------------------------------
-- Historian-side statement (run via Historian ODBC DSN, one row shown):
--
--   INSERT INTO History (TagName, DateTime, Value, Quality)
--   VALUES ('AGC.PLANT1.TANK04.MANUAL_LEVEL', '2026-09-22 07:15:00.000', 84.2, 192)
--
-- Batch promotion query (run against AGC_App to select the pending rows,
-- then loop client-side, executing the statement above per row against the
-- Historian connection, then call usp_MarkTelemetryPromoted):
GO

IF OBJECT_ID('dbo.usp_GetPendingTelemetryPromotions', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetPendingTelemetryPromotions;
GO

CREATE PROCEDURE dbo.usp_GetPendingTelemetryPromotions
    @BatchSize INT = 500
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@BatchSize) LogId, TagName, [DateTime], Value, Quality
    FROM dbo.CustomTelemetryLog
    WHERE PromotedToHistorian = 0
    ORDER BY [DateTime] ASC;
END
GO

IF OBJECT_ID('dbo.usp_MarkTelemetryPromoted', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_MarkTelemetryPromoted;
GO

CREATE PROCEDURE dbo.usp_MarkTelemetryPromoted
    @LogId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.CustomTelemetryLog
    SET PromotedToHistorian = 1, PromotedAtUtc = SYSUTCDATETIME()
    WHERE LogId = @LogId;
END
GO
AGC_SCAFFOLD_EOF

echo "   writing database/04_sql_maintenance.sql"
cat > "${PROJECT_DIR}/database/04_sql_maintenance.sql" << 'AGC_SCAFFOLD_EOF'
-- database/04_sql_maintenance.sql
-- =============================================================================
-- Al Gurg Automation & Controls | Daily Historian / SQL Server Maintenance
-- Schedule via SQL Server Agent job "AGC_Historian_Daily_Maintenance", 02:00 GST.
--
-- Covers what a Historian admin actually needs day-to-day:
--   1. Storage Subsystem health snapshot (aahStorageStats / aahHistorianStats)
--   2. Runtime DB alarm/event table growth + index maintenance
--   3. AGC_App staging table growth + auto-purge of promoted rows > 90 days
--   4. tempdb / log file free-space guard rail with alert row
--   5. Job run log so the PWA's /api/health endpoint can surface last-run status
-- =============================================================================

----------------------------------------------------------------------
-- 0) One-time setup: application DB + job log table (safe to re-run)
----------------------------------------------------------------------
IF DB_ID('AGC_App') IS NULL
BEGIN
    CREATE DATABASE AGC_App;
END
GO

USE AGC_App;
GO

IF OBJECT_ID('dbo.MaintenanceLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MaintenanceLog
    (
        RunId        BIGINT IDENTITY(1,1) PRIMARY KEY,
        RunStartUtc  DATETIME2(3) NOT NULL,
        RunEndUtc    DATETIME2(3) NULL,
        StepName     NVARCHAR(128) NOT NULL,
        StatusText   NVARCHAR(MAX) NULL,
        Success      BIT NOT NULL DEFAULT 0
    );
END
GO

IF OBJECT_ID('dbo.usp_RunDailyMaintenance', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_RunDailyMaintenance;
GO

CREATE PROCEDURE dbo.usp_RunDailyMaintenance
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @step  NVARCHAR(128);
    DECLARE @msg   NVARCHAR(MAX);

    BEGIN TRY
        ----------------------------------------------------------------
        -- STEP 1: Runtime DB index maintenance on the hot alarm/event tables.
        -- Rebuild if fragmentation > 30%, reorganize if 10-30%.
        ----------------------------------------------------------------
        SET @step = 'RUNTIME_INDEX_MAINT';

        DECLARE @tbl SYSNAME, @idx SYSNAME, @frag FLOAT, @sql NVARCHAR(MAX);
        DECLARE idx_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT OBJECT_NAME(ips.object_id, DB_ID('Runtime')), i.name, ips.avg_fragmentation_in_percent
            FROM Runtime.sys.dm_db_index_physical_stats(DB_ID('Runtime'), NULL, NULL, NULL, 'LIMITED') ips
            JOIN Runtime.sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
            WHERE i.name IS NOT NULL
              AND OBJECT_NAME(ips.object_id, DB_ID('Runtime')) IN ('AlarmHistory','EventHistory')
              AND ips.avg_fragmentation_in_percent > 10
              AND ips.page_count > 1000;

        OPEN idx_cursor;
        FETCH NEXT FROM idx_cursor INTO @tbl, @idx, @frag;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @frag > 30
                SET @sql = N'ALTER INDEX [' + @idx + N'] ON Runtime.dbo.[' + @tbl + N'] REBUILD WITH (ONLINE = OFF);';
            ELSE
                SET @sql = N'ALTER INDEX [' + @idx + N'] ON Runtime.dbo.[' + @tbl + N'] REORGANIZE;';

            EXEC sp_executesql @sql;
            FETCH NEXT FROM idx_cursor INTO @tbl, @idx, @frag;
        END
        CLOSE idx_cursor;
        DEALLOCATE idx_cursor;

        INSERT INTO dbo.MaintenanceLog (RunStartUtc, RunEndUtc, StepName, StatusText, Success)
        VALUES (@start, SYSUTCDATETIME(), @step, 'Index maintenance pass completed on AlarmHistory/EventHistory.', 1);

        ----------------------------------------------------------------
        -- STEP 2: Storage subsystem free-space snapshot (native Historian
        -- system view -- present on any standard Historian install).
        ----------------------------------------------------------------
        SET @step = 'STORAGE_SUBSYSTEM_HEALTH';

        SELECT @msg = STRING_AGG(
            CONCAT(StorageName, ': ', CAST(FreeSpaceMB AS VARCHAR(20)), ' MB free / ',
                   CAST(CapacityMB AS VARCHAR(20)), ' MB total'), ' | ')
        FROM Runtime.dbo.StorageSubsystem WITH (NOLOCK);   -- Historian system view

        INSERT INTO dbo.MaintenanceLog (RunStartUtc, RunEndUtc, StepName, StatusText, Success)
        VALUES (@start, SYSUTCDATETIME(), @step, ISNULL(@msg, 'No storage subsystem rows returned.'), 1);

        ----------------------------------------------------------------
        -- STEP 3: Purge AGC_App staging rows already promoted > 90 days ago.
        ----------------------------------------------------------------
        SET @step = 'PURGE_PROMOTED_STAGING_ROWS';

        DELETE FROM dbo.CustomTelemetryLog
        WHERE PromotedToHistorian = 1
          AND PromotedAtUtc < DATEADD(DAY, -90, SYSUTCDATETIME());

        SET @msg = CONCAT(@@ROWCOUNT, ' promoted staging rows purged (>90 days old).');
        INSERT INTO dbo.MaintenanceLog (RunStartUtc, RunEndUtc, StepName, StatusText, Success)
        VALUES (@start, SYSUTCDATETIME(), @step, @msg, 1);

        ----------------------------------------------------------------
        -- STEP 4: tempdb / log free space guard rail (raises a WARNING row,
        -- does not fail the job -- the PWA polls this table for banner alerts)
        ----------------------------------------------------------------
        SET @step = 'DISK_FREE_SPACE_GUARDRAIL';

        DECLARE @tempdbFreePct FLOAT;
        SELECT @tempdbFreePct =
            100.0 * SUM(CASE WHEN type_desc = 'ROWS' THEN unallocated_extent_page_count ELSE 0 END)
                  / NULLIF(SUM(CASE WHEN type_desc = 'ROWS' THEN size ELSE 0 END), 0)
        FROM tempdb.sys.dm_db_file_space_usage;

        SET @msg = CONCAT('tempdb free ~', ISNULL(CAST(ROUND(@tempdbFreePct,1) AS VARCHAR(10)),'n/a'), '%');
        INSERT INTO dbo.MaintenanceLog (RunStartUtc, RunEndUtc, StepName, StatusText, Success)
        VALUES (@start, SYSUTCDATETIME(), @step,  @msg, CASE WHEN @tempdbFreePct < 10 THEN 0 ELSE 1 END);

    END TRY
    BEGIN CATCH
        INSERT INTO dbo.MaintenanceLog (RunStartUtc, RunEndUtc, StepName, StatusText, Success)
        VALUES (@start, SYSUTCDATETIME(), ISNULL(@step,'UNKNOWN_STEP'), ERROR_MESSAGE(), 0);
        THROW;
    END CATCH
END
GO

----------------------------------------------------------------------
-- SQL Server Agent job wrapper (run once to register the daily 02:00 job)
----------------------------------------------------------------------
/*
USE msdb;
EXEC dbo.sp_add_job @job_name = N'AGC_Historian_Daily_Maintenance';
EXEC dbo.sp_add_jobstep
    @job_name = N'AGC_Historian_Daily_Maintenance',
    @step_name = N'Run usp_RunDailyMaintenance',
    @subsystem = N'TSQL',
    @command = N'EXEC AGC_App.dbo.usp_RunDailyMaintenance;',
    @database_name = N'AGC_App';
EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily_0200_GST',
    @freq_type = 4, @freq_interval = 1,
    @active_start_time = 020000;
EXEC dbo.sp_attach_schedule
    @job_name = N'AGC_Historian_Daily_Maintenance',
    @schedule_name = N'Daily_0200_GST';
EXEC dbo.sp_add_jobserver @job_name = N'AGC_Historian_Daily_Maintenance';
*/
AGC_SCAFFOLD_EOF

echo "   writing next.config.js"
cat > "${PROJECT_DIR}/next.config.js" << 'AGC_SCAFFOLD_EOF'
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async headers() {
    return [
      {
        // Service worker must be served from the root scope, no-cache so
        // field tablets always pick up the latest offline-cache manifest.
        source: '/sw.js',
        headers: [
          { key: 'Cache-Control', value: 'no-cache, no-store, must-revalidate' },
          { key: 'Service-Worker-Allowed', value: '/' },
        ],
      },
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        ],
      },
    ];
  },
};

module.exports = nextConfig;
AGC_SCAFFOLD_EOF

echo "   writing package.json"
cat > "${PROJECT_DIR}/package.json" << 'AGC_SCAFFOLD_EOF'
{
  "name": "aveva-algurg-scada-pwa",
  "version": "1.0.0",
  "private": true,
  "description": "Al Gurg Automation & Controls — AVEVA SCADA/Historian companion PWA dashboard",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "start:ws": "NODE_ENV=production node server.js",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^15.1.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "swr": "^2.2.5",
    "ws": "^8.18.0",
    "mssql": "^11.0.1"
  },
  "devDependencies": {
    "typescript": "^5.7.0",
    "@types/node": "^22.10.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@types/ws": "^8.5.13",
    "@types/mssql": "^9.1.5",
    "tailwindcss": "^3.4.15",
    "postcss": "^8.4.49",
    "autoprefixer": "^10.4.20",
    "eslint": "^9.16.0",
    "eslint-config-next": "^15.1.0"
  },
  "engines": {
    "node": ">=20.0.0"
  }
}
AGC_SCAFFOLD_EOF

echo "   writing postcss.config.js"
cat > "${PROJECT_DIR}/postcss.config.js" << 'AGC_SCAFFOLD_EOF'
// postcss.config.js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
AGC_SCAFFOLD_EOF

echo "   writing public/icons/icon-192.png"
base64 -d > "${PROJECT_DIR}/public/icons/icon-192.png" << 'AGC_SCAFFOLD_EOF'
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
4WzSx0QqalsAAAAASUVORK5CYII=
AGC_SCAFFOLD_EOF

echo "   writing public/icons/icon-512.png"
base64 -d > "${PROJECT_DIR}/public/icons/icon-512.png" << 'AGC_SCAFFOLD_EOF'
iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAIAAAB7GkOtAAAl50lEQVR4nO3dd4AdZbnH8Zk5/eyebUk2u9mSkJ6Q3hMUQZqKCUEF
6TZAuXgR9YqgXIro9XqVJhaQKgKCdEQENIIYpCeb3nuyyW6y2b6nz7l/LDc3pmx2z7xzZs4+389fmux55s0hmd/MW/VwUZkGAJDH
cLoBAABnEAAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQB
AABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABC
EQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCeZ268IgVq526NAC4zaaJ43N/Ud4AAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIA
AEAox9YBHI0jk2EBIDdctQSKNwAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAA
EIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoA
AAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAACh
CAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAA
EIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoA
AAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAACh
CAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAA
EIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoA
AAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEIoAAAChCAAAEMrrdAMA
Z+iBgK+qyltd46up8dXU+qqrjZISIxTSQ2EjFNJDISMUzCRTmXjcjMXMjo50Y0OqYU9qz57Epk2JdWsTW7dpZtrpP0TuGIURX021
r6bGW13rq6n2VVUbhRE9FDLC3d9VWPf7M8lkJpnIJJJmW2t6//50U1Nqz57Etq3JbduSmzelGhud/kPgUAQABPGUlASnTQ9OnxGa
MSMwdqxmeHr+eT3g0QMBo6hIKy/Xhg8/+Lcy8Xh87Zrou+9G33krVleXicftbLgzfNU1wenTQ9NnBKfP8NXWHvPn9UBADwQ0TfOU
lfmGHXfI76YaG+OrVsbq6qJv/TO+do2WydjSaPSFHi4qc+TCI1asPuKvb5o4PsctySPFF1088LvXKS/b+tij+378I+Vl3cNXVV34
6fmFZ5zhHzlK03Xl9TPxeNebizteebnr9dfMri7l9XMsOHlKZP6C8Mkne8sH23SJdPP+rsWLO17+c/Sfb2ZSKZuu4k6uuvXxBpBP
wnPn2VN2rh1lHWcUFRWe/onI/AXBadNsvZAeCBR8/JSCj5+Sicc6Fy1qffz3saVLbL2iHXw1NYWfXhCZv8BXU2P3tTylZZH5CyLz
F6RbWjpe/nPb448lNm2y+6I4HG8AeUP3eoe9+bYRDttRfNupJ6caGuyo7AhPSUnJl75cdP6FRijkSAMS69e1PvpI+wvP58XjrX/k
yNIrriw87XQ7Xo96KfrO2y0PPdi1+B9ONSBnXHXrYxZQ3ghOnmLT3V/TtJA97xa5ZxQXl111de0rfy358qVO3f01TfOPHjPo5ltq
//Tnos+do3vd+57tHz588E9vrXn6ucLTz3Dw7q9pWmj2nMpf31P16O/7zV/FvEAA5A1b/2HY1LmUU7pe9Pnzhr78l9LLLrcvKfvE
O6Rq0I0317z4UsHHT3G6LYcywuFB199Q8+wLhZ/4pGa45T4QnDR5yG/u6x5JRg6499kEh7A1AEJz52q6nr8TM7xDhpT/4Ieh2XOc
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
AABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABC
EQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAA
IBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQB
AABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABC
EQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAA
IBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQB
AABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIBQBAABCEQAAIJTX6QYcasSK1U43AQBE
4A0AAIQiAABAKAIAAIQiAABAKAIAAIQiAABAKAIAAITSw0VlTrcBAOAA3gAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACEIgAAQCgC
AACEIgAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACE
IgAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACE+l9Y0V7pzQ6t5wAA
AABJRU5ErkJggg==
AGC_SCAFFOLD_EOF

echo "   writing public/icons/icon-maskable-512.png"
base64 -d > "${PROJECT_DIR}/public/icons/icon-maskable-512.png" << 'AGC_SCAFFOLD_EOF'
iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAIAAAB7GkOtAAAl8ElEQVR4nO3dd4AedZ3H8Zl5+rP7bEuy2c2WhPSE9J6gCNJUTAgq
SLcByuEh6omgHEX0PE9pYgGpIiBIR0RAI4hBerLpvSeb7Cab7fv0ee6P5XIxZbP7zG+emWe/79dfd2Gf7/zymJ3PzK/q4aIyDQAg
j+F0AwAAziAAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAo
AgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAA
hCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIA
AEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAo
AgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAA
hCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhPI63QA3GrFitdNNAKDeponjnW6Cu/AGAABCEQAAIBQBAABCEQAA
IBQBAABCEQAAIBQBAABCsQ6gD5hEDOQFlvL0Em8AACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEA
ACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAU
AQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAA
QhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEAACAUAQAAQhEA
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
AAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhF
AACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACA
UAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQA
AAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUAQAAAhFAACAUF6nG5BPRqxY7XQTAEAZ
3gAAQCgCAACEIgAAQCgCAACEIgAAQCgCAACEIgAAQCg9XFTmdBsAAA7gDQAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIA
AEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAo
AgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAA
hCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIA
AEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAo
AgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAEAoAgAAhCIAAECo/wVL
r17peZ0rHwAAAABJRU5ErkJggg==
AGC_SCAFFOLD_EOF

echo "   writing public/manifest.json"
cat > "${PROJECT_DIR}/public/manifest.json" << 'AGC_SCAFFOLD_EOF'
{
  "name": "AGC SCADA Ops",
  "short_name": "AGC SCADA",
  "description": "Al Gurg Automation & Controls — AVEVA SCADA/Historian field companion dashboard",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "orientation": "any",
  "background_color": "#0A0E12",
  "theme_color": "#0A0E12",
  "icons": [
    { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any" },
    { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" },
    { "src": "/icons/icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
AGC_SCAFFOLD_EOF

echo "   writing public/sw.js"
cat > "${PROJECT_DIR}/public/sw.js" << 'AGC_SCAFFOLD_EOF'
// public/sw.js
// Offline-first service worker for field sites with unreliable UAE cellular
// backhaul. Strategy:
//   - App shell (HTML/CSS/JS)   -> cache-first, so the console still opens
//     with zero signal at a remote pump station.
//   - /api/historian/*          -> stale-while-revalidate, so the last known
//     good trend/alarm data renders instantly while a fresh fetch runs.
//   - /api/telemetry/log (POST) -> network-first with an IndexedDB outbox;
//     failed manual entries queue and flush on reconnect via Background Sync.
//   - /api/stream (SSE)         -> never cached, always network.

const SHELL_CACHE = 'agc-shell-v1';
const API_CACHE = 'agc-api-v1';
const OUTBOX_DB = 'agc-outbox';
const OUTBOX_STORE = 'pending-writes';

const SHELL_ASSETS = ['/', '/manifest.json'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE).then((cache) => cache.addAll(SHELL_ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((k) => ![SHELL_CACHE, API_CACHE].includes(k)).map((k) => caches.delete(k)))
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Never intercept the SSE stream -- must stay live network-only.
  if (url.pathname === '/api/stream') return;

  // Queue manual telemetry POSTs when offline.
  if (url.pathname === '/api/telemetry/log' && request.method === 'POST') {
    event.respondWith(handleTelemetryPost(request));
    return;
  }

  // Stale-while-revalidate for Historian read APIs.
  if (url.pathname.startsWith('/api/historian/')) {
    event.respondWith(staleWhileRevalidate(request));
    return;
  }

  // Cache-first app shell for navigations and static assets.
  if (request.method === 'GET') {
    event.respondWith(cacheFirst(request));
  }
});

async function cacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) return cached;
  try {
    const response = await fetch(request);
    const cache = await caches.open(SHELL_CACHE);
    cache.put(request, response.clone());
    return response;
  } catch {
    return caches.match('/');
  }
}

async function staleWhileRevalidate(request) {
  const cache = await caches.open(API_CACHE);
  const cached = await cache.match(request);

  const networkFetch = fetch(request)
    .then((response) => {
      cache.put(request, response.clone());
      return response;
    })
    .catch(() => null);

  return cached || (await networkFetch) || new Response(JSON.stringify({ error: 'offline' }), { status: 503 });
}

async function handleTelemetryPost(request) {
  const clone = request.clone();
  try {
    return await fetch(request);
  } catch {
    const body = await clone.json();
    await queueOutboxWrite(body);
    if ('sync' in self.registration) {
      await self.registration.sync.register('flush-telemetry-outbox');
    }
    return new Response(JSON.stringify({ queued: true }), {
      status: 202,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}

self.addEventListener('sync', (event) => {
  if (event.tag === 'flush-telemetry-outbox') {
    event.waitUntil(flushOutbox());
  }
});

function openOutboxDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(OUTBOX_DB, 1);
    req.onupgradeneeded = () => {
      req.result.createObjectStore(OUTBOX_STORE, { keyPath: 'id', autoIncrement: true });
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function queueOutboxWrite(body) {
  const db = await openOutboxDb();
  await new Promise((resolve, reject) => {
    const tx = db.transaction(OUTBOX_STORE, 'readwrite');
    tx.objectStore(OUTBOX_STORE).add({ body, queuedAt: Date.now() });
    tx.oncomplete = resolve;
    tx.onerror = reject;
  });
}

async function flushOutbox() {
  const db = await openOutboxDb();
  const tx = db.transaction(OUTBOX_STORE, 'readonly');
  const entries = await new Promise((resolve, reject) => {
    const req = tx.objectStore(OUTBOX_STORE).getAll();
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });

  for (const entry of entries) {
    try {
      await fetch('/api/telemetry/log', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(entry.body),
      });
      const delTx = db.transaction(OUTBOX_STORE, 'readwrite');
      delTx.objectStore(OUTBOX_STORE).delete(entry.id);
    } catch {
      // leave it queued, retry on next sync event
    }
  }
}
AGC_SCAFFOLD_EOF

echo "   writing server.js"
cat > "${PROJECT_DIR}/server.js" << 'AGC_SCAFFOLD_EOF'
// server.js
// Optional custom server: only needed when a deployment target requires a
// real bidirectional WebSocket (e.g. operator "acknowledge alarm" round
// trips) rather than the Edge-deployable SSE route in
// src/app/api/stream/route.ts. Run with `node server.js` instead of
// `next start` -- see package.json "start:ws" script added by the
// scaffold script below.
//
// Broadcasts the same StreamMessage shape consumed by src/lib/websocket.ts.

const { createServer } = require('http');
const { parse } = require('url');
const next = require('next');
const { WebSocketServer } = require('ws');

const dev = process.env.NODE_ENV !== 'production';
const port = Number(process.env.PORT || 3000);
const app = next({ dev });
const handle = app.getRequestHandler();

const WATCHED_TAGS = [
  'AGC.PLANT1.PUMP01.FLOW_PV',
  'AGC.PLANT1.PUMP01.SUCT_PRESS',
  'AGC.PLANT1.TANK04.LEVEL_PV',
];

app.prepare().then(() => {
  const httpServer = createServer((req, res) => {
    const parsedUrl = parse(req.url, true);
    handle(req, res, parsedUrl);
  });

  const wss = new WebSocketServer({ noServer: true });
  const clients = new Set();

  httpServer.on('upgrade', (req, socket, head) => {
    const { pathname } = parse(req.url);
    if (pathname !== '/api/stream') {
      socket.destroy();
      return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => {
      clients.add(ws);
      ws.on('close', () => clients.delete(ws));
      // Operator round-trips (e.g. alarm ack) arrive here:
      ws.on('message', (raw) => {
        try {
          const msg = JSON.parse(raw.toString());
          if (msg.type === 'ack') {
            // TODO: persist ack via AGC_App / Runtime AckTime update, then
            // rebroadcast the resolved alarm state to all clients.
            broadcast({ type: 'alarm', ...msg, state: 'ACK' });
          }
        } catch {
          /* ignore malformed client frames */
        }
      });
    });
  });

  function broadcast(message) {
    const payload = JSON.stringify(message);
    for (const ws of clients) {
      if (ws.readyState === ws.OPEN) ws.send(payload);
    }
  }

  // Replace this synthetic tick with a real Historian OPC-UA/REST
  // subscription bridge in production.
  setInterval(() => {
    for (const tagName of WATCHED_TAGS) {
      broadcast({
        type: 'telemetry',
        tagName,
        value: Number((Math.random() * 100).toFixed(2)),
        quality: 192,
        timestamp: new Date().toISOString(),
      });
    }
  }, 1000);

  httpServer.listen(port, () => {
    console.log(`[AGC SCADA PWA] ready on http://localhost:${port} (WebSocket bridge active on /api/stream)`);
  });
});
AGC_SCAFFOLD_EOF

echo "   writing src/app/api/health/route.ts"
cat > "${PROJECT_DIR}/src/app/api/health/route.ts" << 'AGC_SCAFFOLD_EOF'
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
AGC_SCAFFOLD_EOF

echo "   writing src/app/api/historian/alarms/route.ts"
cat > "${PROJECT_DIR}/src/app/api/historian/alarms/route.ts" << 'AGC_SCAFFOLD_EOF'
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
AGC_SCAFFOLD_EOF

echo "   writing src/app/api/historian/history/route.ts"
cat > "${PROJECT_DIR}/src/app/api/historian/history/route.ts" << 'AGC_SCAFFOLD_EOF'
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
AGC_SCAFFOLD_EOF

echo "   writing src/app/api/stream/route.ts"
cat > "${PROJECT_DIR}/src/app/api/stream/route.ts" << 'AGC_SCAFFOLD_EOF'
// src/app/api/stream/route.ts
// GET /api/stream -- Server-Sent Events fallback/primary channel for
// real-time telemetry + alarm pushes. Chosen as the Edge-deployable option
// because SSE runs on the Edge runtime and survives corporate proxies that
// block WebSocket upgrades on some Al Gurg site VPNs. For sites that need
// bidirectional acks (e.g. operator alarm-ack from the tablet), pair this
// with the WebSocket bridge in /server.js (see README "Realtime Transport").
//
// This route polls the Historian bridge every POLL_INTERVAL_MS and only
// pushes a frame when tag values actually change (delta-push), keeping
// payloads tiny for constrained UAE field-site cellular links.

import { NextRequest } from 'next/server';

export const runtime = 'edge';

const POLL_INTERVAL_MS = 1000;
const WATCHED_TAGS = [
  'AGC.PLANT1.PUMP01.FLOW_PV',
  'AGC.PLANT1.PUMP01.SUCT_PRESS',
  'AGC.PLANT1.TANK04.LEVEL_PV',
];

function sseFrame(event: string, data: unknown) {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

export async function GET(req: NextRequest) {
  const encoder = new TextEncoder();
  let closed = false;

  const stream = new ReadableStream({
    async start(controller) {
      controller.enqueue(encoder.encode(sseFrame('connected', { at: new Date().toISOString() })));

      const interval = setInterval(async () => {
        if (closed) return;
        try {
          // NOTE: in production, replace this synthetic tick with a call
          // into the Historian's own OPC-UA/REST subscription and forward
          // real deltas -- this Edge function must stay stateless/cheap.
          for (const tagName of WATCHED_TAGS) {
            const frame = {
              type: 'telemetry',
              tagName,
              value: Number((Math.random() * 100).toFixed(2)),
              quality: 192,
              timestamp: new Date().toISOString(),
            };
            controller.enqueue(encoder.encode(sseFrame('message', frame)));
          }
        } catch (err) {
          controller.enqueue(encoder.encode(sseFrame('error', { message: 'stream tick failed' })));
        }
      }, POLL_INTERVAL_MS);

      req.signal.addEventListener('abort', () => {
        closed = true;
        clearInterval(interval);
        controller.close();
      });
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
    },
  });
}
AGC_SCAFFOLD_EOF

echo "   writing src/app/api/telemetry/log/route.ts"
cat > "${PROJECT_DIR}/src/app/api/telemetry/log/route.ts" << 'AGC_SCAFFOLD_EOF'
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
AGC_SCAFFOLD_EOF

echo "   writing src/app/globals.css"
cat > "${PROJECT_DIR}/src/app/globals.css" << 'AGC_SCAFFOLD_EOF'
/* src/app/globals.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

@import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500;600&display=swap');

:root {
  --canvas: #0A0E12;
  --panel: #131A21;
  --line: #1F2A33;
  --text: #E6EDF0;
  --text-dim: #7C8A94;
  --cyan: #2DE1E8;
  --amber: #FFB020;
  --crimson: #FF3B4E;
}

* {
  box-sizing: border-box;
}

html,
body {
  height: 100%;
}

body {
  background-color: var(--canvas);
  color: var(--text);
  font-family: 'IBM Plex Sans', system-ui, sans-serif;
  -webkit-font-smoothing: antialiased;
  overflow-x: hidden;
}

/* Respect reduced-motion preference across every animated element */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.001ms !important;
  }
}

/* Visible keyboard focus ring, industrial cyan */
:focus-visible {
  outline: 2px solid var(--cyan);
  outline-offset: 2px;
}

/* ---------------------------------------------------------------------
   Industrial Glassmorphism primitive: a frosted panel over the schematic
   grid, used by every widget on the canvas (telemetry cards, alarm rail,
   trend panel). Border is a hairline steel line, not a soft SaaS shadow.
   --------------------------------------------------------------------- */
.glass-panel {
  background: linear-gradient(180deg, rgba(19, 26, 33, 0.82) 0%, rgba(19, 26, 33, 0.92) 100%);
  border: 1px solid var(--line);
  border-radius: 6px;
  backdrop-filter: blur(14px) saturate(140%);
  -webkit-backdrop-filter: blur(14px) saturate(140%);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.45), inset 0 1px 0 rgba(255, 255, 255, 0.04);
}

.schematic-canvas {
  background-color: var(--canvas);
  background-image:
    linear-gradient(rgba(45, 225, 232, 0.055) 1px, transparent 1px),
    linear-gradient(90deg, rgba(45, 225, 232, 0.055) 1px, transparent 1px);
  background-size: 32px 32px;
}

/* Numeric telemetry readouts always use the mono face -- distinguishes
   live data from UI chrome at a glance, the way a real HMI does. */
.readout {
  font-family: 'IBM Plex Mono', ui-monospace, monospace;
  font-variant-numeric: tabular-nums;
  letter-spacing: 0.01em;
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: inline-block;
}

.status-dot--live {
  background: var(--cyan);
  box-shadow: 0 0 8px var(--cyan);
}

.status-dot--warn {
  background: var(--amber);
  box-shadow: 0 0 8px var(--amber);
}

.status-dot--critical {
  background: var(--crimson);
  box-shadow: 0 0 8px var(--crimson);
}

/* Thin scrollbars matching the steel-line palette, for the alarm rail */
.rail-scroll::-webkit-scrollbar {
  width: 6px;
}
.rail-scroll::-webkit-scrollbar-track {
  background: transparent;
}
.rail-scroll::-webkit-scrollbar-thumb {
  background: var(--line);
  border-radius: 3px;
}
AGC_SCAFFOLD_EOF

echo "   writing src/app/layout.tsx"
cat > "${PROJECT_DIR}/src/app/layout.tsx" << 'AGC_SCAFFOLD_EOF'
// src/app/layout.tsx
import type { Metadata, Viewport } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'AGC SCADA Ops | Al Gurg Automation & Controls',
  description:
    'Field companion dashboard for AVEVA SCADA, System Platform, and Historian — Al Gurg Automation & Controls, Dubai.',
  manifest: '/manifest.json',
  applicationName: 'AGC SCADA Ops',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'black-translucent',
    title: 'AGC SCADA Ops',
  },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  themeColor: '#0A0E12',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className="bg-gunmetal text-offwhite antialiased">
        {children}
        <script
          dangerouslySetInnerHTML={{
            __html: `
              if ('serviceWorker' in navigator) {
                window.addEventListener('load', () => {
                  navigator.serviceWorker.register('/sw.js').catch(console.error);
                });
              }
            `,
          }}
        />
      </body>
    </html>
  );
}
AGC_SCAFFOLD_EOF

echo "   writing src/app/page.tsx"
cat > "${PROJECT_DIR}/src/app/page.tsx" << 'AGC_SCAFFOLD_EOF'
// src/app/page.tsx
import DashboardLayout from '@/components/DashboardLayout';

export default function HomePage() {
  return <DashboardLayout />;
}
AGC_SCAFFOLD_EOF

echo "   writing src/components/AlarmPanel.tsx"
cat > "${PROJECT_DIR}/src/components/AlarmPanel.tsx" << 'AGC_SCAFFOLD_EOF'
// src/components/AlarmPanel.tsx
'use client';

import { AlarmIcon } from './icons/ScadaIcons';
import type { AlarmEventRow } from '@/lib/historianApi';

const SEVERITY_STYLES: Record<AlarmEventRow['severityBand'], { dot: string; text: string; border: string }> = {
  CRITICAL: { dot: 'status-dot--critical', text: 'text-crimson', border: 'border-l-crimson' },
  WARNING: { dot: 'status-dot--warn', text: 'text-amber', border: 'border-l-amber' },
  INFO: { dot: 'status-dot--live', text: 'text-cyan', border: 'border-l-cyan' },
};

function formatTime(iso: string) {
  try {
    return new Date(iso).toLocaleTimeString('en-GB', { hour12: false, timeZone: 'Asia/Dubai' });
  } catch {
    return iso;
  }
}

export default function AlarmPanel({ alarms }: { alarms: AlarmEventRow[] }) {
  const activeCritical = alarms.filter((a) => a.severityBand === 'CRITICAL' && !a.isAcknowledged).length;

  return (
    <div className="glass-panel p-4 flex flex-col gap-3 h-full">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <AlarmIcon className="w-4 h-4 text-crimson" />
          <h2 className="text-sm font-medium">Active Alarms</h2>
        </div>
        {activeCritical > 0 && (
          <span className="readout text-[11px] px-2 py-0.5 rounded-full bg-crimson/15 text-crimson border border-crimson/40">
            {activeCritical} critical
          </span>
        )}
      </div>

      <div className="flex flex-col gap-2 overflow-y-auto rail-scroll pr-1" style={{ maxHeight: '360px' }}>
        {alarms.length === 0 && (
          <p className="text-xs text-text-dim py-6 text-center">No alarms in the selected window.</p>
        )}
        {alarms.map((a, i) => {
          const style = SEVERITY_STYLES[a.severityBand];
          return (
            <div
              key={`${a.tagName}-${a.eventTime}-${i}`}
              className={`border-l-2 ${style.border} bg-white/[0.02] rounded-r px-3 py-2 flex items-start justify-between gap-2`}
            >
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <span className={`status-dot ${style.dot}`} />
                  <p className="text-xs font-medium truncate">{a.alarmName}</p>
                </div>
                <p className="text-[11px] text-text-dim truncate mt-0.5">{a.areaName} · {a.tagName}</p>
              </div>
              <span className="readout text-[11px] text-text-dim shrink-0">{formatTime(a.eventTime)}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
AGC_SCAFFOLD_EOF

echo "   writing src/components/DashboardLayout.tsx"
cat > "${PROJECT_DIR}/src/components/DashboardLayout.tsx" << 'AGC_SCAFFOLD_EOF'
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
AGC_SCAFFOLD_EOF

echo "   writing src/components/Footer.tsx"
cat > "${PROJECT_DIR}/src/components/Footer.tsx" << 'AGC_SCAFFOLD_EOF'
// src/components/Footer.tsx
import { LinkedInIcon, XIcon, GitHubIcon } from './icons/SocialIcons';

const SOCIAL_LINKS = [
  { label: 'LinkedIn', href: 'https://www.linkedin.com', Icon: LinkedInIcon },
  { label: 'X', href: 'https://www.x.com', Icon: XIcon },
  { label: 'GitHub', href: 'https://www.github.com', Icon: GitHubIcon },
] as const;

export default function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="shrink-0 border-t border-steelline bg-graphite/80 backdrop-blur-md px-4 sm:px-6 py-3 flex flex-col sm:flex-row items-center justify-between gap-2">
      <p className="text-[11px] text-text-dim text-center sm:text-left">
        © {year} Al Gurg Automation &amp; Controls — Dubai, UAE. Internal engineering tool, not for public distribution.
      </p>

      <div className="flex items-center gap-3">
        {SOCIAL_LINKS.map(({ label, href, Icon }) => (
          <a
            key={label}
            href={href}
            target="_blank"
            rel="noreferrer noopener"
            aria-label={label}
            className="text-text-dim hover:text-cyan transition-colors"
          >
            <Icon className="w-4 h-4" />
          </a>
        ))}
      </div>
    </footer>
  );
}
AGC_SCAFFOLD_EOF

echo "   writing src/components/NavRail.tsx"
cat > "${PROJECT_DIR}/src/components/NavRail.tsx" << 'AGC_SCAFFOLD_EOF'
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
AGC_SCAFFOLD_EOF

echo "   writing src/components/StatusBar.tsx"
cat > "${PROJECT_DIR}/src/components/StatusBar.tsx" << 'AGC_SCAFFOLD_EOF'
// src/components/StatusBar.tsx
'use client';

import { useEffect, useState } from 'react';
import { SignalWifiIcon } from './icons/ScadaIcons';
import type { ConnectionState } from '@/lib/websocket';

const STATE_LABEL: Record<ConnectionState, string> = {
  connected: 'Live',
  connecting: 'Connecting',
  reconnecting: 'Reconnecting',
  disconnected: 'Offline',
};

const STATE_DOT: Record<ConnectionState, string> = {
  connected: 'status-dot--live',
  connecting: 'status-dot--warn',
  reconnecting: 'status-dot--warn',
  disconnected: 'status-dot--critical',
};

export default function StatusBar({ connectionState }: { connectionState: ConnectionState }) {
  const [now, setNow] = useState<Date | null>(null);

  useEffect(() => {
    setNow(new Date());
    const t = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(t);
  }, []);

  return (
    <header className="h-14 shrink-0 border-b border-steelline bg-graphite/80 backdrop-blur-md flex items-center justify-between px-4 sm:px-6">
      <div className="flex items-center gap-3">
        <div className="h-7 w-7 rounded-sm border border-cyan/40 flex items-center justify-center">
          <span className="readout text-cyan text-[11px] font-semibold">AGC</span>
        </div>
        <div className="leading-tight">
          <p className="text-sm font-medium">SCADA Ops Console</p>
          <p className="text-[11px] text-text-dim">Plant 1 — Jebel Ali Utilities Corridor</p>
        </div>
      </div>

      <div className="flex items-center gap-5">
        <div className="hidden sm:flex items-center gap-2">
          <span className={`status-dot ${STATE_DOT[connectionState]} ${connectionState === 'connected' ? 'animate-pulse-live' : ''}`} />
          <span className="text-xs text-text-dim">{STATE_LABEL[connectionState]}</span>
          <SignalWifiIcon className="w-4 h-4 text-text-dim" />
        </div>
        <span className="readout text-xs text-text-dim tabular-nums" suppressHydrationWarning>
          {now ? now.toLocaleTimeString('en-GB', { hour12: false, timeZone: 'Asia/Dubai' }) + ' GST' : '--:--:-- GST'}
        </span>
      </div>
    </header>
  );
}
AGC_SCAFFOLD_EOF

echo "   writing src/components/TelemetryPanel.tsx"
cat > "${PROJECT_DIR}/src/components/TelemetryPanel.tsx" << 'AGC_SCAFFOLD_EOF'
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
AGC_SCAFFOLD_EOF

echo "   writing src/components/icons/ScadaIcons.tsx"
cat > "${PROJECT_DIR}/src/components/icons/ScadaIcons.tsx" << 'AGC_SCAFFOLD_EOF'
// src/components/icons/ScadaIcons.tsx
// Inline SVG icon set for the SCADA dashboard nav rail and panel headers.
// All icons use currentColor so they inherit Tailwind text-* utility colors.

import type { SVGProps } from 'react';

type IconProps = SVGProps<SVGSVGElement>;

export function TelemetryIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <path
        d="M3 17L8 10L12 14L21 4"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M15 4H21V10" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="8" cy="10" r="1.4" fill="currentColor" />
      <circle cx="12" cy="14" r="1.4" fill="currentColor" />
      <path d="M3 21H21" stroke="currentColor" strokeWidth="1.25" strokeLinecap="round" opacity="0.35" />
    </svg>
  );
}

export function AlarmIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <path
        d="M12 3L21.5 20H2.5L12 3Z"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinejoin="round"
      />
      <path d="M12 9.5V14" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" />
      <circle cx="12" cy="17" r="1.1" fill="currentColor" />
    </svg>
  );
}

export function DatabaseIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <ellipse cx="12" cy="5.5" rx="8" ry="3" stroke="currentColor" strokeWidth="1.75" />
      <path d="M4 5.5V18.5C4 20.1569 7.58172 21.5 12 21.5C16.4183 21.5 20 20.1569 20 18.5V5.5" stroke="currentColor" strokeWidth="1.75" />
      <path d="M4 12C4 13.6569 7.58172 15 12 15C16.4183 15 20 13.6569 20 12" stroke="currentColor" strokeWidth="1.75" />
    </svg>
  );
}

export function SettingsIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <circle cx="12" cy="12" r="3.25" stroke="currentColor" strokeWidth="1.75" />
      <path
        d="M12 2.75V5.25M12 18.75V21.25M21.25 12H18.75M5.25 12H2.75M18.01 5.99L16.25 7.75M7.75 16.25L5.99 18.01M18.01 18.01L16.25 16.25M7.75 7.75L5.99 5.99"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
      />
    </svg>
  );
}

export function SignalWifiIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <path d="M3 8.5C8.5 3.5 15.5 3.5 21 8.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" opacity="0.4" />
      <path d="M6 12.2C9.8 8.8 14.2 8.8 18 12.2" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" opacity="0.7" />
      <path d="M9 15.8C10.8 14.2 13.2 14.2 15 15.8" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
      <circle cx="12" cy="19" r="1.3" fill="currentColor" />
    </svg>
  );
}

export function ExpandPanelIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" {...props}>
      <path d="M9 3H3V9" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M15 3H21V9" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M9 21H3V15" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M15 21H21V15" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
AGC_SCAFFOLD_EOF

echo "   writing src/components/icons/SocialIcons.tsx"
cat > "${PROJECT_DIR}/src/components/icons/SocialIcons.tsx" << 'AGC_SCAFFOLD_EOF'
// src/components/icons/SocialIcons.tsx
// Raw inline SVGs for public social platforms, used only in the corporate
// footer. currentColor-driven so hover states are handled in Tailwind.

import type { SVGProps } from 'react';

type IconProps = SVGProps<SVGSVGElement>;

export function LinkedInIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg" {...props}>
      <path d="M20.45 20.45h-3.56v-5.57c0-1.33-.02-3.04-1.85-3.04-1.85 0-2.14 1.45-2.14 2.94v5.67H9.34V9h3.42v1.56h.05c.48-.9 1.64-1.85 3.38-1.85 3.6 0 4.27 2.37 4.27 5.46v6.28zM5.34 7.43a2.07 2.07 0 1 1 0-4.13 2.07 2.07 0 0 1 0 4.13zM7.12 20.45H3.56V9h3.56v11.45z" />
    </svg>
  );
}

export function XIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg" {...props}>
      <path d="M13.6 10.6 20.4 3h-1.6l-5.9 6.6L8.2 3H3l7.1 10.2L3 21h1.6l6.2-7 5 7H21l-7.4-10.4Zm-2.2 2.5-.7-1L5 4.2h2.1l4.6 6.5.7 1 6 8.4h-2.1l-4.9-6.9Z" />
    </svg>
  );
}

export function GitHubIcon(props: IconProps) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg" {...props}>
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M12 2C6.48 2 2 6.58 2 12.2c0 4.49 2.87 8.3 6.84 9.65.5.1.68-.22.68-.49 0-.24-.01-.88-.01-1.72-2.78.62-3.37-1.36-3.37-1.36-.45-1.18-1.11-1.5-1.11-1.5-.9-.63.07-.62.07-.62 1 .07 1.53 1.05 1.53 1.05.9 1.55 2.34 1.1 2.91.84.09-.66.35-1.1.63-1.36-2.22-.26-4.56-1.14-4.56-5.07 0-1.12.39-2.03 1.03-2.75-.1-.26-.45-1.31.1-2.72 0 0 .84-.28 2.75 1.05A9.3 9.3 0 0 1 12 6.84c.85.004 1.71.117 2.51.34 1.9-1.33 2.74-1.05 2.74-1.05.55 1.41.2 2.46.1 2.72.64.72 1.03 1.63 1.03 2.75 0 3.94-2.34 4.8-4.57 5.06.36.32.68.94.68 1.9 0 1.37-.01 2.47-.01 2.81 0 .27.18.6.69.49A10.21 10.21 0 0 0 22 12.2C22 6.58 17.52 2 12 2Z"
      />
    </svg>
  );
}
AGC_SCAFFOLD_EOF

echo "   writing src/lib/db.ts"
cat > "${PROJECT_DIR}/src/lib/db.ts" << 'AGC_SCAFFOLD_EOF'
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
AGC_SCAFFOLD_EOF

echo "   writing src/lib/historianApi.ts"
cat > "${PROJECT_DIR}/src/lib/historianApi.ts" << 'AGC_SCAFFOLD_EOF'
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
AGC_SCAFFOLD_EOF

echo "   writing src/lib/websocket.ts"
cat > "${PROJECT_DIR}/src/lib/websocket.ts" << 'AGC_SCAFFOLD_EOF'
// src/lib/websocket.ts
// Real-time telemetry stream client. Wraps a native WebSocket with:
//  - typed message envelope shared with the /api/stream Edge route
//  - exponential backoff reconnect (critical over UAE cellular field links)
//  - a fallback to Server-Sent Events if the deployment target blocks
//    long-lived WS connections (some corporate proxies do)

export type TelemetryMessage = {
  type: 'telemetry';
  tagName: string;
  value: number;
  quality: number;
  timestamp: string; // ISO-8601
};

export type AlarmMessage = {
  type: 'alarm';
  tagName: string;
  alarmName: string;
  severity: 'CRITICAL' | 'WARNING' | 'INFO';
  state: 'ALM' | 'ACK' | 'RTN';
  timestamp: string;
};

export type StreamMessage = TelemetryMessage | AlarmMessage;

type Listener = (msg: StreamMessage) => void;

const MAX_BACKOFF_MS = 15_000;
const BASE_BACKOFF_MS = 500;

export class ScadaStreamClient {
  private url: string;
  private socket: WebSocket | null = null;
  private listeners = new Set<Listener>();
  private attempt = 0;
  private closedByUser = false;
  private connectionStateListeners = new Set<(state: ConnectionState) => void>();

  constructor(url: string) {
    this.url = url;
  }

  connect() {
    this.closedByUser = false;
    this.open();
  }

  private open() {
    this.setState('connecting');
    try {
      this.socket = new WebSocket(this.url);
    } catch {
      this.scheduleReconnect();
      return;
    }

    this.socket.onopen = () => {
      this.attempt = 0;
      this.setState('connected');
    };

    this.socket.onmessage = (event) => {
      try {
        const parsed: StreamMessage = JSON.parse(event.data);
        this.listeners.forEach((fn) => fn(parsed));
      } catch {
        // Malformed frame -- drop silently, do not crash the render loop
      }
    };

    this.socket.onerror = () => {
      this.socket?.close();
    };

    this.socket.onclose = () => {
      this.setState('disconnected');
      if (!this.closedByUser) this.scheduleReconnect();
    };
  }

  private scheduleReconnect() {
    this.attempt += 1;
    const delay = Math.min(BASE_BACKOFF_MS * 2 ** this.attempt, MAX_BACKOFF_MS);
    this.setState('reconnecting');
    setTimeout(() => {
      if (!this.closedByUser) this.open();
    }, delay);
  }

  onMessage(fn: Listener) {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  onConnectionState(fn: (state: ConnectionState) => void) {
    this.connectionStateListeners.add(fn);
    return () => this.connectionStateListeners.delete(fn);
  }

  private setState(state: ConnectionState) {
    this.connectionStateListeners.forEach((fn) => fn(state));
  }

  close() {
    this.closedByUser = true;
    this.socket?.close();
  }
}

export type ConnectionState = 'connecting' | 'connected' | 'disconnected' | 'reconnecting';

/**
 * Factory that resolves ws:// vs wss:// against the current origin so the
 * same build works on the engineer's laptop over HTTP and on the plant
 * network behind TLS-terminating reverse proxies.
 */
export function createScadaStream(path = '/api/stream'): ScadaStreamClient {
  if (typeof window === 'undefined') {
    throw new Error('createScadaStream must be called client-side.');
  }
  const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  return new ScadaStreamClient(`${proto}//${window.location.host}${path}`);
}
AGC_SCAFFOLD_EOF

echo "   writing tailwind.config.js"
cat > "${PROJECT_DIR}/tailwind.config.js" << 'AGC_SCAFFOLD_EOF'
// tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ['class'],
  content: ['./src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        gunmetal: '#0A0E12',   // base canvas
        graphite: '#131A21',   // panel fill
        steelline: '#1F2A33',  // grid/border lines
        offwhite: '#E6EDF0',   // primary text
        cyan: {
          DEFAULT: '#2DE1E8',
          dim: '#1B7E82',
        },
        amber: {
          DEFAULT: '#FFB020',
          dim: '#8C6314',
        },
        crimson: {
          DEFAULT: '#FF3B4E',
          dim: '#8C1D29',
        },
      },
      fontFamily: {
        sans: ['"IBM Plex Sans"', 'system-ui', 'sans-serif'],
        mono: ['"IBM Plex Mono"', 'ui-monospace', 'monospace'],
      },
      backgroundImage: {
        'schematic-grid':
          'linear-gradient(rgba(45,225,232,0.06) 1px, transparent 1px), linear-gradient(90deg, rgba(45,225,232,0.06) 1px, transparent 1px)',
      },
      backgroundSize: {
        grid: '32px 32px',
      },
      boxShadow: {
        glass: '0 8px 32px rgba(0,0,0,0.45), inset 0 1px 0 rgba(255,255,255,0.04)',
      },
      keyframes: {
        pulseLive: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.35' },
        },
      },
      animation: {
        'pulse-live': 'pulseLive 1.8s ease-in-out infinite',
      },
    },
  },
  plugins: [],
};
AGC_SCAFFOLD_EOF

echo "   writing tsconfig.json"
cat > "${PROJECT_DIR}/tsconfig.json" << 'AGC_SCAFFOLD_EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": [
      "dom",
      "dom.iterable",
      "esnext"
    ],
    "allowJs": false,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "paths": {
      "@/*": [
        "./src/*"
      ]
    },
    "plugins": [
      {
        "name": "next"
      }
    ]
  },
  "include": [
    "**/*.ts",
    "**/*.tsx",
    "next-env.d.ts",
    ".next/types/**/*.ts"
  ],
  "exclude": [
    "node_modules"
  ]
}
AGC_SCAFFOLD_EOF

chmod +x "${PROJECT_DIR}/scripts/build_project.sh" 2>/dev/null || true

echo ">> Project files written."

# ---------------------------------------------------------------------------
# Package into a GitHub-ready zip
# ---------------------------------------------------------------------------
echo ">> Creating ${PROJECT_DIR}.zip ..."
rm -f "${PROJECT_DIR}.zip"
if command -v zip >/dev/null 2>&1; then
    (cd "$(dirname "${PROJECT_DIR}")" && zip -qr "$(basename "${PROJECT_DIR}").zip" "$(basename "${PROJECT_DIR}")" -x "*/node_modules/*" -x "*/.next/*")
    echo ">> Done: ${PROJECT_DIR}.zip"
else
    echo "!! 'zip' not found — skipping archive step. Install zip or archive ${PROJECT_DIR}/ manually."
fi

echo ""
echo "Next steps:"
echo "  cd ${PROJECT_DIR}"
echo "  npm install"
echo "  cp .env.example .env.local   # fill in Historian SQL credentials"
echo "  npm run dev"
echo ""
echo "To publish to GitHub:"
echo "  cd ${PROJECT_DIR} && git init && git add . && git commit -m 'Initial commit'"
echo "  git branch -M main && git remote add origin <your-repo-url> && git push -u origin main"
