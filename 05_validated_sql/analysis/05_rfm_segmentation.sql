/*
Purpose: Build net-revenue RFM scores and interpretable customer segments.
Dialect: MySQL 8.0+
Base grain: One row per purchasing customer.
Final grain: One row per RFM segment in vw_rfm_segment_summary.
Scoring notes:
  - R score: NTILE(5), lower recency receives the higher score.
  - F score: explicit frequency bands preserve identical order counts.
  - M score: NTILE(5), higher net monetary receives the higher score.
Detailed rationale: docs/rfm_methodology.md
*/

USE commerce_practice;

CREATE OR REPLACE VIEW vw_rfm_base AS
WITH dataset_anchor AS (
    SELECT DATE(MAX(order_time)) AS max_order_date
    FROM vw_order_level_metrics
)
SELECT
    o.customer_id,
    MAX(o.order_time) AS last_order_time,
    DATEDIFF(a.max_order_date, DATE(MAX(o.order_time))) AS recency_days,
    COUNT(*) AS frequency,
    SUM(o.net_revenue) AS net_monetary,
    SUM(o.net_profit) AS customer_net_profit,
    SUM(o.net_revenue) / NULLIF(COUNT(*), 0) AS aov
FROM vw_order_level_metrics o
CROSS JOIN dataset_anchor a
GROUP BY o.customer_id, a.max_order_date;

CREATE OR REPLACE VIEW vw_rfm_segments AS
WITH scored AS (
    SELECT
        customer_id,
        last_order_time,
        recency_days,
        frequency,
        net_monetary,
        customer_net_profit,
        aov,
        NTILE(5) OVER (ORDER BY recency_days DESC, customer_id) AS r_score,
        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency = 4 THEN 4
            ELSE 5
        END AS f_score,
        NTILE(5) OVER (ORDER BY net_monetary ASC, customer_id) AS m_score
    FROM vw_rfm_base
),
segmented AS (
    SELECT
        customer_id,
        last_order_time,
        recency_days,
        frequency,
        net_monetary,
        customer_net_profit,
        aov,
        r_score,
        f_score,
        m_score,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
                THEN 'Champions'
            WHEN f_score >= 4 AND r_score >= 3
                THEN 'Loyal'
            WHEN r_score <= 2 AND m_score >= 4
                THEN 'High-value at Risk'
            WHEN r_score >= 4 AND frequency <= 2
                THEN 'New / Promising'
            WHEN r_score <= 2 AND frequency <= 2 AND m_score <= 3
                THEN 'Dormant'
            ELSE 'Established / Mid-value'
        END AS segment
    FROM scored
)
SELECT
    customer_id,
    last_order_time,
    recency_days,
    frequency,
    net_monetary,
    customer_net_profit,
    aov,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_code,
    segment
FROM segmented;

CREATE OR REPLACE VIEW vw_rfm_segment_summary AS
WITH segment_aggregate AS (
    SELECT
        segment,
        COUNT(*) AS customers,
        SUM(net_monetary) AS net_revenue,
        SUM(frequency) AS orders,
        AVG(frequency) AS average_frequency,
        AVG(recency_days) AS average_recency,
        SUM(net_monetary) / NULLIF(SUM(frequency), 0) AS aov,
        SUM(customer_net_profit) AS net_profit
    FROM vw_rfm_segments
    GROUP BY segment
)
SELECT
    segment,
    customers,
    customers / NULLIF(SUM(customers) OVER (), 0) AS customer_share,
    net_revenue,
    net_revenue / NULLIF(SUM(net_revenue) OVER (), 0) AS revenue_share,
    orders,
    aov,
    average_frequency,
    average_recency,
    net_profit / NULLIF(net_revenue, 0) AS net_margin
FROM segment_aggregate;

SELECT
    segment,
    customers,
    ROUND(customer_share, 4) AS customer_share,
    ROUND(net_revenue, 2) AS net_revenue,
    ROUND(revenue_share, 4) AS revenue_share,
    orders,
    ROUND(aov, 2) AS aov,
    ROUND(average_frequency, 4) AS average_frequency,
    ROUND(average_recency, 2) AS average_recency,
    ROUND(net_margin, 4) AS net_margin
FROM vw_rfm_segment_summary
ORDER BY net_revenue DESC;

/* Immediate QA: RFM base and segments must preserve all purchasing customers. */
SELECT 'rfm_customer_count_reconciles' AS check_name,
       (SELECT COUNT(*) FROM vw_customer_value) AS expected_value,
       COUNT(*) AS actual_value,
       IF((SELECT COUNT(*) FROM vw_customer_value) = COUNT(*), 'PASS', 'WARNING') AS status
FROM vw_rfm_segments
UNION ALL
SELECT 'rfm_order_count_reconciles',
       (SELECT COUNT(*) FROM vw_order_level_metrics),
       SUM(frequency),
       IF((SELECT COUNT(*) FROM vw_order_level_metrics) = SUM(frequency), 'PASS', 'WARNING')
FROM vw_rfm_segments
UNION ALL
SELECT 'rfm_net_revenue_reconciles',
       (SELECT SUM(net_revenue) FROM vw_order_level_metrics),
       SUM(net_monetary),
       IF(ABS((SELECT SUM(net_revenue) FROM vw_order_level_metrics)
              - SUM(net_monetary)) <= 0.01, 'PASS', 'WARNING')
FROM vw_rfm_segments;
