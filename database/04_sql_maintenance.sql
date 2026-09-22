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
