"""Agent C -- Logistics generator for Oakhaven Outfitters.

Produces oakhaven/data/shipments.csv and oakhaven/data/inventory_movements.csv
per DATA_CONTRACT.md v1.1 (SS3.12, SS3.14, quotas D10, D11, D23, D25).

Never reads any other agent's CSV: order truth comes from
contract.order_header(order_id). Deterministic: all randomness flows from
random.Random(f"{contract.SEED}:<key>") streams in fixed iteration order.
"""

import csv
import os
import random
from datetime import datetime, timedelta

import contract

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        os.pardir, "data")
WINDOW_END_TS = datetime(2026, 6, 30, 23, 59, 59)

DT_FMT = "%Y-%m-%d %H:%M:%S"


def fmt_ts(ts):
    return ts.strftime(DT_FMT)


# ======================================================== shipments (SS3.12)

CARRIERS = ["UPS", "FedEx", "USPS", "OnTrac"]
CARRIER_WEIGHTS = [35, 30, 25, 10]
# D11: 6% casing variants
DIRTY_CARRIERS = ["ups", "FEDEX", "usps ", "fedex", "Usps", "ONTRAC"]


def make_tracking(rng, carrier):
    """Carrier-styled tracking numbers (contract silent on format; flagged)."""
    if carrier == "UPS":
        chars = "0123456789ABCDEFGHJKLMNPRSTUVWXYZ"
        return "1Z" + "".join(rng.choice(chars) for _ in range(16))
    if carrier == "FedEx":
        return "".join(rng.choice("0123456789") for _ in range(12))
    if carrier == "USPS":
        return "94" + "".join(rng.choice("0123456789") for _ in range(20))
    return "C" + "".join(rng.choice("0123456789") for _ in range(14))  # OnTrac


def fmt_delivered(rng, delivered):
    """D10: YYYY-MM-DD / MM/DD/YYYY / Mon D, YYYY / PENDING / NULL
    at 55/30/5/4/6%."""
    x = rng.random()
    if x < 0.55:
        return delivered.strftime("%Y-%m-%d")
    if x < 0.85:
        return delivered.strftime("%m/%d/%Y")
    if x < 0.90:
        return f"{delivered.strftime('%b')} {delivered.day}, {delivered.year}"
    if x < 0.94:
        return "PENDING"
    return contract.NULL_TOKEN


def gen_shipments():
    rng = random.Random(f"{contract.SEED}:gen:shipments")
    rows = []            # [order_id, carrier, shipped_ts, delivered_raw, tracking, cost]
    shipped_orders = 0
    split_orders = 0
    for oid in contract.ORDER_IDS:
        h = contract.order_header(oid)
        if not h["has_shipment"]:
            continue
        shipped_orders += 1
        n_ship = 2 if rng.random() < 0.03 else 1
        if n_ship == 2:
            split_orders += 1
        for _ in range(n_ship):
            # shipped_ts = order_ts + 4h..5d, capped to the business window
            delta_s = rng.randrange(4 * 3600, 5 * 86400 + 1)
            shipped = h["order_ts"] + timedelta(seconds=delta_s)
            if shipped > WINDOW_END_TS:
                shipped = WINDOW_END_TS
            base_carrier = rng.choices(CARRIERS, weights=CARRIER_WEIGHTS)[0]
            carrier = base_carrier
            if rng.random() < 0.06:                       # D11
                carrier = rng.choice(DIRTY_CARRIERS)
            delivered = shipped.date() + timedelta(days=rng.randrange(1, 11))
            delivered_raw = fmt_delivered(rng, delivered)
            tracking = make_tracking(rng, base_carrier)
            cost = 0.00 if rng.random() < 0.01 else round(rng.uniform(3.50, 34.99), 2)
            rows.append([oid, carrier, shipped, delivered_raw, tracking, cost])

    # D25: ~1% of rows carry a duplicated tracking value (pairs); PK stays unique
    n = len(rows)
    n_pairs = round(0.01 * n / 2)
    idxs = rng.sample(range(n), 2 * n_pairs)
    for k in range(n_pairs):
        src, dst = idxs[2 * k], idxs[2 * k + 1]
        rows[dst][4] = rows[src][4]

    path = os.path.join(DATA_DIR, "shipments.csv")
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["shipment_id", "order_id", "carrier", "shipped_ts",
                    "delivered_date_raw", "tracking_number", "ship_cost"])
        for i, (oid, carrier, shipped, delivered_raw, tracking, cost) in enumerate(rows, 1):
            w.writerow([i, oid, carrier, fmt_ts(shipped), delivered_raw,
                        tracking, f"{cost:.2f}"])
    return rows, shipped_orders, split_orders


