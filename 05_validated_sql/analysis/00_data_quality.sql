/*
Purpose: Validate source-table integrity, reconciliation, join cardinality, and
         known timestamp anomalies before analytical modeling.
Dialect: MySQL 8.0+
Final grain: One row per QA check in vw_data_quality_summary.
Important assumption: duplicate-like order-item rows are inspected but not
                      deleted because the source has no stable order_item_id.
*/

USE commerce_practice;

CREATE OR REPLACE VIEW vw_data_quality_summary AS

/* Row counts */
SELECT 'row_count' AS check_group, 'customers_rows' AS check_name,
       COUNT(*) AS result_value, 'PASS' AS status,
       'Source row count; expected from the loaded file.' AS interpretation
FROM customers
UNION ALL
SELECT 'row_count', 'products_rows', COUNT(*), 'PASS', 'Source row count.' FROM products
UNION ALL
SELECT 'row_count', 'sessions_rows', COUNT(*), 'PASS', 'Source row count.' FROM sessions
UNION ALL
SELECT 'row_count', 'events_rows', COUNT(*), 'PASS', 'Source row count.' FROM events
UNION ALL
SELECT 'row_count', 'orders_rows', COUNT(*), 'PASS', 'Source row count.' FROM orders
UNION ALL
SELECT 'row_count', 'order_items_rows', COUNT(*), 'PASS', 'Source row count.' FROM order_items
UNION ALL
SELECT 'row_count', 'reviews_rows', COUNT(*), 'PASS', 'Source row count.' FROM reviews

/* Primary-key uniqueness */
UNION ALL
SELECT 'primary_key', 'duplicate_customer_ids', COUNT(*) - COUNT(DISTINCT customer_id),
       IF(COUNT(*) = COUNT(DISTINCT customer_id), 'PASS', 'WARNING'),
       'customer_id should be unique and non-null.'
FROM customers
UNION ALL
SELECT 'primary_key', 'duplicate_product_ids', COUNT(*) - COUNT(DISTINCT product_id),
       IF(COUNT(*) = COUNT(DISTINCT product_id), 'PASS', 'WARNING'),
       'product_id should be unique and non-null.'
FROM products
UNION ALL
SELECT 'primary_key', 'duplicate_session_ids', COUNT(*) - COUNT(DISTINCT session_id),
       IF(COUNT(*) = COUNT(DISTINCT session_id), 'PASS', 'WARNING'),
       'session_id should be unique and non-null.'
FROM sessions
UNION ALL
SELECT 'primary_key', 'duplicate_event_ids', COUNT(*) - COUNT(DISTINCT event_id),
       IF(COUNT(*) = COUNT(DISTINCT event_id), 'PASS', 'WARNING'),
       'event_id should be unique and non-null.'
FROM events
UNION ALL
SELECT 'primary_key', 'duplicate_order_ids', COUNT(*) - COUNT(DISTINCT order_id),
       IF(COUNT(*) = COUNT(DISTINCT order_id), 'PASS', 'WARNING'),
       'order_id should be unique and non-null.'
FROM orders
UNION ALL
SELECT 'primary_key', 'duplicate_review_ids', COUNT(*) - COUNT(DISTINCT review_id),
       IF(COUNT(*) = COUNT(DISTINCT review_id), 'PASS', 'WARNING'),
       'review_id should be unique and non-null.'
FROM reviews

/* Foreign-key integrity */
UNION ALL
SELECT 'foreign_key', 'orphan_sessions_customer', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Sessions whose customer_id is absent from customers.'
FROM sessions s LEFT JOIN customers c ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'foreign_key', 'orphan_events_session', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Events whose session_id is absent from sessions.'
FROM events e LEFT JOIN sessions s ON e.session_id = s.session_id
WHERE s.session_id IS NULL
UNION ALL
SELECT 'foreign_key', 'orphan_events_product_nonnull', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Non-null event product_ids absent from products.'
FROM events e LEFT JOIN products p ON e.product_id = p.product_id
WHERE e.product_id IS NOT NULL AND p.product_id IS NULL
UNION ALL
SELECT 'foreign_key', 'orphan_orders_customer', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Orders whose customer_id is absent from customers.'
FROM orders o LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'foreign_key', 'orphan_order_items_order', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Order items whose order_id is absent from orders.'
FROM order_items oi LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'foreign_key', 'orphan_order_items_product', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Order items whose product_id is absent from products.'
FROM order_items oi LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'foreign_key', 'orphan_reviews_order', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Reviews whose order_id is absent from orders.'
FROM reviews r LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'foreign_key', 'orphan_reviews_product', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Reviews whose product_id is absent from products.'
FROM reviews r LEFT JOIN products p ON r.product_id = p.product_id
WHERE p.product_id IS NULL

