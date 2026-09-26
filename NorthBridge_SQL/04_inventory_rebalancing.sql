/*
NorthBridge Distribution
Q4: Inventory Rebalancing Analysis

Business Question:
Is inventory in the wrong place, and can we rebalance it
instead of buying more?

Purpose:
Identify warehouses with SKU shortages while the same SKU has
excess inventory elsewhere in the network, then calculate how
much of the shortage could potentially be covered through
internal stock rebalancing.
*/

SELECT
    Warehouse_ID,
    SKU_ID,
    Demand_Shortage,
    Total_SKU_Excess,
    Transferable_Qty

FROM (
    SELECT
        Warehouse_ID,
        SKU_ID,
        Demand_Shortage,
        Excess_Stock,

        -- Total excess inventory for this SKU across all warehouses
        SUM(Excess_Stock)
            OVER (PARTITION BY SKU_ID) AS Total_SKU_Excess,

        -- Transfer the smaller of the shortage or available network excess
        CASE
            WHEN Demand_Shortage <
                 SUM(Excess_Stock) OVER (PARTITION BY SKU_ID)
            THEN Demand_Shortage

            ELSE SUM(Excess_Stock)
                 OVER (PARTITION BY SKU_ID)
        END AS Transferable_Qty

    FROM (
        SELECT
            i.Warehouse_ID,
            i.SKU_ID,

            -- Available inventory after allocations
            SUM(i.Stock_On_Hand - i.Allocated_Qty)
                AS Available_Stock,

            -- Current forecast demand
            SUM(wd.Demand_Forecast)
                AS Weekly_Demand,

            -- Shortage where demand exceeds available stock
            CASE
                WHEN SUM(wd.Demand_Forecast)
                     - SUM(i.Stock_On_Hand - i.Allocated_Qty) > 0

                THEN SUM(wd.Demand_Forecast)
                     - SUM(i.Stock_On_Hand - i.Allocated_Qty)

                ELSE 0
            END AS Demand_Shortage,

            -- Excess where available stock exceeds demand
            CASE
                WHEN SUM(i.Stock_On_Hand - i.Allocated_Qty)
                     - SUM(wd.Demand_Forecast) > 0

                THEN SUM(i.Stock_On_Hand - i.Allocated_Qty)
                     - SUM(wd.Demand_Forecast)

                ELSE 0
            END AS Excess_Stock

        FROM inventory_snapshots i

        JOIN weekly_demand wd
            ON i.SKU_ID = wd.SKU_ID
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
            i.Warehouse_ID,
            i.SKU_ID

    ) t

) q

-- Only return locations currently experiencing a shortage
WHERE Demand_Shortage > 0

ORDER BY
    Warehouse_ID,
    SKU_ID;
