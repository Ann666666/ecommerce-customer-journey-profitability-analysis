# Final Validated Tableau Dashboard

## Status

This directory contains the final validated portfolio dashboards. The original exploratory Tableau workbook remains unchanged in `04_original_visualization/` and is not a source for the final dashboard.

The packaged workbook is saved as:

`visualization/tableau/final_validated_dashboard.twbx`

Portfolio dashboard screenshots are stored as:

- `visualization/screenshots/01_executive_overview.png`
- `visualization/screenshots/02_customer_value_deep_dive.png`

## Approved Tableau Sources

The final dashboard must use only the frozen validated summary files below. Do not connect to original outputs, the original Tableau workbook, canonical detail models, or customer-level RFM detail.

| File | Grain | Primary Fields | Display Metrics |
|---|---|---|---|
| `06_validated_outputs/core_analysis/funnel_summary.csv` | One row per funnel stage | `stage_order`, `stage` | `sessions`, `step_conversion`, `step_drop_off`, `overall_conversion` |
| `06_validated_outputs/core_analysis/customer_value_segments.csv` | One row per customer type | `customer_type` | `customers`, `customer_share`, `orders`, `order_share`, `net_revenue`, `revenue_share`, `revenue_per_customer`, `aov`, `average_purchase_frequency`, `net_margin` |
| `06_validated_outputs/core_analysis/rfm_segment_summary.csv` | One row per RFM segment | `segment` | `customers`, `customer_share`, `net_revenue`, `revenue_share`, `orders`, `aov`, `average_frequency`, `average_recency`, `net_margin` |
| `06_validated_outputs/core_analysis/discount_economics.csv` | One row per observed discount tier | `discount_pct` | `orders`, `order_share`, `total_units`, `units_per_order`, `gross_basket_value_per_order`, `discount_amount_per_order`, `net_aov`, `net_profit_per_order`, `net_margin` |
| `06_validated_outputs/core_analysis/category_portfolio.csv` | One row per product category | `category`, `revenue_rank` | `units`, `orders`, `purchasing_customers`, `gross_revenue`, `net_revenue`, `revenue_share`, `net_profit`, `net_margin`, `net_revenue_per_category_order`, `avg_rating`, `review_count`, `review_coverage`, `low_rating_count`, `low_rating_rate` |

## Prohibited Sources

- `03_original_outputs/`
- `04_original_visualization/`
- `06_validated_outputs/model_outputs/order_level_metrics.csv`
- `06_validated_outputs/model_outputs/item_level_profitability.csv`
- `06_validated_outputs/core_analysis/rfm_customer_segments.csv`

## Workbook Plan

Workbook name: `final_validated_dashboard`

Main worksheets:

1. Executive KPI
2. Funnel
3. Customer Contribution
4. RFM Segment Portfolio
5. Discount Economics
6. Category Portfolio

Planned appendix worksheets:

1. QA Summary
2. Cohort Activity

The current approved-source list does not include QA files or `cohort_summary.csv`. These appendix worksheets must remain unbuilt unless their validated sources are separately authorized.

## Dashboard Configuration

- Fixed size: 1440 × 810 pixels
- Background: white
- Primary color: dark blue
- Highlight color: orange
- No 3D marks or decorative charts
- Restrained color use and direct data labels
- Descriptive language only; do not present discount patterns as causal or as ROI
