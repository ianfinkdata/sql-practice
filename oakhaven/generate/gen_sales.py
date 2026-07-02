"""gen_sales.py -- Agent B (Sales) generator for Oakhaven Outfitters.

Produces oakhaven/data/{orders,order_items,payments,returns}.csv per
DATA_CONTRACT.md v1.1 (sections 3.9-3.11, 3.13) and generate/contract.py.

Deterministic: all randomness flows from contract.SEED via string-keyed
random.Random streams; rerunning reproduces every CSV byte-for-byte.

Money math: decimal.Decimal, per-line rounding half-up to 2dp:
    line_amount = round(quantity * unit_price * (1 - line_discount_pct/100), 2)
True order total = sum of line_amounts. Captured payments per non-cancelled
order sum EXACTLY to that total (splits differ by the remainder cent).
"""

import csv
import random
import sys
from datetime import date, datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import contract  # noqa: E402

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
CENT = Decimal("0.01")
ONE = Decimal("1")
DT_FMT = "%Y-%m-%d %H:%M:%S"
WINDOW_END_TS = datetime(2026, 6, 30, 23, 59, 59)
NULLT = contract.NULL_TOKEN

PROMO_PCT = {pid: Decimal(str(pct)) for pid, _, _, _, pct in contract.PROMOS}
PRODUCT_LIST = list(contract.PRODUCT_IDS)


def q2(x: Decimal) -> Decimal:
    return x.quantize(CENT, rounding=ROUND_HALF_UP)


def write_csv(name, header, rows):
    path = DATA_DIR / name
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    return path


# --------------------------------------------------------------- order_items
# unit_price = contract.product_list_price(pid) * U(0.95, 1.05) round 2dp,
# EXCEPT 0.2% of lines get 0.01 (D17 penny-pricing error).
# line_discount_pct = promo pct if the order has a promo, else 0 --
# plus 6% of non-promo lines get clearance 10-40.

def build_items(headers):
    r_prod = random.Random(f"{contract.SEED}:B:item-product")
    r_qty = random.Random(f"{contract.SEED}:B:item-qty")
    r_price = random.Random(f"{contract.SEED}:B:item-price")
    r_penny = random.Random(f"{contract.SEED}:B:item-penny")
    r_clear = random.Random(f"{contract.SEED}:B:item-clearance")
    qty_pop = [1, 2, 3, 4, 5, 6, 7, 8]
    qty_wts = [40, 25, 15, 9, 5, 3, 2, 1]

    items = []          # (oiid, oid, pid, qty, unit_price, disc, line_amount)
    order_totals = {}
    penny_count = 0
    oiid = 0
    for oid in contract.ORDER_IDS:
        h = headers[oid]
        promo_pct = PROMO_PCT[h["promo_id"]] if h["promo_id"] else None
        total = Decimal("0.00")
        for _ in range(contract.order_line_count(oid)):
            oiid += 1
            pid = r_prod.choice(PRODUCT_LIST)
            qty = r_qty.choices(qty_pop, weights=qty_wts)[0]
            if r_penny.random() < 0.002:
                unit_price = CENT
                penny_count += 1
            else:
                lp = contract.product_list_price(pid)
                unit_price = Decimal(f"{lp * r_price.uniform(0.95, 1.05):.2f}")
            if promo_pct is not None:
                disc = promo_pct
            elif r_clear.random() < 0.06:
                disc = Decimal(r_clear.choice(
                    ["10", "15", "20", "25", "30", "35", "40"]))
            else:
                disc = Decimal("0")
            line_amount = q2(Decimal(qty) * unit_price * (ONE - disc / 100))
            total += line_amount
            items.append((oiid, oid, pid, qty, unit_price, disc, line_amount))
        order_totals[oid] = total
    return items, order_totals, penny_count


# ------------------------------------------------------------------- returns
# 3.3% of order_items on completed/refunded orders; the guaranteed 1 return
# per refunded order is carved out of that 3.3% budget (not additive), so the
# row count stays ~4,900 (section 2). return_date = order date + 1-90d capped
# at 2026-06-30. refund_amount = qty_returned * unit_price * (1 - disc/100),
# rounded 2dp half-up.

