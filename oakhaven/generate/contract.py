"""Oakhaven Outfitters data contract -- executable twin of DATA_CONTRACT.md.

This module IS the contract. Generator agents (A: dimensions, B: sales,
C: logistics) import from it and must never redefine a constant or function
found here. If the contract is silent on something, flag it in your report --
do not improvise. Any change requires Ian's sign-off and a CONTRACT_VERSION
bump, after which affected tables are regenerated in full (never patch CSVs).

Determinism: every value derives from SEED through random.Random seeded with
a string key. String seeding in CPython is hash-independent, so any process
importing this module computes identical values. This is what lets Agent B
emit a customer_id and Agent C compute shipment dates for an order neither
has "seen" -- they both derive the same truth from the same functions.
"""

import random
from datetime import date, datetime, timedelta

CONTRACT_VERSION = "1.2"
SEED = "oakhaven-v1"
SCHEMA = "oakhaven"

# CSV conventions (all agents): UTF-8 no BOM, header row = column names,
# python csv module defaults, datetimes 'YYYY-MM-DD HH:MM:SS', dates
# 'YYYY-MM-DD', SQL NULL written as unquoted \N via NULL_TOKEN.
NULL_TOKEN = r"\N"

DATE_START = date(2019, 1, 1)
DATE_END = date(2026, 6, 30)

# --------------------------------------------------------------- ID ranges
# PK ranges are FIXED here so agents can emit valid FKs independently.
WEB_STORE_ID = 13
EMPLOYEE_ID_START, EMPLOYEE_COUNT = 100, 240
SUPPLIER_COUNT = 45                      # supplier_id 1..45
CATEGORY_COUNT = 24                      # category_id 1..24
PRODUCT_ID_START, PRODUCT_COUNT = 10001, 850
CUSTOMER_COUNT = 12000                   # customer_id 1..12000
PROMO_COUNT = 70                         # promo_id 1..70
ORDER_ID_START, ORDER_COUNT = 100001, 60000

EMPLOYEE_IDS = range(EMPLOYEE_ID_START, EMPLOYEE_ID_START + EMPLOYEE_COUNT)
PRODUCT_IDS = range(PRODUCT_ID_START, PRODUCT_ID_START + PRODUCT_COUNT)
ORDER_IDS = range(ORDER_ID_START, ORDER_ID_START + ORDER_COUNT)

# ------------------------------------------------------------------ stores
# Normative rows: (store_id, store_code, city, state, opened_date).
# Agent A renders these exactly as-is (stores is a clean utility dim).
STORES = [
    (1,  "SEA-PIKE", "Seattle",  "WA", date(2019, 1, 1)),
    (2,  "SEA-BAL",  "Seattle",  "WA", date(2019, 1, 1)),
    (3,  "TAC-01",   "Tacoma",   "WA", date(2019, 3, 1)),
    (4,  "BEL-01",   "Bellevue", "WA", date(2019, 6, 1)),
    (5,  "SPO-01",   "Spokane",  "WA", date(2019, 9, 1)),
    (6,  "PDX-PRL",  "Portland", "OR", date(2019, 1, 1)),
    (7,  "PDX-HAW",  "Portland", "OR", date(2020, 2, 1)),
    (8,  "EUG-01",   "Eugene",   "OR", date(2020, 8, 1)),
    (9,  "BOI-01",   "Boise",    "ID", date(2021, 4, 1)),
    (10, "MSO-01",   "Missoula", "MT", date(2021, 10, 1)),
    (11, "BZN-01",   "Bozeman",  "MT", date(2023, 3, 1)),
    (12, "BEN-01",   "Bend",     "OR", date(2024, 5, 1)),
    (13, "WEB",      "Online",   "WA", date(2019, 1, 1)),
]
STORE_IDS = [s[0] for s in STORES]