# ============================================= inventory_movements (SS3.14)

N_MOVEMENTS = 90_000
TYPE_COUNTS = {           # 22 / 64 / 6 / 4 / 4 %
    "receipt": round(N_MOVEMENTS * 0.22),        # 19,800
    "sale": round(N_MOVEMENTS * 0.64),           # 57,600
    "adjustment": round(N_MOVEMENTS * 0.06),     # 5,400
    "transfer_out": round(N_MOVEMENTS * 0.04),   # 3,600
    "transfer_in": round(N_MOVEMENTS * 0.04),    # 3,600
}
UNMATCHED_OUT_RATE = 0.015   # 1.5% of transfer_out rows lack a transfer_in

JUNK_REFS = ["???", "see spreadsheet", "TBD", "fix later", "-", "n/a??"]


def movement_stores(d):
    """Stores that can hold inventory on date d: open physical stores plus
    the WEB fulfilment center (store 13, open all window). Flagged choice."""
    return contract.stores_open_on(d) + [contract.WEB_STORE_ID]


def rand_ts(rng, d, lo_hour=6, hi_hour=21):
    return datetime(d.year, d.month, d.day,
                    rng.randrange(lo_hour, hi_hour + 1),
                    rng.randrange(60), rng.randrange(60))


# Every transfer_out and every matched transfer_in keeps its shared TR-
# reference clean, so the 1.5% unmatched-transfer anomaly is exactly
# measurable via a reference anti-join; D23 dirt probabilities are scaled up
# on the remaining rows so table-wide quotas still land on target.
_N_MATCHED_PAIRS = TYPE_COUNTS["transfer_out"] - round(
    TYPE_COUNTS["transfer_out"] * UNMATCHED_OUT_RATE)
_N_PROTECTED = TYPE_COUNTS["transfer_out"] + _N_MATCHED_PAIRS
_DIRT_SCALE = N_MOVEMENTS / (N_MOVEMENTS - _N_PROTECTED)


def make_reference(rng, default_ref, protect=False):
    """D23: MIGRATION 3% / junk 2% / NULL 25% (table-wide) / else PO-style."""
    if protect:
        return default_ref
    x = rng.random()
    if x < 0.03 * _DIRT_SCALE:
        return "MIGRATION"
    if x < 0.05 * _DIRT_SCALE:
        return rng.choice(JUNK_REFS)
    if x < 0.30 * _DIRT_SCALE:
        return contract.NULL_TOKEN
    return default_ref


def make_cost(rng, pid):
    """unit_cost_at_time = contract cost x U(0.9, 1.1); 10% NULL."""
    if rng.random() < 0.10:
        return contract.NULL_TOKEN
    return f"{contract.product_unit_cost(pid) * rng.uniform(0.9, 1.1):.2f}"


