/*=============================================================================
    GOLD LAYER — DIMENSION AND FACT VIEWS
===============================================================================

    PURPOSE
    -------
    This script creates the analytical views in the Gold layer of the
    data warehouse.

    The Gold layer is the business-facing layer. It provides clean,
    integrated, and analysis-ready data for reporting, dashboards,
    BI tools, and analytical queries.

    OBJECTS CREATED
    ----------------
        1. gold.dim_customers
           - Customer dimension
           - Combines CRM customer information with ERP customer attributes
             and location information.

        2. gold.dim_products
           - Product dimension
           - Combines CRM product information with ERP product category data.
           - Keeps only currently active products.

        3. gold.fact_sales
           - Sales fact view
           - Combines sales transactions with customer and product dimensions.

    DESIGN NOTES
    ------------
    - Views are used instead of physical tables.
    - Surrogate keys are generated using ROW_NUMBER().
    - LEFT JOINs preserve records from the primary source tables.
    - Business-ready attributes are exposed with analytical-friendly names.
    - The product dimension filters out products with an end date.

    IMPORTANT
    ---------
    This script intentionally preserves the original business logic.
    No joins, filters, calculations, or column mappings have been changed.

=============================================================================*/


/*=============================================================================
    1. CUSTOMER DIMENSION
===============================================================================

    View:
        gold.dim_customers

    Purpose:
        Creates a unified customer dimension by combining customer data
        from the CRM system with:

        - Customer birth date and gender from ERP
        - Customer country/location from ERP

    Grain:
        One row per customer record from silver.crm_cust_info,
        subject to the results of the LEFT JOIN operations.

    Surrogate Key:
        customer_key is generated using ROW_NUMBER().

=============================================================================*/

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS

SELECT   
    ROW_NUMBER() OVER (
        ORDER BY cst_id
    ) AS customer_key,-- Surrogate key generated for analytical/data warehouse purposes
    cu.cst_id AS customer_id,
    cu.cst_key AS customer_number,
    cu.cst_firstname AS first_name,
    cu.cst_lastname AS last_name,
    cloc.cntry AS country,
    cu.cst_marital_status AS marital_status,
    CASE
        WHEN cu.cst_gndr != 'n/a'
            THEN cu.cst_gndr
        ELSE COALESCE(caz.gen, 'n/a')
    END AS gender,
    cu.cst_create_date AS create_date,
    caz.bdate AS birthate

FROM silver.crm_cust_info AS cu
LEFT JOIN silver.erp_cust_az12 AS caz
    ON cu.cst_key = caz.cid
LEFT JOIN silver.erp_loc_a101 AS cloc
    ON cu.cst_key = cloc.cid;
GO


/*=============================================================================
    2. PRODUCT DIMENSION
===============================================================================

    View:
        gold.dim_products

    Purpose:
        Creates a unified product dimension by combining CRM product
        information with ERP product category information.

    Business Rule:
        Only currently active products are included.

        A product is considered active when:
            prd_end_dt IS NULL

    Surrogate Key:
        product_key is generated using ROW_NUMBER().

=============================================================================*/

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS

SELECT
    
    ROW_NUMBER() OVER (
        ORDER BY pri.prd_start_dt, pri.prd_key
    ) AS product_key,-- Surrogate key generated based on product start date and product key
    pri.prd_id AS product_id,
    pri.prd_key AS product_number,
    pri.prd_nm AS product_name,
    pri.cat_id AS category_id,
    ca.cat AS category,
    ca.subcat AS subcategory,
    ca.maintenance AS maintenance,
    pri.prd_cost AS product_cost,
    pri.prd_line AS poduct_line,
    pri.prd_start_dt AS start_date

FROM silver.crm_prd_info AS pri
LEFT JOIN silver.erp_px_cat_g1v2 AS ca
    ON pri.cat_id = ca.id
WHERE pri.prd_end_dt IS NULL;
GO


/*=============================================================================
    3. SALES FACT
===============================================================================

    View:
        gold.fact_sales

    Purpose:
        Creates the central sales fact view by combining sales transactions
        with the customer and product dimensions.

    Grain:
        One row per sales transaction from silver.crm_sales_details,
        subject to the results of the LEFT JOIN operations.

    Dimension Relationships:
        Sales → Customer
        Sales → Product

    Measures:
        - sale_amount
        - quantity
        - price

    Dates:
        - order_date
        - ship_date
        - due_date

=============================================================================*/

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS

SELECT  
    sa.sls_ord_num AS order_number,
    -- Surrogate key from the Product dimension
    dp.product_key AS product_key,
    -- Surrogate key from the Customer dimension
    dc.customer_key AS customer_key,
    sa.sls_order_dt AS order_date,
    sa.sls_ship_dt AS ship_date,
    sa.sls_due_dt AS due_date,
    sa.sls_sales AS sale_amount,
    sa.sls_quantity AS quantity,
    sa.sls_price AS price
FROM silver.crm_sales_details AS sa
LEFT JOIN gold.dim_customers AS dc
    ON sa.sls_cust_id = dc.customer_id
LEFT JOIN gold.dim_products AS dp
    ON sa.sls_prd_key = dp.product_number;
GO


/*=============================================================================
    END OF GOLD LAYER VIEW CREATION
=============================================================================*/

