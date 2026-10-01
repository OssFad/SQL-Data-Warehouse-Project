	
/*=============================================================================
    SILVER LAYER - TABLE CREATION SCRIPT
===============================================================================

    Purpose:
        Creates the required tables in the Silver layer of the data warehouse.

    Process:
        1. Check whether each table already exists.
        2. Drop the existing table if found.
        3. Recreate the table with the required structure.

    Layer:
        Silver

    Notes:
        - Existing tables are dropped before recreation.
        - This script defines the physical table structures only.
        - Data loading and transformation logic are handled separately.

=============================================================================*/


/*=============================================================================
    1. CUSTOMER INFORMATION
    Source: CRM
    Target: silver.cust_info
=============================================================================*/

IF OBJECT_ID('silver.cust_info', 'U') IS NOT NULL
    DROP TABLE silver.cust_info;
GO

CREATE TABLE silver.cust_info
(
    cst_id              INT,
    cst_key             NVARCHAR(50),
    cst_firstname       NVARCHAR(50),
    cst_lastname        NVARCHAR(50),
    cst_marital_status  NVARCHAR(50),
    cst_gndr            NVARCHAR(50),
    cst_create_date     DATE
);
GO


/*=============================================================================
    2. PRODUCT INFORMATION
    Source: CRM
    Target: silver.crm_prd_info
=============================================================================*/

IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO

CREATE TABLE silver.crm_prd_info
(
    prd_id          INT,
    prd_key         NVARCHAR(50),
    prd_nm          NVARCHAR(50),
    prd_cost        INT,
    prd_start_dt    DATE,
    prd_end_dt      DATE
);
GO


/*=============================================================================
    3. SALES TRANSACTION DETAILS
    Source: CRM
    Target: silver.crm_sales_details
=============================================================================*/

IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
GO

CREATE TABLE silver.crm_sales_details
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


/*=============================================================================
    4. CUSTOMER MASTER DATA
    Source: ERP
    Target: silver.erp_cust_az12
=============================================================================*/

IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
GO

CREATE TABLE silver.erp_cust_az12
(
    cid     NVARCHAR(50),
    bdate   DATE,
    gen     NVARCHAR(50)
);
GO


/*=============================================================================
    5. CUSTOMER LOCATION DATA
    Source: ERP
    Target: silver.erp_loc_a101
=============================================================================*/

IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
GO

CREATE TABLE silver.erp_loc_a101
(
    cid     NVARCHAR(50),
    cntry   NVARCHAR(50)
);
GO


/*=============================================================================
    6. PRODUCT CATEGORY INFORMATION
    Source: ERP
    Target: silver.erp_px_cat_g1v2
=============================================================================*/

IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
GO

CREATE TABLE silver.erp_px_cat_g1v2
(
    id              NVARCHAR(50),
    cat             NVARCHAR(50),
    subcat          NVARCHAR(50),
    maintenance     NVARCHAR(50)
);
GO