def gen_inventory_movements():
    rng = random.Random(f"{contract.SEED}:gen:inventory")
    products = list(contract.PRODUCT_IDS)
    rows = []   # (ts, type, product_id, store_id, qty, reference, cost)

    def add_row(ts, mtype, pid, sid, qty, ref, protect=False):
        rows.append((ts, mtype, pid, sid, qty,
                     make_reference(rng, ref, protect), make_cost(rng, pid)))

    # --- sales: daily store/product aggregates on the demand shape ----------
    seen = set()
    made = 0
    while made < TYPE_COUNTS["sale"]:
        d = rng.choices(contract._DAYS, weights=contract._DAY_WEIGHTS)[0]
        sid = rng.choice(movement_stores(d))
        pid = rng.choice(products)
        key = (d, sid, pid)
        if key in seen:                     # one aggregate per store/product/day
            continue
        seen.add(key)
        qty = -rng.choices(range(1, 13),
                           weights=[30, 22, 15, 10, 7, 5, 4, 3, 2, 1, 0.6, 0.4])[0]
        add_row(rand_ts(rng, d, 8, 21), "sale", pid, sid, qty,
                f"SO-{rng.randrange(100000, 1000000)}")
        made += 1

    # --- receipts: inbound stock, loosely follows the same demand shape -----
    for _ in range(TYPE_COUNTS["receipt"]):
        d = rng.choices(contract._DAYS, weights=contract._DAY_WEIGHTS)[0]
        sid = rng.choice(movement_stores(d))
        pid = rng.choice(products)
        add_row(rand_ts(rng, d, 6, 12), "receipt", pid, sid,
                rng.randrange(6, 49), f"PO-{rng.randrange(100000, 1000000)}")

    # --- adjustments: +/- and never 0 ---------------------------------------
    for _ in range(TYPE_COUNTS["adjustment"]):
        d = rng.choices(contract._DAYS, weights=contract._DAY_WEIGHTS)[0]
        sid = rng.choice(movement_stores(d))
        pid = rng.choice(products)
        qty = rng.randrange(1, 7) * rng.choice([1, -1])
        add_row(rand_ts(rng, d), "adjustment", pid, sid, qty,
                f"ADJ-{rng.randrange(10000, 100000)}")

    # --- transfers: paired out/in; 1.5% of outs deliberately unmatched ------
    n_out = TYPE_COUNTS["transfer_out"]
    n_unmatched_out = round(n_out * UNMATCHED_OUT_RATE)          # 54
    n_matched = n_out - n_unmatched_out                          # 3,546
    n_standalone_in = TYPE_COUNTS["transfer_in"] - n_matched     # 54
    used_tr = set()

    def unique_tr():                     # ref is the pair key: keep it unique
        while True:
            ref = f"TR-{rng.randrange(100000, 1000000)}"
            if ref not in used_tr:
                used_tr.add(ref)
                return ref

    for k in range(n_out):
        d = rng.choices(contract._DAYS, weights=contract._DAY_WEIGHTS)[0]
        src = rng.choice(movement_stores(d))
        pid = rng.choice(products)
        qty = rng.randrange(2, 25)
        ref = unique_tr()
        matched = k < n_matched
        out_ts = rand_ts(rng, d)
        add_row(out_ts, "transfer_out", pid, src, -qty, ref, protect=True)
        if matched:                                              # matching in
            d_in = min(d + timedelta(days=rng.randrange(0, 3)), contract.DATE_END)
            dests = [s for s in movement_stores(d_in) if s != src]
            in_ts = rand_ts(rng, d_in)
            if in_ts < out_ts:               # arrival never precedes dispatch
                in_ts = min(out_ts + timedelta(hours=rng.randrange(2, 49)),
                            WINDOW_END_TS)
            add_row(in_ts, "transfer_in", pid, rng.choice(dests), qty, ref,
                    protect=True)
    for _ in range(n_standalone_in):        # keeps transfer_in at its 4% share
        d = rng.choices(contract._DAYS, weights=contract._DAY_WEIGHTS)[0]
        sid = rng.choice(movement_stores(d))
        pid = rng.choice(products)
        add_row(rand_ts(rng, d), "transfer_in", pid, sid,
                rng.randrange(2, 25), unique_tr())

    # chronological movement_id, like a real auto-increment
    rows.sort(key=lambda r: (r[0], r[1], r[2], r[3], r[4]))

    path = os.path.join(DATA_DIR, "inventory_movements.csv")
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["movement_id", "product_id", "store_id", "movement_ts",
                    "movement_type", "quantity", "reference",
                    "unit_cost_at_time"])
        for i, (ts, mtype, pid, sid, qty, ref, cost) in enumerate(rows, 1):
            w.writerow([i, pid, sid, fmt_ts(ts), mtype, qty, ref, cost])
    return rows


# =============================================================== reporting

def main():
    os.makedirs(DATA_DIR, exist_ok=True)

    ship_rows, shipped_orders, split_orders = gen_shipments()
    print(f"shipments.csv           rows: {len(ship_rows):>6}  "
          f"(shipped orders: {shipped_orders}, split: {split_orders})")

    mov_rows = gen_inventory_movements()
    print(f"inventory_movements.csv rows: {len(mov_rows):>6}")

    from collections import Counter
    mix = Counter(r[1] for r in mov_rows)
    for t in ("receipt", "sale", "adjustment", "transfer_in", "transfer_out"):
        print(f"  {t:<13} {mix[t]:>6}  ({mix[t] / len(mov_rows):.1%})")


if __name__ == "__main__":
    main()
