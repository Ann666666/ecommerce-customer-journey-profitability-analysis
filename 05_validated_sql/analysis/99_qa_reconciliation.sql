/*
Purpose: Consolidate model-level reconciliation checks after all validated views run.
Dialect: MySQL 8.0+
Final grain: One row per QA check.
Tolerance: Monetary reconciliation allows an absolute difference of 0.01 USD.
*/

USE commerce_practice;

CREATE OR REPLACE VIEW vw_model_reconciliation_summary AS
SELECT
    'order_model' AS check_group,
    'order_rows_reconcile' AS check_name,
    CAST((SELECT COUNT(*) FROM orders) AS DECIMAL(20, 4)) AS expected_value,
    CAST((SELECT COUNT(*) FROM vw_order_level_metrics) AS DECIMAL(20, 4)) AS actual_value,
    IF((SELECT COUNT(*) FROM orders) = (SELECT COUNT(*) FROM vw_order_level_metrics),
       'PASS', 'WARNING') AS status,
    'Canonical order model must contain exactly one row per source order.' AS interpretation
UNION ALL
SELECT 'order_model', 'order_id_is_unique',
       CAST((SELECT COUNT(*) FROM vw_order_level_metrics) AS DECIMAL(20, 4)),
       CAST((SELECT COUNT(DISTINCT order_id) FROM vw_order_level_metrics) AS DECIMAL(20, 4)),
       IF((SELECT COUNT(*) FROM vw_order_level_metrics)
          = (SELECT COUNT(DISTINCT order_id) FROM vw_order_level_metrics),
          'PASS', 'WARNING'),
       'order_id must remain unique after item aggregation and joins.'
UNION ALL
SELECT 'order_model', 'net_revenue_reconciles',
       CAST((SELECT SUM(total_usd) FROM orders) AS DECIMAL(20, 4)),
       CAST((SELECT SUM(net_revenue) FROM vw_order_level_metrics) AS DECIMAL(20, 4)),
       IF(ABS((SELECT SUM(total_usd) FROM orders)
              - (SELECT SUM(net_revenue) FROM vw_order_level_metrics)) <= 0.01,
          'PASS', 'WARNING'),
       'Order-model net revenue must equal orders.total_usd.'
UNION ALL
SELECT 'order_model', 'units_reconcile',
       CAST((SELECT SUM(quantity) FROM order_items) AS DECIMAL(20, 4)),
       CAST((SELECT SUM(total_units) FROM vw_order_level_metrics) AS DECIMAL(20, 4)),
       IF((SELECT SUM(quantity) FROM order_items)
          = (SELECT SUM(total_units) FROM vw_order_level_metrics), 'PASS', 'WARNING'),
       'Units are summed from quantity, not source row count.'
UNION ALL
SELECT 'item_model', 'item_net_allocation_reconciles',
       CAST((SELECT SUM(total_usd) FROM orders) AS DECIMAL(20, 4)),
       CAST((SELECT SUM(allocated_net_revenue) FROM vw_item_level_profitability)
            AS DECIMAL(20, 4)),
       IF(ABS((SELECT SUM(total_usd) FROM orders)
              - (SELECT SUM(allocated_net_revenue) FROM vw_item_level_profitability)) <= 0.01,
          'PASS', 'WARNING'),
       'Allocated item net revenue must return to total order net revenue.'
UNION ALL
SELECT 'item_model', 'item_cost_reconciles',
       CAST((SELECT SUM(total_product_cost) FROM vw_order_level_metrics) AS DECIMAL(20, 4)),
       CAST((SELECT SUM(item_cost) FROM vw_item_level_profitability) AS DECIMAL(20, 4)),
       IF(ABS((SELECT SUM(total_product_cost) FROM vw_order_level_metrics)
              - (SELECT SUM(item_cost) FROM vw_item_level_profitability)) <= 0.01,
          'PASS', 'WARNING'),
       'Item costs must reconcile after repeated order-product rows are aggregated.'
UNION ALL
SELECT 'item_model', 'item_net_profit_reconciles',
       CAST((SELECT SUM(net_profit) FROM vw_order_level_metrics) AS DECIMAL(20, 4)),
       CAST((SELECT SUM(net_item_profit) FROM vw_item_level_profitability) AS DECIMAL(20, 4)),
       IF(ABS((SELECT SUM(net_profit) FROM vw_order_level_metrics)
              - (SELECT SUM(net_item_profit) FROM vw_item_level_profitability)) <= 0.01,
          'PASS', 'WARNING'),
       'Allocated item profit must return to canonical order-level profit.'
UNION ALL
SELECT 'customer_model', 'customer_counts_reconcile',
       CAST((SELECT COUNT(DISTINCT customer_id) FROM orders) AS DECIMAL(20, 4)),
       CAST((SELECT COUNT(*) FROM vw_customer_value) AS DECIMAL(20, 4)),
       IF((SELECT COUNT(DISTINCT customer_id) FROM orders)
          = (SELECT COUNT(*) FROM vw_customer_value), 'PASS', 'WARNING'),
       'Customer-value model includes every purchasing customer exactly once.'
UNION ALL
SELECT 'customer_model', 'rfm_net_revenue_reconciles',
       CAST((SELECT SUM(net_revenue) FROM vw_order_level_metrics) AS DECIMAL(20, 4)),
       CAST((SELECT SUM(net_monetary) FROM vw_rfm_segments) AS DECIMAL(20, 4)),
       IF(ABS((SELECT SUM(net_revenue) FROM vw_order_level_metrics)
              - (SELECT SUM(net_monetary) FROM vw_rfm_segments)) <= 0.01,
          'PASS', 'WARNING'),
       'RFM monetary uses net customer revenue and must reconcile globally.'
UNION ALL
SELECT 'funnel_model', 'funnel_sessions_reconcile',
       CAST((SELECT COUNT(*) FROM sessions) AS DECIMAL(20, 4)),
       CAST((SELECT COUNT(*) FROM vw_session_funnel_flags) AS DECIMAL(20, 4)),
       IF((SELECT COUNT(*) FROM sessions)
          = (SELECT COUNT(*) FROM vw_session_funnel_flags), 'PASS', 'WARNING'),
       'Funnel flag view preserves one row per session.'
UNION ALL
SELECT 'cohort_model', 'cohort_customers_reconcile',
       CAST((SELECT COUNT(DISTINCT customer_id) FROM orders) AS DECIMAL(20, 4)),
       CAST((SELECT SUM(cohort_size)
             FROM vw_first_purchase_cohort WHERE month_index = 0) AS DECIMAL(20, 4)),
       IF((SELECT COUNT(DISTINCT customer_id) FROM orders)
          = (SELECT SUM(cohort_size)
             FROM vw_first_purchase_cohort WHERE month_index = 0), 'PASS', 'WARNING'),
       'First-purchase cohorts cover every purchasing customer once.'
UNION ALL
SELECT 'category_model', 'category_net_revenue_reconciles',
       CAST((SELECT SUM(net_revenue) FROM vw_order_level_metrics) AS DECIMAL(20, 4)),
       CAST((SELECT SUM(net_revenue) FROM vw_category_portfolio) AS DECIMAL(20, 4)),
       IF(ABS((SELECT SUM(net_revenue) FROM vw_order_level_metrics)
              - (SELECT SUM(net_revenue) FROM vw_category_portfolio)) <= 0.01,
          'PASS', 'WARNING'),
       'Category net revenue must reconcile to the canonical order model.';

SELECT
    check_group,
    check_name,
    expected_value,
    actual_value,
    status,
    interpretation
FROM vw_model_reconciliation_summary
ORDER BY check_group, check_name;

