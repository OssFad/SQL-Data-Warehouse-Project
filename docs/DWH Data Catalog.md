# Data Catalog — Gold Layer

**Document type:** Technical & Business Data Catalog  
**Warehouse layer:** Gold  
**Primary use cases:** BI, reporting, business analysis, Power BI, ad-hoc analytics  
**Source systems represented:** CRM and ERP  
**Catalog status:** Initial catalog derived from the current SQL view definitions  
**Owner:** Data / Analytics Team  
**Last updated:** 2026-10-04

---

## 1. Purpose

This Data Catalog documents the Gold-layer analytical objects created from the Silver layer.

The catalog provides a common reference for:

- What each table/view represents
- The business meaning of each column
- The source column and source system
- Transformation and derivation logic
- Data types
- Grain of each object
- Relationships between dimensions and facts
- Key fields
- Data-quality considerations
- Known assumptions and items requiring business confirmation

The Gold layer is designed to provide **business-ready data for reporting and analytics** rather than exposing raw source-system structures directly to business users.

---

# 2. Gold Layer Data Model

The current model follows a **star-schema pattern**:

```text
                         ┌──────────────────────┐
                         │   gold.dim_customers │
                         │──────────────────────│
                         │ customer_key    (SK) │
                         │ customer_id          │
                         │ customer_number      │
                         │ customer attributes  │
                         └──────────┬───────────┘
                                    │
                                    │ customer_key
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │   gold.fact_sales    │
                         │──────────────────────│
                         │ order_number         │
                         │ customer_key    (FK) │
                         │ product_key     (FK) │
                         │ dates                │
                         │ sales measures       │
                         └──────────┬───────────┘
                                    │
                                    │ product_key
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │   gold.dim_products  │
                         │──────────────────────│
                         │ product_key     (SK) │
                         │ product_id           │
                         │ product_number       │
                         │ product attributes  │
                         └──────────────────────┘
```

### Object classification

| Object | Type | Role | Grain |
|---|---|---|---|
| `gold.dim_customers` | View | Dimension | Customer record |
| `gold.dim_products` | View | Dimension | Active product record |
| `gold.fact_sales` | View | Fact | Sales transaction/order line |

> **Important:** The exact business grain of `fact_sales` should be formally confirmed against the source system. The SQL exposes `sls_ord_num` but does not prove whether one row represents an order, an order line, or another transaction grain.

---

# 3. Source-to-Gold Lineage

## Customer Dimension

```text
silver.crm_cust_info
        │
        ├──────────────┐
        │              │
        ▼              ▼
silver.erp_cust_az12  silver.erp_loc_a101
        │              │
        └───────┬──────┘
                ▼
       gold.dim_customers
```

## Product Dimension

```text
silver.crm_prd_info
        │
        │ LEFT JOIN
        ▼
silver.erp_px_cat_g1v2
        │
        ▼
gold.dim_products
```

## Sales Fact

```text
silver.crm_sales_details
        │
        ├──────────────┐
        │              │
        ▼              ▼
gold.dim_customers  gold.dim_products
        │              │
        └───────┬──────┘
                ▼
         gold.fact_sales
```

---

# 4. Object: `gold.dim_customers`

## 4.1 Overview

**Business purpose:** Provides a unified customer dimension by combining CRM customer information with ERP customer demographic and location information.

**Object type:** View

**Primary source:** `silver.crm_cust_info`

**Additional sources:**

- `silver.erp_cust_az12`
- `silver.erp_loc_a101`

**Join strategy:** `LEFT JOIN`

**Expected analytical role:** Customer dimension in the star schema.

### Grain

The SQL is driven by:

```sql
FROM silver.crm_cust_info AS cu
```

Therefore, the intended grain is a **CRM customer record**, subject to the cardinality of the ERP joins.

The data model should verify that `cst_key → cid` is one-to-one in the ERP sources. If not, a single CRM customer can produce multiple rows.

---

## 4.2 Column Catalog

