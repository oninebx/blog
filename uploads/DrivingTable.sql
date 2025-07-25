-- ====================================
-- 1. Setup Environment (Drop & Create)
-- ====================================
IF OBJECT_ID('dbo.Donation') IS NOT NULL DROP TABLE dbo.Donation;
IF OBJECT_ID('dbo.CausePage') IS NOT NULL DROP TABLE dbo.CausePage;
IF OBJECT_ID('dbo.Profile') IS NOT NULL DROP TABLE dbo.Profile;
IF OBJECT_ID('dbo.Payee') IS NOT NULL DROP TABLE dbo.Payee;

CREATE TABLE Payee (
    Id INT PRIMARY KEY IDENTITY,
    Name NVARCHAR(100) NOT NULL,
    Verified BIT NOT NULL DEFAULT 0
);

CREATE TABLE Profile (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    PayeeId INT NOT NULL,
    FullName NVARCHAR(100),
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (PayeeId) REFERENCES Payee(Id)
);

CREATE TABLE CausePage (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    Title NVARCHAR(200) NOT NULL,
    ProfileId UNIQUEIDENTIFIER NOT NULL,
    FOREIGN KEY (ProfileId) REFERENCES Profile(Id)
);

CREATE TABLE Donation (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    CausePageId UNIQUEIDENTIFIER NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    IsProcessed BIT NOT NULL DEFAULT 0,
    FOREIGN KEY (CausePageId) REFERENCES CausePage(Id)
);

-- ====================================
-- 2. Insert Test Data
-- ====================================
SET NOCOUNT ON;

-- Insert 100,000 Payees (~1% verified)
;WITH Numbered AS
(
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO Payee (Name, Verified)
SELECT 
    CONCAT('Payee_', rn),
    CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 1 THEN 1 ELSE 0 END
FROM Numbered
WHERE rn <= 100000;

-- Create one Profile per Payee
INSERT INTO Profile (PayeeId, FullName)
SELECT Id, CONCAT('Profile_', Id) FROM Payee;

-- Create one CausePage per Profile
INSERT INTO CausePage (Title, ProfileId)
SELECT CONCAT('CausePage_', Id), Id FROM Profile;

-- Insert 300,000 Donations
;WITH RandomPages AS
(
    SELECT Id AS CausePageId FROM CausePage
),
Numbered AS
(
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO Donation (CausePageId, Amount, IsProcessed)
SELECT 
    (SELECT TOP 1 CausePageId FROM RandomPages ORDER BY NEWID()),
    CAST((ABS(CHECKSUM(NEWID())) % 990 + 10) AS DECIMAL(18,2)),
    CASE WHEN ABS(CHECKSUM(NEWID())) % 10 < 7 THEN 1 ELSE 0 END
FROM Numbered
WHERE rn <= 300000;

-- ====================================
-- 3. Performance Test
-- ====================================
SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

DECLARE @StartTime DATETIME2, @EndTime DATETIME2, @DurationMs INT;

-- Query 1: Payee as Driving Table
PRINT '--- Query 1: Payee as Driving Table ---';
SET @StartTime = SYSDATETIME();
SELECT 
    pa.Id AS PayeeId,
    pa.Name,
    SUM(d.Amount) AS TotalProcessedAmount
FROM Payee pa
JOIN Profile pr ON pa.Id = pr.PayeeId
JOIN CausePage cp ON cp.ProfileId = pr.Id
JOIN Donation d ON d.CausePageId = cp.Id
WHERE pa.Verified = 0
  AND d.IsProcessed = 1
GROUP BY pa.Id, pa.Name
HAVING SUM(d.Amount) > 0;

SET @EndTime = SYSDATETIME();
SET @DurationMs = DATEDIFF(MILLISECOND, @StartTime, @EndTime);
PRINT CONCAT('Query 1 Duration: ', @DurationMs, ' ms');

-- Query 2: Donation as Driving Table
PRINT '--- Query 2: Donation as Driving Table ---';
SET @StartTime = SYSDATETIME();
SELECT 
    pa.Id AS PayeeId,
    pa.Name,
    SUM(d.Amount) AS TotalProcessedAmount
FROM Donation d
JOIN CausePage cp ON cp.Id = d.CausePageId
JOIN Profile pr ON cp.ProfileId = pr.Id
JOIN Payee pa ON pr.PayeeId = pa.Id
WHERE pa.Verified = 0
  AND d.IsProcessed = 1
GROUP BY pa.Id, pa.Name;

SET @EndTime = SYSDATETIME();
SET @DurationMs = DATEDIFF(MILLISECOND, @StartTime, @EndTime);
PRINT CONCAT('Query 2 Duration: ', @DurationMs, ' ms');

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
