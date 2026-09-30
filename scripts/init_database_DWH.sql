

/* ============================================================
   DATA WAREHOUSE INITIALIZATION SCRIPT
   ============================================================
   Purpose:
       1. Delete the existing DWH database if it already exists.
       2. Create a fresh DWH database.
       3. Create the Bronze, Silver, and Gold schemas.

   Architecture:
       Bronze → Raw / Source Data
       Silver → Cleaned / Transformed Data
       Gold   → Business / Analytics Data

   WARNING:
       This script is DESTRUCTIVE.
       If the DWH database already exists, it will be permanently
       deleted along with all objects and data inside it.
   ============================================================ */


/* ============================================================
   1. DROP EXISTING DATABASE
   ============================================================ */

IF EXISTS
(
    SELECT 1
    FROM sys.databases
    WHERE name = 'DWH'
)
BEGIN

    -- Force the database into single-user mode and
    -- immediately terminate existing connections.
    -- Any active transactions will be rolled back.
    ALTER DATABASE DWH
        SET SINGLE_USER
        WITH ROLLBACK IMMEDIATE;

    -- Permanently delete the DWH database.
    DROP DATABASE DWH;

END;
GO


/* ============================================================
   2. CREATE DATABASE
   ============================================================ */

CREATE DATABASE DWH;
GO


/* ============================================================
   3. CREATE DATA WAREHOUSE SCHEMAS
   ============================================================ */

-- Bronze Layer:
-- Stores raw data extracted from source systems.
CREATE SCHEMA bronze;
GO


-- Silver Layer:
-- Stores cleaned, standardized, and validated data.
CREATE SCHEMA silver;
GO


-- Gold Layer:
-- Stores business-ready data used for reporting and analytics.
CREATE SCHEMA gold;
GO