| Column | Data Type | Key | Source | Transformation / Definition | Business Meaning |
|---|---|---|---|---|---|
| `customer_key` | BIGINT* | SK | Derived | `ROW_NUMBER() OVER (ORDER BY cst_id)` | Surrogate identifier used to connect the customer dimension to fact data |
| `customer_id` | INT* | Business ID | `silver.crm_cust_info.cst_id` | Direct mapping | CRM customer identifier |
| `customer_number` | NVARCHAR(50)* | Business reference | `silver.crm_cust_info.cst_key` | Direct mapping | Customer business/source-system key |
| `first_name` | NVARCHAR(50)* | — | `silver.crm_cust_info.cst_firstname` | Direct mapping | Customer first name |
| `last_name` | NVARCHAR(50)* | — | `silver.crm_cust_info.cst_lastname` | Direct mapping | Customer last name |
| `country` | NVARCHAR(50)* | — | `silver.erp_loc_a101.cntry` | Direct mapping through LEFT JOIN | Customer country |
| `marital_status` | NVARCHAR(50)* | — | `silver.crm_cust_info.cst_marital_status` | Direct mapping | Customer marital status |
| `gender` | NVARCHAR(50)* | — | CRM + ERP | CRM gender used unless it equals `n/a`; otherwise ERP gender; fallback `n/a` | Customer gender |
| `create_date` | DATE* | — | `silver.crm_cust_info.cst_create_date` | Direct mapping | Date the customer record was created |
| `birthate` | DATE* | — | `silver.erp_cust_az12.bdate` | Direct mapping | Customer birth date |

\* Data types marked with `*` are inferred from the underlying Silver definitions or SQL expression. The actual view metadata should be checked in SQL Server for authoritative output types.

### Gender business rule

```sql
CASE
    WHEN cu.cst_gndr != 'n/a'
        THEN cu.cst_gndr
    ELSE COALESCE(caz.gen, 'n/a')
END
```

Priority:

1. Use CRM gender when it is not `n/a`.
2. Otherwise use ERP gender.
3. If ERP gender is unavailable, return `n/a`.

### Known naming issue

`birthate` appears to be a spelling error for `birth_date`.

This catalog preserves the current SQL name rather than changing the implementation.

---

# 5. Object: `gold.dim_products`

## 5.1 Overview

**Business purpose:** Provides a business-friendly product dimension by combining CRM product information with ERP category information.

**Object type:** View

**Primary source:** `silver.crm_prd_info`

**Additional source:** `silver.erp_px_cat_g1v2`

**Join strategy:** `LEFT JOIN`

**Business rule:** Only products where `prd_end_dt IS NULL` are included.

**Expected analytical role:** Product dimension in the star schema.

### Grain

The intended grain is **one active product record**.

The product view filters the Silver product table using:

```sql
WHERE pri.prd_end_dt IS NULL
```

Therefore, historical/inactive records with a non-null end date are excluded.

---

## 5.2 Column Catalog

| Column | Data Type | Key | Source | Transformation / Definition | Business Meaning |
|---|---|---|---|---|---|
| `product_key` | BIGINT* | SK | Derived | `ROW_NUMBER() OVER (ORDER BY prd_start_dt, prd_key)` | Surrogate product identifier |
| `product_id` | INT* | Business ID | `silver.crm_prd_info.prd_id` | Direct mapping | CRM product identifier |
| `product_number` | NVARCHAR(50)* | Business reference | `silver.crm_prd_info.prd_key` | Direct mapping | Product business/source-system key |
| `product_name` | NVARCHAR(50)* | — | `silver.crm_prd_info.prd_nm` | Direct mapping | Product name |
| `category_id` | —* | FK/reference | `silver.crm_prd_info.cat_id` | Direct mapping | Product category identifier |
| `category` | NVARCHAR(50)* | — | `silver.erp_px_cat_g1v2.cat` | LEFT JOIN on category ID | Product category |
| `subcategory` | NVARCHAR(50)* | — | `silver.erp_px_cat_g1v2.subcat` | LEFT JOIN on category ID | Product subcategory |
| `maintenance` | NVARCHAR(50)* | — | `silver.erp_px_cat_g1v2.maintenance` | LEFT JOIN on category ID | Product maintenance classification |
| `product_cost` | INT* | — | `silver.crm_prd_info.prd_cost` | Direct mapping | Product cost |
| `poduct_line` | —* | — | `silver.crm_prd_info.prd_line` | Direct mapping | Product line |
| `start_date` | DATE* | — | `silver.crm_prd_info.prd_start_dt` | Direct mapping | Product effective start date |

### Active-product rule

Only records satisfying:

```sql
prd_end_dt IS NULL
```

are exposed in the Gold dimension.

Therefore:

- `prd_end_dt IS NULL` → included
- `prd_end_dt IS NOT NULL` → excluded

### Known naming issue

