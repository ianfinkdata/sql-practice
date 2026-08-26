#!/usr/bin/env python3
"""
generate_lasagna_query.py - Lasagna SQL Query Generator & Transpiler

Generates deeply nested subquery ("Lasagna SQL") patterns and modern CTE equivalents
for retail supply chain friction, stockout opportunity sizing, and margin leakage.
Supports multi-dialect translation (SQLite, Snowflake, BigQuery, PostgreSQL, Databricks)
and live execution against project/oakhaven.db.
"""

import sys
import json
import sqlite3
import argparse
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.resolve()
DB_PATH = REPO_ROOT / "project" / "oakhaven.db"


def get_lasagna_sql(dialect: str = "sqlite", depth: int = 6, limit: int = 15) -> str:
    """Generates a deeply nested lasagna query."""
    
    # Dialect-specific date diff & null handling expressions
    if dialect in ("snowflake", "bigquery"):
        delay_expr = "DATEDIFF('day', s.order_date, s.ship_date) > 7"
    elif dialect in ("postgres", "databricks"):
        delay_expr = "(s.ship_date - s.order_date) > 7"
    else:  # sqlite default
        delay_expr = "s.ship_date IS NOT NULL AND s.order_date IS NOT NULL AND julianday(s.ship_date) - julianday(s.order_date) > 7"

    sql = f"""SELECT 
    action_priority_rank,
    product_id,
    product_name,
    category,
    sku_quadrant,
    completed_revenue,
    realized_margin_pct,
    cancellation_rate_pct,
    category_avg_cancellation_rate,
    cancelled_revenue_loss,
    recoverable_shortage_revenue,
    recoverable_shortage_margin,
    carrying_cost_drag_penalty,
    net_value_at_stake,
    strategic_recommendation
FROM (
    -- Layer 5: Opportunity Sizing & Financial Impact
    SELECT 
        l4.*,
        CASE 
            WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
            THEN ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2)
            ELSE 0.0 
        END AS recoverable_shortage_revenue,
        CASE 
            WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
            THEN ROUND(ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2) * (l4.realized_margin_pct / 100.0), 2)
            ELSE 0.0 
        END AS recoverable_shortage_margin,
        CASE 
            WHEN l4.sku_quadrant IN ('Deadstock - Shelf Space Drag', 'Slow Mover - Low Margin')
            THEN ROUND(l4.completed_units * l4.clean_unit_cost * 0.18, 2)
            ELSE 0.0 
        END AS carrying_cost_drag_penalty,
        ROUND(
            (CASE 
                WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
                THEN ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2) * (l4.realized_margin_pct / 100.0)
                ELSE 0.0 
             END) - 
            (CASE 
                WHEN l4.sku_quadrant IN ('Deadstock - Shelf Space Drag', 'Slow Mover - Low Margin')
                THEN l4.completed_units * l4.clean_unit_cost * 0.18
                ELSE 0.0 
             END),
            2
        ) AS net_value_at_stake,
        DENSE_RANK() OVER (
            ORDER BY 
                (CASE 
                    WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
                    THEN ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2) * (l4.realized_margin_pct / 100.0)
                    ELSE 0.0 
                 END) DESC
        ) AS action_priority_rank,
        CASE 
            WHEN l4.sku_quadrant = 'Top Runner - High Stockout Risk' THEN 'EXPEDITE_SUPPLY & EXPAND_SAFETY_STOCK'
            WHEN l4.sku_quadrant = 'Cash Cow - Core Engine' THEN 'PROTECT_ALLOCATION & MAINTAIN_BUFFER'
            WHEN l4.sku_quadrant = 'Volume Driver - Margin Bleeder' THEN 'RENEGOTIATE_COGS & TRIM_DISCOUNTS'
            WHEN l4.sku_quadrant = 'Deadstock - Shelf Space Drag' THEN 'LIQUIDATE_CLEARANCE & REALLOCATE_SHELF_SPACE'
            WHEN l4.sku_quadrant = 'Niche Specialty' THEN 'EVALUATE_MINIMUM_ORDER_QTY'
            ELSE 'MONITOR_STANDARD'
        END AS strategic_recommendation
    FROM (
        -- Layer 4: Multi-Dimensional Quadrant Scoring via Nested CASE Logic
        SELECT 
            l3.*,
            CASE 
                WHEN l3.category_revenue_quartile = 1 THEN 
                    CASE 
                        WHEN l3.category_margin_quartile <= 2 THEN 
                            CASE 
                                WHEN l3.cancellation_rate_pct > l3.category_avg_cancellation_rate THEN 'Top Runner - High Stockout Risk'
                                ELSE 'Cash Cow - Core Engine'
                            END
                        ELSE 'Volume Driver - Margin Bleeder'
                    END
                WHEN l3.category_revenue_quartile >= 3 THEN 
                    CASE 
                        WHEN l3.category_margin_quartile >= 3 THEN 
                            CASE 
                                WHEN l3.total_orders < 75 THEN 'Deadstock - Shelf Space Drag'
                                ELSE 'Slow Mover - Low Margin'
                            END
                        ELSE 'Niche Specialty'
                    END
                ELSE 'Core Catalog Standard'
            END AS sku_quadrant
        FROM (
            -- Layer 3: Ratio Derivations & Category Benchmarks via Window Functions
            SELECT 
                l2.*,
                ROUND(l2.realized_gross_profit * 100.0 / NULLIF(l2.completed_revenue, 0), 2) AS realized_margin_pct,
                ROUND(l2.cancelled_orders * 100.0 / NULLIF(l2.total_orders, 0), 2) AS cancellation_rate_pct,
                ROUND(l2.returned_orders * 100.0 / NULLIF(l2.total_orders, 0), 2) AS return_rate_pct,
                ROUND((l2.cancelled_revenue_loss + l2.returned_revenue_loss) * 100.0 / NULLIF(l2.completed_revenue + l2.cancelled_revenue_loss + l2.returned_revenue_loss, 0), 2) AS friction_index,
                NTILE(4) OVER (PARTITION BY l2.category ORDER BY l2.completed_revenue DESC) AS category_revenue_quartile,
                NTILE(4) OVER (PARTITION BY l2.category ORDER BY (l2.realized_gross_profit * 1.0 / NULLIF(l2.completed_revenue, 0)) DESC) AS category_margin_quartile,
                ROUND(AVG(l2.cancelled_orders * 100.0 / NULLIF(l2.total_orders, 0)) OVER (PARTITION BY l2.category), 2) AS category_avg_cancellation_rate,
                ROUND(AVG(l2.completed_revenue) OVER (), 2) AS fleet_avg_revenue
            FROM (
                -- Layer 2: Product Grain Aggregations & Status Metric Rollups
                SELECT 
                    l1.product_id,
                    l1.product_name,
                    l1.category,
                    l1.brand,
                    l1.unit_price,
                    l1.clean_unit_cost,
                    COUNT(l1.order_id) AS total_orders,
                    SUM(l1.quantity) AS total_units_demanded,
                    SUM(CASE WHEN l1.order_status = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
                    SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.quantity ELSE 0 END) AS completed_units,
                    ROUND(SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.net_amount ELSE 0 END), 2) AS completed_revenue,
                    SUM(CASE WHEN l1.order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
                    SUM(CASE WHEN l1.order_status = 'Cancelled' THEN l1.quantity ELSE 0 END) AS cancelled_units,
                    ROUND(SUM(CASE WHEN l1.order_status = 'Cancelled' THEN l1.net_amount ELSE 0 END), 2) AS cancelled_revenue_loss,
                    SUM(CASE WHEN l1.order_status = 'Returned' THEN 1 ELSE 0 END) AS returned_orders,
                    SUM(CASE WHEN l1.order_status = 'Returned' THEN l1.quantity ELSE 0 END) AS returned_units,
                    ROUND(SUM(CASE WHEN l1.order_status = 'Returned' THEN l1.net_amount ELSE 0 END), 2) AS returned_revenue_loss,
                    SUM(CASE WHEN l1.is_delayed_shipment = 1 THEN 1 ELSE 0 END) AS delayed_shipment_orders,
                    ROUND(SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.quantity * l1.clean_unit_cost ELSE 0 END), 2) AS realized_cogs,
                    ROUND(SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.net_amount - (l1.quantity * l1.clean_unit_cost) ELSE 0 END), 2) AS realized_gross_profit
                FROM (
                    -- Layer 1: Base Fact-to-Dimension Enrichment & Anomaly Cleansing
                    SELECT 
                        s.order_id,
                        s.order_line_id,
                        s.customer_id,
                        s.product_id,
                        p.product_name,
                        p.category,
                        p.brand,
                        p.unit_price,
                        CASE 
                            WHEN p.unit_cost IS NULL OR p.unit_cost <= 0 THEN ROUND(p.unit_price * 0.45, 2)
                            ELSE p.unit_cost 
                        END AS clean_unit_cost,
                        s.order_date,
                        s.ship_date,
                        s.quantity,
                        s.discount_pct,
                        s.net_amount,
                        s.order_status,
                        s.channel,
                        CASE 
                            WHEN {delay_expr} THEN 1 
                            ELSE 0 
                        END AS is_delayed_shipment
                    FROM fact_sales s
                    JOIN dim_product p ON s.product_id = p.product_id
                    WHERE s.is_product_orphan = 0
                ) l1
                GROUP BY 
                    l1.product_id,
                    l1.product_name,
                    l1.category,
                    l1.brand,
                    l1.unit_price,
                    l1.clean_unit_cost
            ) l2
        ) l3
    ) l4
) l5
WHERE action_priority_rank <= 10 OR sku_quadrant LIKE '%Deadstock%'
ORDER BY action_priority_rank ASC, recoverable_shortage_margin DESC
LIMIT {limit};"""
    return sql


