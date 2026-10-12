-- 04_analysis_queries.sql  |  Business questions answered in SQL
USE pharma_sales;

-- Q1. Revenue by region
SELECT r.region_name,
       SUM(f.net_revenue)                                              AS net_revenue,
       SUM(f.units_sold)                                               AS units,
       ROUND(100 * SUM(f.net_revenue) / SUM(SUM(f.net_revenue)) OVER (), 2) AS pct_of_total
FROM fact_sales f JOIN dim_region r USING (region_id)
GROUP BY r.region_name
ORDER BY net_revenue DESC;

-- Q2. Revenue and units by drug category
SELECT d.category,
       SUM(f.net_revenue) AS net_revenue,
       SUM(f.units_sold)  AS units,
       ROUND(AVG(f.discount_pct), 2) AS avg_discount_pct
FROM fact_sales f JOIN dim_drug d USING (drug_id)
GROUP BY d.category
ORDER BY net_revenue DESC;

-- Q3. Sales rep leaderboard with rank inside their region
SELECT r.region_name, p.rep_name,
       SUM(f.net_revenue) AS net_revenue,
       RANK() OVER (PARTITION BY r.region_name ORDER BY SUM(f.net_revenue) DESC) AS rank_in_region,
       RANK() OVER (ORDER BY SUM(f.net_revenue) DESC)                            AS overall_rank
FROM fact_sales f
JOIN dim_rep p    USING (rep_id)
JOIN dim_region r ON r.region_id = f.region_id
GROUP BY r.region_name, p.rep_name
ORDER BY overall_rank;

-- Q4. Monthly revenue trend with MoM growth
WITH monthly AS (
    SELECT DATE_FORMAT(sale_date, '%Y-%m-01') AS month_start,
           SUM(net_revenue) AS revenue
    FROM fact_sales GROUP BY month_start
)
SELECT month_start, revenue,
       LAG(revenue) OVER (ORDER BY month_start) AS prev_month,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month_start))
             / LAG(revenue) OVER (ORDER BY month_start), 2) AS mom_growth_pct
FROM monthly ORDER BY month_start;

-- Q5. Year-over-year growth by region
WITH yearly AS (
    SELECT region_id, YEAR(sale_date) AS yr, SUM(net_revenue) AS revenue
    FROM fact_sales GROUP BY region_id, yr
)
SELECT r.region_name, y.yr, y.revenue,
       LAG(y.revenue) OVER (PARTITION BY y.region_id ORDER BY y.yr) AS prev_year_revenue,
       ROUND(100 * (y.revenue - LAG(y.revenue) OVER (PARTITION BY y.region_id ORDER BY y.yr))
             / LAG(y.revenue) OVER (PARTITION BY y.region_id ORDER BY y.yr), 2) AS yoy_growth_pct
FROM yearly y JOIN dim_region r USING (region_id)
ORDER BY r.region_name, y.yr;

-- Q6. Top 3 drugs per category by revenue
SELECT * FROM (
    SELECT d.category, d.drug_name, SUM(f.net_revenue) AS net_revenue,
           DENSE_RANK() OVER (PARTITION BY d.category ORDER BY SUM(f.net_revenue) DESC) AS rnk
    FROM fact_sales f JOIN dim_drug d USING (drug_id)
    GROUP BY d.category, d.drug_name
) t WHERE rnk <= 3 ORDER BY category, rnk;

-- Q7. Running (cumulative) revenue per year
SELECT YEAR(sale_date) AS yr, DATE_FORMAT(sale_date, '%Y-%m') AS ym,
       SUM(net_revenue) AS monthly_revenue,
       SUM(SUM(net_revenue)) OVER (PARTITION BY yr ORDER BY ym) AS ytd_revenue
FROM fact_sales GROUP BY yr, ym ORDER BY ym;

-- Q8. Seasonality: category x month heatmap data
SELECT d.category, MONTH(f.sale_date) AS month_no, SUM(f.units_sold) AS units
FROM fact_sales f JOIN dim_drug d USING (drug_id)
GROUP BY d.category, month_no ORDER BY d.category, month_no;

-- Q9. Discount impact: do deeper discounts drive bigger orders?
SELECT discount_pct, COUNT(*) AS orders, ROUND(AVG(units_sold), 1) AS avg_units,
       ROUND(AVG(net_revenue), 2) AS avg_order_value
FROM fact_sales GROUP BY discount_pct ORDER BY discount_pct;

-- Q10. Reps below their region's average revenue (coaching list)
WITH rep_rev AS (
    SELECT f.region_id, f.rep_id, SUM(f.net_revenue) AS rev
    FROM fact_sales f GROUP BY f.region_id, f.rep_id
),
scored AS (
    SELECT rr.region_id, rr.rep_id, rr.rev,
           AVG(rr.rev) OVER (PARTITION BY rr.region_id) AS region_avg
    FROM rep_rev rr
)
SELECT r.region_name, p.rep_name, ROUND(sc.rev, 2) AS rev, ROUND(sc.region_avg, 2) AS region_avg,
       ROUND(100 * (sc.rev - sc.region_avg) / sc.region_avg, 1) AS pct_vs_region_avg
FROM scored sc
JOIN dim_rep p    ON p.rep_id    = sc.rep_id
JOIN dim_region r ON r.region_id = sc.region_id
WHERE sc.rev < sc.region_avg
ORDER BY r.region_name, pct_vs_region_avg;