REASONS = [
    "Too small", "too small", "TOO SMALL", "Too big",
    "Defective", "defective", "DEFECTIVE ",
    "Changed mind", "changed mind", "Didn't like the color",
    "doesnt fit", "Doesn't fit", "Broken zipper", "broken zipper",
    "Arrived damaged", "arrived damaged", "Wrong item shipped",
    "wrong item", "Not as described", "Gift - not wanted",
    "duplicate order", "Quality not as expected", "seam ripped",
    "Leaks", "missing parts", "MISSING PARTS", "Ordered wrong size",
]
CONDITION_CODES = ["A", "B", "C", "used", "LIKE NEW"]
CONDITION_WTS = [40, 25, 15, 10, 10]


def build_returns(headers, items):
    # eligible pool: items on completed/refunded orders
    by_order = {}
    eligible = []
    for it in items:
        st = headers[it[1]]["status"]
        if st in ("completed", "refunded"):
            eligible.append(it)
            by_order.setdefault(it[1], []).append(it)

    n_target = round(0.033 * len(eligible))

    r_pick = random.Random(f"{contract.SEED}:B:return-pick")
    chosen = {}                      # order_item_id -> item tuple
    for oid in sorted(o for o in by_order
                      if headers[o]["status"] == "refunded"):
        it = r_pick.choice(by_order[oid])
        chosen[it[0]] = it

    # completed orders dated 2026-06-30 are excluded from the random pool so
    # return_date (+1d min, capped 2026-06-30) can stay > order date
    pool = [it for it in eligible
            if it[0] not in chosen
            and headers[it[1]]["order_ts"].date() != contract.DATE_END]
    extra = max(n_target - len(chosen), 0)
    for it in r_pick.sample(pool, extra):
        chosen[it[0]] = it

    r_f = random.Random(f"{contract.SEED}:B:return-fields")
    rows = []                        # DDL column order
    refunds_by_order = {}            # oid -> (Decimal sum, earliest return date)
    cap_conflicts = 0
    null_reasons = 0
    for rid, oiid in enumerate(sorted(chosen), start=1):
        _, oid, _, qty, unit_price, disc, _ = chosen[oiid]
        order_date = headers[oid]["order_ts"].date()
        rd = min(order_date + timedelta(days=r_f.randint(1, 90)),
                 contract.DATE_END)
        if rd <= order_date:         # only possible when order date == cap
            cap_conflicts += 1
        qty_ret = r_f.randint(1, qty)
        refund = q2(Decimal(qty_ret) * unit_price * (ONE - disc / 100))
        if r_f.random() < 0.06:
            reason = NULLT
            null_reasons += 1
        else:
            reason = r_f.choice(REASONS)
        cond = r_f.choices(CONDITION_CODES, weights=CONDITION_WTS)[0]
        rows.append((rid, oiid, rd.isoformat(), qty_ret, reason,
                     f"{refund:.2f}", cond))
        amt, first = refunds_by_order.get(oid, (Decimal("0.00"), None))
        refunds_by_order[oid] = (amt + refund,
                                 rd if first is None else min(first, rd))
    return rows, refunds_by_order, cap_conflicts, null_reasons


# ------------------------------------------------------------------ payments
# cancelled -> failed attempt(s) only, or nothing.
# all other orders -> captured payments summing EXACTLY to the true total
# (4% split across two rows); 5% get one failed attempt before success.
# refunded orders additionally get a negative refund row >= order_ts + 1d
# (clamped to 2026-06-30 23:59:59 to respect the business window).

METHODS = [  # (spelling, weight, is_card) -- >=8 distinct spellings (D12)
    ("Visa", 30, True), ("VISA", 4, True), ("visa", 2, True),
    ("Mastercard", 20, True), ("Master Card", 3, True), ("MC", 2, True),
    ("AMEX", 8, True),
    ("cash", 12, False), ("CASH", 3, False),
    ("GIFT", 4, False),
]
METHOD_POP = [m[0] for m in METHODS]
METHOD_WTS = [m[1] for m in METHODS]
IS_CARD = {m[0]: m[2] for m in METHODS}


