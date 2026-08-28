/*
Purpose: Describe order economics across observed discount tiers.
Dialect: MySQL 8.0+
Final grain: One row per discount_pct.
Important limitation: This is descriptive discount economics. The synthetic
                      dataset does not support causal discount ROI estimation.
*/

USE commerce_practice;

CREATE OR REPLACE VIEW vw_discount_economics AS
WITH tier_aggregate AS (
    SELECT
        discount_pct,
        COUNT(*) AS orders,
        SUM(total_units) AS total_units,
        SUM(gross_revenue) AS gross_revenue,
        SUM(discount_amount) AS discount_amount,
        SUM(net_revenue) AS net_revenue,
        SUM(net_profit) AS net_profit
    FROM vw_order_level_metrics
    GROUP BY discount_pct
),
tier_metrics AS (
    SELECT
        discount_pct,
        orders,
        orders / NULLIF(SUM(orders) OVER (), 0) AS order_share,
        total_units,
        total_units / NULLIF(orders, 0) AS units_per_order,
        gross_revenue / NULLIF(orders, 0) AS gross_basket_value_per_order,
        discount_amount / NULLIF(orders, 0) AS discount_amount_per_order,
        net_revenue / NULLIF(orders, 0) AS net_aov,
        net_profit / NULLIF(orders, 0) AS net_profit_per_order,
        net_profit / NULLIF(net_revenue, 0) AS net_margin
    FROM tier_aggregate
)
SELECT
    discount_pct,
    orders,
    order_share,
    total_units,
    units_per_order,
    gross_basket_value_per_order,
    discount_amount_per_order,
    net_aov,
    net_profit_per_order,
    net_margin,
    MAX(CASE WHEN discount_pct = 0 THEN net_margin END) OVER () - net_margin
      AS margin_compression_vs_full_price
FROM tier_metrics;

SELECT
    discount_pct,
    orders,
    ROUND(order_share, 4) AS order_share,
    total_units,
    ROUND(units_per_order, 4) AS units_per_order,
    ROUND(gross_basket_value_per_order, 2) AS gross_basket_value_per_order,
    ROUND(discount_amount_per_order, 2) AS discount_amount_per_order,
    ROUND(net_aov, 2) AS net_aov,
    ROUND(net_profit_per_order, 2) AS net_profit_per_order,
    ROUND(net_margin, 4) AS net_margin,
    ROUND(margin_compression_vs_full_price, 4) AS margin_compression_vs_full_price
FROM vw_discount_economics
ORDER BY discount_pct;

/* Immediate QA: tier totals must reconcile to the canonical order model. */
SELECT 'discount_tier_orders_reconcile' AS check_name,
       (SELECT COUNT(*) FROM vw_order_level_metrics) AS expected_value,
       SUM(orders) AS actual_value,
       IF((SELECT COUNT(*) FROM vw_order_level_metrics) = SUM(orders), 'PASS', 'WARNING') AS status
FROM vw_discount_economics
UNION ALL
SELECT 'discount_tier_units_reconcile',
       (SELECT SUM(total_units) FROM vw_order_level_metrics),
       SUM(total_units),
       IF((SELECT SUM(total_units) FROM vw_order_level_metrics) = SUM(total_units), 'PASS', 'WARNING')
FROM vw_discount_economics;

