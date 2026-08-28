/*
Purpose: Build canonical order-product profitability with proportional discount allocation.
Dialect: MySQL 8.0+
Final grain: One row per order_id + product_id.
Assumption: Repeated source lines for the same order-product are aggregated;
            no source rows are deleted.
*/

USE commerce_practice;

CREATE OR REPLACE VIEW vw_item_level_profitability AS
WITH order_product_rollup AS (
    SELECT
        oi.order_id,
        oi.product_id,
        SUM(oi.quantity) AS quantity,
        SUM(oi.line_total_usd) AS gross_item_revenue,
        SUM(oi.quantity * p.cost_usd) AS item_cost
    FROM order_items oi
    JOIN products p
      ON oi.product_id = p.product_id
    GROUP BY oi.order_id, oi.product_id
)
SELECT
    r.order_id,
    r.product_id,
    p.category,
    o.customer_id,
    o.order_time,
    r.quantity,
    r.gross_item_revenue,
    r.item_cost,
    r.gross_item_revenue / NULLIF(o.subtotal_usd, 0) AS share_of_order_subtotal,
    r.gross_item_revenue
      * (o.subtotal_usd - o.total_usd)
      / NULLIF(o.subtotal_usd, 0) AS allocated_discount,
    r.gross_item_revenue
      * o.total_usd
      / NULLIF(o.subtotal_usd, 0) AS allocated_net_revenue,
    r.gross_item_revenue
      * o.total_usd
      / NULLIF(o.subtotal_usd, 0)
      - r.item_cost AS net_item_profit,
    (
        r.gross_item_revenue
          * o.total_usd
          / NULLIF(o.subtotal_usd, 0)
          - r.item_cost
    ) / NULLIF(
        r.gross_item_revenue * o.total_usd / NULLIF(o.subtotal_usd, 0),
        0
    ) AS net_item_margin
FROM order_product_rollup r
JOIN orders o
  ON r.order_id = o.order_id
JOIN products p
  ON r.product_id = p.product_id;

/* Immediate QA: order and global allocations must reconcile. */
WITH order_allocation AS (
    SELECT
        i.order_id,
        SUM(i.gross_item_revenue) AS allocated_gross,
        SUM(i.allocated_net_revenue) AS allocated_net,
        SUM(i.item_cost) AS allocated_cost,
        SUM(i.net_item_profit) AS allocated_profit
    FROM vw_item_level_profitability i
    GROUP BY i.order_id
),
order_qa AS (
    SELECT
        COUNT(*) AS order_rows,
        SUM(ABS(a.allocated_gross - o.subtotal_usd) > 0.01) AS gross_mismatch_orders,
        SUM(ABS(a.allocated_net - o.total_usd) > 0.01) AS net_mismatch_orders
    FROM order_allocation a
    JOIN orders o
      ON a.order_id = o.order_id
),
global_qa AS (
    SELECT
        SUM(gross_item_revenue) AS item_gross,
        SUM(allocated_net_revenue) AS item_net,
        SUM(item_cost) AS item_cost,
        SUM(net_item_profit) AS item_profit
    FROM vw_item_level_profitability
)
SELECT 'order_gross_allocation_mismatches' AS check_name,
       0 AS expected_value,
       gross_mismatch_orders AS actual_value,
       IF(gross_mismatch_orders = 0, 'PASS', 'WARNING') AS status
FROM order_qa
UNION ALL
SELECT 'order_net_allocation_mismatches', 0, net_mismatch_orders,
       IF(net_mismatch_orders = 0, 'PASS', 'WARNING')
FROM order_qa
UNION ALL
SELECT 'global_gross_revenue_reconciles',
       (SELECT SUM(subtotal_usd) FROM orders), item_gross,
       IF(ABS((SELECT SUM(subtotal_usd) FROM orders) - item_gross) <= 0.01, 'PASS', 'WARNING')
FROM global_qa
UNION ALL
SELECT 'global_net_revenue_reconciles',
       (SELECT SUM(total_usd) FROM orders), item_net,
       IF(ABS((SELECT SUM(total_usd) FROM orders) - item_net) <= 0.01, 'PASS', 'WARNING')
FROM global_qa
UNION ALL
SELECT 'global_product_cost_reconciles',
       (SELECT SUM(total_product_cost) FROM vw_order_level_metrics), item_cost,
       IF(ABS((SELECT SUM(total_product_cost) FROM vw_order_level_metrics) - item_cost) <= 0.01, 'PASS', 'WARNING')
FROM global_qa
UNION ALL
SELECT 'global_net_profit_reconciles',
       (SELECT SUM(net_profit) FROM vw_order_level_metrics), item_profit,
       IF(ABS((SELECT SUM(net_profit) FROM vw_order_level_metrics) - item_profit) <= 0.01, 'PASS', 'WARNING')
FROM global_qa;