def build_payments(headers, order_totals, refunds_by_order):
    r = random.Random(f"{contract.SEED}:B:payments")
    rows = []
    pid = 0

    def emit(oid, ts, method, amount, status, last4):
        nonlocal pid
        pid += 1
        rows.append((pid, oid, ts.strftime(DT_FMT), method,
                     f"{amount:.2f}", status, last4))

    for oid in contract.ORDER_IDS:
        h = headers[oid]
        total = order_totals[oid]
        order_ts = h["order_ts"]
        method = r.choices(METHOD_POP, weights=METHOD_WTS)[0]
        last4 = f"{r.randrange(10000):04d}" if IS_CARD[method] else NULLT

        if h["status"] == "cancelled":
            if r.random() < 0.5:
                ts = order_ts + timedelta(minutes=r.randint(0, 10),
                                          seconds=r.randint(0, 59))
                emit(oid, ts, method, total, "failed", last4)
            continue

        cap_ts = order_ts + timedelta(minutes=r.randint(1, 45),
                                      seconds=r.randint(0, 59))
        if r.random() < 0.05:        # failed attempt before success
            fail_ts = order_ts + timedelta(minutes=r.randint(0, 5),
                                           seconds=r.randint(0, 59))
            if fail_ts >= cap_ts:
                cap_ts = fail_ts + timedelta(minutes=r.randint(1, 5))
            emit(oid, fail_ts, method, total, "failed", last4)

        if r.random() < 0.04 and total >= Decimal("0.02"):   # split capture
            a1 = q2(total * Decimal(f"{r.uniform(0.3, 0.7):.4f}"))
            a1 = min(max(a1, CENT), total - CENT)
            emit(oid, cap_ts, method, a1, "captured", last4)
            emit(oid, cap_ts + timedelta(minutes=r.randint(1, 3)),
                 method, total - a1, "captured", last4)
        else:
            emit(oid, cap_ts, method, total, "captured", last4)

        if h["status"] == "refunded":
            refund_amt, first_rd = refunds_by_order[oid]
            cand = datetime(first_rd.year, first_rd.month, first_rd.day,
                            r.randint(9, 18), r.randint(0, 59),
                            r.randint(0, 59))
            ts = max(cand, order_ts + timedelta(days=1))
            ts = min(ts, WINDOW_END_TS)
            ts = max(ts, order_ts)   # window clamp never precedes order_ts
            emit(oid, ts, method, -refund_amt, "refunded", last4)
    return rows


# -------------------------------------------------------------------- orders
# Header fields verbatim from contract.order_header. Agent B adds
# order_total_text (D8: $1,234.56 / $1234.56 / no-$ / leading space at
# 90/5/3/2%) and order_notes (D9: 80% NULL, junk otherwise).

NOTE_JUNK = [
    "called re: delivery", "N/A", "MIGRATED 2021", "customer will pick up",
    "gift wrap requested", "ok", "???", "PICKUP", "address confirmed",
    "left VM", "price match approved", "do not ship before friday",
    "see ticket", "loyalty points applied manually", "n/a",
]


def build_orders(headers, order_totals):
    r_text = random.Random(f"{contract.SEED}:B:total-text")
    r_note = random.Random(f"{contract.SEED}:B:notes")
    rows = []
    text_counts = {"comma": 0, "plain": 0, "nodollar": 0, "space": 0}
    notes_nonnull = 0
    for oid in contract.ORDER_IDS:
        h = headers[oid]
        total = order_totals[oid]
        p = r_text.random()
        if p < 0.90:
            text, key = f"${total:,.2f}", "comma"
        elif p < 0.95:
            text, key = f"${total:.2f}", "plain"
        elif p < 0.98:
            text, key = f"{total:,.2f}", "nodollar"
        else:
            text, key = f" ${total:,.2f}", "space"
        text_counts[key] += 1

        if r_note.random() < 0.20:
            note = r_note.choice(NOTE_JUNK)
            if note == "see ticket":
                note = f"see ticket #{r_note.randint(1000, 99999)}"
            notes_nonnull += 1
        else:
            note = NULLT

        rows.append((
            oid,
            h["customer_id"],
            h["store_id"],
            h["employee_id"] if h["employee_id"] is not None else NULLT,
            h["promo_id"] if h["promo_id"] is not None else NULLT,
            h["channel"],
            h["order_ts"].strftime(DT_FMT),
            h["status"],
            text,
            note,
        ))
    return rows, text_counts, notes_nonnull


