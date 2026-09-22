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
