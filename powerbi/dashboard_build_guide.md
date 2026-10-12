# Building the Power BI Dashboard (step by step)

## 1. Connect
**Option A (MySQL):** Get Data → MySQL database → server `localhost`, DB `pharma_sales` → import `vw_sales_detail` and `dim_date`. (Install MySQL Connector/NET if prompted.)
**Option B (no MySQL driver):** In MySQL Workbench, export `vw_sales_detail` and `dim_date` to CSV → Get Data → Text/CSV.

Rename queries to **Sales** and **Date**. Set `sale_date` / `date_key` to Date type.

## 2. Model
- Relationship: Sales[sale_date] → Date[date_key] (many-to-one, single direction).
- Date table → *Mark as date table* → `date_key`.
- Sort `Date[month_name]` by `Date[month_no]`.
- Paste measures from `DAX_measures.md` into a table called `_Measures`.

## 3. Page 1 – Executive Overview
| Visual | Fields |
|---|---|
| KPI cards (×5) | Total Revenue, Total Units, Total Orders, Avg Order Value, YoY Growth % (+ YoY Label) |
| Line chart | Axis `Date[year_mon]`; values Total Revenue, Revenue LY |
| Clustered bar | Axis region_name; value Total Revenue; tooltip Region Share % |
| Donut | Legend category; value Total Revenue |
| Slicers | Year, Region, Category |

## 4. Page 2 – Regional YoY
- Matrix: rows region_name → expand to category; columns `Date[year_no]`; values Total Revenue, YoY Growth %.
- Conditional formatting on YoY Growth % (green/red).
- Clustered column: Revenue YTD by month, legend year.

## 5. Page 3 – Sales Rep Performance
- Table: rep_name, Total Revenue, Rep Rank, Avg Discount %, Total Orders.
- Top N filter (10) on rep_name by Total Revenue.
- Scatter: x = Avg Discount %, y = Avg Order Value, size = Total Revenue.

## 6. Page 4 – Drug Detail (drill-through target)
1. Create page "Drug Detail".
2. Drag `Sales[drug_name]` into **Drill through → Add drill-through fields here**.
3. Add: card Total Revenue, line chart (month trend), table by region, YoY Growth %.
4. On Pages 1–3, right-click any category/drug bar → **Drill through → Drug Detail**.
Also add a drill-through on `region_name` → "Region Detail" for the second drill-through filter.

## 7. Finish
- Theme: View → Themes (pick one consistent palette), consistent fonts, align via Format → Align.
- Add a Back button on drill-through pages (Insert → Buttons → Back).
- Save as `powerbi/Pharma_Sales_Dashboard.pbix`.
- Export 3–4 screenshots (File → Export → PDF, or Win+Shift+S) into `powerbi/screenshots/` for the README.