/* Required-field null checks */
UNION ALL
SELECT 'null_check', 'customers_required_null_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Rows with a null in a required customer field.'
FROM customers
WHERE customer_id IS NULL OR email IS NULL OR country IS NULL OR signup_date IS NULL
UNION ALL
SELECT 'null_check', 'products_required_null_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Rows with a null in a required product field.'
FROM products
WHERE product_id IS NULL OR category IS NULL OR price_usd IS NULL OR cost_usd IS NULL
UNION ALL
SELECT 'null_check', 'sessions_required_null_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Rows with a null in a required session field.'
FROM sessions
WHERE session_id IS NULL OR customer_id IS NULL OR start_time IS NULL OR device IS NULL OR source IS NULL
UNION ALL
SELECT 'null_check', 'events_required_null_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Rows with a null in a required event field; event product attributes are stage-dependent and optional.'
FROM events
WHERE event_id IS NULL OR session_id IS NULL OR `timestamp` IS NULL OR event_type IS NULL
UNION ALL
SELECT 'null_check', 'orders_required_null_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Rows with a null in a required order field.'
FROM orders
WHERE order_id IS NULL OR customer_id IS NULL OR order_time IS NULL
   OR subtotal_usd IS NULL OR total_usd IS NULL OR discount_pct IS NULL
UNION ALL
SELECT 'null_check', 'order_items_required_null_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Rows with a null in a required order-item field.'
FROM order_items
WHERE order_id IS NULL OR product_id IS NULL OR unit_price_usd IS NULL
   OR quantity IS NULL OR line_total_usd IS NULL
UNION ALL
SELECT 'null_check', 'reviews_required_null_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Rows with a null in a required review field.'
FROM reviews
WHERE review_id IS NULL OR order_id IS NULL OR product_id IS NULL
   OR rating IS NULL OR review_time IS NULL

/* Domain and arithmetic validity */
UNION ALL
SELECT 'validity', 'invalid_customer_age_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Age must be greater than zero and no more than 120.'
FROM customers
WHERE age <= 0 OR age > 120
UNION ALL
SELECT 'validity', 'invalid_product_value_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Product price and cost must be non-negative.'
FROM products
WHERE price_usd < 0 OR cost_usd < 0
UNION ALL
SELECT 'validity', 'product_margin_mismatch_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Stored product margin should equal price less cost within 0.01 USD.'
FROM products
WHERE ABS((price_usd - cost_usd) - margin_usd) > 0.01
UNION ALL
SELECT 'validity', 'invalid_order_value_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Order values must be non-negative and net total cannot exceed subtotal.'
FROM orders
WHERE subtotal_usd < 0 OR total_usd < 0 OR total_usd > subtotal_usd
UNION ALL
SELECT 'validity', 'unexpected_discount_values', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Expected synthetic discount levels are 0, 5, 10, 15, and 20 percent.'
FROM orders
WHERE discount_pct NOT IN (0, 5, 10, 15, 20)
UNION ALL
SELECT 'validity', 'invalid_order_item_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Order-item quantity must be positive and monetary values non-negative.'
FROM order_items
WHERE quantity <= 0 OR unit_price_usd < 0 OR line_total_usd < 0
UNION ALL
SELECT 'validity', 'order_item_extension_mismatch_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Line total should equal unit price multiplied by quantity within 0.01 USD.'
FROM order_items
WHERE ABS(unit_price_usd * quantity - line_total_usd) > 0.01
UNION ALL
SELECT 'validity', 'invalid_review_rating_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Review rating must be between 1 and 5.'
FROM reviews
WHERE rating NOT BETWEEN 1 AND 5
UNION ALL
SELECT 'validity', 'unexpected_event_type_rows', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Event type should belong to the documented customer-journey stages.'
FROM events
WHERE event_type NOT IN ('page_view', 'add_to_cart', 'checkout', 'purchase')

