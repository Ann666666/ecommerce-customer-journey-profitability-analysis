/*
Purpose: Measure monthly e-commerce performance using validated order metrics.
Dialect: MySQL 8.0+
Final grain: One row per calendar month; comparable-period view is one row per year.
Important assumption: 2025 is incomplete, so year comparisons use matching months.
*/

USE commerce_practice;

CREATE OR REPLACE VIEW vw_monthly_performance AS
SELECT
    CAST(DATE_FORMAT(order_time, '%Y-%m-01') AS DATE) AS order_month,
    COUNT(*) AS orders,
    SUM(total_units) AS units,
    SUM(gross_revenue) AS gross_revenue,
    SUM(discount_amount) AS discount_amount,
    SUM(net_revenue) AS net_revenue,
    SUM(net_profit) AS net_profit,
    SUM(net_revenue) / NULLIF(COUNT(*), 0) AS aov,
    SUM(net_profit) / NULLIF(SUM(net_revenue), 0) AS net_margin
FROM vw_order_level_metrics
GROUP BY CAST(DATE_FORMAT(order_time, '%Y-%m-01') AS DATE);

CREATE OR REPLACE VIEW vw_time_trend AS
WITH lagged AS (
    SELECT
        m.*,
        LAG(net_revenue, 1) OVER (ORDER BY order_month) AS prior_month_revenue,
        LAG(net_revenue, 12) OVER (ORDER BY order_month) AS prior_year_revenue,
        LAG(orders, 12) OVER (ORDER BY order_month) AS prior_year_orders,
        LAG(aov, 12) OVER (ORDER BY order_month) AS prior_year_aov
    FROM vw_monthly_performance m
)
SELECT
    order_month,
    orders,
    units,
    gross_revenue,
    discount_amount,
    net_revenue,
    net_profit,
    aov,
    net_margin,
    (net_revenue - prior_month_revenue) / NULLIF(prior_month_revenue, 0)
      AS mom_net_revenue_growth,
    (net_revenue - prior_year_revenue) / NULLIF(prior_year_revenue, 0)
      AS yoy_net_revenue_growth,
    (orders - prior_year_orders) / NULLIF(prior_year_orders, 0)
      AS yoy_order_growth,
    (aov - prior_year_aov) / NULLIF(prior_year_aov, 0)
      AS yoy_aov_growth
FROM lagged;

CREATE OR REPLACE VIEW vw_comparable_period_summary AS
WITH dataset_cutoff AS (
    SELECT
        YEAR(MAX(order_time)) AS current_year,
        MONTH(MAX(order_time)) AS cutoff_month
    FROM vw_order_level_metrics
),
year_periods AS (
    SELECT
        YEAR(o.order_time) AS order_year,
        COUNT(*) AS orders,
        SUM(o.total_units) AS units,
        SUM(o.net_revenue) AS net_revenue,
        SUM(o.net_profit) AS net_profit,
        SUM(o.net_revenue) / NULLIF(COUNT(*), 0) AS aov,
        SUM(o.net_profit) / NULLIF(SUM(o.net_revenue), 0) AS net_margin
    FROM vw_order_level_metrics o
    CROSS JOIN dataset_cutoff d
    WHERE YEAR(o.order_time) IN (d.current_year - 1, d.current_year)
      AND MONTH(o.order_time) <= d.cutoff_month
    GROUP BY YEAR(o.order_time)
),
with_prior AS (
    SELECT
        y.*,
        LAG(orders) OVER (ORDER BY order_year) AS prior_orders,
        LAG(net_revenue) OVER (ORDER BY order_year) AS prior_net_revenue,
        LAG(net_profit) OVER (ORDER BY order_year) AS prior_net_profit,
        LAG(aov) OVER (ORDER BY order_year) AS prior_aov
    FROM year_periods y
)
SELECT
    order_year,
    orders,
    units,
    net_revenue,
    net_profit,
    aov,
    net_margin,
    (orders - prior_orders) / NULLIF(prior_orders, 0) AS order_growth,
    (net_revenue - prior_net_revenue) / NULLIF(prior_net_revenue, 0)
      AS net_revenue_growth,
    (net_profit - prior_net_profit) / NULLIF(prior_net_profit, 0)
      AS net_profit_growth,
    (aov - prior_aov) / NULLIF(prior_aov, 0) AS aov_growth
FROM with_prior;

SELECT
    order_month,
    orders,
    units,
    ROUND(net_revenue, 2) AS net_revenue,
    ROUND(net_profit, 2) AS net_profit,
    ROUND(aov, 2) AS aov,
    ROUND(net_margin, 4) AS net_margin,
    ROUND(mom_net_revenue_growth, 4) AS mom_net_revenue_growth,
    ROUND(yoy_net_revenue_growth, 4) AS yoy_net_revenue_growth,
    ROUND(yoy_order_growth, 4) AS yoy_order_growth,
    ROUND(yoy_aov_growth, 4) AS yoy_aov_growth
FROM vw_time_trend
ORDER BY order_month;

SELECT
    order_year,
    orders,
    units,
    ROUND(net_revenue, 2) AS net_revenue,
    ROUND(net_profit, 2) AS net_profit,
    ROUND(aov, 2) AS aov,
    ROUND(net_margin, 4) AS net_margin,
    ROUND(order_growth, 4) AS order_growth,
    ROUND(net_revenue_growth, 4) AS net_revenue_growth,
    ROUND(net_profit_growth, 4) AS net_profit_growth,
    ROUND(aov_growth, 4) AS aov_growth
FROM vw_comparable_period_summary
ORDER BY order_year;

/* Immediate QA: monthly totals must reconcile to the order model. */
SELECT 'monthly_orders_reconcile' AS check_name,
       (SELECT COUNT(*) FROM vw_order_level_metrics) AS expected_value,
       SUM(orders) AS actual_value,
       IF((SELECT COUNT(*) FROM vw_order_level_metrics) = SUM(orders),
          'PASS', 'WARNING') AS status
FROM vw_monthly_performance
UNION ALL
SELECT 'monthly_net_revenue_reconcile',
       ROUND((SELECT SUM(net_revenue) FROM vw_order_level_metrics), 2),
       ROUND(SUM(net_revenue), 2),
       IF(ABS((SELECT SUM(net_revenue) FROM vw_order_level_metrics)
              - SUM(net_revenue)) <= 0.01, 'PASS', 'WARNING')
FROM vw_monthly_performance
UNION ALL
SELECT 'monthly_net_profit_reconcile',
       ROUND((SELECT SUM(net_profit) FROM vw_order_level_metrics), 2),
       ROUND(SUM(net_profit), 2),
       IF(ABS((SELECT SUM(net_profit) FROM vw_order_level_metrics)
              - SUM(net_profit)) <= 0.01, 'PASS', 'WARNING')
FROM vw_monthly_performance;

