# Limitations

## Source and Generalizability

- The Kaggle creator describes the dataset as fully synthetic. The records do not represent a real company, market, or customer base.
- Patterns are suitable for demonstrating analytical workflow, metric design, SQL, and QA. They should not be treated as evidence of real e-commerce benchmarks.
- No company, stakeholder request, campaign, operational event, or market explanation is inferred.

## Chronology

The synthetic generation process produces material lifecycle inconsistencies:

| Issue | Records / Sessions | Share of relevant population |
|---|---:|---:|
| Sessions before customer signup | 60,411 | 50.34% of sessions |
| Orders before customer signup | 16,923 | 50.40% of orders |
| Reviews before order timestamp | 5,482 | 50.85% of reviews |
| Checkout before add-to-cart | 118 | 0.26% of checkout sessions |

Consequences:

- `signup_date` is not used for retention, lifecycle, or acquisition-age analysis.
- Cohorts use first purchase month rather than signup month.
- Review timing is excluded from interpretation.
- The main funnel uses event presence. A strict sequence comparison is reported separately.

## Customer Journey Linkage

- Orders do not contain `session_id`, so a specific transaction cannot be joined directly to a specific clickstream session.
- The session funnel is calculated only from `sessions` and `events`.
- Source/device conversion uses purchase-event sessions, while source/device revenue uses the order attributes with the same category labels. This supports aggregate comparison but not individual-session attribution.

## Revenue and Profitability

- `orders.total_usd` is treated as net revenue after discount because that is the strongest available transaction metric.
- The dataset does not include taxes, shipping revenue/cost, returns, refunds, payment fees, customer acquisition cost, fulfillment cost, or operating expenses.
- `net_profit = net_revenue - product_cost` is therefore a merchandise contribution proxy, not accounting profit.
- Order-level discount is allocated to items in proportion to each item's share of order subtotal. This is a modeling assumption because item-level discount is unavailable.

## Discount Analysis

- Discount tiers are observed categories, not randomized treatments.
- No control group, assignment mechanism, campaign information, or counterfactual exists.
- The analysis is therefore descriptive discount economics, not discount ROI or causal uplift.

## Order-item Identity

- `order_items` has no stable `order_item_id`.
- There are 73 extra rows that are exact duplicates across the available fields and 110 repeated `order_id + product_id` groups.
- These rows are not deleted because source totals reconcile to `orders.subtotal_usd`; deleting them would change valid order value. The canonical item model aggregates to `order_id + product_id`.

## Reviews

- Review coverage is partial: approximately 17.25%–19.97% of sold order-product pairs by category receive a review.
- Review patterns are descriptive and may reflect selection bias.
- Ratings cannot be interpreted as the causal effect of a product category.

## Time Analysis

- The dataset ends on 2025-10-31, so 2025 is incomplete.
- Annual comparison is limited to 2024 Jan–Oct versus 2025 Jan–Oct.
- Synthetic monthly changes are not assigned real-world explanations.

## Cohort Metric

- The cohort measure is monthly repeat-purchase activity, not contractual retention or survival.
- A customer can be inactive in one month and active in a later month.
- Zero-activity eligible cells are retained, but the synthetic data should not be used as a real retention benchmark.