`poduct_line` appears to be a spelling error for `product_line`.

The catalog preserves the current SQL output name.

---

# 6. Object: `gold.fact_sales`

## 6.1 Overview

**Business purpose:** Provides the central sales transaction dataset used for analytical reporting.

**Object type:** View

**Primary source:** `silver.crm_sales_details`

**Dimensions connected:**

- `gold.dim_customers`
- `gold.dim_products`

**Join strategy:** `LEFT JOIN`

**Expected analytical role:** Central fact object in the star schema.

### Grain

The source driving the view is:

```sql
silver.crm_sales_details
```

The view exposes:

```text
order_number
product_key
customer_key
order_date
ship_date
due_date
sale_amount
quantity
price
```

The exact business grain must be confirmed from the source-system documentation. Do not automatically assume that `order_number` alone is unique.

---

# 7. Fact Sales Column Catalog

| Column | Data Type | Key / Measure | Source | Transformation / Definition | Business Meaning |
|---|---|---|---|---|---|
| `order_number` | NVARCHAR(50)* | Business reference | `silver.crm_sales_details.sls_ord_num` | Direct mapping | Sales order identifier |
| `product_key` | BIGINT* | FK | `gold.dim_products.product_key` | Derived through product join | Surrogate product key |
| `customer_key` | BIGINT* | FK | `gold.dim_customers.customer_key` | Derived through customer join | Surrogate customer key |
| `order_date` | INT* | Date | `silver.crm_sales_details.sls_order_dt` | Direct mapping | Order date |
| `ship_date` | INT* | Date | `silver.crm_sales_details.sls_ship_dt` | Direct mapping | Shipment date |
| `due_date` | INT* | Date | `silver.crm_sales_details.sls_due_dt` | Direct mapping | Due date |
| `sale_amount` | INT* | Measure | `silver.crm_sales_details.sls_sales` | Direct mapping | Sales amount |
| `quantity` | INT* | Measure | `silver.crm_sales_details.sls_quantity` | Direct mapping | Quantity sold |
| `price` | INT* | Measure | `silver.crm_sales_details.sls_price` | Direct mapping | Sales price |

---

# 8. Relationships

## 8.1 Customer Relationship

```text
gold.dim_customers.customer_key
              │
              │ 1 : many
              ▼
gold.fact_sales.customer_key
```

**Business interpretation:**

One customer can have many sales transactions.

---

## 8.2 Product Relationship

```text
gold.dim_products.product_key
              │
              │ 1 : many
              ▼
gold.fact_sales.product_key
```

**Business interpretation:**

One product can appear in many sales transactions.

---

# 9. Source-to-Target Lineage Matrix

| Gold Object | Gold Column | Source Object | Source Column | Transformation |
|---|---|---|---|---|
| `dim_customers` | `customer_key` | — | — | `ROW_NUMBER()` |
| `dim_customers` | `customer_id` | `crm_cust_info` | `cst_id` | Direct |
| `dim_customers` | `customer_number` | `crm_cust_info` | `cst_key` | Direct |
| `dim_customers` | `first_name` | `crm_cust_info` | `cst_firstname` | Direct |
| `dim_customers` | `last_name` | `crm_cust_info` | `cst_lastname` | Direct |
| `dim_customers` | `country` | `erp_loc_a101` | `cntry` | LEFT JOIN |
| `dim_customers` | `marital_status` | `crm_cust_info` | `cst_marital_status` | Direct |
| `dim_customers` | `gender` | CRM + ERP | `cst_gndr`, `gen` | CASE + COALESCE |
| `dim_customers` | `create_date` | `crm_cust_info` | `cst_create_date` | Direct |
| `dim_customers` | `birthate` | `erp_cust_az12` | `bdate` | LEFT JOIN |
| `dim_products` | `product_key` | — | — | `ROW_NUMBER()` |
| `dim_products` | `product_id` | `crm_prd_info` | `prd_id` | Direct |
| `dim_products` | `product_number` | `crm_prd_info` | `prd_key` | Direct |
| `dim_products` | `product_name` | `crm_prd_info` | `prd_nm` | Direct |
| `dim_products` | `category_id` | `crm_prd_info` | `cat_id` | Direct |
| `dim_products` | `category` | `erp_px_cat_g1v2` | `cat` | LEFT JOIN |
| `dim_products` | `subcategory` | `erp_px_cat_g1v2` | `subcat` | LEFT JOIN |
| `dim_products` | `maintenance` | `erp_px_cat_g1v2` | `maintenance` | LEFT JOIN |
| `dim_products` | `product_cost` | `crm_prd_info` | `prd_cost` | Direct |
| `dim_products` | `poduct_line` | `crm_prd_info` | `prd_line` | Direct |
| `dim_products` | `start_date` | `crm_prd_info` | `prd_start_dt` | Direct |
| `fact_sales` | `order_number` | `crm_sales_details` | `sls_ord_num` | Direct |
| `fact_sales` | `product_key` | `dim_products` | `product_key` | LEFT JOIN |
| `fact_sales` | `customer_key` | `dim_customers` | `customer_key` | LEFT JOIN |
| `fact_sales` | `order_date` | `crm_sales_details` | `sls_order_dt` | Direct |
| `fact_sales` | `ship_date` | `crm_sales_details` | `sls_ship_dt` | Direct |
| `fact_sales` | `due_date` | `crm_sales_details` | `sls_due_dt` | Direct |
| `fact_sales` | `sale_amount` | `crm_sales_details` | `sls_sales` | Direct |
| `fact_sales` | `quantity` | `crm_sales_details` | `sls_quantity` | Direct |
| `fact_sales` | `price` | `crm_sales_details` | `sls_price` | Direct |

