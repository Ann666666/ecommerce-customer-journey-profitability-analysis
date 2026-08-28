# Metric Dictionary

The project uses the following canonical KPI definitions. Unless explicitly noted, monetary values are in USD.

## Revenue

| Metric | Definition | Grain / Notes |
|---|---|---|
| Gross Merchandise Value (GMV) / Gross Revenue | `SUM(order_items.quantity * order_items.unit_price_usd)` | before discount; may also be reconciled to `SUM(orders.subtotal_usd)` |
| Discount Amount | `SUM(orders.subtotal_usd - orders.total_usd)` | order-level discount in USD |
| Net Revenue | `SUM(orders.total_usd)` | after discount; canonical realized revenue in this dataset |
| Allocated Item Net Revenue | `gross_item_revenue / order_subtotal * order_net_revenue` | used only at `order_id + product_id` grain; not rounded before aggregation |

## Orders

| Metric | Definition | Grain / Notes |
|---|---|---|
| Orders | `COUNT(DISTINCT order_id)` | order grain |
| Units Sold | `SUM(quantity)` | physical units; not the same as order lines |
| Order Lines | source `order_items` row count | a source order can contain multiple lines and repeated SKUs |
| AOV | `SUM(net_revenue) / COUNT(DISTINCT order_id)` | net average order value |
| Units per Order | `SUM(total_units) / COUNT(DISTINCT order_id)` | calculated from the canonical order model |

## Profitability

| Metric | Definition | Grain / Notes |
|---|---|---|
| Product Cost | `SUM(quantity * products.cost_usd)` | extended merchandise cost; excludes shipping, tax, returns, and operating cost |
| Gross Profit Before Discount | `gross_revenue - product_cost` | pre-discount merchandise profit |
| Net Profit After Discount | `net_revenue - product_cost` | project-level contribution proxy; not accounting profit |
| Net Margin | `net_profit / NULLIF(net_revenue, 0)` | weighted margin; calculate from summed dollars, not average row margins |
| Profit per Order | `SUM(net_profit) / COUNT(DISTINCT order_id)` | order-level profitability metric |

## Customer

| Metric | Definition |
|---|---|
| Purchasing Customers | customers with at least one order |
| One-time Buyers | purchasing customers with exactly one distinct order |
| Repeat Buyers | purchasing customers with two or more distinct orders |
| Repeat Buyer Rate | repeat buyers / purchasing customers |
| Customer Net Revenue | `SUM(order_level.net_revenue)` by customer |
| Revenue per Customer | segment net revenue / segment customers |
| Purchase Frequency | distinct orders per purchasing customer |

## Session funnel

All funnel metrics use session grain, not user grain.

| Metric | Definition |
|---|---|
| Sessions | distinct `session_id` in `sessions` |
| View Sessions | distinct sessions with at least one `page_view` event |
| Add-to-cart Sessions | distinct sessions with at least one `add_to_cart` event |
| Checkout Sessions | distinct sessions with at least one `checkout` event |
| Purchase Sessions | distinct sessions with at least one `purchase` event |
| Step Conversion | sessions reaching current stage / sessions reaching prior stage |
| Step Drop-off | `1 - step_conversion` |
| Overall Session Conversion | purchase sessions / view sessions |

The primary funnel is an event-presence funnel. A separate QA result quantifies sessions that violate strict timestamp sequence.

## First-purchase cohort

**Cohort definition:** calendar month of a customer's first completed order.

**Metric name:** Monthly Repeat-purchase Activity Rate.

- Denominator: distinct customers in the first-purchase cohort.
- Numerator: distinct cohort customers with at least one order in the specified calendar month index.
- Month 0: the first-purchase month and therefore 100% by definition.
- Eligible horizon: month index 0–12, constrained by the latest observed order month.
- Eligible months with no active customers are reported as zero rather than omitted.

## RFM

| Metric | Definition |
|---|---|
| Recency | calendar days between the dataset's latest order date and the customer's latest order date; lower is better |
| Frequency | distinct orders per purchasing customer; higher is better |
| Monetary | `SUM(orders.total_usd)` per customer; net customer revenue; higher is better |

RFM scores and segment rules are documented in `docs/rfm_methodology.md`.

## Review quality

| Metric | Definition |
|---|---|
| Average Rating | arithmetic mean of review rating |
| Low-rating Count | reviews with `rating <= 2` |
| Low-rating Rate | low-rating count / all reviews |
| Review Coverage | distinct reviewed `order_id + product_id` pairs / sold `order_id + product_id` pairs |

Review metrics are descriptive. They do not establish that a category caused customer satisfaction outcomes.