/* Monetary reconciliation; 0.01 USD tolerance */
UNION ALL
SELECT 'reconciliation', 'orders_with_item_subtotal_mismatch', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Order-item line totals should reconcile to order subtotal within 0.01 USD.'
FROM orders o
JOIN (
    SELECT order_id, SUM(line_total_usd) AS item_subtotal
    FROM order_items
    GROUP BY order_id
) i ON o.order_id = i.order_id
WHERE ABS(o.subtotal_usd - i.item_subtotal) > 0.01
UNION ALL
SELECT 'reconciliation', 'orders_with_discount_total_mismatch', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Rounded subtotal less stated discount percentage should equal order total within 0.01 USD.'
FROM orders
WHERE ABS(ROUND(subtotal_usd * (1 - discount_pct / 100), 2) - total_usd) > 0.01

/* Join cardinality */
UNION ALL
SELECT 'join_cardinality', 'orders_without_items', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Every order should have at least one order-item row.'
FROM orders o LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
UNION ALL
SELECT 'join_cardinality', 'max_source_lines_per_order', MAX(source_lines),
       'PASS', 'Expected one-to-many relationship; aggregate items before order-level metrics.'
FROM (
    SELECT order_id, COUNT(*) AS source_lines
    FROM order_items
    GROUP BY order_id
) x
UNION ALL
SELECT 'join_cardinality', 'reviews_product_not_in_order', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Reviewed product should appear in the reviewed order.'
FROM reviews r
LEFT JOIN order_items oi
  ON r.order_id = oi.order_id AND r.product_id = oi.product_id
WHERE oi.order_id IS NULL

/* Timestamp anomalies are preserved and documented, not deleted. */
UNION ALL
SELECT 'timestamp_anomaly', 'sessions_before_signup', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'LIMITATION'),
       'Synthetic-data chronology limitation; do not use signup_date for lifecycle inference.'
FROM sessions s JOIN customers c ON s.customer_id = c.customer_id
WHERE s.start_time < c.signup_date
UNION ALL
SELECT 'timestamp_anomaly', 'orders_before_signup', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'LIMITATION'),
       'Synthetic-data chronology limitation; first-purchase cohort therefore uses orders only.'
FROM orders o JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_time < c.signup_date
UNION ALL
SELECT 'timestamp_anomaly', 'reviews_before_order', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'LIMITATION'),
       'Synthetic-data chronology limitation; review timing is out of scope.'
FROM reviews r JOIN orders o ON r.order_id = o.order_id
WHERE r.review_time < o.order_time
UNION ALL
SELECT 'timestamp_anomaly', 'checkout_before_add_to_cart_sessions', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'LIMITATION'),
       'Sessions whose first checkout timestamp precedes first add-to-cart timestamp.'
FROM (
    SELECT session_id,
           MIN(CASE WHEN event_type = 'add_to_cart' THEN `timestamp` END) AS cart_time,
           MIN(CASE WHEN event_type = 'checkout' THEN `timestamp` END) AS checkout_time
    FROM events
    GROUP BY session_id
) stage_time
WHERE checkout_time IS NOT NULL
  AND cart_time IS NOT NULL
  AND checkout_time < cart_time

/* Duplicate-like order items */
UNION ALL
SELECT 'duplicate_like', 'exact_duplicate_order_item_extra_rows',
       COALESCE(SUM(source_row_count - 1), 0),
       IF(COALESCE(SUM(source_row_count - 1), 0) = 0, 'PASS', 'WARNING'),
       'Do not delete automatically; source lacks order_item_id and totals reconcile.'
FROM (
    SELECT order_id, product_id, unit_price_usd, quantity, line_total_usd,
           COUNT(*) AS source_row_count
    FROM order_items
    GROUP BY order_id, product_id, unit_price_usd, quantity, line_total_usd
    HAVING COUNT(*) > 1
) duplicates
UNION ALL
SELECT 'duplicate_like', 'duplicate_order_product_groups', COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'WARNING'),
       'Canonical item model aggregates repeated order-product rows rather than deleting them.'