---

# 10. Data Quality Rules

The following controls are recommended for this Gold model.

## 10.1 Customer surrogate-key uniqueness

```sql
SELECT
    customer_key,
    COUNT(*) AS record_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;
```

**Expected result:** 0 rows.

---

## 10.2 Product surrogate-key uniqueness

```sql
SELECT
    product_key,
    COUNT(*) AS record_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;
```

**Expected result:** 0 rows.

---

## 10.3 Fact-to-customer referential integrity

```sql
SELECT COUNT(*) AS unmatched_customer_records
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_customers AS dc
    ON fs.customer_key = dc.customer_key
WHERE dc.customer_key IS NULL;
```

**Expected result:** 0.

---

## 10.4 Fact-to-product referential integrity

```sql
SELECT COUNT(*) AS unmatched_product_records
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_products AS dp
    ON fs.product_key = dp.product_key
WHERE dp.product_key IS NULL;
```

**Expected result:** 0.

---

## 10.5 Gender domain validation

Review distinct values in:

```sql
SELECT DISTINCT gender
FROM gold.dim_customers
ORDER BY gender;
```

The approved business domain should be formally defined by the business/data owner.

---

# 11. Data Classification

The SQL reveals several types of information with different sensitivity levels.

| Data | Example columns | Suggested classification |
|---|---|---|
| Customer name | `first_name`, `last_name` | Internal / potentially personal data |
| Birth date | `birthate` | Personal data |
| Gender | `gender` | Personal / potentially sensitive depending on jurisdiction and policy |
| Country | `country` | Personal/contextual data |
| Customer identifier | `customer_id`, `customer_number` | Internal identifier |
| Sales amount | `sale_amount` | Business confidential |
| Product cost | `product_cost` | Business confidential |
| Product information | `product_name`, `category` | Internal/business data |
| Sales quantity | `quantity` | Business data |

**Recommendation:** Apply the organization's data-classification policy before exposing the Gold views broadly, particularly because customer attributes include personal data.

---

# 12. Business Glossary

| Term | Definition |
|---|---|
| Customer | An entity represented in the CRM customer source and integrated into the customer dimension |
| Customer Key | Gold-layer surrogate identifier for a customer |
| Customer Number | Source/business identifier associated with a customer |
| Product | A product represented in the CRM product source |
| Product Key | Gold-layer surrogate identifier for a product |
| Product Number | Source/business identifier associated with a product |
| Sales Fact | Analytical representation of sales transactions |
| Sale Amount | Sales monetary amount exposed by the source sales data |
| Quantity | Number of units sold |
| Product Category | High-level classification assigned to a product |
| Product Subcategory | More detailed product classification |
| Active Product | Product whose `prd_end_dt` is NULL according to the current SQL logic |
| Surrogate Key | Warehouse-generated key used independently from the operational business identifier |
| Dimension | Descriptive entity used to provide context to business events |
| Fact | Transaction/event-oriented dataset containing measurable business activity |

---

# 13. Known Data Model Risks / Review Items

## 13.1 Surrogate keys generated with `ROW_NUMBER()`

Both dimensions use:

```sql
ROW_NUMBER() OVER (...)
```

