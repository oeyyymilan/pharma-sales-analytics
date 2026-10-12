-- 02_load_data.sql
-- Run from the repo root so relative paths resolve, using:
--   mysql --local-infile=1 -u root -p < sql/02_load_data.sql
-- The column lists below strip a trailing \r so CRLF (Windows) and LF files both load.
-- (If LOAD DATA is blocked: SET GLOBAL local_infile = 1; as admin, or use
--  MySQL Workbench's Table Data Import Wizard on the same CSVs.)

USE pharma_sales;

LOAD DATA LOCAL INFILE 'data/raw/dim_region.csv'
INTO TABLE dim_region
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(region_id, @name) SET region_name = TRIM(TRAILING '\r' FROM @name);

LOAD DATA LOCAL INFILE 'data/raw/dim_drug.csv'
INTO TABLE dim_drug
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(drug_id, drug_name, category, @price) SET unit_price = TRIM(TRAILING '\r' FROM @price);

LOAD DATA LOCAL INFILE 'data/raw/dim_rep.csv'
INTO TABLE dim_rep
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(rep_id, rep_name, @rid) SET region_id = TRIM(TRAILING '\r' FROM @rid);

LOAD DATA LOCAL INFILE 'data/raw/sales_raw.csv'
INTO TABLE stg_sales_raw
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(txn_id, sale_date, region, drug_name, rep_name, units_sold, unit_price, @disc)
SET discount_pct = TRIM(TRAILING '\r' FROM @disc);

SELECT 'stg_sales_raw rows' AS check_name, COUNT(*) AS n FROM stg_sales_raw;
