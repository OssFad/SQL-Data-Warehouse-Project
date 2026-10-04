
/*=============================================================================
    GOLD LAYER — DATA QUALITY & VALIDATION CHECKS
===============================================================================

    PURPOSE
    -------
    This script validates the quality and integrity of the Gold-layer
    dimension and fact views before they are consumed by BI tools,
    dashboards, reports, or analytical queries.

    OBJECTIVES
    ----------
    The validation checks cover:

        1. Customer dimension validation
        2. Customer surrogate-key uniqueness
        3. Customer gender value validation
        4. Product source-data inspection
        5. Product/category relationship validation
        6. Product surrogate-key uniqueness
        7. Sales source-data inspection
        8. Gold fact-table referential integrity

    GOLD OBJECTS VALIDATED
    ----------------------
        - gold.dim_customers
        - gold.dim_products
        - gold.fact_sales

    SOURCE OBJECTS INSPECTED
    ------------------------
        - silver.crm_prd_info
        - silver.erp_px_cat_g1v2
        - silver.crm_sales_details

    VALIDATION PRINCIPLE
    --------------------
    The objective is not only to verify that the Gold views were created
    successfully, but also to verify that:

        - Surrogate keys are unique.
        - Dimension attributes contain expected values.
        - Source-to-source relationships are working correctly.
        - Fact records can be matched to their dimensions.
        - No unexpected orphan records exist.

=============================================================================*/


/*=============================================================================
    1. CUSTOMER DIMENSION — GENERAL DATA INSPECTION
===============================================================================

    Purpose:
        Review the records currently available in the customer dimension.

    Usage:
        Useful during development and troubleshooting to visually inspect
        the Gold-layer customer data.

=============================================================================*/

SELECT *
FROM gold.dim_customers;


/*=============================================================================
    2. CUSTOMER DIMENSION — SURROGATE KEY UNIQUENESS CHECK
===============================================================================

    Purpose:
        Verify that customer_key is unique in gold.dim_customers.

    Expected Result:
        The query should return ZERO rows.

    Why:
        customer_key is intended to uniquely identify each customer record
        within the dimension.

    If rows are returned:
        One or more customer_key values appear more than once and should
        be investigated.

=============================================================================*/

SELECT
    customer_key,
    COUNT(*) AS record_count
FROM gold.dim_customers
GROUP BY
    customer_key
HAVING COUNT(*) > 1;


/*=============================================================================
    3. CUSTOMER DIMENSION — GENDER VALUE VALIDATION
===============================================================================

    Purpose:
        Identify the distinct gender values currently stored in the
        customer dimension.

    Usage:
        Helps detect unexpected, inconsistent, or incorrectly transformed
        categorical values.

    Example:
        Expected values might include:
            - Male
            - Female
            - n/a

    Note:
        The query does not define what the correct values should be.
        It simply exposes the existing distinct values for validation.

=============================================================================*/

SELECT DISTINCT
    gender
FROM gold.dim_customers
ORDER BY
    gender;


/*=============================================================================
    4. PRODUCT SOURCE DATA — INSPECTION
===============================================================================

    Purpose:
        Inspect the main Silver-layer product and category source tables,
        as well as sales data used downstream.

    Usage:
        Useful for troubleshooting product relationships and validating
        the source data before analyzing Gold-layer results.

=============================================================================*/

SELECT *
FROM silver.crm_prd_info;

SELECT *
FROM silver.erp_px_cat_g1v2;

SELECT *
FROM silver.crm_sales_details;


/*=============================================================================
    5. PRODUCT SOURCE DATA — CATEGORY LOOKUP VALIDATION
===============================================================================

    Purpose:
        Inspect the CRM product records associated with category ID 'CO_PE'.

    Usage:
        This is a targeted validation check to investigate whether the
        product category exists and is correctly represented in the
        source product data.

=============================================================================*/

SELECT *
FROM silver.crm_prd_info
WHERE cat_id = 'CO_PE';


/*=============================================================================
    6. ERP CATEGORY DATA — CATEGORY LOOKUP VALIDATION
===============================================================================

    Purpose:
        Verify whether the corresponding category ID 'CO_PE' exists
        in the ERP category reference table.

    Usage:
        This allows us to compare the CRM product category reference
        against the ERP category master data.

=============================================================================*/

SELECT *
FROM silver.erp_px_cat_g1v2
WHERE id = 'CO_PE';


/*=============================================================================
    7. PRODUCT DIMENSION — SURROGATE KEY UNIQUENESS CHECK
===============================================================================

    Purpose:
        Verify that product_key is unique in gold.dim_products.

    Expected Result:
        The query should return ZERO rows.

    Why:
        product_key is intended to uniquely identify a product within
        the Gold-layer product dimension.

    If rows are returned:
        Duplicate surrogate keys exist and should be investigated.

=============================================================================*/

SELECT
    product_key,
    COUNT(*) AS record_count
FROM gold.dim_products
GROUP BY
    product_key
HAVING COUNT(*) > 1;


/*=============================================================================
    8. SALES AND DIMENSION DATA — GENERAL INSPECTION
===============================================================================

    Purpose:
        Inspect the main sales fact source and the two dimensions that
        will be used to enrich sales transactions.

    Objects:
        - Silver sales transactions
        - Gold customer dimension
        - Gold product dimension

    Usage:
        Useful for troubleshooting missing relationships between the
        sales data and the Gold-layer dimensions.

=============================================================================*/

SELECT *
FROM silver.crm_sales_details;

SELECT *
FROM gold.dim_customers;

SELECT *
FROM gold.dim_products;


/*=============================================================================
    9. FACT SALES — REFERENTIAL INTEGRITY CHECK
===============================================================================

    Purpose:
        Identify sales transactions that cannot be matched to either:

            - gold.dim_customers
            - gold.dim_products

    Logic:
        A LEFT JOIN is used so that all sales transactions remain in
        the result.

        The WHERE clause then identifies records where either dimension
        failed to match.

    Expected Result:
        ZERO rows.

    If rows are returned:
        The fact table contains orphan records.

        Possible causes include:
            - Missing customer in dim_customers
            - Missing product in dim_products
            - Incorrect customer key
            - Incorrect product key
            - Data transformation issue
            - Source-system data-quality problem

=============================================================================*/

SELECT *
FROM gold.fact_sales AS fs

LEFT JOIN gold.dim_customers AS dc
    ON fs.customer_key = dc.customer_key

LEFT JOIN gold.dim_products AS dp
    ON fs.product_key = dp.product_key

WHERE dc.customer_key IS NULL
   OR dp.product_key IS NULL;


/*=============================================================================
    END OF GOLD LAYER DATA QUALITY VALIDATION
=============================================================================*/