This generates a surrogate key at query execution time.

Because the objects are views, these keys are **not persistent physical identifiers**.

For a production dimensional warehouse, confirm whether the organization requires stable surrogate keys across refreshes and historical loads.

---

## 13.2 Potential duplicate rows from LEFT JOINs

The customer dimension joins:

```text
crm_cust_info
    → erp_cust_az12
    → erp_loc_a101
```

The product dimension joins:

```text
crm_prd_info
    → erp_px_cat_g1v2
```

The uniqueness/cardinality of these relationships should be tested.

For example:

```text
cst_key → cid
cat_id  → id
```

should normally be many-to-one from the business entity to the lookup/reference table.

---

## 13.3 Date data type in the fact

The Silver sales table currently exposes:

```text
sls_order_dt
sls_ship_dt
sls_due_dt
```

as `INT` according to the earlier Silver-layer definition.

The Gold view directly exposes those fields.

Therefore, the Gold fact currently does not explicitly convert them to `DATE`.

**Recommendation:** Confirm whether date conversion is intentionally performed upstream in the Silver layer.

---

## 13.4 Naming consistency

Two current Gold column names should be reviewed:

```text
birthate     → likely birth_date
poduct_line  → likely product_line
```

These should only be renamed after confirming that downstream reports, Power BI models, SQL queries, and other consumers will not be broken.

---

# 14. Recommended Data Ownership

A mature data environment should assign ownership to each domain.

| Domain | Suggested Owner |
|---|---|
| Customer master data | Customer/CRM Data Owner |
| Product master data | Product/Merchandising Data Owner |
| Sales transactions | Sales/Commercial Data Owner |
| Data transformation | Data Engineering |
| Analytical definitions | BI / Analytics |
| Data quality monitoring | Data Engineering + Data/Business Owners |
| Power BI semantic model | BI / Analytics |

The actual owners should be replaced with named teams or roles within the organization.

---

# 15. Recommended Consumption

The Gold views should be the preferred analytical interface for downstream users.

### Power BI

```text
Power BI
   │
   ├── gold.dim_customers
   ├── gold.dim_products
   └── gold.fact_sales
```

### SQL Analytics

Analysts can use the Gold layer for:

- Sales performance
- Customer analysis
- Product performance
- Category analysis
- Geographic analysis
- Revenue trends
- Quantity trends
- Customer/product segmentation

Example:

```sql
SELECT
    dp.category,
    SUM(fs.sale_amount) AS total_sales,
    SUM(fs.quantity) AS total_quantity
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_products AS dp
    ON fs.product_key = dp.product_key
GROUP BY
    dp.category;
```

---

# 16. Catalog Governance Recommendations

For a production-grade data catalog, add the following metadata over time:

| Metadata | Why it matters |
|---|---|
| Data Owner | Defines business accountability |
| Technical Owner | Defines engineering accountability |
| Refresh Frequency | Tells users how current the data is |
| SLA | Defines expected availability |
| Data Classification | Controls access and handling |
| Business Definition | Creates a common understanding |
| Source System | Establishes lineage |
| Transformation Logic | Explains how data changes |
| Data Quality Rules | Defines acceptable quality |
| Known Issues | Prevents incorrect interpretation |
| Downstream Consumers | Shows impact of changes |
| Last Successful Refresh | Shows data freshness |
| Deprecation Status | Prevents use of obsolete objects |

---

# 17. Senior-Level Summary

The current Gold layer implements a simple analytical star schema:

```text
                 CUSTOMER
                    │
                    │
                    ▼
               FACT SALES
                    ▲
                    │
                    │
                 PRODUCT
```

The three main analytical objects have clear responsibilities:

- **`gold.dim_customers`** → customer descriptive attributes
- **`gold.dim_products`** → active product descriptive attributes
- **`gold.fact_sales`** → sales events and measures

The model is suitable as a foundation for BI and business analytics, but before treating it as production-grade, the following areas should be formally validated:

1. **Dimension grain**
2. **Join cardinality**
3. **Surrogate-key stability**
4. **Fact grain**
5. **Date data types**
6. **Referential integrity**
7. **Data ownership**
8. **Business definitions**
9. **Data classification**
10. **Refresh/freshness requirements**

A strong Data Catalog is not merely documentation of column names. It establishes a shared contract between **business stakeholders, analysts, BI developers, data engineers, and data owners** about what the data means and how it should be used.
