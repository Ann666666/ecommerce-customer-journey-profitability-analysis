/*
Purpose: Build a session-level event-presence funnel and quantify strict
         timestamp-sequence anomalies.
Dialect: MySQL 8.0+
Base grain: One row per session in vw_session_funnel_flags.
Final grain: One row per funnel stage in vw_funnel_stage_summary.
*/

USE commerce_practice;

CREATE OR REPLACE VIEW vw_session_funnel_flags AS
SELECT
    s.session_id,
    s.customer_id,
    s.source,
    s.device,
    s.country,
    MIN(CASE WHEN e.event_type = 'page_view' THEN e.`timestamp` END) AS first_view_time,
    MIN(CASE WHEN e.event_type = 'add_to_cart' THEN e.`timestamp` END) AS first_cart_time,
    MIN(CASE WHEN e.event_type = 'checkout' THEN e.`timestamp` END) AS first_checkout_time,
    MIN(CASE WHEN e.event_type = 'purchase' THEN e.`timestamp` END) AS first_purchase_time
FROM sessions s
LEFT JOIN events e
  ON s.session_id = e.session_id
GROUP BY s.session_id, s.customer_id, s.source, s.device, s.country;

CREATE OR REPLACE VIEW vw_funnel_stage_summary AS
WITH stage_counts AS (
    SELECT
        COUNT(*) AS all_sessions,
        SUM(first_view_time IS NOT NULL) AS view_sessions,
        SUM(first_cart_time IS NOT NULL) AS cart_sessions,
        SUM(first_checkout_time IS NOT NULL) AS checkout_sessions,
        SUM(first_purchase_time IS NOT NULL) AS purchase_sessions
    FROM vw_session_funnel_flags
),
long_stage AS (
    SELECT 1 AS stage_order, 'View' AS stage,
           view_sessions AS sessions,
           view_sessions AS previous_stage_sessions,
           view_sessions AS overall_base_sessions
    FROM stage_counts
    UNION ALL
    SELECT 2, 'Add to Cart', cart_sessions, view_sessions, view_sessions
    FROM stage_counts
    UNION ALL
    SELECT 3, 'Checkout', checkout_sessions, cart_sessions, view_sessions
    FROM stage_counts
    UNION ALL
    SELECT 4, 'Purchase', purchase_sessions, checkout_sessions, view_sessions
    FROM stage_counts
)
SELECT
    stage_order,
    stage,
    sessions,
    sessions / NULLIF(previous_stage_sessions, 0) AS step_conversion,
    1 - sessions / NULLIF(previous_stage_sessions, 0) AS step_drop_off,
    sessions / NULLIF(overall_base_sessions, 0) AS overall_conversion
FROM long_stage;

CREATE OR REPLACE VIEW vw_funnel_sequence_qa AS
WITH anomaly_flags AS (
    SELECT
        session_id,
        first_view_time,
        first_cart_time,
        first_checkout_time,
        first_purchase_time,
        first_cart_time IS NOT NULL
          AND first_view_time IS NOT NULL
          AND first_cart_time < first_view_time AS cart_before_view,
        first_checkout_time IS NOT NULL
          AND first_cart_time IS NOT NULL
          AND first_checkout_time < first_cart_time AS checkout_before_cart,
        first_purchase_time IS NOT NULL
          AND first_checkout_time IS NOT NULL
          AND first_purchase_time < first_checkout_time AS purchase_before_checkout
    FROM vw_session_funnel_flags
)
SELECT
    'cart_before_view' AS anomaly_type,
    SUM(cart_before_view) AS anomaly_sessions,
    SUM(first_cart_time IS NOT NULL) AS relevant_stage_sessions,
    SUM(cart_before_view) / NULLIF(SUM(first_cart_time IS NOT NULL), 0) AS anomaly_share
FROM anomaly_flags
UNION ALL
SELECT
    'checkout_before_cart',
    SUM(checkout_before_cart),
    SUM(first_checkout_time IS NOT NULL),
    SUM(checkout_before_cart) / NULLIF(SUM(first_checkout_time IS NOT NULL), 0)
FROM anomaly_flags
UNION ALL
SELECT
    'purchase_before_checkout',
    SUM(purchase_before_checkout),
    SUM(first_purchase_time IS NOT NULL),
    SUM(purchase_before_checkout) / NULLIF(SUM(first_purchase_time IS NOT NULL), 0)
FROM anomaly_flags;

CREATE OR REPLACE VIEW vw_funnel_strict_comparison AS
WITH comparison AS (
    SELECT
        SUM(first_view_time IS NOT NULL) AS presence_view,
        SUM(first_cart_time IS NOT NULL) AS presence_cart,
        SUM(first_checkout_time IS NOT NULL) AS presence_checkout,
        SUM(first_purchase_time IS NOT NULL) AS presence_purchase,
        SUM(first_view_time IS NOT NULL) AS strict_view,
        SUM(first_view_time IS NOT NULL
            AND first_cart_time >= first_view_time) AS strict_cart,
        SUM(first_view_time IS NOT NULL
            AND first_cart_time >= first_view_time
            AND first_checkout_time >= first_cart_time) AS strict_checkout,
        SUM(first_view_time IS NOT NULL
            AND first_cart_time >= first_view_time
            AND first_checkout_time >= first_cart_time
            AND first_purchase_time >= first_checkout_time) AS strict_purchase
    FROM vw_session_funnel_flags
)
SELECT 'View' AS stage, presence_view AS event_presence_sessions,
       strict_view AS strict_sequence_sessions,
       presence_view - strict_view AS excluded_anomaly_sessions
FROM comparison
UNION ALL
SELECT 'Add to Cart', presence_cart, strict_cart, presence_cart - strict_cart
FROM comparison
UNION ALL
SELECT 'Checkout', presence_checkout, strict_checkout, presence_checkout - strict_checkout
FROM comparison
UNION ALL
SELECT 'Purchase', presence_purchase, strict_purchase, presence_purchase - strict_purchase
FROM comparison;

SELECT
    stage_order,
    stage,
    sessions,
    ROUND(step_conversion, 4) AS step_conversion,
    ROUND(step_drop_off, 4) AS step_drop_off,
    ROUND(overall_conversion, 4) AS overall_conversion
FROM vw_funnel_stage_summary
ORDER BY stage_order;

SELECT
    anomaly_type,
    anomaly_sessions,
    relevant_stage_sessions,
    ROUND(anomaly_share, 6) AS anomaly_share
FROM vw_funnel_sequence_qa;

SELECT stage, event_presence_sessions, strict_sequence_sessions, excluded_anomaly_sessions
FROM vw_funnel_strict_comparison
ORDER BY FIELD(stage, 'View', 'Add to Cart', 'Checkout', 'Purchase');

/* Immediate QA: presence funnel stages are nested in this dataset. */
SELECT 'presence_funnel_is_nested' AS check_name,
       0 AS expected_value,
       SUM(
           (first_cart_time IS NOT NULL AND first_view_time IS NULL)
           OR (first_checkout_time IS NOT NULL AND first_cart_time IS NULL)
           OR (first_purchase_time IS NOT NULL AND first_checkout_time IS NULL)
       ) AS actual_value,
       IF(SUM(
           (first_cart_time IS NOT NULL AND first_view_time IS NULL)
           OR (first_checkout_time IS NOT NULL AND first_cart_time IS NULL)
           OR (first_purchase_time IS NOT NULL AND first_checkout_time IS NULL)
       ) = 0, 'PASS', 'WARNING') AS status
FROM vw_session_funnel_flags;

