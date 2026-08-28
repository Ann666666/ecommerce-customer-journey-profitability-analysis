"""Export validated MySQL views to portfolio-ready CSV files.

This script preserves SQL as the source of truth. It calls the MySQL client in
batch mode, converts tabular output to CSV, and writes only to the selected
output directory.
"""

from __future__ import annotations

import argparse
import csv
import subprocess
from pathlib import Path


EXPORTS = {
    "data_quality_summary.csv": """
        SELECT check_group, check_name, result_value, status, interpretation
        FROM vw_data_quality_summary
        ORDER BY check_group, check_name
    """,
    "data_profile_summary.csv": """
        SELECT profile_metric, min_value, max_value, avg_value,
               population_rows, interpretation
        FROM vw_data_profile_summary
        ORDER BY profile_metric
    """,
    "model_reconciliation_summary.csv": """
        SELECT check_group, check_name, expected_value, actual_value, status, interpretation
        FROM vw_model_reconciliation_summary
        ORDER BY check_group, check_name
    """,
    "order_level_metrics.csv": """
        SELECT order_id, customer_id, order_time, country, device, source,
               payment_method, discount_pct, gross_revenue, discount_amount,
               net_revenue, order_lines, total_units, total_product_cost,
               gross_profit_before_discount, net_profit, net_margin
        FROM vw_order_level_metrics
        ORDER BY order_id
    """,
    "item_level_profitability.csv": """
        SELECT order_id, product_id, category, customer_id, order_time, quantity,
               gross_item_revenue, item_cost, share_of_order_subtotal,
               allocated_discount, allocated_net_revenue, net_item_profit,
               net_item_margin
        FROM vw_item_level_profitability
        ORDER BY order_id, product_id
    """,
    "discount_economics.csv": """
        SELECT discount_pct, orders, order_share, total_units, units_per_order,
               gross_basket_value_per_order, discount_amount_per_order, net_aov,
               net_profit_per_order, net_margin, margin_compression_vs_full_price
        FROM vw_discount_economics
        ORDER BY discount_pct
    """,
    "customer_value_segments.csv": """
        SELECT customer_type, customers, customer_share, orders, order_share,
               net_revenue, revenue_share, revenue_per_customer, aov,
               average_purchase_frequency, net_margin
        FROM vw_customer_value_segments
        ORDER BY FIELD(customer_type, 'Repeat Buyer', 'One-time Buyer')
    """,
    "rfm_customer_segments.csv": """
        SELECT customer_id, last_order_time, recency_days, frequency,
               net_monetary, customer_net_profit, aov, r_score, f_score,
               m_score, rfm_code, segment
        FROM vw_rfm_segments
        ORDER BY customer_id
    """,
    "rfm_segment_summary.csv": """
        SELECT segment, customers, customer_share, net_revenue, revenue_share,
               orders, aov, average_frequency, average_recency, net_margin
        FROM vw_rfm_segment_summary
        ORDER BY net_revenue DESC, segment
    """,
    "funnel_summary.csv": """
        SELECT stage_order, stage, sessions, step_conversion, step_drop_off,
               overall_conversion
        FROM vw_funnel_stage_summary
        ORDER BY stage_order
    """,
    "funnel_sequence_qa.csv": """
        SELECT anomaly_type, anomaly_sessions, relevant_stage_sessions, anomaly_share
        FROM vw_funnel_sequence_qa
        ORDER BY anomaly_type
    """,
    "funnel_strict_comparison.csv": """
        SELECT stage, event_presence_sessions, strict_sequence_sessions,
               excluded_anomaly_sessions
        FROM vw_funnel_strict_comparison
        ORDER BY FIELD(stage, 'View', 'Add to Cart', 'Checkout', 'Purchase')
    """,
    "first_purchase_cohort_matrix.csv": """
        SELECT cohort_month, month_index, cohort_size, active_customers,
               monthly_repeat_purchase_activity_rate
        FROM vw_first_purchase_cohort
        ORDER BY cohort_month, month_index
    """,
    "cohort_summary.csv": """
        SELECT month_index, eligible_cohorts, eligible_customers,
               active_customers, weighted_monthly_repeat_purchase_activity_rate
        FROM vw_cohort_summary
        ORDER BY month_index
    """,
    "category_portfolio.csv": """
        SELECT category, revenue_rank, units, orders, purchasing_customers,
               gross_revenue, net_revenue, revenue_share, net_profit, net_margin,
               net_revenue_per_category_order, avg_rating, review_count,
               review_coverage, low_rating_count, low_rating_rate
        FROM vw_category_portfolio
        ORDER BY revenue_rank, category
    """,
    "monthly_performance.csv": """
        SELECT order_month, orders, units, gross_revenue, discount_amount,
               net_revenue, net_profit, aov, net_margin,
               mom_net_revenue_growth, yoy_net_revenue_growth,
               yoy_order_growth, yoy_aov_growth
        FROM vw_time_trend
        ORDER BY order_month
    """,
    "comparable_period_summary.csv": """
        SELECT order_year, orders, units, net_revenue, net_profit, aov,
               net_margin, order_growth, net_revenue_growth,
               net_profit_growth, aov_growth
        FROM vw_comparable_period_summary
        ORDER BY order_year
    """,
    "geography_performance.csv": """
        SELECT country, orders, purchasing_customers, net_revenue,
               revenue_share, aov, net_margin
        FROM vw_geography_performance
        ORDER BY net_revenue DESC, country
    """,
    "source_performance.csv": """
        SELECT source, sessions, purchase_sessions, session_conversion,
               orders, net_revenue, aov, revenue_per_session, net_margin
        FROM vw_source_performance
        ORDER BY revenue_per_session DESC, source
    """,
    "device_performance.csv": """
        SELECT device, sessions, purchase_sessions, session_conversion,
               orders, net_revenue, aov, revenue_per_session, net_margin
        FROM vw_device_performance
        ORDER BY revenue_per_session DESC, device
    """,
    "category_revenue_contribution.csv": """
        SELECT category, revenue_rank, net_revenue, revenue_share,
               cumulative_revenue_share
        FROM vw_category_revenue_contribution
        ORDER BY revenue_rank, category
    """,
}


def export_query(
    mysql_client: str,
    user: str,
    socket: str | None,
    host: str | None,
    port: int | None,
    database: str,
    query: str,
    output: Path,
) -> int:
    command = [
        mysql_client,
        f"-u{user}",
        "--batch",
        "--raw",
        database,
        f"--execute={query.strip()}",
    ]
    if socket:
        command.insert(1, f"--socket={socket}")
    elif host:
        command.insert(1, f"--host={host}")
        if port:
            command.insert(2, f"--port={port}")
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    rows = list(csv.reader(result.stdout.splitlines(), delimiter="\t"))
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as file_handle:
        csv.writer(file_handle).writerows(rows)
    return max(len(rows) - 1, 0)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mysql-client", default="mysql")
    parser.add_argument("--user", default="root")
    parser.add_argument("--socket")
    parser.add_argument("--host")
    parser.add_argument("--port", type=int)
    parser.add_argument("--database", default="commerce_practice")
    parser.add_argument("--output-dir", default="06_validated_outputs")
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    total_rows = 0
    for filename, query in EXPORTS.items():
        row_count = export_query(
            args.mysql_client,
            args.user,
            args.socket,
            args.host,
            args.port,
            args.database,
            query,
            output_dir / filename,
        )
        total_rows += row_count
        print(f"{filename}: {row_count} rows")
    print(f"Exported {len(EXPORTS)} files and {total_rows} data rows.")


if __name__ == "__main__":
    main()
