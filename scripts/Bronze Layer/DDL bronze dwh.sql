
/* ============================================================
   BRONZE LAYER - TABLE CREATION SCRIPT
   ============================================================
   Purpose:
       1. Drop existing Bronze tables if they already exist.
       2. Recreate the Bronze tables with the required structure.

   Bronze Layer:
       The Bronze layer stores raw data ingested from source
       systems with minimal transformation.

   Tables:
       - crm_cust_info
       - crm_prd_info
       - crm_sales_details
       - erp_loc_a101
       - erp_px_cat_g1v2
       - erp_cust_az12

   WARNING:
       Existing tables are dropped before being recreated.
       Any existing data in these tables will be permanently
       deleted.
   ============================================================ */


/* ============================================================
   1. CRM CUSTOMER INFORMATION
   ============================================================ */

-- Drop the table if it already exists.
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
BEGIN
    DROP TABLE bronze.crm_cust_info;
END;
GO

-- Create the CRM customer information table.
CREATE TABLE bronze.crm_cust_info
(
    cst_id             INT,
    cst_key            NVARCHAR(50),
    cst_firstname      NVARCHAR(50),
    cst_lastname       NVARCHAR(50),
    cst_marital_status NVARCHAR(50),
    cst_gndr           NVARCHAR(50),
    cst_create_date    DATE
);
GO


/* ============================================================
   2. CRM PRODUCT INFORMATION
   ============================================================ */

-- Drop the table if it already exists.
IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
BEGIN
    DROP TABLE bronze.crm_prd_info;
END;
GO

-- Create the CRM product information table.
CREATE TABLE bronze.crm_prd_info
(
    prd_id       INT,
    prd_key      NVARCHAR(50),
    prd_nm       NVARCHAR(50),
    prd_cost     INT,
    prd_line     NVARCHAR(50),
    prd_start_dt DATE,
    prd_end_dt   DATE
);
GO


/* ============================================================
   3. CRM SALES DETAILS
   ============================================================ */

-- Drop the table if it already exists.
IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL

    DROP TABLE bronze.crm_sales_details;

GO

-- Create the CRM sales details table.
CREATE TABLE bronze.crm_sales_details
(
    sls_ord_num  NVARCHAR(50),
    sls_prd_key  NVARCHAR(50),
    sls_cust_id  INT,
    sls_order_dt INT,
    sls_ship_dt  INT,
    sls_due_dt   INT,
    sls_sales    INT,
    sls_quantity INT,
    sls_price    INT
);
GO


/* ============================================================
   4. ERP LOCATION INFORMATION
   ============================================================ */

-- Drop the table if it already exists.
IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL
BEGIN
    DROP TABLE bronze.erp_loc_a101;
END;
GO

-- Create the ERP location information table.
CREATE TABLE bronze.erp_loc_a101
(
    cid   NVARCHAR(50),
    cntry NVARCHAR(50)
);
GO


/* ============================================================
   5. ERP PRODUCT CATEGORY INFORMATION
   ============================================================ */

-- Drop the table if it already exists.
IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL
BEGIN
    DROP TABLE bronze.erp_px_cat_g1v2;
END;
GO

-- Create the ERP product category information table.
CREATE TABLE bronze.erp_px_cat_g1v2
(
    id          NVARCHAR(50),
    cat         NVARCHAR(50),
    subcat      NVARCHAR(50),
    maintenance NVARCHAR(50)
);
GO


/* ============================================================
   6. ERP CUSTOMER INFORMATION
   ============================================================ */

-- Drop the table if it already exists.
IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL
BEGIN
    DROP TABLE bronze.erp_cust_az12;
END;
GO

-- Create the ERP customer information table.
CREATE TABLE bronze.erp_cust_az12
(
    cid  NVARCHAR(50),
    bdate DATE,
    gen  NVARCHAR(50)
);
GO
