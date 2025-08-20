-- ====================================================================================
-- Project: Falcon Models - Sales & Customers Analysis
-- File: Analysis-queries.sql [By Kashish Pal]
-- Description: This file contains SQL queries used for 
-- credit & payment analysis, customer segmentation, and 
-- business insights for the Falcon Models dataset.
-- ====================================================================================

-- Overview of Queries:
-- • Joined multiple tables (customers, orders, payments, products) for integrated analysis  
-- • Created new columns for sales, profit, payment gaps, and payment performance  
-- • Assessed customer credit risk based on credit limits and payment behavior  
-- • Built customer scores using sales, profit, and payment gap metrics  
-- • Segmented customers into tiers (VIP, Premium, Regular) for business insights  

-- ====================================================================================
-- SQL Queries Start Below
-- ====================================================================================

-- 🔹 Sales Data CTE (include all customers even without orders)
WITH sales_data AS (
    SELECT 
        c.customerNumber,
        c.customerName,
        c.country,
        c.creditLimit,
        c.salesRepEmployeeNumber,
        COALESCE(SUM(od.priceEach * od.quantityOrdered), 0) AS sales,
        COALESCE(SUM(p.buyPrice * od.quantityOrdered), 0) AS totalBuyPrice,
        COALESCE(SUM((od.priceEach - p.buyPrice) * od.quantityOrdered), 0) AS profit
    FROM customers c
    LEFT JOIN orders o ON c.customerNumber = o.customerNumber
    LEFT JOIN orderdetails od ON o.orderNumber = od.orderNumber
    LEFT JOIN products p ON od.productCode = p.productCode
    GROUP BY c.customerNumber
),

-- 🔹 Payment Data CTE
payment_data AS (
    SELECT 
        customerNumber,
        SUM(amount) AS payment
    FROM payments
    GROUP BY customerNumber
),

-- 🔹 Base Data with Calculations
base_data AS (
    SELECT 
        s.customerNumber,
        s.customerName,
        s.country,
        s.creditLimit,
        s.salesRepEmployeeNumber,
        s.sales,
        s.totalBuyPrice,
        s.profit,
        COALESCE(p.payment, 0) AS payment,
        (s.sales - COALESCE(p.payment, 0)) AS payment_gap,

        CASE 
            WHEN s.sales = 0 THEN 0
            ELSE ROUND(COALESCE(p.payment, 0) / s.sales, 2) * 100
        END AS payment_performance_ratio,
        
        CASE
            WHEN s.sales = 0 THEN 'No Sales'
            WHEN ROUND(COALESCE(p.payment, 0) / s.sales, 2) * 100 BETWEEN 95 AND 100 THEN 'On time - Reliable'
            WHEN ROUND(COALESCE(p.payment, 0) / s.sales, 2) * 100 BETWEEN 75 AND 94.99 THEN 'Delayed - Monitor'
            ELSE 'Risk-Prone'
        END AS payment_performance_status,
        
        CASE 
            WHEN s.creditLimit IS NULL OR s.creditLimit = 0 THEN 'No Credit Limit'
            WHEN (s.sales - COALESCE(p.payment, 0)) > s.creditLimit THEN 'Over Credit Limit'
            WHEN (s.sales - COALESCE(p.payment, 0)) > 0 THEN 'Within Credit Limit'
            ELSE 'No Risk'
        END AS credit_limit_risk
    FROM sales_data s
    LEFT JOIN payment_data p ON s.customerNumber = p.customerNumber
),

-- 🔹 Scoring Metrics
scoring_data AS (
    SELECT *,
        CASE 
            WHEN sales >= 150000 THEN 3
            WHEN sales BETWEEN 75000 AND 149999 THEN 2
            ELSE 1
        END AS sales_score,

        CASE 
            WHEN payment_performance_ratio >= 95 THEN 3
            WHEN payment_performance_ratio BETWEEN 75 AND 94.99 THEN 2
            ELSE 1
        END AS payment_score,

        CASE 
            WHEN profit >= 60000 THEN 3
            WHEN profit BETWEEN 25000 AND 59999 THEN 2
            ELSE 1
        END AS profit_score
    FROM base_data
),

-- 🔹 Final Segment with Segmentation Tier
final_segmented AS (
    SELECT *,
        (sales_score + payment_score + profit_score) AS customer_score,
        CASE 
            WHEN (sales_score + payment_score + profit_score) >= 8 THEN 'VIP'
            WHEN (sales_score + payment_score + profit_score) BETWEEN 6 AND 7 THEN 'Premium'
            ELSE 'Regular'
        END AS Customer_tier
    FROM scoring_data
)

-- 🔚 Final Output with employee and office details
SELECT 
    f.customerNumber,
    f.customerName,
    f.country,
    f.creditLimit,
    f.sales,
    f.payment,
    f.profit,
    f.payment_gap,
    f.payment_performance_ratio,
    f.payment_performance_status,
    f.credit_limit_risk,
    f.sales_score,
    f.payment_score,
    f.profit_score,
    f.customer_score,
    f.Customer_tier,

    -- Employee Info
    e.employeeNumber,
    CONCAT(e.firstName, ' ', e.lastName) AS employee_name,
    e.jobTitle,

    -- Office Info
    o.officeCode,
    o.country AS office_country

FROM final_segmented f
LEFT JOIN employees e ON f.salesRepEmployeeNumber = e.employeeNumber
LEFT JOIN offices o ON e.officeCode = o.officeCode;
