
/*
================================================================================
PURPOSE
================================================================================
    This stored procedure loads and transforms data from the BRONZE layer
    into the SILVER layer of the data warehouse.

    The procedure:
        1. Truncates the existing SILVER tables.
        2. Extracts data from BRONZE tables.
        3. Cleans and standardizes the data.
        4. Applies business transformations and data-quality rules.
        5. Loads the transformed data into the corresponding SILVER tables.
        6. Displays the execution duration for each table and the total batch.
        7. Captures and displays errors using TRY/CATCH.

    Source Layer:
        - bronze.crm_cust_info
        - bronze.crm_prd_info
        - bronze.crm_sales_details
        - bronze.erp_cust_az12
        - bronze.erp_loc_a101
        - bronze.erp_px_cat_g1v2

    Target Layer:
        - silver.crm_cust_info
        - silver.crm_prd_info
        - silver.crm_sales_details
        - silver.erp_cust_az12
        - silver.erp_loc_a101
        - silver.erp_px_cat_g1v2

IMPORTANT
================================================================================
    This procedure uses a FULL REFRESH approach.

    Each target SILVER table is truncated before the transformed data
    is inserted.

EXECUTION
================================================================================
    To create or update the stored procedure, execute this script.

    Then execute the procedure using:

        EXEC silver.load_silver;

    Or execute both statements together:

        EXEC silver.load_silver;

================================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN

    DECLARE
        @start_time       DATETIME,
        @end_time         DATETIME,
        @start_batch_time DATETIME,
        @end_batch_time   DATETIME;

    BEGIN TRY

        /*========================================================================
          Start Batch
        =========================================================================*/
        SET @start_batch_time = GETDATE();

        PRINT '==============================================================';
        PRINT ' Loading Silver layer';
        PRINT '==============================================================';


        /*========================================================================
          CRM TABLES
        =========================================================================*/
        PRINT '==============================================================';
        PRINT 'Loading CRM Tables';
        PRINT '==============================================================';


        /*========================================================================
          1. CRM CUSTOMER INFORMATION
             Source : bronze.crm_cust_info
             Target : silver.crm_cust_info
        =========================================================================*/
        SET @start_time = GETDATE();

        PRINT '>> Truncating the silver.crm_cust_info table';

        TRUNCATE TABLE silver.crm_cust_info;

        PRINT '>> Inserting data into the silver.crm_cust_info table';

        INSERT INTO silver.crm_cust_info
        (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            TRIM(cst_key)       AS cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname)  AS cst_lastname,

            CASE
                WHEN TRIM(cst_marital_status) = 'M'
                    THEN 'Married'
                WHEN TRIM(cst_marital_status) = 'S'
                    THEN 'Single'
                ELSE 'n/a'
            END AS cst_marital_status,

            CASE
                WHEN TRIM(cst_gndr) = 'F'
                    THEN 'Female'
                WHEN TRIM(cst_gndr) = 'M'
                    THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr,

            cst_create_date

        FROM
        (
            SELECT
                *,
                ROW_NUMBER() OVER
                (
                    PARTITION BY cst_id
                    ORDER BY cst_create_date DESC
                ) AS rec_date

            FROM bronze.crm_cust_info

            WHERE cst_id IS NOT NULL
        ) t

        WHERE rec_date = 1;

        SET @end_time = GETDATE();

        PRINT 'Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '-------------------------';


        /*========================================================================
          2. CRM PRODUCT INFORMATION
             Source : bronze.crm_prd_info
             Target : silver.crm_prd_info
        =========================================================================*/
        SET @start_time = GETDATE();

        PRINT 'Truncating the silver.crm_prd_info table';

        TRUNCATE TABLE silver.crm_prd_info;

        PRINT 'Inserting data into silver.crm_prd_info table';

        INSERT INTO silver.crm_prd_info
        (
            prd_id,
            prd_key,
            cat_id,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT
            prd_id,

            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,

            REPLACE
            (
                SUBSTRING(prd_key, 1, 5),
                '-',
                '_'
            ) AS cat_id,

            TRIM(prd_nm) AS prd_nm,

            ISNULL(prd_cost, 0) AS prd_cost,

            CASE
                WHEN UPPER(TRIM(prd_line)) = 'R'
                    THEN 'Road'
                WHEN UPPER(TRIM(prd_line)) = 'S'
                    THEN 'Other Sales'
                WHEN UPPER(TRIM(prd_line)) = 'T'
                    THEN 'Touring'
                WHEN UPPER(TRIM(prd_line)) = 'M'
                    THEN 'Mountain'
                ELSE 'n/a'
            END AS prd_line,

            CAST(prd_start_dt AS DATE) AS prd_start_dt,

            CAST
            (
                DATEADD
                (
                    DAY,
                    -1,
                    LEAD(prd_start_dt) OVER
                    (
                        PARTITION BY prd_key
                        ORDER BY prd_start_dt
                    )
                ) AS DATE
            ) AS prd_end_dt

        FROM bronze.crm_prd_info;

        SET @end_time = GETDATE();

        PRINT 'Loading Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR)
            + ' seconds';

        PRINT '-------------------------------------';


        /*========================================================================
          3. CRM SALES DETAILS
             Source : bronze.crm_sales_details
             Target : silver.crm_sales_details
        =========================================================================*/
        SET @start_time = GETDATE();

        PRINT 'Truncating table: silver.crm_sales_details';

        TRUNCATE TABLE silver.crm_sales_details;

        PRINT 'Inserting data into silver.crm_sales_details';

        INSERT INTO silver.crm_sales_details
        (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,

            CASE
                WHEN LEN(sls_order_dt) = 0
                     OR LEN(sls_order_dt) != 8
                    THEN NULL
                ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,

            CASE
                WHEN LEN(sls_ship_dt) = 0
                     OR LEN(sls_ship_dt) != 8
                    THEN NULL
                ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,

            CASE
                WHEN LEN(sls_due_dt) = 0
                     OR LEN(sls_due_dt) != 8
                    THEN NULL
                ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,

            CASE
                WHEN sls_sales <= 0
                     OR sls_sales IS NULL
                     OR sls_sales != sls_quantity * ABS(sls_price)
                    THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END AS sls_sales,

            sls_quantity,

            CASE
                WHEN sls_price <= 0
                     OR sls_price IS NULL
                    THEN ABS(sls_sales) / NULLIF(sls_quantity, 0)
                ELSE sls_price
            END AS sls_price

        FROM bronze.crm_sales_details;

        SET @end_time = GETDATE();


        /*========================================================================
          ERP TABLES
        =========================================================================*/
        PRINT '==============================================================';
        PRINT 'Loading ERP Tables';
        PRINT '==============================================================';


        /*========================================================================
          4. ERP CUSTOMER INFORMATION
             Source : bronze.erp_cust_az12
             Target : silver.erp_cust_az12
        =========================================================================*/
        SET @start_time = GETDATE();

        PRINT 'Truncating table silver.erp_cust_az12';

        TRUNCATE TABLE silver.erp_cust_az12;

        PRINT 'Inserting data into silver.erp_cust_az12';

        INSERT INTO silver.erp_cust_az12
        (
            cid,
            bdate,
            gen
        )
        SELECT

            CASE
                WHEN cid LIKE 'NAS%'
                    THEN REPLACE(cid, 'NAS', '')
                ELSE cid
            END AS cid,

            CASE
                WHEN CAST(bdate AS DATE) > GETDATE()
                    THEN NULL
                ELSE CAST(bdate AS DATE)
            END AS bdate,

            CASE
                WHEN UPPER(TRIM(gen)) IN ('F', 'Female')
                    THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M', 'Male')
                    THEN 'Male'
                ELSE 'n/a'
            END AS gen

        FROM bronze.erp_cust_az12;

        SET @end_time = GETDATE();

        PRINT 'Loading Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '---------------------------------------';


        /*========================================================================
          5. ERP LOCATION INFORMATION
             Source : bronze.erp_loc_a101
             Target : silver.erp_loc_a101
        =========================================================================*/
        SET @start_time = GETDATE();

        PRINT 'Truncating the table silver.erp_loc_a101';

        TRUNCATE TABLE silver.erp_loc_a101;

        PRINT 'Inserting data into silver.erp_loc_a101';

        INSERT INTO silver.erp_loc_a101
        (
            cid,
            cntry
        )
        SELECT
            TRIM(REPLACE(cid, '-', '')) AS cid,

            CASE
                WHEN UPPER(TRIM(cntry)) = 'DE'
                    THEN 'Germany'

                WHEN UPPER(TRIM(cntry)) IN ('USA', 'US')
                    THEN 'United States'

                WHEN UPPER(TRIM(cntry)) IS NULL
                     OR UPPER(TRIM(cntry)) = ''
                    THEN 'n/a'

                ELSE TRIM(cntry)
            END AS cntry

        FROM bronze.erp_loc_a101;

        SET @end_time = GETDATE();

        PRINT 'Loading Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '-------------------------------------------';


        /*========================================================================
          6. ERP PRODUCT CATEGORY INFORMATION
             Source : bronze.erp_px_cat_g1v2
             Target : silver.erp_px_cat_g1v2
        =========================================================================*/
        SET @start_time = GETDATE();

        PRINT 'Truncating table silver.erp_px_cat_g1v2';

        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        PRINT 'Inserting data into silver.erp_px_cat_g1v2';

        INSERT INTO silver.erp_px_cat_g1v2
        (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            id,
            cat,
            subcat,
            maintenance

        FROM bronze.erp_px_cat_g1v2;

        SET @end_time = GETDATE();

        PRINT 'Loading Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';

        PRINT '---------------------------------------------';


        /*========================================================================
          END OF BATCH
        =========================================================================*/
        SET @end_batch_time = GETDATE();

        PRINT '===================================================';
        PRINT 'The Total Load Duration: '
            + CAST
              (
                  DATEDIFF
                  (
                      SECOND,
                      @start_batch_time,
                      @end_batch_time
                  ) AS NVARCHAR
              )
            + ' seconds';
        PRINT '===================================================';


    END TRY


    /*========================================================================
      ERROR HANDLING
    =========================================================================*/
    BEGIN CATCH

        PRINT '===================================================';

        PRINT 'Error Message: ' + ERROR_MESSAGE();

        PRINT 'Error Number: '
            + CAST(ERROR_NUMBER() AS NVARCHAR);

        PRINT 'Error State: '
            + CAST(ERROR_STATE() AS NVARCHAR);

        PRINT '===================================================';

    END CATCH;

END;
GO


/*==============================================================================
  EXECUTE THE SILVER LAYER LOAD
==============================================================================*/

EXEC silver.load_silver;
GO

