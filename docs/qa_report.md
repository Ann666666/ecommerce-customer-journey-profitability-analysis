# QA and Reconciliation Report

## Status Definitions

- **PASS** — the check reconciles or no invalid records were found.
- **FAIL** — independently calculated expected and actual results do not reconcile; this blocks technical freeze.
- **WARNING** — the source contains an ambiguity that requires controlled modeling.
- **LIMITATION** — the issue reflects the synthetic-data design or missing information and cannot be repaired without inventing facts.

## Source Integrity

| Check | Result | Status | Interpretation |
|---|---:|---|---|
| Customers row count | 20,000 | PASS | Source file loaded completely |
| Products row count | 1,197 | PASS | Source file loaded completely |
| Sessions row count | 120,000 | PASS | Source file loaded completely |
| Events row count | 760,958 | PASS | Source file loaded completely |
| Orders row count | 33,580 | PASS | Source file loaded completely |
| Order items row count | 59,163 | PASS | Source file loaded completely |
| Reviews row count | 10,780 | PASS | Source file loaded completely |
| Primary-key duplicate checks | 0 across six keyed tables | PASS | All documented primary keys are unique |
| Foreign-key orphan checks | 0 across tested relationships | PASS | Tested child records resolve to their parent keys |
| Required-field null checks | 0 | PASS | No nulls in modeled required fields across all seven tables |
| Invalid domain/arithmetic checks | 0 | PASS | Prices, quantities, ratings, discounts, event types, and stored arithmetic pass |

## Financial Reconciliation

| Check | Expected | Actual | Status | Interpretation |
|---|---:|---:|---|---|
| Order-item subtotal mismatches | 0 orders | 0 orders | PASS | Line totals reconcile to order subtotal within $0.01 |
| Discount-total mismatches | 0 orders | 0 orders | PASS | Rounded discount arithmetic reconciles to order total |
| Canonical order rows | 33,580 | 33,580 | PASS | One row per order |
| Unique order IDs in order model | 33,580 | 33,580 | PASS | No row multiplication |
| Net revenue | $4,493,217.47 | $4,493,217.47 | PASS | Canonical order model reconciles to `orders.total_usd` |
| Units | 77,106 | 77,106 | PASS | Units use `SUM(quantity)`, not item row count |
| Product cost | $3,122,310.56 | $3,122,310.56 | PASS | Extended item cost reconciles across models |
| Item allocated net revenue | $4,493,217.47 | $4,493,217.47 | PASS | Proportional allocation returns to order totals |
| Item allocated net profit | $1,370,906.91 | $1,370,906.91 | PASS | Item and order profitability reconcile |
| Category net revenue | $4,493,217.47 | $4,493,217.47 | PASS | Category model preserves total net revenue |

## Analytical Model QA

| Check | Result | Status | Interpretation |
|---|---:|---|---|
| Purchasing customers | 16,268 | PASS | Customer-value model contains one row per purchasing customer |
| RFM customers | 16,268 | PASS | All purchasing customers receive one segment |
| RFM orders | 33,580 | PASS | Frequency reconciles to canonical order count |
| RFM monetary | $4,493,217.47 | PASS | Monetary reconciles to net revenue |
| Funnel sessions | 120,000 | PASS | One row per source session |
| Presence funnel nesting violations | 0 | PASS | Each later event stage also exists at prior stages |
| Cohort customers | 16,268 | PASS | Each purchasing customer belongs to one first-purchase cohort |
| Eligible cohort-month cells | 832 | PASS | Actual cohort output size matches an independently reconstructed eligible grid |
| Eligible zero-activity cells retained | 13 | PASS | Actual zero-activity cells match an independent expected count built from the eligible grid and observed activity cells |

## Warnings and Limitations

| Check | Result | Status | Classification | Interpretation |
|---|---:|---|---|---|
| Exact duplicate-like item extra rows | 73 | WARNING | Modeling assumption | Kept because no item ID exists and order totals reconcile |
| Repeated order-product groups | 110 | WARNING | Modeling assumption | Aggregated to `order_id + product_id` in the item model |
| Sessions before signup | 60,411 | LIMITATION | Synthetic-data limitation | Signup-based lifecycle analysis is unreliable |
| Orders before signup | 16,923 | LIMITATION | Synthetic-data limitation | First-purchase cohorts use orders only |
| Reviews before order | 5,482 | LIMITATION | Synthetic-data limitation | Review timing is excluded |
| Checkout before add-to-cart | 118 sessions | LIMITATION | Synthetic-data limitation | 0.26% of checkout sessions violate strict sequence |
| Presence versus strict purchase | 83 sessions | LIMITATION | Synthetic-data limitation | Strict purchase count is 0.25% lower than presence count |

No source rows were silently deleted. The duplicate-like rows are ambiguous rather than proven data errors, and the chronology issues are retained as explicit limitations.

The cohort grid-size and zero-activity checks are independently reconstructed from the canonical order model. Either check now returns `FAIL` if the cohort output no longer preserves the expected eligible grid or zero-activity cells.

## Reproducibility

- Source QA: `05_validated_sql/analysis/00_data_quality.sql`
- Order model: `05_validated_sql/analysis/01_order_level_metrics.sql`
- Item model: `05_validated_sql/analysis/02_item_level_profitability.sql`
- Consolidated reconciliation: `05_validated_sql/analysis/99_qa_reconciliation.sql`
- Machine-readable results: `06_validated_outputs/qa/data_quality_summary.csv` and `06_validated_outputs/qa/model_reconciliation_summary.csv`
