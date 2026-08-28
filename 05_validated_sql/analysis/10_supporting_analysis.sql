/*
Purpose: Provide supporting geography, acquisition source, device, and category
contribution analyses for the README or appendix.
Dialect: MySQL 8.0+
Final grains: One row per country, source, device, or category depending on view.
*/

USE commerce_practice;

CREATE OR REPLACE VIEW vw_geography_performance AS
SELECT
    country,
    COUNT(*) AS orders,
    COUNT(DISTINCT customer_id) AS purchasing_customers,
    SUM(net_revenue) AS net_revenue,
    SUM(net_revenue) / NULLIF(SUM(SUM(net_revenue)) OVER (), 0) AS revenue_share,
    SUM(net_revenue) / NULLIF(COUNT(*), 0) AS aov,
    SUM(net_profit) / NULLIF(SUM(net_revenue), 0) AS net_margin
FROM vw_order_level_metrics
GROUP BY country;

CREATE OR REPLACE VIEW vw_source_performance AS
WITH session_base AS (
    SELECT
        s.source,
        COUNT(*) AS sessions,
        SUM(f.first_purchase_time IS NOT NULL) AS purchase_sessions
    FROM sessions s
    JOIN vw_session_funnel_flags f
      ON s.session_id = f.session_id
    GROUP BY s.source
),
order_base AS (
    SELECT
        source,
        COUNT(*) AS orders,
        SUM(net_revenue) AS net_revenue,
        SUM(net_profit) AS net_profit
    FROM vw_order_level_metrics
    GROUP BY source
)
SELECT
    s.source,
    s.sessions,
    s.purchase_sessions,
    s.purchase_sessions / NULLIF(s.sessions, 0) AS session_conversion,
    COALESCE(o.orders, 0) AS orders,
    COALESCE(o.net_revenue, 0) AS net_revenue,
    COALESCE(o.net_revenue, 0) / NULLIF(o.orders, 0) AS aov,
    COALESCE(o.net_revenue, 0) / NULLIF(s.sessions, 0) AS revenue_per_session,
    COALESCE(o.net_profit, 0) / NULLIF(o.net_revenue, 0) AS net_margin
FROM session_base s
LEFT JOIN order_base o
  ON s.source = o.source;

CREATE OR REPLACE VIEW vw_device_performance AS
WITH session_base AS (
    SELECT
        s.device,
        COUNT(*) AS sessions,
        SUM(f.first_purchase_time IS NOT NULL) AS purchase_sessions
    FROM sessions s
    JOIN vw_session_funnel_flags f
      ON s.session_id = f.session_id
    GROUP BY s.device
),
order_base AS (
    SELECT
        device,
        COUNT(*) AS orders,
        SUM(net_revenue) AS net_revenue,
        SUM(net_profit) AS net_profit
    FROM vw_order_level_metrics
    GROUP BY device
)
SELECT
    s.device,
    s.sessions,
    s.purchase_sessions,
    s.purchase_sessions / NULLIF(s.sessions, 0) AS session_conversion,
    COALESCE(o.orders, 0) AS orders,
    COALESCE(o.net_revenue, 0) AS net_revenue,
    COALESCE(o.net_revenue, 0) / NULLIF(o.orders, 0) AS aov,
    COALESCE(o.net_revenue, 0) / NULLIF(s.sessions, 0) AS revenue_per_session,
    COALESCE(o.net_profit, 0) / NULLIF(o.net_revenue, 0) AS net_margin
FROM session_base s
LEFT JOIN order_base o
  ON s.device = o.device;

CREATE OR REPLACE VIEW vw_category_revenue_contribution AS
SELECT
    category,
    revenue_rank,
    net_revenue,
    revenue_share,
    SUM(net_revenue) OVER (ORDER BY net_revenue DESC, category)
      / NULLIF(SUM(net_revenue) OVER (), 0) AS cumulative_revenue_share
FROM vw_category_portfolio;

SELECT
    country,
    orders,
    purchasing_customers,
    ROUND(net_revenue, 2) AS net_revenue,
    ROUND(revenue_share, 4) AS revenue_share,
    ROUND(aov, 2) AS aov,
    ROUND(net_margin, 4) AS net_margin
FROM vw_geography_performance
ORDER BY net_revenue DESC;

SELECT
    source,
    sessions,
    purchase_sessions,
    ROUND(session_conversion, 4) AS session_conversion,
    orders,
    ROUND(net_revenue, 2) AS net_revenue,
    ROUND(aov, 2) AS aov,
    ROUND(revenue_per_session, 2) AS revenue_per_session,
    ROUND(net_margin, 4) AS net_margin
FROM vw_source_performance
ORDER BY revenue_per_session DESC;

SELECT
    device,
    sessions,
    purchase_sessions,
    ROUND(session_conversion, 4) AS session_conversion,
    orders,
    ROUND(net_revenue, 2) AS net_revenue,
    ROUND(aov, 2) AS aov,
    ROUND(revenue_per_session, 2) AS revenue_per_session,
    ROUND(net_margin, 4) AS net_margin
FROM vw_device_performance
ORDER BY revenue_per_session DESC;

SELECT
    category,
    revenue_rank,
    ROUND(net_revenue, 2) AS net_revenue,
    ROUND(revenue_share, 4) AS revenue_share,
    ROUND(cumulative_revenue_share, 4) AS cumulative_revenue_share
FROM vw_category_revenue_contribution
ORDER BY revenue_rank, category;

/* Immediate QA: dimensional totals must reconcile to their source entities. */
SELECT 'geography_orders_reconcile' AS check_name,
       (SELECT COUNT(*) FROM vw_order_level_metrics) AS expected_value,
       SUM(orders) AS actual_value,
       IF((SELECT COUNT(*) FROM vw_order_level_metrics) = SUM(orders),
          'PASS', 'WARNING') AS status
FROM vw_geography_performance
UNION ALL
SELECT 'source_sessions_reconcile',
       (SELECT COUNT(*) FROM sessions),
       SUM(sessions),
       IF((SELECT COUNT(*) FROM sessions) = SUM(sessions), 'PASS', 'WARNING')
FROM vw_source_performance
UNION ALL
SELECT 'device_sessions_reconcile',
       (SELECT COUNT(*) FROM sessions),
       SUM(sessions),
       IF((SELECT COUNT(*) FROM sessions) = SUM(sessions), 'PASS', 'WARNING')
FROM vw_device_performance
UNION ALL
SELECT 'source_purchase_sessions_reconcile',
       (SELECT SUM(first_purchase_time IS NOT NULL) FROM vw_session_funnel_flags),
       SUM(purchase_sessions),
       IF((SELECT SUM(first_purchase_time IS NOT NULL) FROM vw_session_funnel_flags)
          = SUM(purchase_sessions), 'PASS', 'WARNING')
FROM vw_source_performance
UNION ALL
SELECT 'category_contribution_reconciles',
       ROUND((SELECT SUM(net_revenue) FROM vw_order_level_metrics), 2),
       ROUND(SUM(net_revenue), 2),
       IF(ABS((SELECT SUM(net_revenue) FROM vw_order_level_metrics)
              - SUM(net_revenue)) <= 0.01, 'PASS', 'WARNING')
FROM vw_category_revenue_contribution;
