-- 05_powerbi_views.sql
-- Views Power BI connects to (MySQL connector) or that you export to CSV.
USE pharma_sales;

-- Calendar dimension (needed for time intelligence / YoY in DAX)
DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date (
    date_key     DATE PRIMARY KEY,
    year_no      INT,
    quarter_no   INT,
    month_no     INT,
    month_name   VARCHAR(10),
    year_mon     CHAR(7),
    day_of_week  VARCHAR(10)
);

-- Calendar 2023-01-01 .. 2025-12-31, built from a digits cross join
-- (portable: no recursive CTE, so no recursion-depth limit to worry about)
INSERT INTO dim_date
SELECT d, YEAR(d), QUARTER(d), MONTH(d), MONTHNAME(d), DATE_FORMAT(d, '%Y-%m'), DAYNAME(d)
FROM (
    SELECT DATE('2023-01-01') + INTERVAL (a.n + 10*b.n + 100*c.n + 1000*e.n) DAY AS d
    FROM (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
          UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
    CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
          UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
    CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
          UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
    CROSS JOIN (SELECT 0 n UNION ALL SELECT 1) e
) t
WHERE d <= '2025-12-31';

-- Flat, report-ready fact view
CREATE OR REPLACE VIEW vw_sales_detail AS
SELECT f.sale_id, f.txn_id, f.sale_date,
       r.region_name, d.drug_name, d.category, p.rep_name,
       f.units_sold, f.unit_price, f.discount_pct,
       f.gross_revenue, f.net_revenue
FROM fact_sales f
JOIN dim_region r ON r.region_id = f.region_id
JOIN dim_drug   d ON d.drug_id   = f.drug_id
JOIN dim_rep    p ON p.rep_id    = f.rep_id;

-- Pre-aggregated monthly view (fast visuals)
CREATE OR REPLACE VIEW vw_monthly_region_category AS
SELECT DATE_FORMAT(sale_date, '%Y-%m-01') AS month_start,
       region_name, category,
       SUM(units_sold) AS units, SUM(net_revenue) AS net_revenue, COUNT(*) AS orders
FROM vw_sales_detail
GROUP BY month_start, region_name, category;
