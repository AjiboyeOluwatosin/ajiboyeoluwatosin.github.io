/*
NorthBridge Distribution
Q3: Supplier Performance & Supply Risk Analysis

Business Question:
Which suppliers are creating the greatest supply risk based on
historical delivery performance and current outstanding purchase orders?

Purpose:
Compare supplier delivery reliability against service targets and combine
this with current outstanding PO exposure to identify suppliers requiring
closer attention.
*/

WITH Historical_Supplier_Performance AS (
    SELECT
        s.Supplier_ID,
        s.Supplier_Name,

        -- Total deliveries during the last 52 weeks
        COUNT(d.Delivery_ID) AS Total_Deliveries,

        -- Number of deliveries received on time
        COUNT(
            CASE
                WHEN d.Actual_Delivery_Date <= d.Promised_Delivery_Date
                THEN d.Delivery_ID
            END
        ) AS On_Time_Deliveries,

        -- On-Time Delivery Rate
        ROUND(
            COUNT(
                CASE
                    WHEN d.Actual_Delivery_Date <= d.Promised_Delivery_Date
                    THEN d.Delivery_ID
                END
            ) * 1.0
            / NULLIF(COUNT(d.Delivery_ID), 0) * 100,
            2
        ) AS OTD_Rate,

        -- Supplier OTD target
        MAX(s.Target_On_Time_Rate) * 100
            AS Target_OTD_Rate,

        -- Total quantity ordered and received
        SUM(d.Ordered_Qty)
            AS Delivery_Total_Orders,

        SUM(d.Received_Qty)
            AS Received_Orders,

        -- Fill Rate
        ROUND(
            SUM(d.Received_Qty) * 1.0
            / NULLIF(SUM(d.Ordered_Qty), 0) * 100,
            2
        ) AS Fill_Rate,

        -- Supplier Fill Rate target
        MAX(s.Target_Fill_Rate) * 100
            AS Target_Fill_Rate,

        -- Average delay for late deliveries
        AVG(
            CASE
                WHEN d.Delay_Days > 0
                THEN d.Delay_Days
            END
        ) AS Avg_Delay_Days,

        -- Standard supplier lead time
        MAX(s.Standard_Lead_Time_Days)
            AS Supplier_Lead_Time

    FROM suppliers s

    JOIN deliveries d
        ON s.Supplier_ID = d.Supplier_ID

    WHERE d.Actual_Delivery_Date >= DATEADD(
        WEEK,
        -52,
        (SELECT MAX(Actual_Delivery_Date)
         FROM deliveries)
    )

    GROUP BY
        s.Supplier_ID,
        s.Supplier_Name
),

Current_Supplier_Exposure AS (
    SELECT
        ps.Supplier_ID,

        -- Current open / partially received purchase orders
        COUNT(DISTINCT ps.PO_ID)
            AS Purchase_Order_Count,

        SUM(pl.Ordered_Qty)
            AS Purchase_Total_Order,

        SUM(pl.Received_Qty)
            AS Total_Received,

        -- Quantity still outstanding
        SUM(pl.Outstanding_Qty)
            AS Total_Outstanding,

        -- Financial value currently outstanding
        SUM(pl.Outstanding_Qty * pl.Unit_Cost)
            AS Outstanding_PO_Value

    FROM po_lines pl

    JOIN purchase_orders ps
        ON pl.PO_ID = ps.PO_ID

    WHERE ps.PO_Status IN (
        'open',
        'partially received'
    )

    GROUP BY
        ps.Supplier_ID
)

SELECT
    hs.Supplier_ID,
    hs.Supplier_Name,

    hs.OTD_Rate,
    hs.Target_OTD_Rate,

    hs.Fill_Rate,
    hs.Target_Fill_Rate,

    hs.Avg_Delay_Days,

    cs.Total_Received,
    cs.Total_Outstanding,
    cs.Outstanding_PO_Value,

    hs.Supplier_Lead_Time

FROM Historical_Supplier_Performance hs

JOIN Current_Supplier_Exposure cs
    ON hs.Supplier_ID = cs.Supplier_ID

ORDER BY
    cs.Outstanding_PO_Value DESC;
