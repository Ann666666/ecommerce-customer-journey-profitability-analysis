# Grain Map

This document defines the row-level meaning of every source table and the safe analytical grain for each project module. The dataset is a fully synthetic Kaggle dataset; the grain rules below are based on the local files and validated key relationships.

## Source tables

| Table | Grain | Primary Key | Important Foreign Keys | Safe Metrics | Risks |
|---|---|---|---|---|---|
| `customers` | One row per registered customer | `customer_id` | — | registered customers, age distribution, country mix, marketing opt-in | `signup_date` is not reliable for lifecycle analysis because many sessions and orders predate signup |
| `sessions` | One row per browsing session | `session_id` | `customer_id → customers.customer_id` | sessions, sessions by source/device/country | a customer can have many sessions; joining directly to events expands rows |
| `events` | One row per clickstream event | `event_id` | `session_id → sessions.session_id`; nullable `product_id → products.product_id` | event counts; distinct sessions reaching each funnel stage | event counts are not session counts; event presence does not guarantee strict timestamp sequence |
| `orders` | One row per completed order | `order_id` | `customer_id → customers.customer_id` | orders, net revenue, order-level discounts, AOV | joining to `order_items` creates multiple rows per order and can inflate order-level metrics |
| `order_items` | One source row per order line | no stable row key | `order_id → orders.order_id`; `product_id → products.product_id` | gross line revenue, quantity, extended product cost after joining products | duplicate-like rows exist; source rows must not be blindly deduplicated; aggregate to `order_id + product_id` for the canonical item model |
| `products` | One row per product/SKU | `product_id` | — | catalog price, unit cost, unit margin, category | product price is not revenue until multiplied by sold quantity |
| `reviews` | One row per review | `review_id` | `order_id → orders.order_id`; `product_id → products.product_id` | review count, average rating, low-rating count/rate | many review timestamps predate orders; review timing is not suitable for lifecycle analysis |

## Canonical analytical grains

| Analysis | Required Grain | Entity Definition | Grain Control |
|---|---|---|---|
| Session funnel | One row per session before stage aggregation | `session_id` | collapse events to first timestamp / existence flag per session before counting stages |
| Order metrics | One row per order | `order_id` | aggregate order items to `order_id` before joining to `orders` |
| Customer value | One row per purchasing customer | `customer_id` | aggregate the canonical order model by customer |
| Product/category profitability | One row per `order_id + product_id` | aggregated order-product item | combine duplicate-like source lines, allocate order discount by gross item revenue share |
| First-purchase cohort | One row per cohort-month | `cohort_month + month_index` | derive cohort from first order month; build an eligible 0–12 month scaffold and left join activity |
| Review analysis | One row per product/category in final result | product or category | aggregate reviews separately, then join to sales aggregates at the same product/category grain |

## Join rules

1. Never calculate AOV, order revenue, or profit per order directly on expanded `orders × order_items` rows.
2. Use `orders.total_usd` as the source of truth for net order revenue.
3. Use `SUM(quantity * unit_price_usd)` or `SUM(line_total_usd)` only for pre-discount gross merchandise value.
4. Allocate discounts to order-product rows using `gross_item_revenue / order_subtotal`.
5. Use `COUNT(DISTINCT session_id)` for funnel stages and label the result as sessions, not users.
6. Use `COUNT(DISTINCT customer_id)` only after the analysis question has explicitly moved to customer grain.

