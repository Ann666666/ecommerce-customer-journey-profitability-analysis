# RFM Segmentation Methodology

## Purpose

The RFM model separates purchasing customers by recency, order frequency, and net monetary contribution. It is a descriptive portfolio segmentation, not a prediction of future customer value or churn.

## Base Population and Grain

- Population: customers with at least one order.
- Base grain: one row per purchasing customer.
- Purchasing customers: 16,268.
- Anchor date: `2025-10-31`, the latest order date in the dataset.
- Source: `vw_order_level_metrics`, which is unique at `order_id`.

## Metric Definitions

| Component | Definition | Direction |
|---|---|---|
| Recency | Days between the dataset anchor date and the customer's latest order date | Lower is better |
| Frequency | Distinct orders per customer | Higher is better |
| Monetary | Sum of `orders.total_usd` by customer | Higher is better |

Monetary uses net revenue after discount. It does not use the original `SUM(unit_price_usd)` logic.

## Scoring

### Recency score

`NTILE(5)` is applied with recency sorted descending, so the most recent customers receive the highest score.

| R score | Observed recency range (days) | Customers |
|---:|---:|---:|
| 5 | 0–222 | 3,253 |
| 4 | 222–489 | 3,253 |
| 3 | 489–850 | 3,254 |
| 2 | 850–1,337 | 3,254 |
| 1 | 1,337–2,130 | 3,254 |

Boundary values can appear in adjacent tiles because several customers share the same recency. `customer_id` provides deterministic tie-breaking.

### Frequency score

Frequency is highly discrete and concentrated: 38.25% of buyers have one order and 32.67% have two. `NTILE()` would split identical order counts into different scores, so explicit bands are used.

| F score | Orders | Customers |
|---:|---:|---:|
| 1 | 1 | 6,223 |
| 2 | 2 | 5,315 |
| 3 | 3 | 2,960 |
| 4 | 4 | 1,194 |
| 5 | 5+ | 576 |

### Monetary score

`NTILE(5)` is applied with net monetary value sorted ascending, so the highest-value customers receive the highest score.

| M score | Observed net monetary range (USD) | Customers |
|---:|---:|---:|
| 5 | 430.46–3,026.42 | 3,253 |
| 4 | 257.02–430.40 | 3,253 |
| 3 | 151.64–257.01 | 3,254 |
| 2 | 73.76–151.47 | 3,254 |
| 1 | 2.80–73.75 | 3,254 |

## Segment Rules

Rules are evaluated from top to bottom so each customer receives exactly one segment.

| Segment | Rule | Analytical meaning |
|---|---|---|
| Champions | `R >= 4 AND F >= 4 AND M >= 4` | Recent, frequent, and high-value customers |
| Loyal | `F >= 4 AND R >= 3` | High-frequency customers not already classified as Champions |
| High-value at Risk | `R <= 2 AND M >= 4` | Historically valuable customers with low recent activity |
| New / Promising | `R >= 4 AND frequency <= 2` | Recent customers with limited order history |
| Dormant | `R <= 2 AND frequency <= 2 AND M <= 3` | Low-frequency, low-to-mid value, inactive customers |
| Established / Mid-value | All remaining customers | Mixed middle group without an extreme RFM profile |

These labels are analytical shorthand. Because the data is synthetic and spans almost six years, they should not be interpreted as production CRM rules without business calibration.

## Validation

| Check | Result |
|---|---:|
| Segment customers | 16,268 |
| Distinct purchasing customers | 16,268 |
| Orders represented | 33,580 |
| RFM net monetary | $4,493,217.47 |
| Canonical net revenue | $4,493,217.47 |

All checks pass. SQL implementation: `05_validated_sql/analysis/05_rfm_segmentation.sql`.
