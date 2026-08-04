"""
Post-build sanity checks for oakhaven.db.

Hard checks (deterministic, exact counts baked in by the generators)
raise AssertionError and abort the build if they fail. Soft checks
(percentage-based messiness outcomes, which vary slightly with any
change to generator logic even at a fixed seed) are just reported.

run(conn) returns a list of human-readable summary lines and raises
AssertionError on the first hard-check failure.
"""

from build_lib.config import (
    CALENDAR_END,
    CALENDAR_START,
    N_CUSTOMER_DUPLICATE_PEOPLE,
    N_CUSTOMERS,
    N_EMPLOYEES,
    N_PRODUCTS,
    N_SALES_LINES,
)

EXPECTED_CALENDAR_ROWS = (CALENDAR_END - CALENDAR_START).days + 1

EXPECTED_VIEWS = [
    "silver_customers", "silver_products", "silver_employees", "silver_sales", "silver_calendar",
    "dim_customer", "dim_product", "dim_employee", "dim_date", "fact_sales",
    "agg_monthly_sales_by_category", "agg_customer_ltv", "agg_daily_sales",
]


def _count(conn, table_or_view):
    return conn.execute(f"SELECT COUNT(*) FROM {table_or_view}").fetchone()[0]


def run(conn):
    lines = []

    def check(label, actual, expected):
        status = "OK" if actual == expected else "FAIL"
        lines.append(f"[{status}] {label}: expected {expected}, got {actual}")
        assert actual == expected, f"{label}: expected {expected}, got {actual}"

    lines.append("=== Row counts (hard checks) ===")
    check("bronze_customers row count", _count(conn, "bronze_customers"), N_CUSTOMERS)
    check("bronze_products row count", _count(conn, "bronze_products"), N_PRODUCTS)
    check("bronze_employees row count", _count(conn, "bronze_employees"), N_EMPLOYEES)
    check("bronze_sales row count", _count(conn, "bronze_sales"), N_SALES_LINES)
    check("bronze_calendar row count", _count(conn, "bronze_calendar"), EXPECTED_CALENDAR_ROWS)
    check(
        "near-duplicate customer rows (customer_id > base range)",
        _count(conn, f"(SELECT * FROM bronze_customers WHERE customer_id > {N_CUSTOMERS - N_CUSTOMER_DUPLICATE_PEOPLE})"),
        N_CUSTOMER_DUPLICATE_PEOPLE,
    )

    lines.append("")
    lines.append("=== Views queryable (hard checks) ===")
    for view in EXPECTED_VIEWS:
        count = _count(conn, view)
        lines.append(f"[OK] {view}: {count} rows")

    lines.append("")
    lines.append("=== Structural known-answer checks (hard checks) ===")
    check("dim_date row count == bronze_calendar row count", _count(conn, "dim_date"), EXPECTED_CALENDAR_ROWS)
    check("fact_sales row count == bronze_sales row count", _count(conn, "fact_sales"), N_SALES_LINES)

    dup_pairs = conn.execute(
        "SELECT COUNT(*) FROM (SELECT order_id, order_line_id, COUNT(*) c "
        "FROM fact_sales GROUP BY order_id, order_line_id HAVING c > 1)"
    ).fetchone()[0]
    check("duplicate (order_id, order_line_id) pairs in fact_sales", dup_pairs, 0)

    lines.append("")
    lines.append("=== Messiness outcomes (informational, not asserted) ===")

    def info(label, sql):
        val = conn.execute(sql).fetchone()[0]
        lines.append(f"    {label}: {val}")
        return val

    info("bronze_customers.email NULL count", "SELECT COUNT(*) FROM bronze_customers WHERE email IS NULL")
    info("bronze_customers.email empty-string count", "SELECT COUNT(*) FROM bronze_customers WHERE email = ''")
    info("bronze_products with sku_is_duplicate", "SELECT COUNT(*) FROM dim_product WHERE sku_is_duplicate = 1")
    info("bronze_products.unit_cost negative count", "SELECT COUNT(*) FROM bronze_products WHERE unit_cost < 0")
    info("bronze_sales orphan customer_id count", "SELECT COUNT(*) FROM fact_sales WHERE is_customer_orphan = 1")
    info("bronze_sales orphan product_id count", "SELECT COUNT(*) FROM fact_sales WHERE is_product_orphan = 1")
    info("bronze_sales.employee_id NULL count", "SELECT COUNT(*) FROM bronze_sales WHERE employee_id IS NULL")
    info("bronze_sales.order_date NULL count", "SELECT COUNT(*) FROM bronze_sales WHERE order_date IS NULL")
    info("bronze_sales.order_total NULL count", "SELECT COUNT(*) FROM bronze_sales WHERE order_total IS NULL")
    info("bronze_sales.order_total = 'TBD' count", "SELECT COUNT(*) FROM bronze_sales WHERE order_total = 'TBD'")
    info("bronze_sales.order_total = 'N/A' count", "SELECT COUNT(*) FROM bronze_sales WHERE order_total = 'N/A'")
    info("bronze_sales negative quantity count", "SELECT COUNT(*) FROM bronze_sales WHERE quantity < 0")
    info("bronze_sales quantity = 0 count", "SELECT COUNT(*) FROM bronze_sales WHERE quantity = 0")
    info("bronze_sales quantity NULL count", "SELECT COUNT(*) FROM bronze_sales WHERE quantity IS NULL")
    info(
        "silver_sales ship_date before order_date count (parsed, ISO)",
        "SELECT COUNT(*) FROM silver_sales WHERE ship_date IS NOT NULL AND order_date IS NOT NULL "
        "AND date(ship_date) < date(order_date)",
    )
    info(
        "bronze_sales.discount_pct whole-number bug count (> 1)",
        "SELECT COUNT(*) FROM bronze_sales WHERE discount_pct > 1",
    )

    lines.append("")
    lines.append("ALL HARD CHECKS PASSED")
    return lines
