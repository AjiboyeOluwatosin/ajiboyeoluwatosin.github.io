/*
NorthBridge Distribution
Q2: Excess & Slow-Moving Inventory Analysis

Business Question:
Where is too much cash tied up in excess or slow-moving inventory,
and how much can we safely reduce?

Purpose:
Use historical inventory turnover and current weeks of cover to identify
SKUs carrying more inventory than comparable products within their
category, then quantify the value of potential excess stock.
*/

WITH Historical AS (
    SELECT
        wd.Week_Start_Date,
        ps.SKU_ID,
        ps.Category,

        -- Historical cost of goods sold
        SUM(wd.Units_Sold * ps.Unit_Cost) AS COGS,

        -- Historical inventory value
        SUM(i.Stock_On_Hand * ps.Unit_Cost) AS Inventory_Value

    FROM weekly_demand wd

    JOIN products ps
        ON wd.SKU_ID = ps.SKU_ID

    JOIN inventory_snapshots i
        ON i.SKU_ID = ps.SKU_ID
        AND i.Warehouse_ID = wd.Warehouse_ID
        AND i.Snapshot_Date = wd.Week_Start_Date

    -- Use the latest 52 weeks of history
    WHERE wd.Week_Start_Date >= DATEADD(
        WEEK,
        -51,
        (SELECT MAX(Week_Start_Date) FROM weekly_demand)
    )

    AND i.Snapshot_Date >= DATEADD(
        WEEK,
        -51,
        (SELECT MAX(Snapshot_Date) FROM inventory_snapshots)
    )

    GROUP BY
        wd.Week_Start_Date,
        ps.Category,
        ps.SKU_ID
),

Currently AS (
    SELECT
        i.Snapshot_Date,
        ps.Category,
        ps.SKU_ID,
        MAX(ps.Unit_Cost) AS Unit_Cost,

        -- Current available stock after allocations
        SUM(i.Stock_On_Hand - i.Allocated_Qty)
            AS Current_Available_Stock,

        -- Current forecast demand
        SUM(wd.Demand_Forecast)
            AS Current_Demand,

        -- Current Weeks of Cover
        SUM(i.Stock_On_Hand - i.Allocated_Qty) * 1.0
            / NULLIF(SUM(wd.Demand_Forecast), 0)
            AS Current_WOC,

        -- Current inventory value
        ROUND(
            SUM(ps.Unit_Cost * i.Stock_On_Hand),
            2
        ) AS Current_Inventory_Value

    FROM inventory_snapshots i

    JOIN products ps
        ON i.SKU_ID = ps.SKU_ID

    JOIN weekly_demand wd
        ON ps.SKU_ID = wd.SKU_ID
        AND i.Warehouse_ID = wd.Warehouse_ID

    WHERE i.Snapshot_Date = (
        SELECT MAX(Snapshot_Date)
        FROM inventory_snapshots
    )

    AND wd.Week_Start_Date = (
        SELECT MAX(Week_Start_Date)
        FROM weekly_demand
    )

    GROUP BY
        i.Snapshot_Date,
        ps.Category,
        ps.SKU_ID
),

SKU_Turnover AS (
    SELECT
        c.SKU_ID,
        c.Category,
        c.Current_Available_Stock,
        c.Current_Demand,
        c.Unit_Cost,
        c.Current_WOC,

        ROUND(SUM(h.COGS), 2)
            AS Total_COGS,

        ROUND(AVG(h.Inventory_Value), 2)
            AS Avg_Inventory_Value,

        -- Inventory turnover for each SKU
        ROUND(
            SUM(h.COGS)
            / NULLIF(AVG(h.Inventory_Value), 0),
            2
        ) AS SKU_Inventory_Turnover

    FROM Currently c

    JOIN Historical h
        ON c.SKU_ID = h.SKU_ID

    GROUP BY
        c.SKU_ID,
        c.Category,
        c.Current_Available_Stock,
        c.Current_Demand,
        c.Unit_Cost,
        c.Current_WOC
),

Excess_Analysis AS (
    SELECT
        SKU_ID,
        Category,
        Total_COGS,
        SKU_Inventory_Turnover,

        -- Compare SKU turnover with category benchmark
        AVG(SKU_Inventory_Turnover)
            OVER (PARTITION BY Category)
            AS Category_Turnover,

        Current_WOC,

        -- Category benchmark for Weeks of Cover
        AVG(Current_WOC)
            OVER (PARTITION BY Category)
            AS Category_WOC,

        -- Flag low-turnover SKUs carrying above-average stock cover
        CASE
            WHEN SKU_Inventory_Turnover <
                 AVG(SKU_Inventory_Turnover)
                 OVER (PARTITION BY Category)

             AND Current_WOC >
                 AVG(Current_WOC)
                 OVER (PARTITION BY Category)

            THEN 'Slow Moving'
            ELSE 'Healthy'
        END AS Slow_Moving_Status,

        -- Target inventory based on category-average WOC
        Current_Demand *
            AVG(Current_WOC)
            OVER (PARTITION BY Category)
            AS Target_Stock_Qty,

        Current_Available_Stock,

        -- Stock held above the category benchmark
        CASE
            WHEN Current_Available_Stock -
                (
                    Current_Demand *
                    AVG(Current_WOC)
                    OVER (PARTITION BY Category)
                ) > 0

            THEN Current_Available_Stock -
                (
                    Current_Demand *
                    AVG(Current_WOC)
                    OVER (PARTITION BY Category)
                )

            ELSE 0
        END AS Excess_Stock_Qty,

        Unit_Cost

    FROM SKU_Turnover
)

SELECT
    *,

    -- Estimated cash tied up in excess inventory
    Excess_Stock_Qty * Unit_Cost AS Excess_Stock_Value

FROM Excess_Analysis

WHERE Excess_Stock_Qty > 0

ORDER BY Excess_Stock_Value DESC;
