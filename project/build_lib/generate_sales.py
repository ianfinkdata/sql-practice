"""
Generates bronze_sales: ~12,000 order-line rows. This is the messiest
bronze table -- see docs/data_dictionary.md for the full list of
deliberate defects. Grain is one row per order line; several columns
(order_date, customer_id, employee_id, payment_method, order_status,
channel) are shared across all lines of the same order_id, mirroring how
a real order-header/order-line system would look if flattened.
"""

import random
from datetime import timedelta

from build_lib import messiness as mz
from build_lib.config import (
    CHANNELS,
    N_CUSTOMERS,
    N_EMPLOYEES,
    N_PRODUCTS,
    N_SALES_LINES,
    ORDER_STATUSES,
    PAYMENT_METHODS,
    SALES_START,
    SNAPSHOT_DATE,
)

# Exact literal variant pools (spec calls out these specific strings).
ORDER_STATUS_POOL = ["Completed", "completed", "CANCELLED", "Cancelled", "Returned", None]
ORDER_STATUS_WEIGHTS = [0.45, 0.15, 0.07, 0.08, 0.15, 0.10]

PAYMENT_METHOD_POOL = [
    "Credit Card", "credit card", "CC", "Cash", "cash ",
    "Debit Card", "debit card", "PayPal", "paypal", "Gift Card",
]

CHANNEL_POOL = ["Online", "In-Store", "online", "in store"]

DISCOUNT_POOL = [0.0, 0.0, 0.0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30]


def _random_date_between(start, end):
    delta_days = (end - start).days
    offset = random.randint(0, delta_days)
    return start + timedelta(days=offset)


def _pick_customer_id():
    if random.random() < 0.01:
        return N_CUSTOMERS + random.randint(1000, 9000)  # orphan: guaranteed nonexistent
    return random.randint(1, N_CUSTOMERS)


def _pick_product_id():
    if random.random() < 0.01:
        return N_PRODUCTS + random.randint(1000, 9000)  # orphan: guaranteed nonexistent
    return random.randint(1, N_PRODUCTS)


def _dollar_format(value):
    s = f"${value:.2f}"
    if random.random() < 0.3:
        s = " " + s
    if random.random() < 0.3:
        s = s + " "
    return s


def _plain_format(value):
    s = f"{value:.2f}"
    if random.random() < 0.1:
        s = " " + s
    return s


def _order_total_text(correct_total, stale_total):
    bucket = random.random()
    if bucket < 0.574:
        return _plain_format(correct_total)
    bucket -= 0.574
    if bucket < 0.13:
        return _dollar_format(correct_total)
    bucket -= 0.13
    if bucket < 0.20:
        return _plain_format(stale_total)
    bucket -= 0.20
    if bucket < 0.07:
        return _dollar_format(stale_total)
    bucket -= 0.07
    if bucket < 0.02:
        return None
    bucket -= 0.02
    if bucket < 0.003:
        return "TBD"
    bucket -= 0.003
    if bucket < 0.003:
        return "N/A"
    # unreachable in practice (weights sum to 1.0); safe fallback
    return _plain_format(correct_total)


def generate(conn, product_rows):
    price_by_product = {p["product_id"]: p["unit_price"] for p in product_rows}

    rows = []
    order_id = 1
    lines_generated = 0

    while lines_generated < N_SALES_LINES:
        n_lines_this_order = random.choice([1, 1, 1, 2, 2, 3])

        order_date_actual = _random_date_between(SALES_START, SNAPSHOT_DATE)
        order_date_text = mz.maybe_null(mz.messy_date(order_date_actual), 0.005)

        customer_id = _pick_customer_id()
        employee_id = None if random.random() < 0.10 else random.randint(1, N_EMPLOYEES)

        payment_method = random.choice(PAYMENT_METHOD_POOL)
        order_status = random.choices(ORDER_STATUS_POOL, weights=ORDER_STATUS_WEIGHTS, k=1)[0]
        channel = random.choice(CHANNEL_POOL)

        # ship_date behaviour is decided once per order (not per line), so
        # all lines of a "bad" order look consistently bad.
        ship_roll = random.random()
        if ship_roll < 0.15:
            ship_date_actual = None
        elif ship_roll < 0.17:
            # intentional bad data: shipped before ordered
            ship_date_actual = order_date_actual - timedelta(days=random.randint(1, 5))
        else:
            ship_date_actual = order_date_actual + timedelta(days=random.randint(0, 10))
        ship_date_text = mz.messy_date(ship_date_actual) if ship_date_actual is not None else None

        for line_no in range(1, n_lines_this_order + 1):
            if lines_generated >= N_SALES_LINES:
                break

            product_id = _pick_product_id()
            base_price = price_by_product.get(product_id)
            if base_price is None:
                base_price = round(random.uniform(10.0, 300.0), 2)
            # price-at-time-of-sale drift vs. the product's current price
            unit_price = round(base_price * random.uniform(0.85, 1.15), 2)

            qty_roll = random.random()
            if qty_roll < 0.015:
                quantity = None
            elif qty_roll < 0.035:
                quantity = 0
            elif qty_roll < 0.065:
                quantity = -random.randint(1, 3)
            else:
                quantity = random.randint(1, 5)

            true_discount = random.choice(DISCOUNT_POOL)
            if random.random() < 0.015 and true_discount > 0:
                stored_discount = true_discount * 100  # whole-number data-entry bug
            else:
                stored_discount = true_discount

            qty_for_calc = quantity if quantity is not None else 0
            correct_total = round(qty_for_calc * unit_price * (1 - true_discount), 2)
            stale_total = round(qty_for_calc * unit_price, 2)

            row = {
                "order_id": order_id,
                "order_line_id": line_no,
                "customer_id": customer_id,
                "product_id": product_id,
                "employee_id": employee_id,
                "order_date": order_date_text,
                "ship_date": ship_date_text,
                "quantity": quantity,
                "unit_price": unit_price,
                "discount_pct": round(stored_discount, 4),
                "order_total": _order_total_text(correct_total, stale_total),
                "payment_method": payment_method,
                "order_status": order_status,
                "channel": channel,
            }
            rows.append(row)
            lines_generated += 1

        order_id += 1

    conn.executemany(
        """INSERT INTO bronze_sales
           (order_id, order_line_id, customer_id, product_id, employee_id, order_date, ship_date,
            quantity, unit_price, discount_pct, order_total, payment_method, order_status, channel)
           VALUES (:order_id, :order_line_id, :customer_id, :product_id, :employee_id, :order_date, :ship_date,
                   :quantity, :unit_price, :discount_pct, :order_total, :payment_method, :order_status, :channel)""",
        rows,
    )
    return rows
