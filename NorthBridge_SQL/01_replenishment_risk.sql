/*
NorthBridge Distribution
Q1: Replenishment Risk Analysis

Business Question:
Which SKUs are projected to stock out before replenishment can arrive?

Purpose:
Compare available inventory and forecast demand against supplier
lead times to identify SKUs requiring priority replenishment.
*/

SELECT
    w.Week_Start_Date,
    p.SKU_ID,
    s.Standard_Lead_Time_Days,

    -- Available inventory after allocations
    SUM(i.Stock_On_Hand - i.Allocated_Qty) AS Current_SOH,

    -- Current forecast demand
    SUM(w.Demand_Forecast) AS Total_Forecast,

    -- Weeks of Cover
    SUM(i.Stock_On_Hand - i.Allocated_Qty) * 1.0
        / NULLIF(SUM(w.Demand_Forecast), 0) AS WOC,

    -- Supplier lead time converted to weeks
    AVG(s.Standard_Lead_Time_Days) / 7.0 AS Lead_Time_Weeks,

    -- Forecast demand during supplier lead time
    SUM(w.Demand_Forecast)
        * AVG(s.Standard_Lead_Time_Days) / 7.0 AS Lead_Time_Demand,

    -- Projected shortage before replenishment arrives
    SUM(w.Demand_Forecast)
        * AVG(s.Standard_Lead_Time_Days) / 7.0
        - SUM(i.Stock_On_Hand - i.Allocated_Qty)
        AS Projected_Shortage_Qty,

    -- Potential revenue exposed to projected shortage
    (
        SUM(w.Demand_Forecast)
        * AVG(s.Standard_Lead_Time_Days) / 7.0
        - SUM(i.Stock_On_Hand - i.Allocated_Qty)
    ) * MAX(p.Unit_Price) AS Potential_Revenue_Risk,

    -- Stockout risk classification
    CASE
        WHEN SUM(i.Stock_On_Hand - i.Allocated_Qty) * 1.0
             / NULLIF(SUM(w.Demand_Forecast), 0)
             < AVG(s.Standard_Lead_Time_Days) / 7.0
        THEN 'Stockout Risk'
        ELSE 'Safe Stock'
    END AS Stockout_Risk

FROM products p

LEFT JOIN inventory_snapshots i
    ON p.SKU_ID = i.SKU_ID

JOIN weekly_demand w
    ON i.SKU_ID = w.SKU_ID
    AND i.Warehouse_ID = w.Warehouse_ID

JOIN suppliers s
    ON p.Primary_Supplier_ID = s.Supplier_ID

WHERE i.Snapshot_Date = (
    SELECT MAX(Snapshot_Date)
    FROM inventory_snapshots
)

AND w.Week_Start_Date = (
    SELECT MAX(Week_Start_Date)
    FROM weekly_demand
)

GROUP BY
    w.Week_Start_Date,
    s.Standard_Lead_Time_Days,
    p.SKU_ID

HAVING
    SUM(i.Stock_On_Hand - i.Allocated_Qty) * 1.0
    / NULLIF(SUM(w.Demand_Forecast), 0)
    < AVG(s.Standard_Lead_Time_Days) / 7.0

ORDER BY Projected_Shortage_Qty DESC;