def get_cte_sql(dialect: str = "sqlite", limit: int = 15) -> str:
    """Generates the modern CTE refactored equivalent."""
    if dialect in ("snowflake", "bigquery"):
        delay_expr = "DATEDIFF('day', s.order_date, s.ship_date) > 7"
    elif dialect in ("postgres", "databricks"):
        delay_expr = "(s.ship_date - s.order_date) > 7"
    else:  # sqlite default
        delay_expr = "s.ship_date IS NOT NULL AND s.order_date IS NOT NULL AND julianday(s.ship_date) - julianday(s.order_date) > 7"

    sql = f"""WITH l1_base_fact AS (
    SELECT 
        s.order_id,
        s.order_line_id,
        s.customer_id,
        s.product_id,
        p.product_name,
        p.category,
        p.brand,
        p.unit_price,
        CASE 
            WHEN p.unit_cost IS NULL OR p.unit_cost <= 0 THEN ROUND(p.unit_price * 0.45, 2)
            ELSE p.unit_cost 
        END AS clean_unit_cost,
        s.order_date,
        s.ship_date,
        s.quantity,
        s.discount_pct,
        s.net_amount,
        s.order_status,
        s.channel,
        CASE 
            WHEN {delay_expr} THEN 1 
            ELSE 0 
        END AS is_delayed_shipment
    FROM fact_sales s
    JOIN dim_product p ON s.product_id = p.product_id
    WHERE s.is_product_orphan = 0
),
l2_product_agg AS (
    SELECT 
        l1.product_id,
        l1.product_name,
        l1.category,
        l1.brand,
        l1.unit_price,
        l1.clean_unit_cost,
        COUNT(l1.order_id) AS total_orders,
        SUM(l1.quantity) AS total_units_demanded,
        SUM(CASE WHEN l1.order_status = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
        SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.quantity ELSE 0 END) AS completed_units,
        ROUND(SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.net_amount ELSE 0 END), 2) AS completed_revenue,
        SUM(CASE WHEN l1.order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
        SUM(CASE WHEN l1.order_status = 'Cancelled' THEN l1.quantity ELSE 0 END) AS cancelled_units,
        ROUND(SUM(CASE WHEN l1.order_status = 'Cancelled' THEN l1.net_amount ELSE 0 END), 2) AS cancelled_revenue_loss,
        SUM(CASE WHEN l1.order_status = 'Returned' THEN 1 ELSE 0 END) AS returned_orders,
        SUM(CASE WHEN l1.order_status = 'Returned' THEN l1.quantity ELSE 0 END) AS returned_units,
        ROUND(SUM(CASE WHEN l1.order_status = 'Returned' THEN l1.net_amount ELSE 0 END), 2) AS returned_revenue_loss,
        SUM(CASE WHEN l1.is_delayed_shipment = 1 THEN 1 ELSE 0 END) AS delayed_shipment_orders,
        ROUND(SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.quantity * l1.clean_unit_cost ELSE 0 END), 2) AS realized_cogs,
        ROUND(SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.net_amount - (l1.quantity * l1.clean_unit_cost) ELSE 0 END), 2) AS realized_gross_profit
    FROM l1_base_fact l1
    GROUP BY 
        l1.product_id,
        l1.product_name,
        l1.category,
        l1.brand,
        l1.unit_price,
        l1.clean_unit_cost
),
l3_benchmarks AS (
    SELECT 
        l2.*,
        ROUND(l2.realized_gross_profit * 100.0 / NULLIF(l2.completed_revenue, 0), 2) AS realized_margin_pct,
        ROUND(l2.cancelled_orders * 100.0 / NULLIF(l2.total_orders, 0), 2) AS cancellation_rate_pct,
        ROUND(l2.returned_orders * 100.0 / NULLIF(l2.total_orders, 0), 2) AS return_rate_pct,
        ROUND((l2.cancelled_revenue_loss + l2.returned_revenue_loss) * 100.0 / NULLIF(l2.completed_revenue + l2.cancelled_revenue_loss + l2.returned_revenue_loss, 0), 2) AS friction_index,
        NTILE(4) OVER (PARTITION BY l2.category ORDER BY l2.completed_revenue DESC) AS category_revenue_quartile,
        NTILE(4) OVER (PARTITION BY l2.category ORDER BY (l2.realized_gross_profit * 1.0 / NULLIF(l2.completed_revenue, 0)) DESC) AS category_margin_quartile,
        ROUND(AVG(l2.cancelled_orders * 100.0 / NULLIF(l2.total_orders, 0)) OVER (PARTITION BY l2.category), 2) AS category_avg_cancellation_rate,
        ROUND(AVG(l2.completed_revenue) OVER (), 2) AS fleet_avg_revenue
    FROM l2_product_agg l2
),
l4_scoring AS (
    SELECT 
        l3.*,
        CASE 
            WHEN l3.category_revenue_quartile = 1 THEN 
                CASE 
                    WHEN l3.category_margin_quartile <= 2 THEN 
                        CASE 
                            WHEN l3.cancellation_rate_pct > l3.category_avg_cancellation_rate THEN 'Top Runner - High Stockout Risk'
                            ELSE 'Cash Cow - Core Engine'
                        END
                    ELSE 'Volume Driver - Margin Bleeder'
                END
            WHEN l3.category_revenue_quartile >= 3 THEN 
                CASE 
                    WHEN l3.category_margin_quartile >= 3 THEN 
                        CASE 
                            WHEN l3.total_orders < 75 THEN 'Deadstock - Shelf Space Drag'
                            ELSE 'Slow Mover - Low Margin'
                        END
                    ELSE 'Niche Specialty'
                END
            ELSE 'Core Catalog Standard'
        END AS sku_quadrant
    FROM l3_benchmarks l3
),
l5_opportunity_sizing AS (
    SELECT 
        l4.*,
        CASE 
            WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
            THEN ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2)
            ELSE 0.0 
        END AS recoverable_shortage_revenue,
        CASE 
            WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
            THEN ROUND(ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2) * (l4.realized_margin_pct / 100.0), 2)
            ELSE 0.0 
        END AS recoverable_shortage_margin,
        CASE 
            WHEN l4.sku_quadrant IN ('Deadstock - Shelf Space Drag', 'Slow Mover - Low Margin')
            THEN ROUND(l4.completed_units * l4.clean_unit_cost * 0.18, 2)
            ELSE 0.0 
        END AS carrying_cost_drag_penalty,
        ROUND(
            (CASE 
                WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
                THEN ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2) * (l4.realized_margin_pct / 100.0)
                ELSE 0.0 
             END) - 
            (CASE 
                WHEN l4.sku_quadrant IN ('Deadstock - Shelf Space Drag', 'Slow Mover - Low Margin')
                THEN l4.completed_units * l4.clean_unit_cost * 0.18
                ELSE 0.0 
             END),
            2
        ) AS net_value_at_stake,
        DENSE_RANK() OVER (
            ORDER BY 
                (CASE 
                    WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
                    THEN ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2) * (l4.realized_margin_pct / 100.0)
                    ELSE 0.0 
                 END) DESC
        ) AS action_priority_rank,
        CASE 
            WHEN l4.sku_quadrant = 'Top Runner - High Stockout Risk' THEN 'EXPEDITE_SUPPLY & EXPAND_SAFETY_STOCK'
            WHEN l4.sku_quadrant = 'Cash Cow - Core Engine' THEN 'PROTECT_ALLOCATION & MAINTAIN_BUFFER'
            WHEN l4.sku_quadrant = 'Volume Driver - Margin Bleeder' THEN 'RENEGOTIATE_COGS & TRIM_DISCOUNTS'
            WHEN l4.sku_quadrant = 'Deadstock - Shelf Space Drag' THEN 'LIQUIDATE_CLEARANCE & REALLOCATE_SHELF_SPACE'
            WHEN l4.sku_quadrant = 'Niche Specialty' THEN 'EVALUATE_MINIMUM_ORDER_QTY'
            ELSE 'MONITOR_STANDARD'
        END AS strategic_recommendation
    FROM l4_scoring l4
)
SELECT 
    action_priority_rank,
    product_id,
    product_name,
    category,
    sku_quadrant,
    completed_revenue,
    realized_margin_pct,
    cancellation_rate_pct,
    category_avg_cancellation_rate,
    cancelled_revenue_loss,
    recoverable_shortage_revenue,
    recoverable_shortage_margin,
    carrying_cost_drag_penalty,
    net_value_at_stake,
    strategic_recommendation
FROM l5_opportunity_sizing
WHERE action_priority_rank <= 10 OR sku_quadrant LIKE '%Deadstock%'
ORDER BY action_priority_rank ASC, recoverable_shortage_margin DESC
LIMIT {limit};"""
    return sql


