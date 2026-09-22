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
