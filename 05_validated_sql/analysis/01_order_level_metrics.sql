/*
Purpose: Build the canonical order-level analytical model.
Dialect: MySQL 8.0+
Final grain: One row per order_id.
Metric definitions: docs/metric_dictionary.md
*/

USE commerce_practice;

CREATE OR REPLACE VIEW vw_order_level_metrics AS
WITH item_rollup AS (
    SELECT
        oi.order_id,
        COUNT(*) AS order_lines,
        SUM(oi.quantity) AS total_units,
        SUM(oi.line_total_usd) AS item_subtotal,
        SUM(oi.quantity * p.cost_usd) AS total_product_cost
    FROM order_items oi
    JOIN products p
      ON oi.product_id = p.product_id
    GROUP BY oi.order_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_time,
    o.country,
    o.device,
    o.source,
    o.payment_method,
    o.discount_pct,
    o.subtotal_usd AS gross_revenue,
    o.subtotal_usd - o.total_usd AS discount_amount,
    o.total_usd AS net_revenue,
    i.order_lines,
    i.total_units,
    i.total_product_cost,
    o.subtotal_usd - i.total_product_cost AS gross_profit_before_discount,
    o.total_usd - i.total_product_cost AS net_profit,
    (o.total_usd - i.total_product_cost) / NULLIF(o.total_usd, 0) AS net_margin
FROM orders o
JOIN item_rollup i
  ON o.order_id = i.order_id;

/* Immediate QA: every result should be PASS. */
WITH qa AS (
    SELECT
        (SELECT COUNT(*) FROM orders) AS source_order_rows,
        COUNT(*) AS model_rows,
        COUNT(DISTINCT order_id) AS distinct_model_orders,
        SUM(gross_revenue) AS model_gross_revenue,
        SUM(net_revenue) AS model_net_revenue,
        SUM(total_units) AS model_units,
        SUM(total_product_cost) AS model_product_cost
    FROM vw_order_level_metrics
)
SELECT 'row_count_equals_orders' AS check_name,
       source_order_rows AS source_value,
       model_rows AS model_value,
       IF(source_order_rows = model_rows, 'PASS', 'WARNING') AS status
FROM qa
UNION ALL
SELECT 'order_id_is_unique', model_rows, distinct_model_orders,
       IF(model_rows = distinct_model_orders, 'PASS', 'WARNING')
FROM qa
UNION ALL
SELECT 'gross_revenue_reconciles',
       (SELECT SUM(subtotal_usd) FROM orders), model_gross_revenue,
       IF(ABS((SELECT SUM(subtotal_usd) FROM orders) - model_gross_revenue) <= 0.01, 'PASS', 'WARNING')
FROM qa
UNION ALL
SELECT 'net_revenue_reconciles',
       (SELECT SUM(total_usd) FROM orders), model_net_revenue,
       IF(ABS((SELECT SUM(total_usd) FROM orders) - model_net_revenue) <= 0.01, 'PASS', 'WARNING')
FROM qa
UNION ALL
SELECT 'units_reconcile',
       (SELECT SUM(quantity) FROM order_items), model_units,
       IF((SELECT SUM(quantity) FROM order_items) = model_units, 'PASS', 'WARNING')
FROM qa
UNION ALL
SELECT 'product_cost_reconciles',
       (SELECT SUM(oi.quantity * p.cost_usd)
        FROM order_items oi JOIN products p ON oi.product_id = p.product_id),
       model_product_cost,
       IF(ABS((SELECT SUM(oi.quantity * p.cost_usd)
               FROM order_items oi JOIN products p ON oi.product_id = p.product_id)
              - model_product_cost) <= 0.01, 'PASS', 'WARNING')
FROM qa;