def execute_query(sql: str, as_json: bool = False):
    """Executes the query read-only against project/oakhaven.db."""
    if not DB_PATH.exists():
        print(f"Error: Database not found at {DB_PATH}", file=sys.stderr)
        sys.exit(1)

    # Strictly read-only connection
    conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    try:
        cursor.execute(sql)
        rows = cursor.fetchall()
        
        if as_json:
            dict_rows = [dict(r) for r in rows]
            print(json.dumps(dict_rows, indent=2))
        else:
            if not rows:
                print("No rows returned.")
                return
            headers = rows[0].keys()
            # Calculate column widths
            col_widths = {h: len(h) for h in headers}
            str_rows = []
            for r in rows:
                str_row = {h: str(r[h]) if r[h] is not None else "" for h in headers}
                for h in headers:
                    col_widths[h] = max(col_widths[h], len(str_row[h]))
                str_rows.append(str_row)

            # Print header
            header_line = "  ".join(h.ljust(col_widths[h]) for h in headers)
            sep_line = "  ".join("-" * col_widths[h] for h in headers)
            print(header_line)
            print(sep_line)
            for r in str_rows:
                print("  ".join(r[h].ljust(col_widths[h]) for h in headers))
            print(f"\n({len(rows)} rows)")
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(description="Generate and execute Lasagna SQL queries.")
    parser.add_argument("--style", choices=["lasagna", "cte"], default="lasagna", help="Query architecture style (default: lasagna)")
    parser.add_argument("--dialect", choices=["sqlite", "snowflake", "bigquery", "postgres", "databricks"], default="sqlite", help="SQL dialect (default: sqlite)")
    parser.add_argument("--depth", type=int, default=6, help="Nesting depth (default: 6)")
    parser.add_argument("--limit", type=int, default=15, help="Result row limit (default: 15)")
    parser.add_argument("--run", action="store_true", help="Execute read-only against project/oakhaven.db")
    parser.add_argument("--json", action="store_true", help="Format run output as JSON")
    parser.add_argument("--output", type=str, help="Save SQL output to specified file")

    args = parser.parse_args()

    if args.style == "lasagna":
        sql = get_lasagna_sql(dialect=args.dialect, depth=args.depth, limit=args.limit)
    else:
        sql = get_cte_sql(dialect=args.dialect, limit=args.limit)

    if args.output:
        out_path = Path(args.output)
        out_path.write_text(sql, encoding="utf-8")
        print(f"Saved {args.style} SQL ({args.dialect}) to {out_path}")

    if args.run:
        if args.dialect != "sqlite":
            print(f"Warning: Executing {args.dialect} dialect against local SQLite engine may encounter syntax differences.", file=sys.stderr)
        execute_query(sql, as_json=args.json)
    elif not args.output:
        print(sql)


if __name__ == "__main__":
    main()
