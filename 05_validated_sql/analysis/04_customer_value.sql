/*
Purpose: Quantify one-time and repeat buyer contribution using net order metrics.
Dialect: MySQL 8.0+
Base grain: One row per purchasing customer in vw_customer_value.
Final grain: One row per customer_type in vw_customer_value_segments.
*/

USE commerce_practice;

CREATE OR REPLACE VIEW vw_customer_value AS
SELECT
    customer_id,
    MIN(order_time) AS first_order_time,
    MAX(order_time) AS last_order_time,
    COUNT(*) AS purchase_frequency,
    SUM(total_units) AS total_units,
    SUM(net_revenue) AS customer_net_revenue,
    SUM(net_profit) AS customer_net_profit,
    SUM(net_revenue) / NULLIF(COUNT(*), 0) AS customer_aov
FROM vw_order_level_metrics
GROUP BY customer_id;

CREATE OR REPLACE VIEW vw_customer_value_segments AS
WITH segment_aggregate AS (
    SELECT
        CASE
            WHEN purchase_frequency = 1 THEN 'One-time Buyer'
            ELSE 'Repeat Buyer'
        END AS customer_type,
        COUNT(*) AS customers,
        SUM(purchase_frequency) AS orders,
        SUM(customer_net_revenue) AS net_revenue,
        SUM(customer_net_profit) AS net_profit
    FROM vw_customer_value
    GROUP BY
        CASE
            WHEN purchase_frequency = 1 THEN 'One-time Buyer'
            ELSE 'Repeat Buyer'
        END
)
SELECT
    customer_type,
    customers,
    customers / NULLIF(SUM(customers) OVER (), 0) AS customer_share,
    orders,
    orders / NULLIF(SUM(orders) OVER (), 0) AS order_share,
    net_revenue,
    net_revenue / NULLIF(SUM(net_revenue) OVER (), 0) AS revenue_share,
    net_revenue / NULLIF(customers, 0) AS revenue_per_customer,
    net_revenue / NULLIF(orders, 0) AS aov,
    orders / NULLIF(customers, 0) AS average_purchase_frequency,
    net_profit / NULLIF(net_revenue, 0) AS net_margin
FROM segment_aggregate;

SELECT
    customer_type,
    customers,
    ROUND(customer_share, 4) AS customer_share,
    orders,
    ROUND(order_share, 4) AS order_share,
    ROUND(net_revenue, 2) AS net_revenue,
    ROUND(revenue_share, 4) AS revenue_share,
    ROUND(revenue_per_customer, 2) AS revenue_per_customer,
    ROUND(aov, 2) AS aov,
    ROUND(average_purchase_frequency, 4) AS average_purchase_frequency,
    ROUND(net_margin, 4) AS net_margin
FROM vw_customer_value_segments
ORDER BY customers DESC;

/* Immediate QA: customer aggregates must reconcile to the order model. */
SELECT 'purchasing_customers_reconcile' AS check_name,
       (SELECT COUNT(DISTINCT customer_id) FROM orders) AS expected_value,
       COUNT(*) AS actual_value,
       IF((SELECT COUNT(DISTINCT customer_id) FROM orders) = COUNT(*), 'PASS', 'WARNING') AS status
FROM vw_customer_value
UNION ALL
SELECT 'customer_orders_reconcile',
       (SELECT COUNT(*) FROM vw_order_level_metrics),
       SUM(purchase_frequency),
       IF((SELECT COUNT(*) FROM vw_order_level_metrics) = SUM(purchase_frequency), 'PASS', 'WARNING')
FROM vw_customer_value
UNION ALL
SELECT 'customer_net_revenue_reconciles',
       (SELECT SUM(net_revenue) FROM vw_order_level_metrics),
       SUM(customer_net_revenue),
       IF(ABS((SELECT SUM(net_revenue) FROM vw_order_level_metrics)
              - SUM(customer_net_revenue)) <= 0.01, 'PASS', 'WARNING')
FROM vw_customer_value;