# -------------------------------------------------------------- categories
# Normative rows: (category_id, category_name, parent_category_id).
# 1-8 are parents; products attach to child categories (9-24) only.
CATEGORIES = [
    (1,  "Camping",                None),
    (2,  "Hiking",                 None),
    (3,  "Climbing",               None),
    (4,  "Paddling",               None),
    (5,  "Apparel",                None),
    (6,  "Footwear",               None),
    (7,  "Winter Sports",          None),
    (8,  "Accessories",            None),
    (9,  "Tents",                  1),
    (10, "Sleeping Bags",          1),
    (11, "Camp Kitchen",           1),
    (12, "Backpacks",              2),
    (13, "Trekking Poles",         2),
    (14, "Navigation",             2),
    (15, "Ropes & Harnesses",      3),
    (16, "Carabiners & Hardware",  3),
    (17, "Kayaks",                 4),
    (18, "Paddles & PFDs",         4),
    (19, "Jackets",                5),
    (20, "Base Layers",            5),
    (21, "Hiking Boots",           6),
    (22, "Trail Runners",          6),
    (23, "Skis & Snowboards",      7),
    (24, "Water Bottles",          8),
]
CHILD_CATEGORY_IDS = [c[0] for c in CATEGORIES if c[2] is not None]

# ------------------------------------------------- demand shape (normative)
MONTH_WEIGHT = {1: 0.72, 2: 0.70, 3: 0.85, 4: 0.95, 5: 1.15, 6: 1.35,
                7: 1.45, 8: 1.40, 9: 1.10, 10: 0.95, 11: 1.20, 12: 1.30}
YEAR_GROWTH = {2019: 0.55, 2020: 0.52, 2021: 0.75, 2022: 0.92,
               2023: 1.05, 2024: 1.18, 2025: 1.30, 2026: 1.38}
COVID_DIP = {(2020, 3): 0.45, (2020, 4): 0.35, (2020, 5): 0.55, (2020, 6): 0.75}
DOW_WEIGHT = [0.95, 0.85, 0.85, 0.90, 1.10, 1.35, 1.25]   # Mon..Sun
_HOUR_WEIGHTS = [2, 3, 4, 5, 6, 6, 5, 5, 5, 6, 6, 5, 4, 3]  # hours 8..21

CHANNEL_WEB_SHARE = 0.45      # WEB orders; the rest are STORE
STORE_DELIVERY_SHARE = 0.08   # STORE orders that also ship to home
PROMO_ATTACH_RATE = 0.25
STATUS_DIST = [("completed", 0.91), ("refunded", 0.04),
               ("cancelled", 0.03), ("pending", 0.02)]
LINE_COUNT_WEIGHTS = {1: 30, 2: 27, 3: 19, 4: 11, 5: 6, 6: 4, 7: 2, 8: 1}


def _day_weight(d):
    w = MONTH_WEIGHT[d.month] * YEAR_GROWTH[d.year] * DOW_WEIGHT[d.weekday()]
    return w * COVID_DIP.get((d.year, d.month), 1.0)


_DAYS = [DATE_START + timedelta(days=i)
         for i in range((DATE_END - DATE_START).days + 1)]
_DAY_WEIGHTS = [_day_weight(d) for d in _DAYS]


def _build_order_dates():
    r = random.Random(f"{SEED}:order-dates")
    days = r.choices(_DAYS, weights=_DAY_WEIGHTS, k=ORDER_COUNT)
    days.sort()   # order_id is chronological, like a real auto-increment
    return days


ORDER_DATES = _build_order_dates()

# -------------------------------------------------------------- promotions
# Normative rows: (promo_id, promo_code, start_date, end_date, discount_pct).
# Agent A renders these (plus its own descriptive/dirty columns); Agent B
# reads them to attach promos to orders.


def _build_promos():
    r = random.Random(f"{SEED}:promos")
    promos = []
    for pid in range(1, PROMO_COUNT + 1):
        start = r.choice(_DAYS[:-45])
        end = min(start + timedelta(days=r.randrange(7, 45)), DATE_END)
        pct = r.choice([5, 10, 10, 15, 15, 20, 25, 30])
        promos.append((pid, f"PROMO-{pid:03d}", start, end, pct))
    return promos


PROMOS = _build_promos()

# --------------------------------------------------------------- employees


def store_of_employee(employee_id):
    return STORE_IDS[(employee_id - EMPLOYEE_ID_START) % len(STORE_IDS)]


