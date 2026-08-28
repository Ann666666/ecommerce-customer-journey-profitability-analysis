/*
Purpose: Build a complete first-purchase cohort matrix for month index 0–12.
Dialect: MySQL 8.0+
Final grain: One row per eligible cohort_month + month_index.
Metric: Monthly Repeat-purchase Activity Rate.
Important assumption: signup_date is not used because source chronology is unreliable.
*/

USE commerce_practice;

CREATE OR REPLACE VIEW vw_first_purchase_cohort AS
WITH RECURSIVE month_index AS (
    SELECT 0 AS month_index
    UNION ALL
    SELECT month_index + 1
    FROM month_index
    WHERE month_index < 12
),
dataset_max AS (
    SELECT CAST(DATE_FORMAT(MAX(order_time), '%Y-%m-01') AS DATE) AS max_order_month
    FROM vw_order_level_metrics
),
customer_cohort AS (
    SELECT
        customer_id,
        CAST(DATE_FORMAT(MIN(order_time), '%Y-%m-01') AS DATE) AS cohort_month
    FROM vw_order_level_metrics
    GROUP BY customer_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM customer_cohort
    GROUP BY cohort_month
),
eligible_grid AS (
    SELECT
        c.cohort_month,
        m.month_index,
        c.cohort_size
    FROM cohort_size c
    CROSS JOIN month_index m
    CROSS JOIN dataset_max d
    WHERE m.month_index <= TIMESTAMPDIFF(MONTH, c.cohort_month, d.max_order_month)
),
customer_activity AS (
    SELECT DISTINCT
        o.customer_id,
        CAST(DATE_FORMAT(o.order_time, '%Y-%m-01') AS DATE) AS activity_month
    FROM vw_order_level_metrics o
),
cohort_activity AS (
    SELECT
        c.cohort_month,
        TIMESTAMPDIFF(MONTH, c.cohort_month, a.activity_month) AS month_index,
        COUNT(DISTINCT a.customer_id) AS active_customers
    FROM customer_cohort c
    JOIN customer_activity a
      ON c.customer_id = a.customer_id
    WHERE TIMESTAMPDIFF(MONTH, c.cohort_month, a.activity_month) BETWEEN 0 AND 12
    GROUP BY c.cohort_month,
             TIMESTAMPDIFF(MONTH, c.cohort_month, a.activity_month)
)
SELECT
    g.cohort_month,
    g.month_index,
    g.cohort_size,
    COALESCE(a.active_customers, 0) AS active_customers,
    COALESCE(a.active_customers, 0) / NULLIF(g.cohort_size, 0)
      AS monthly_repeat_purchase_activity_rate
FROM eligible_grid g
LEFT JOIN cohort_activity a
  ON g.cohort_month = a.cohort_month
 AND g.month_index = a.month_index;

CREATE OR REPLACE VIEW vw_cohort_summary AS
SELECT
    month_index,
    COUNT(*) AS eligible_cohorts,
    SUM(cohort_size) AS eligible_customers,
    SUM(active_customers) AS active_customers,
    SUM(active_customers) / NULLIF(SUM(cohort_size), 0)
      AS weighted_monthly_repeat_purchase_activity_rate
FROM vw_first_purchase_cohort
WHERE month_index IN (1, 3, 6, 12)
GROUP BY month_index;

SELECT
    cohort_month,
    month_index,
    cohort_size,
    active_customers,
    ROUND(monthly_repeat_purchase_activity_rate, 4)
      AS monthly_repeat_purchase_activity_rate
FROM vw_first_purchase_cohort
ORDER BY cohort_month, month_index;

SELECT
    month_index,
    eligible_cohorts,
    eligible_customers,
    active_customers,
    ROUND(weighted_monthly_repeat_purchase_activity_rate, 4)
      AS weighted_monthly_repeat_purchase_activity_rate
FROM vw_cohort_summary
ORDER BY month_index;

/* Immediate QA: cohort membership and the eligible grid must reconcile. */
WITH RECURSIVE qa_month_index AS (
    SELECT 0 AS month_index
    UNION ALL
    SELECT month_index + 1
    FROM qa_month_index
    WHERE month_index < 12
),
qa_dataset_max AS (
    SELECT CAST(DATE_FORMAT(MAX(order_time), '%Y-%m-01') AS DATE) AS max_order_month
    FROM vw_order_level_metrics
),
qa_customer_cohort AS (
    SELECT
        customer_id,
        CAST(DATE_FORMAT(MIN(order_time), '%Y-%m-01') AS DATE) AS cohort_month
    FROM vw_order_level_metrics
    GROUP BY customer_id
),
qa_customer_activity AS (
    SELECT DISTINCT
        customer_id,
        CAST(DATE_FORMAT(order_time, '%Y-%m-01') AS DATE) AS activity_month
    FROM vw_order_level_metrics
),
qa_expected_grid AS (
    SELECT
        c.cohort_month,
        m.month_index
    FROM (SELECT DISTINCT cohort_month FROM qa_customer_cohort) c
    CROSS JOIN qa_month_index m
    CROSS JOIN qa_dataset_max d
    WHERE m.month_index <= TIMESTAMPDIFF(MONTH, c.cohort_month, d.max_order_month)
),
qa_observed_activity_cells AS (
    SELECT DISTINCT
        c.cohort_month,
        TIMESTAMPDIFF(MONTH, c.cohort_month, a.activity_month) AS month_index
    FROM qa_customer_cohort c
    JOIN qa_customer_activity a
      ON c.customer_id = a.customer_id
    WHERE TIMESTAMPDIFF(MONTH, c.cohort_month, a.activity_month) BETWEEN 0 AND 12
),
qa_expected_counts AS (
    SELECT
        COUNT(*) AS expected_cells,
        SUM(a.cohort_month IS NULL) AS expected_zero_activity_cells
    FROM qa_expected_grid g
    LEFT JOIN qa_observed_activity_cells a
      ON g.cohort_month = a.cohort_month
     AND g.month_index = a.month_index
)
SELECT 'cohort_customers_reconcile' AS check_name,
       (SELECT COUNT(DISTINCT customer_id) FROM vw_order_level_metrics) AS expected_value,
       SUM(cohort_size) AS actual_value,
       IF((SELECT COUNT(DISTINCT customer_id) FROM vw_order_level_metrics)
          = SUM(cohort_size), 'PASS', 'WARNING') AS status
FROM vw_first_purchase_cohort
WHERE month_index = 0
UNION ALL
SELECT 'month_zero_is_complete',
       0,
       SUM(active_customers <> cohort_size),
       IF(SUM(active_customers <> cohort_size) = 0, 'PASS', 'WARNING')
FROM vw_first_purchase_cohort
WHERE month_index = 0
UNION ALL
SELECT 'eligible_grid_is_complete',
       (SELECT expected_cells FROM qa_expected_counts),
       COUNT(*),
       IF(COUNT(*) = (SELECT expected_cells FROM qa_expected_counts), 'PASS', 'FAIL')
FROM vw_first_purchase_cohort
UNION ALL
SELECT 'eligible_zero_activity_cells_retained',
       (SELECT expected_zero_activity_cells FROM qa_expected_counts),
       SUM(active_customers = 0),
       IF(SUM(active_customers = 0)
          = (SELECT expected_zero_activity_cells FROM qa_expected_counts),
          'PASS', 'FAIL')
FROM vw_first_purchase_cohort;
