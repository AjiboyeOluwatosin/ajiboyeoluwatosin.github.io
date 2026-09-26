# NorthBridge Distribution — SQL Analysis

## Project Overview

This SQL analysis forms part of the NorthBridge Distribution Supply Chain Planning & Inventory Risk project.

The analysis investigates inventory availability, forecast demand, supplier performance and stock positioning to identify operational risks and support replenishment and inventory planning decisions.

## Business Questions

### 1. Which SKUs are projected to stock out before replenishment can arrive?
**File:** `01_replenishment_risk.sql`

Analyses current available stock, forecast demand and supplier lead times to calculate weeks of cover, projected shortage quantities and potential revenue at risk.

### 2. Where is too much cash tied up in excess or slow-moving inventory, and how much can we safely reduce?
**File:** `02_excess_inventory_analysis.sql`

Uses inventory value, demand, weeks of cover and inventory turnover to identify slow-moving SKUs and quantify excess inventory value.

### 3. Which suppliers are creating the greatest supply risk?
**File:** `03_supplier_performance.sql`

Evaluates historical supplier delivery performance alongside current purchase-order exposure using measures including on-time delivery, fill rate, delivery delays and outstanding PO value.

### 4. Is inventory in the wrong place and can we rebalance it instead of buying more?
**File:** `04_inventory_rebalancing.sql`

Compares demand shortages and excess stock across warehouse locations to identify quantities that could potentially be rebalanced between locations before additional inventory is purchased.

> The analysis identifies potential transferable quantities at SKU level; it does not assign specific source-to-destination warehouse transfers.

## SQL Techniques Used

- Common Table Expressions (CTEs)
- Joins
- Aggregations
- Window functions
- CASE expressions
- Subqueries
- NULL handling
- Business-rule calculations

## Tools

**Microsoft SQL Server | Excel | Power BI**

## Project Outputs

The SQL analysis supports the wider NorthBridge project, which includes:

- Supply Chain Planning & Inventory Risk Analysis Report
- Power BI Inventory Risk Dashboard
- SQL analysis and business-question investigation
