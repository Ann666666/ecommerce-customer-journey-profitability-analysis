# Validated Outputs

These files are exports of the views in `05_validated_sql/analysis/`.

- `model_outputs/order_level_metrics.csv` — canonical one-row-per-order model.
- `model_outputs/item_level_profitability.csv` — canonical one-row-per-order-product model.
- `qa/data_quality_summary.csv` — source integrity checks and documented limitations.
- `qa/data_profile_summary.csv` — non-destructive range profiling for key numeric fields.
- `qa/model_reconciliation_summary.csv` — cross-model reconciliation.
- `core_analysis/` — funnel, customer value, RFM, discount economics, category portfolio, and cohort summaries.
- `supporting_analysis/` — time trend, geography, source, device, and category contribution summaries.
- `workbook/ecommerce_validated_analysis.xlsx` — formatted review workbook containing the key summaries and QA results.

The CSV files can be regenerated with `scripts/export_validated_outputs.py` after all validated SQL views are created.
