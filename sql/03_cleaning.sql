-- 03_cleaning.sql
-- Cleans stg_sales_raw and loads fact_sales. Also logs what was rejected.

USE pharma_sales;

-- ---------- 1. Profile the dirt (run these to document issues found) ----------
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT txn_id) AS distinct_txn,
       COUNT(*) - COUNT(DISTINCT txn_id)               AS duplicate_rows,
       SUM(units_sold = '' OR units_sold IS NULL)      AS missing_units,
       SUM(CAST(NULLIF(units_sold,'') AS SIGNED) < 0)  AS negative_units,
       SUM(unit_price = '')                            AS missing_price,
       SUM(discount_pct = '')                          AS missing_discount,
       SUM(sale_date LIKE '%/%')                       AS dd_mm_yyyy_dates,
       SUM(region <> TRIM(region) OR region <> CONCAT(UPPER(LEFT(TRIM(region),1)), LOWER(SUBSTRING(TRIM(region),2)))) AS messy_region_text
FROM stg_sales_raw;

-- ---------- 2. Cleaned view: standardise text, parse dates, impute price/discount ----------
CREATE OR REPLACE VIEW v_sales_cleaned AS
WITH parsed AS (
    SELECT
        TRIM(s.txn_id)                                           AS txn_id,
        CASE WHEN TRIM(s.sale_date) LIKE '%/%'                   -- dd/mm/yyyy
             THEN STR_TO_DATE(TRIM(s.sale_date), '%d/%m/%Y')
             ELSE STR_TO_DATE(TRIM(s.sale_date), '%Y-%m-%d')     -- yyyy-mm-dd
        END                                                      AS sale_date,
        r.region_id,
        d.drug_id,
        p.rep_id,
        CAST(NULLIF(TRIM(s.units_sold), '') AS SIGNED)           AS units_sold,
        COALESCE(CAST(NULLIF(TRIM(s.unit_price), '') AS DECIMAL(10,2)), d.unit_price) AS unit_price,
        COALESCE(CAST(NULLIF(TRIM(s.discount_pct), '') AS DECIMAL(5,2)), 0)           AS discount_pct,
        ROW_NUMBER() OVER (PARTITION BY TRIM(s.txn_id) ORDER BY s.sale_date) AS rn
    FROM stg_sales_raw s
    LEFT JOIN dim_region r ON LOWER(TRIM(s.region))    = LOWER(r.region_name)
    LEFT JOIN dim_drug   d ON LOWER(TRIM(s.drug_name)) = LOWER(d.drug_name)
    LEFT JOIN dim_rep    p ON LOWER(TRIM(s.rep_name))  = LOWER(p.rep_name)
)
SELECT txn_id, sale_date, region_id, drug_id, rep_id, units_sold, unit_price, discount_pct
FROM parsed
WHERE rn = 1                      -- drop duplicates
  AND sale_date  IS NOT NULL
  AND region_id  IS NOT NULL
  AND drug_id    IS NOT NULL
  AND rep_id     IS NOT NULL
  AND units_sold IS NOT NULL
  AND units_sold > 0;             -- drop missing / negative units

-- ---------- 3. Load fact table ----------
TRUNCATE TABLE fact_sales;

INSERT INTO fact_sales (txn_id, sale_date, region_id, drug_id, rep_id, units_sold, unit_price, discount_pct)
SELECT txn_id, sale_date, region_id, drug_id, rep_id, units_sold, unit_price, discount_pct
FROM v_sales_cleaned;

-- ---------- 4. Reconciliation ----------
SELECT (SELECT COUNT(*) FROM stg_sales_raw) AS raw_rows,
       (SELECT COUNT(*) FROM fact_sales)    AS clean_rows,
       (SELECT COUNT(*) FROM stg_sales_raw) - (SELECT COUNT(*) FROM fact_sales) AS rows_removed;

-- ---------- 5. Rejected rows for audit ----------
-- Rows whose txn_id never made it into fact_sales (missing/negative units, unmatched keys).
-- Exact duplicates are not listed here: their txn_id is already in fact_sales via the kept copy.
CREATE OR REPLACE VIEW v_sales_rejected AS
SELECT s.*
FROM stg_sales_raw s
LEFT JOIN fact_sales f ON f.txn_id = TRIM(s.txn_id)
WHERE f.txn_id IS NULL;