# ---------------------------------------------------------------------- main

def main():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    headers = {oid: contract.order_header(oid) for oid in contract.ORDER_IDS}

    items, order_totals, penny_count = build_items(headers)
    return_rows, refunds_by_order, cap_conflicts, null_reasons = \
        build_returns(headers, items)
    payment_rows = build_payments(headers, order_totals, refunds_by_order)
    order_rows, text_counts, notes_nonnull = build_orders(headers, order_totals)

    write_csv("orders.csv",
              ["order_id", "customer_id", "store_id", "employee_id",
               "promo_id", "channel", "order_ts", "status",
               "order_total_text", "order_notes"],
              order_rows)
    write_csv("order_items.csv",
              ["order_item_id", "order_id", "product_id", "quantity",
               "unit_price", "line_discount_pct"],
              [(i[0], i[1], i[2], i[3], f"{i[4]:.2f}", f"{i[5]:.1f}")
               for i in items])
    write_csv("payments.csv",
              ["payment_id", "order_id", "payment_ts", "method", "amount",
               "status", "card_last4"],
              payment_rows)
    write_csv("returns.csv",
              ["return_id", "order_item_id", "return_date",
               "quantity_returned", "reason", "refund_amount",
               "condition_code"],
              return_rows)

    # ------------------------------------------------------------ self-check
    n_orders, n_items = len(order_rows), len(items)
    n_pay, n_ret = len(payment_rows), len(return_rows)
    print(f"orders:      {n_orders}")
    print(f"order_items: {n_items}")
    print(f"payments:    {n_pay}")
    print(f"returns:     {n_ret}")

    assert n_orders == contract.ORDER_COUNT
    assert n_items == sum(contract.order_line_count(i)
                          for i in contract.ORDER_IDS)

    # captured payments sum EXACTLY to true total for every non-cancelled order
    captured = {}
    for _, oid, _, _, amt, status, _ in payment_rows:
        if status == "captured":
            captured[oid] = captured.get(oid, Decimal("0")) + Decimal(amt)
    bad = [oid for oid in contract.ORDER_IDS
           if headers[oid]["status"] != "cancelled"
           and captured.get(oid, Decimal("0")) != order_totals[oid]]
    cancelled_captured = [oid for oid in captured
                          if headers[oid]["status"] == "cancelled"]
    print(f"captured-sum mismatches (non-cancelled): {len(bad)}")
    print(f"cancelled orders with captured rows:     {len(cancelled_captured)}")
    assert not bad and not cancelled_captured

    refunded_orders = [oid for oid in contract.ORDER_IDS
                       if headers[oid]["status"] == "refunded"]
    print(f"refunded orders: {len(refunded_orders)}; "
          f"all have >=1 return + refund row: "
          f"{all(oid in refunds_by_order for oid in refunded_orders)}")

    print(f"D8 order_total_text mix: {text_counts} "
          f"(pct: {[round(100*v/n_orders, 2) for v in text_counts.values()]})")
    print(f"D9 order_notes non-NULL: {notes_nonnull} "
          f"({100*notes_nonnull/n_orders:.2f}%)")
    methods = {row[3] for row in payment_rows}
    print(f"D12 distinct method spellings: {len(methods)} -> {sorted(methods)}")
    print(f"D17 penny-price lines: {penny_count} "
          f"({100*penny_count/n_items:.3f}%)")
    print(f"D22 NULL reasons: {null_reasons} ({100*null_reasons/n_ret:.2f}%)")
    print(f"return_date cap conflicts (order date == 2026-06-30): "
          f"{cap_conflicts}")


if __name__ == "__main__":
    main()
