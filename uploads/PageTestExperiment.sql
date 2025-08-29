-- 1. Switch Database & Environment Setup
USE [dev-Test];
GO

-- Sequential Primary Key
DROP TABLE IF EXISTS dbo.PageTest_SEQUENTIAL_INT;
GO

CREATE TABLE dbo.PageTest_SEQUENTIAL_INT
(
    ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    Value CHAR(200) NOT NULL DEFAULT 'Test'
);
GO

-- Random Primary Key
DROP TABLE IF EXISTS dbo.PageTest_RANDOM_GUID;
GO

CREATE TABLE dbo.PageTest_RANDOM_GUID
(
    ID UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY CLUSTERED,
    Value CHAR(200) NOT NULL DEFAULT 'Test'
);
GO

-- Use SQLQueryStress to simulate concurrent execution of the following SQL. e.g. 1000 Threads, 100 Iterations.

-- 2. Generate Page Splits in PageTest_RANDOM_GUID
INSERT INTO dbo.PageTest_RANDOM_GUID DEFAULT VALUES;
GO

-- Run 4 to view results

-- 3. Generate Hotspot Page Contention in PageTest_SEQUENTIAL_INT
INSERT INTO dbo.PageTest_SEQUENTIAL_INT DEFAULT VALUES;
GO

-- Run 4 to view results

/*==========================================================================*/
-- 4. View Hotspot Page Contention

-- Rest Awaiting Stats
DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);

-- Reset Latch Stats
DBCC SQLPERF('sys.dm_os_latch_stats', CLEAR);


-- View PAGELATCH Awaiting
SELECT wait_type, waiting_tasks_count, wait_time_ms, max_wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type LIKE 'PAGELATCH%';

-- View latch Awaiting Details
SELECT latch_class, waiting_requests_count, wait_time_ms
FROM sys.dm_os_latch_stats
ORDER BY wait_time_ms DESC;

-- 5. Compare Page Splits

-- View Total
SELECT 'Sequential INT' AS TableName, COUNT(*) AS [RowCount] FROM [dev-Test].dbo.PageTest_SEQUENTIAL_INT
UNION ALL
SELECT 'Random Guid', COUNT(*) FROM [dev-Test].dbo.PageTest_RANDOM_GUID;

-- View Page Splits Stats
SELECT 
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    ips.page_count,
    ips.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON i.object_id = ips.object_id AND i.index_id = ips.index_id
WHERE OBJECT_NAME(ips.object_id) IN ('PageTest_SEQUENTIAL_INT', 'PageTest_RANDOM_GUID');
