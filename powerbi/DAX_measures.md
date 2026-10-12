# DAX Measures (15)

Model: `vw_sales_detail` → table **Sales**; `dim_date` → table **Date**.
Relationship: `Sales[sale_date]` (many) → `Date[date_key]` (one). Mark **Date** as a date table.

```DAX
-- Core
Total Revenue    = SUM ( Sales[net_revenue] )
Gross Revenue    = SUM ( Sales[gross_revenue] )
Total Units      = SUM ( Sales[units_sold] )
Total Orders     = DISTINCTCOUNT ( Sales[txn_id] )
Avg Order Value  = DIVIDE ( [Total Revenue], [Total Orders] )
Avg Discount %   = DIVIDE ( [Gross Revenue] - [Total Revenue], [Gross Revenue] )

-- Time intelligence
Revenue LY       = CALCULATE ( [Total Revenue], SAMEPERIODLASTYEAR ( 'Date'[date_key] ) )
YoY Growth       = [Total Revenue] - [Revenue LY]
YoY Growth %     = DIVIDE ( [YoY Growth], [Revenue LY] )
Revenue YTD      = TOTALYTD ( [Total Revenue], 'Date'[date_key] )
Revenue MoM %    =
VAR Prev = CALCULATE ( [Total Revenue], DATEADD ( 'Date'[date_key], -1, MONTH ) )
RETURN DIVIDE ( [Total Revenue] - Prev, Prev )

-- Share & ranking
Region Share %   = DIVIDE ( [Total Revenue], CALCULATE ( [Total Revenue], ALL ( Sales[region_name] ) ) )
Rep Rank         = RANKX ( ALL ( Sales[rep_name] ), [Total Revenue], , DESC, DENSE )
Top Category     = 
    VAR T = TOPN ( 1, ALL ( Sales[category] ), [Total Revenue], DESC )
    RETURN MAXX ( T, Sales[category] )

-- Dynamic KPI label (use in a card / tooltip)
YoY Label        = 
    VAR g = [YoY Growth %]
    RETURN IF ( ISBLANK ( g ), "n/a", IF ( g >= 0, "▲ ", "▼ " ) & FORMAT ( ABS ( g ), "0.0%" ) )
```

**Conditional-format rule:** font colour on YoY cards → rules based on `YoY Growth %` (≥0 green, <0 red).
