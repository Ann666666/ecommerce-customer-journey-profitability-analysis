/*
Purpose: Compare category scale, allocated net profitability, and review signals.
Dialect: MySQL 8.0+
Final grain: One row per product category.
Important assumption: order-level discounts are allocated to items in proportion
to each item's share of the order subtotal.
*/

USE commerce_practice;

CREATE OR REPLACE VIEW vw_category_portfolio AS
WITH category_sales AS (
    SELECT
        category,
        SUM(quantity) AS units,
        COUNT(DISTINCT order_id) AS orders,
        COUNT(DISTINCT customer_id) AS purchasing_customers,
        COUNT(*) AS sold_order_product_pairs,
        SUM(gross_item_revenue) AS gross_revenue,
        SUM(allocated_net_revenue) AS net_revenue,
        SUM(net_item_profit) AS net_profit
    FROM vw_item_level_profitability
    GROUP BY category
),
category_reviews AS (
    SELECT
        p.category,
        COUNT(*) AS review_count,
        COUNT(DISTINCT CONCAT(r.order_id, '|', r.product_id)) AS reviewed_order_product_pairs,
        AVG(r.rating) AS avg_rating,
        SUM(r.rating <= 2) AS low_rating_count
    FROM reviews r
    JOIN products p
      ON r.product_id = p.product_id
    GROUP BY p.category
),
combined AS (
    SELECT
        s.category,
        s.units,
        s.orders,
        s.purchasing_customers,
        s.sold_order_product_pairs,
        s.gross_revenue,
        s.net_revenue,
        s.net_profit,
        COALESCE(r.review_count, 0) AS review_count,
        COALESCE(r.reviewed_order_product_pairs, 0) AS reviewed_order_product_pairs,
        r.avg_rating,
        COALESCE(r.low_rating_count, 0) AS low_rating_count
    FROM category_sales s
    LEFT JOIN category_reviews r
      ON s.category = r.category
)
SELECT
    category,
    DENSE_RANK() OVER (ORDER BY net_revenue DESC) AS revenue_rank,
    units,
    orders,
    purchasing_customers,
    gross_revenue,
    net_revenue,
    net_revenue / NULLIF(SUM(net_revenue) OVER (), 0) AS revenue_share,
    net_profit,
    net_profit / NULLIF(net_revenue, 0) AS net_margin,
    net_revenue / NULLIF(orders, 0) AS net_revenue_per_category_order,
    avg_rating,
    review_count,
    reviewed_order_product_pairs / NULLIF(sold_order_product_pairs, 0) AS review_coverage,
    low_rating_count,
    low_rating_count / NULLIF(review_count, 0) AS low_rating_rate
FROM combined;

SELECT
    category,
    revenue_rank,
    units,
    orders,
    purchasing_customers,
    ROUND(gross_revenue, 2) AS gross_revenue,
    ROUND(net_revenue, 2) AS net_revenue,
    ROUND(revenue_share, 4) AS revenue_share,
    ROUND(net_profit, 2) AS net_profit,
    ROUND(net_margin, 4) AS net_margin,
    ROUND(net_revenue_per_category_order, 2) AS net_revenue_per_category_order,
    ROUND(avg_rating, 2) AS avg_rating,
    review_count,
    ROUND(review_coverage, 4) AS review_coverage,
    low_rating_count,
    ROUND(low_rating_rate, 4) AS low_rating_rate
FROM vw_category_portfolio
ORDER BY revenue_rank, category;

/* Immediate QA: category totals must reconcile to the canonical item model. */
SELECT 'category_units_reconcile' AS check_name,
       (SELECT SUM(quantity) FROM vw_item_level_profitability) AS expected_value,
       SUM(units) AS actual_value,
       IF((SELECT SUM(quantity) FROM vw_item_level_profitability) = SUM(units),
          'PASS', 'WARNING') AS status
FROM vw_category_portfolio
UNION ALL
SELECT 'category_net_revenue_reconcile',
       ROUND((SELECT SUM(allocated_net_revenue) FROM vw_item_level_profitability), 2),
       ROUND(SUM(net_revenue), 2),
       IF(ABS((SELECT SUM(allocated_net_revenue) FROM vw_item_level_profitability)
              - SUM(net_revenue)) <= 0.01, 'PASS', 'WARNING')
FROM vw_category_portfolio
UNION ALL
SELECT 'category_net_profit_reconcile',
       ROUND((SELECT SUM(net_item_profit) FROM vw_item_level_profitability), 2),
       ROUND(SUM(net_profit), 2),
       IF(ABS((SELECT SUM(net_item_profit) FROM vw_item_level_profitability)
              - SUM(net_profit)) <= 0.01, 'PASS', 'WARNING')
FROM vw_category_portfolio;

