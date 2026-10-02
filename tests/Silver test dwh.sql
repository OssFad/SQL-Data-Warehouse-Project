
/*
================================================================================
PURPOSE:
    Explore Bronze/Silver data, understand table relationships, and validate
    data quality through checks for duplicates, NULLs, formatting, dates,
    referential integrity, and business rules.

HOW TO EXECUTE:
    Run the script in SQL Server Management Studio (SSMS).
    The queries are read-only and do not modify the data.
================================================================================
*/


/*==============================================================================
  1. UNDERSTAND THE DATA AND THE RELATIONSHIPS BETWEEN TABLES
==============================================================================*/

-- Inspect CRM and ERP source tables
SELECT TOP 100 *
FROM bronze.crm_cust_info;

SELECT TOP 100 *
FROM bronze.crm_prd_info;

SELECT TOP 100 *
FROM bronze.crm_sales_details;

SELECT TOP 100 *
FROM bronze.erp_cust_az12;

SELECT TOP 100 *
FROM bronze.erp_loc_a101;

SELECT TOP 100 *
FROM bronze.erp_px_cat_g1v2;


-- Compare product keys between Sales and Product tables
SELECT DISTINCT
    sls_prd_key
FROM bronze.crm_sales_details;

SELECT DISTINCT
    prd_key
FROM bronze.crm_prd_info;


/*==============================================================================
  2. DATA QUALITY CHECKS — CRM CUSTOMER INFORMATION
==============================================================================*/

-- Inspect source customer data
SELECT TOP 100 *
FROM bronze.crm_cust_info;


-- Check for duplicate customer IDs in the Silver layer
SELECT
    cst_id,
    COUNT(*) AS record_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1;


-- Investigate specific duplicate customer records
SELECT *
FROM silver.crm_cust_info
WHERE cst_id = 29466
   OR cst_id = 29449;


-- Identify the most recent record for each customer
SELECT
    *,
    ROW_NUMBER() OVER
    (
        PARTITION BY cst_id
        ORDER BY cst_create_date DESC
    ) AS rec_date
FROM silver.crm_cust_info
WHERE cst_id = 29466
   OR cst_id = 29449;


-- Check for leading/trailing spaces in customer first names
SELECT
    cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);


-- Check for NULL customer creation dates
SELECT *
FROM silver.crm_cust_info
WHERE cst_create_date IS NULL;


/*==============================================================================
  3. DATA QUALITY CHECKS — CRM PRODUCT INFORMATION
==============================================================================*/

-- Inspect CRM product and related source tables
SELECT *
FROM bronze.crm_prd_info;

SELECT *
FROM bronze.crm_sales_details;

SELECT *
FROM bronze.erp_px_cat_g1v2;


-- Check for duplicate product keys
SELECT
    prd_key,
    COUNT(*) AS record_count
FROM silver.crm_prd_info
GROUP BY prd_key
HAVING COUNT(*) > 1;


-- Check for leading/trailing spaces in product names
SELECT
    prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);


-- Check for negative or NULL product costs
SELECT
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0
   OR prd_cost IS NULL;


-- Review distinct product line values
SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;


-- Check for invalid product date ranges
SELECT *
FROM silver.crm_prd_info
WHERE prd_start_dt > prd_end_dt;


/*==============================================================================
  4. DATA QUALITY CHECKS — CRM SALES DETAILS
==============================================================================*/

-- Inspect sales and related Silver tables
SELECT *
FROM bronze.crm_sales_details;

SELECT *
FROM silver.crm_cust_info;

SELECT *
FROM silver.crm_prd_info;


-- Check for sales records referencing non-existing customers
SELECT *
FROM silver.crm_sales_details
WHERE sls_cust_id NOT IN
(
    SELECT cst_id
    FROM silver.crm_cust_info
);


-- Check for leading/trailing spaces in product keys
SELECT *
FROM silver.crm_sales_details
WHERE sls_prd_key != TRIM(sls_prd_key);


-- Check for invalid order-date formats
SELECT DISTINCT
    sls_order_dt
FROM silver.crm_sales_details
WHERE LEN(sls_order_dt) != 10
   OR LEN(sls_order_dt) = 0;


-- Validate sales, quantity, and price business rules
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price,

    CASE
        WHEN sls_sales <= 0
             OR sls_sales IS NULL
             OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales
    END AS sales,

    CASE
        WHEN sls_price <= 0
             OR sls_price IS NULL
            THEN ABS(sls_sales) / NULLIF(sls_quantity, 0)
        ELSE sls_price
    END AS price

FROM silver.crm_sales_details

WHERE sls_sales <= 0
   OR sls_sales IS NULL
   OR sls_sales != sls_quantity * ABS(sls_price)
   OR sls_price <= 0
   OR sls_price IS NULL
   OR sls_quantity <= 0
   OR sls_quantity IS NULL

ORDER BY
    sls_sales,
    sls_quantity,
    sls_price;


/*==============================================================================
  5. DATA QUALITY CHECKS — ERP CUSTOMER INFORMATION
==============================================================================*/

-- Inspect ERP customer data and related tables
SELECT *
FROM bronze.erp_cust_az12;

SELECT *
FROM silver.crm_cust_info;

SELECT *
FROM bronze.erp_loc_a101;


-- Check for leading/trailing spaces in gender values
SELECT *
FROM silver.erp_cust_az12
WHERE gen != TRIM(gen);


-- Review distinct customer IDs
SELECT DISTINCT
    cid
FROM silver.erp_cust_az12;


-- Check for invalid birth dates
SELECT *
FROM silver.erp_cust_az12
WHERE LEN(bdate) < 10
   OR LEN(bdate) > 10
   OR bdate > GETDATE();


-- Review distinct gender values
SELECT DISTINCT
    gen
FROM silver.erp_cust_az12;


/*==============================================================================
  6. DATA QUALITY CHECKS — ERP LOCATION INFORMATION
==============================================================================*/

-- Inspect ERP location and related tables
SELECT *
FROM bronze.erp_cust_az12;

SELECT *
FROM silver.crm_cust_info;

SELECT *
FROM bronze.erp_loc_a101;


-- Check for ERP customer IDs that do not exist in the CRM customer table
SELECT *
FROM silver.erp_loc_a101
WHERE cid NOT IN
(
    SELECT cst_key
    FROM bronze.crm_cust_info
);


-- Review distinct country values
SELECT DISTINCT
    cntry
FROM silver.erp_loc_a101;


/*==============================================================================
  7. DATA QUALITY CHECKS — ERP PRODUCT CATEGORY INFORMATION
==============================================================================*/

-- Inspect ERP product category and related Silver tables
SELECT *
FROM bronze.erp_px_cat_g1v2;

SELECT *
FROM silver.crm_prd_info;

SELECT *
FROM silver.crm_sales_details;


-- Check for duplicate category IDs
SELECT
    id,
    COUNT(*) AS record_count
FROM bronze.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1;


-- Check for leading/trailing spaces in category attributes
SELECT *
FROM bronze.erp_px_cat_g1v2
WHERE id != TRIM(id)
   OR cat != TRIM(cat)
   OR subcat != TRIM(subcat)
   OR maintenance != TRIM(maintenance);


-- Review distinct maintenance values
SELECT DISTINCT
    maintenance
FROM bronze.erp_px_cat_g1v2;


/*==============================================================================
  END OF DATA EXPLORATION & DATA QUALITY VALIDATION
==============================================================================*/

