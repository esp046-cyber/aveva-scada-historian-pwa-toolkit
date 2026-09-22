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
