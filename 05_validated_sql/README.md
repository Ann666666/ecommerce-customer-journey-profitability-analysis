# Validated SQL Run Order

The SQL uses MySQL 8.0+ syntax. Run the files in the following order after loading the source data:

1. `00_data_quality.sql`
2. `01_order_level_metrics.sql`
3. `02_item_level_profitability.sql`
4. `03_discount_economics.sql`
5. `04_customer_value.sql`
6. `05_rfm_segmentation.sql`
7. `06_funnel.sql`
8. `07_cohort.sql`
9. `08_category_portfolio.sql`
10. `09_time_trend.sql`
11. `10_supporting_analysis.sql`
12. `99_qa_reconciliation.sql`

Each file creates reusable views, emits the analytical output, and runs an immediate module-level QA check. `99_qa_reconciliation.sql` provides the final cross-model reconciliation.