FROM (
    SELECT order_id, product_id
    FROM order_items
    GROUP BY order_id, product_id
    HAVING COUNT(*) > 1
) duplicate_products;

CREATE OR REPLACE VIEW vw_data_profile_summary AS
SELECT 'customer_age' AS profile_metric,
       CAST(MIN(age) AS DECIMAL(20, 4)) AS min_value,
       CAST(MAX(age) AS DECIMAL(20, 4)) AS max_value,
       CAST(AVG(age) AS DECIMAL(20, 4)) AS avg_value,
       COUNT(*) AS population_rows,
       'Profile only; values are not removed based on range alone.' AS interpretation
FROM customers
UNION ALL
SELECT 'product_price_usd',
       CAST(MIN(price_usd) AS DECIMAL(20, 4)),
       CAST(MAX(price_usd) AS DECIMAL(20, 4)),
       CAST(AVG(price_usd) AS DECIMAL(20, 4)),
       COUNT(*),
       'Catalog price distribution.'
FROM products
UNION ALL
SELECT 'product_cost_usd',
       CAST(MIN(cost_usd) AS DECIMAL(20, 4)),
       CAST(MAX(cost_usd) AS DECIMAL(20, 4)),
       CAST(AVG(cost_usd) AS DECIMAL(20, 4)),
       COUNT(*),
       'Catalog product-cost distribution.'
FROM products
UNION ALL
SELECT 'order_subtotal_usd',
       CAST(MIN(subtotal_usd) AS DECIMAL(20, 4)),
       CAST(MAX(subtotal_usd) AS DECIMAL(20, 4)),
       CAST(AVG(subtotal_usd) AS DECIMAL(20, 4)),
       COUNT(*),
       'Gross basket value before discount.'
FROM orders
UNION ALL
SELECT 'order_total_usd',
       CAST(MIN(total_usd) AS DECIMAL(20, 4)),
       CAST(MAX(total_usd) AS DECIMAL(20, 4)),
       CAST(AVG(total_usd) AS DECIMAL(20, 4)),
       COUNT(*),
       'Net order value after discount.'
FROM orders
UNION ALL
SELECT 'order_item_quantity',
       CAST(MIN(quantity) AS DECIMAL(20, 4)),
       CAST(MAX(quantity) AS DECIMAL(20, 4)),
       CAST(AVG(quantity) AS DECIMAL(20, 4)),
       COUNT(*),
       'Source-line quantity distribution.'
FROM order_items
UNION ALL
SELECT 'source_lines_per_order',
       CAST(MIN(source_lines) AS DECIMAL(20, 4)),
       CAST(MAX(source_lines) AS DECIMAL(20, 4)),
       CAST(AVG(source_lines) AS DECIMAL(20, 4)),
       COUNT(*),
       'Use this profile to confirm the one-to-many orders-to-items relationship.'
FROM (
    SELECT order_id, COUNT(*) AS source_lines
    FROM order_items
    GROUP BY order_id
) order_line_profile
UNION ALL
SELECT 'events_per_session',
       CAST(MIN(session_events) AS DECIMAL(20, 4)),
       CAST(MAX(session_events) AS DECIMAL(20, 4)),
       CAST(AVG(session_events) AS DECIMAL(20, 4)),
       COUNT(*),
       'Session event-count distribution; no rows are removed as outliers.'
FROM (
    SELECT s.session_id, COUNT(e.event_id) AS session_events
    FROM sessions s
    LEFT JOIN events e ON s.session_id = e.session_id
    GROUP BY s.session_id
) session_event_profile;

SELECT check_group, check_name, result_value, status, interpretation
FROM vw_data_quality_summary
ORDER BY check_group, check_name;

SELECT profile_metric, min_value, max_value, avg_value, population_rows, interpretation
FROM vw_data_profile_summary
ORDER BY profile_metric;

/* Review the source-row patterns behind duplicate-like order items. */
SELECT
    order_id,
    product_id,
    unit_price_usd,
    quantity,
    line_total_usd,
    COUNT(*) AS source_row_count
FROM order_items
GROUP BY order_id, product_id, unit_price_usd, quantity, line_total_usd
HAVING COUNT(*) > 1
ORDER BY source_row_count DESC, order_id, product_id
LIMIT 100;
