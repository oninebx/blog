DROP TABLE IF EXISTS DossierBiometricImage;
DROP TABLE IF EXISTS DossierBiometric;
DROP TABLE IF EXISTS Dossier;
DROP TABLE IF EXISTS Profile;
DROP TABLE IF EXISTS Member;

-- ================================
-- 1. Member
-- ================================
CREATE TABLE Member (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    FirstName NVARCHAR(100),
    LastName NVARCHAR(100),
    Email NVARCHAR(200),
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

-- ================================
-- 2. Profile (1-to-many with Member)
-- ================================
CREATE TABLE Profile (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    MemberId UNIQUEIDENTIFIER NOT NULL,  -- 去掉 UNIQUE，允许多条 Profile 对应同一个 Member
    Nationality NVARCHAR(100),
    DateOfBirth DATE,
    PhoneNumber NVARCHAR(50),
    Address NVARCHAR(300),
    JobTitle NVARCHAR(100),
    CONSTRAINT FK_Profile_Member FOREIGN KEY (MemberId)
        REFERENCES Member(Id)
);

-- ================================
-- 3. Dossier (1-to-many with Member)
-- ================================
CREATE TABLE Dossier (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    MemberId UNIQUEIDENTIFIER NOT NULL,  -- 去掉 UNIQUE，允许多条 Dossier 对应同一个 Member
    ReferenceNumber NVARCHAR(100),
    Status NVARCHAR(50),
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Dossier_Member FOREIGN KEY (MemberId)
        REFERENCES Member(Id)
);

-- ================================
-- 4. DossierBiometric (1-to-many)
-- ================================
CREATE TABLE DossierBiometric (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    DossierId UNIQUEIDENTIFIER NOT NULL,
    Type NVARCHAR(50),
    CapturedAt DATETIME2,
    Notes NVARCHAR(500),
    CONSTRAINT FK_DossierBiometric_Dossier FOREIGN KEY (DossierId)
        REFERENCES Dossier(Id)
);

-- ================================
-- 5. DossierBiometricImage (1-to-many)
-- ================================
CREATE TABLE DossierBiometricImage (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    DossierBiometricId UNIQUEIDENTIFIER NOT NULL,
    ImageData VARBINARY(MAX),
    Format NVARCHAR(20),
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_DossierBiometricImage_Biometric FOREIGN KEY (DossierBiometricId)
        REFERENCES DossierBiometric(Id)
);


-- Create one Member
DECLARE @MemberId UNIQUEIDENTIFIER = NEWID();

INSERT INTO Member (Id, FirstName, LastName, Email)
VALUES (@MemberId, 'John', 'Doe', 'john.doe@example.com');

----------------------------------------------------------
-- Create 2 Profiles (1 Member → many Profiles)
----------------------------------------------------------
DECLARE @ProfileId1 UNIQUEIDENTIFIER = NEWID();
DECLARE @ProfileId2 UNIQUEIDENTIFIER = NEWID();

INSERT INTO Profile (Id, MemberId, Nationality, DateOfBirth, PhoneNumber, Address, JobTitle)
VALUES
    (@ProfileId1, @MemberId, 'New Zealand', '1985-01-15', '0211234567', '123 Queen St, Auckland', 'Engineer'),
    (@ProfileId2, @MemberId, 'Australia',   '1988-03-22', '0229876543', '456 King St, Sydney',   'Designer');

----------------------------------------------------------
-- Create 4 Dossiers (1 Member → many Dossiers)
----------------------------------------------------------
DECLARE @DossierId1 UNIQUEIDENTIFIER = NEWID();
DECLARE @DossierId2 UNIQUEIDENTIFIER = NEWID();
DECLARE @DossierId3 UNIQUEIDENTIFIER = NEWID();
DECLARE @DossierId4 UNIQUEIDENTIFIER = NEWID();

INSERT INTO Dossier (Id, MemberId, ReferenceNumber, Status)
VALUES
    (@DossierId1, @MemberId, 'DSR-001', 'Active'),
    (@DossierId2, @MemberId, 'DSR-002', 'Active'),
    (@DossierId3, @MemberId, 'DSR-003', 'Inactive'),
    (@DossierId4, @MemberId, 'DSR-004', 'Pending');

----------------------------------------------------------
-- For each Dossier → create 2 Biometrics (total 8)
-- For each Biometric → create 16 Images (total 128)
----------------------------------------------------------

DECLARE @DossierTable TABLE (RowId INT IDENTITY(1,1), DossierId UNIQUEIDENTIFIER);
INSERT INTO @DossierTable (DossierId) VALUES (@DossierId1), (@DossierId2), (@DossierId3), (@DossierId4);

DECLARE @k INT = 1;

WHILE @k <= 4
BEGIN
    DECLARE @CurrentDossierId UNIQUEIDENTIFIER;
    SELECT @CurrentDossierId = DossierId FROM @DossierTable WHERE RowId = @k;

    -- Two biometrics per dossier
    DECLARE @bi INT = 1;

    WHILE @bi <= 2
    BEGIN
        DECLARE @BiometricId UNIQUEIDENTIFIER = NEWID();

        INSERT INTO DossierBiometric (Id, DossierId, Type, CapturedAt, Notes)
        VALUES (@BiometricId, @CurrentDossierId, 'FaceScan', DATEADD(DAY, -@bi, SYSDATETIME()), CONCAT('Biometric note ', @bi, ' for dossier ', @k));

        -- 16 images per biometric
        DECLARE @img INT = 1;

        WHILE @img <= 16
        BEGIN
            INSERT INTO DossierBiometricImage (Id, DossierBiometricId, ImageData, Format)
            VALUES (NEWID(), @BiometricId, 0x1234, 'jpg');

            SET @img += 1;
        END

        SET @bi += 1;
    END

    SET @k += 1;
END