_STORE_EMPLOYEES = {}
for _eid in EMPLOYEE_IDS:
    _STORE_EMPLOYEES.setdefault(store_of_employee(_eid), []).append(_eid)


def store_employees(store_id):
    return list(_STORE_EMPLOYEES[store_id])

# ----------------------------------------------------------------- pricing
# Normative so Agent A (products.csv) and Agent B (order_items.unit_price)
# agree on prices without sharing files.


def product_unit_cost(product_id):
    r = random.Random(f"{SEED}:cost:{product_id}")
    return round(r.uniform(4.0, 240.0), 2)


def product_list_price(product_id):
    r = random.Random(f"{SEED}:price:{product_id}")
    price = product_unit_cost(product_id) * r.uniform(1.6, 2.4)
    ra = random.Random(f"{SEED}:price-anomaly:{product_id}")
    if ra.random() < 0.02:   # discoverable anomaly: priced below cost
        price = product_unit_cost(product_id) * 0.8
    return max(round(price) - 0.01, 0.99)

# ------------------------------------------------------------ order header
# THE cross-agent interface. Agent B renders orders.csv from this (plus its
# own dirty columns); Agent C calls it to build shipments without ever
# reading orders.csv.


def stores_open_on(d):
    return [sid for sid, _, _, _, opened in STORES
            if opened <= d and sid != WEB_STORE_ID]


def order_header(order_id):
    if order_id not in ORDER_IDS:
        raise ValueError(f"order_id {order_id} outside contract range")
    r = random.Random(f"{SEED}:order:{order_id}")
    d = ORDER_DATES[order_id - ORDER_ID_START]
    hour = r.choices(range(8, 22), weights=_HOUR_WEIGHTS)[0]
    order_ts = datetime(d.year, d.month, d.day, hour,
                        r.randrange(60), r.randrange(60))
    if r.random() < CHANNEL_WEB_SHARE:
        channel, store_id, employee_id = "WEB", WEB_STORE_ID, None
    else:
        channel = "STORE"
        store_id = r.choice(stores_open_on(d))
        employee_id = r.choice(store_employees(store_id))
    # power-law skew: low-ID customers are long-tenured repeat buyers
    customer_id = min(int(CUSTOMER_COUNT * (r.random() ** 1.8)) + 1,
                      CUSTOMER_COUNT)
    x, cum, status = r.random(), 0.0, "completed"
    for name, share in STATUS_DIST:
        cum += share
        if x < cum:
            status = name
            break
    if status == "pending" and (DATE_END - d).days > 14:
        status = "completed"   # only recent orders may still be pending
    promo_id = None
    if r.random() < PROMO_ATTACH_RATE:
        active = [pid for pid, _, s, e, _ in PROMOS if s <= d <= e]
        if active:
            promo_id = r.choice(active)
    wants_shipment = channel == "WEB" or r.random() < STORE_DELIVERY_SHARE
    return {
        "order_id": order_id,
        "order_ts": order_ts,
        "channel": channel,
        "store_id": store_id,
        "customer_id": customer_id,
        "employee_id": employee_id,
        "promo_id": promo_id,
        "status": status,
        "has_shipment": wants_shipment and status != "cancelled",
    }


def order_line_count(order_id):
    r = random.Random(f"{SEED}:lines:{order_id}")
    return r.choices(list(LINE_COUNT_WEIGHTS),
                     weights=list(LINE_COUNT_WEIGHTS.values()))[0]


if __name__ == "__main__":
    # smoke test: print contract vitals
    first, last = order_header(ORDER_ID_START), order_header(ORDER_ID_START + ORDER_COUNT - 1)
    ships = sum(order_header(i)["has_shipment"] for i in ORDER_IDS)
    lines = sum(order_line_count(i) for i in ORDER_IDS)
    print(f"contract v{CONTRACT_VERSION} seed={SEED}")
    print(f"orders: {ORDER_COUNT}  first={first['order_ts']}  last={last['order_ts']}")
    print(f"expected order_items rows: {lines}")
    print(f"expected shipped orders:   {ships}")
    print(f"promos: {len(PROMOS)}  stores: {len(STORES)}  categories: {len(CATEGORIES)}")
