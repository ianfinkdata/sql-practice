"""Agent A -- dimension generator for Oakhaven Outfitters (contract v1.1).

Generates: stores, product_categories, suppliers, employees, products,
customers, promotions -> oakhaven/data/<table>.csv

All randomness flows from contract.SEED via random.Random(f"{SEED}:<key>").
Faker is seeded once with a CRC32 of f"{SEED}:dimensions" and consumed in a
fixed call order, so reruns are byte-identical.

CSV conventions per contract SS1: UTF-8 no BOM, header row, python csv module
defaults (CRLF via newline=""), dates YYYY-MM-DD, SQL NULL = contract.NULL_TOKEN.
Column order matches ddl/01_schema.sql exactly.
"""

import csv
import os
import random
import zlib
from datetime import date, timedelta

from faker import Faker

import contract

SEED = contract.SEED
NULL = contract.NULL_TOKEN
OUT_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data"))

fake = Faker("en_US")
Faker.seed(zlib.crc32(f"{SEED}:dimensions".encode("utf-8")))


def rng(key):
    return random.Random(f"{SEED}:{key}")


def iso(d):
    return d.isoformat()


def money(x):
    return f"{x:.2f}"


def rand_date(r, start, end):
    """Uniform date in [start, end] inclusive."""
    return start + timedelta(days=r.randrange((end - start).days + 1))


def dirt_slices(ids, key, counts):
    """Deterministically shuffle ids and cut leading slices of given sizes.

    Returns a list of sets, one per count, mutually disjoint."""
    pool = list(ids)
    rng(key).shuffle(pool)
    out, i = [], 0
    for c in counts:
        out.append(frozenset(pool[i:i + c]))
        i += c
    return out


def write_csv(name, header, rows):
    path = os.path.join(OUT_DIR, f"{name}.csv")
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"{name}: {len(rows)} rows")


def email_local(first, last):
    clean = lambda s: "".join(ch for ch in s.lower() if ch.isalpha())
    return f"{clean(first)}.{clean(last)}"


# ------------------------------------------------------------------ stores

def gen_stores():
    r = rng("stores:sqft")
    rows = []
    for sid, code, city, st, opened in contract.STORES:
        sqft = NULL if sid == contract.WEB_STORE_ID else r.randrange(3000, 14001)
        rows.append([sid, code, city, st, iso(opened), sqft])
    write_csv("stores",
              ["store_id", "store_code", "city", "state", "opened_date",
               "square_feet"], rows)


# ------------------------------------------------------- product_categories

def gen_product_categories():
    rows = [[cid, name, NULL if parent is None else parent]
            for cid, name, parent in contract.CATEGORIES]
    write_csv("product_categories",
              ["category_id", "category_name", "parent_category_id"], rows)


# --------------------------------------------------------------- suppliers

SUPPLIER_A = ["Cascade", "Summit", "Rainier", "Timberline", "Alpine",
              "Pacific Crest", "Glacier", "Basecamp", "Northslope",
              "Evergreen", "Blue Ridge", "Silvertip", "Granite Peak",
              "Wolf Creek", "Kestrel", "Osprey Bay", "Larchwood",
              "Stonefield", "Redcedar", "Skyline", "Trailforge", "Windward",
              "Ironwood", "Snowfield", "Riverbend", "Highline", "Duskwatch",
              "Falcon Ridge", "Mossback", "Clearwater", "Fjordland",
              "Sagebrush", "Copper Basin", "Whitecap", "Longtrail",
              "Bearpaw", "Foxglove", "Tamarack", "Obsidian", "Juniper Flats",
              "Cirrus", "Hollowpine", "Saltmarsh", "Windrose"]
SUPPLIER_B = ["Gear Co.", "Outfitting", "Supply Co.", "Equipment",
              "Trading Co.", "Gear Works", "Manufacturing", "Outdoor Supply",
              "Industries", "Textiles"]

# D20: >=3 codings of the US mixed with real trading-partner countries.
SUPPLIER_COUNTRIES = (["USA"] * 10 + ["US"] * 7 + ["United States"] * 6 +
                      ["Canada"] * 6 + ["China"] * 5 + ["Vietnam"] * 4 +
                      ["Taiwan"] * 3 + ["Germany"] * 2 + ["Italy"] * 2)
SUPPLIER_FLAGS = (["Y"] * 18 + ["N"] * 7 + ["1"] * 8 + ["0"] * 4 +
                  ["yes"] * 5 + ["no"] * 3)


def gen_suppliers():
    n = contract.SUPPLIER_COUNT
    ids = list(range(1, n + 1))
    r = rng("suppliers")

    # 44 unique names; one near-dup pair (trailing-period variant) fills 45.
    names, used = [], set()
    for a in SUPPLIER_A:
        name = f"{a} {r.choice(SUPPLIER_B)}"
        while name in used:
            name = f"{a} {r.choice(SUPPLIER_B)}"
        used.add(name)
        names.append(name)
    dup_src, dup_dst = sorted(rng("suppliers:near-dup").sample(ids, 2))
    name_by_id, it = {}, iter(names)
    for sid in ids:
        if sid != dup_dst:
            name_by_id[sid] = next(it)
    base = name_by_id[dup_src]
    name_by_id[dup_dst] = base[:-1] if base.endswith(".") else base + "."

    countries = SUPPLIER_COUNTRIES[:]
    rng("suppliers:country").shuffle(countries)
    flags = SUPPLIER_FLAGS[:]
    rng("suppliers:flag").shuffle(flags)

    # contact_email dirt (contract silent on quota -- minimal): 2 NULL,
    # 1 'N/A', 2 UPPERCASE.  phone dirt: mixed formats + 2 NULL.
    em_null, em_na, em_upper = dirt_slices(ids, "suppliers:email-dirt",
                                           [2, 1, 2])
    ph_null, = dirt_slices(ids, "suppliers:phone-dirt", [2])
    sentinel_ids = frozenset(rng("suppliers:leadtime-sentinel").sample(ids, 2))

    rows = []
    for sid in ids:
        name = name_by_id[sid]
        slug = "".join(ch for ch in name.lower() if ch.isalnum())[:20]
        email = f"{r.choice(['sales', 'info', 'orders'])}@{slug}.com"
        if sid in em_null:
            email = NULL
        elif sid in em_na:
            email = "N/A"
        elif sid in em_upper:
            email = email.upper()
        npa, line = r.randrange(200, 990), r.randrange(0, 10000)
        fmt = r.randrange(4)
        phone = [f"({npa}) 555-{line:04d}", f"{npa}-555-{line:04d}",
                 f"{npa}.555.{line:04d}", f"+1 {npa} 555 {line:04d}"][fmt]
        if sid in ph_null:
            phone = NULL
        lead = -999 if sid in sentinel_ids else r.randrange(3, 46)
        rows.append([sid, name, countries[sid - 1], email, phone, lead,
                     flags[sid - 1]])
    write_csv("suppliers",
              ["supplier_id", "supplier_name", "country", "contact_email",
               "phone", "lead_time_days", "active_flag"], rows)


# --------------------------------------------------------------- employees

TITLE_WAGE = {  # canonical title -> (lo, hi), within contract 16.50-41.00
    "Store Manager": (30.00, 41.00),
    "Assistant Manager": (25.00, 32.00),
    "Sales Associate": (17.00, 23.50),
    "Cashier": (16.50, 20.50),
    "Web Support": (19.50, 27.00),
    "Buyer": (24.00, 33.00),
    "Warehouse Lead": (19.00, 26.00),
}
STORE_TITLES = (["Sales Associate"] * 45 + ["Cashier"] * 25 +
                ["Assistant Manager"] * 12 + ["Warehouse Lead"] * 10 +
                ["Buyer"] * 8)
WEB_TITLES = (["Web Support"] * 55 + ["Buyer"] * 20 +
              ["Warehouse Lead"] * 15 + ["Assistant Manager"] * 10)


def gen_employees():
    r = rng("employees")
    ids = list(contract.EMPLOYEE_IDS)
    open_by_store = {sid: opened for sid, _, _, _, opened in contract.STORES}
    manager_of_store = {sid: min(contract.store_employees(sid))
                        for sid in contract.STORE_IDS}
    manager_ids = set(manager_of_store.values())
    hire_max = date(2026, 5, 31)

    emp = {}
    for eid in ids:  # fixed Faker call order
        sid = contract.store_of_employee(eid)
        opened = open_by_store[sid]
        if eid in manager_ids:
            title = "Store Manager"
        elif sid == contract.WEB_STORE_ID:
            title = r.choice(WEB_TITLES)
        else:
            title = r.choice(STORE_TITLES)
        lo, hi = TITLE_WAGE[title]
        emp[eid] = {
            "first": fake.first_name(), "last": fake.last_name(),
            "title": title, "store": sid,
            "manager": None if eid in manager_ids else manager_of_store[sid],
            "hire": rand_date(r, opened - timedelta(days=60), hire_max),
            "term": None,
            "wage": round(r.uniform(lo, hi), 2),
        }

    # 6 rehired humans: same name under two IDs, different hire dates.
    pr = rng("employees:rehire")
    pool = sorted(set(ids) - manager_ids)
    picks = sorted(pr.sample(pool, 12))
    pairs = list(zip(picks[:6], picks[6:]))
    for a, b in pairs:
        ea, eb = emp[a], emp[b]
        eb["first"], eb["last"] = ea["first"], ea["last"]
        opened_a = open_by_store[ea["store"]]
        ea["hire"] = rand_date(pr, opened_a - timedelta(days=60),
                               date(2024, 6, 30))
        b_min = max(ea["hire"] + timedelta(days=200),
                    open_by_store[eb["store"]] - timedelta(days=60))
        eb["hire"] = min(rand_date(pr, b_min, b_min + timedelta(days=500)),
                         hire_max)
        # first stint ends before the rehire
        ea["term"] = rand_date(pr, ea["hire"] + timedelta(days=60),
                               eb["hire"] - timedelta(days=30))

    # 25% terminated (60 of 240) including the 6 forced pair-firsts
    tr = rng("employees:termination")
    forced = {a for a, _ in pairs}
    extra = tr.sample(sorted(set(ids) - forced - {b for _, b in pairs}),
                      60 - len(forced))
    for eid in extra:
        e = emp[eid]
        e["term"] = min(e["hire"] + timedelta(days=tr.randrange(30, 1500)),
                        contract.DATE_END)

    # D18: wage typo outliers (>150.00), ~1% -> 3 rows: decimal slipped
    for eid in rng("employees:wage-outlier").sample(ids, 3):
        emp[eid]["wage"] = round(emp[eid]["wage"] * 100, 2)

    # D19: job_title casing variants, 6% -> 14 rows
    dirt14, = dirt_slices(ids, "employees:title-dirt", [14])
    variants = [str.lower, str.upper, lambda t: t + " "]
    for i, eid in enumerate(sorted(dirt14)):
        emp[eid]["title"] = variants[i % 3](emp[eid]["title"])

    rows = []
    for eid in ids:
        e = emp[eid]
        rows.append([
            eid, e["first"], e["last"], e["title"], e["store"],
            NULL if e["manager"] is None else e["manager"],
            iso(e["hire"]),
            NULL if e["term"] is None else iso(e["term"]),
            money(e["wage"]),
            f"{email_local(e['first'], e['last'])}@oakhavenoutfitters.com",
        ])
    write_csv("employees",
              ["employee_id", "first_name", "last_name", "job_title",
               "store_id", "manager_id", "hire_date", "termination_date",
               "hourly_wage", "work_email"], rows)


# ---------------------------------------------------------------- products

ADJ = ["Cascade", "Summit", "Ridgeline", "Timberline", "Alpine", "Glacier",
       "Rainier", "Olympic", "Ember", "Nimbus", "Basalt", "Juniper", "Sable",
       "Kestrel", "Boreal", "Torrent", "Zephyr", "Granite", "Skyline",
       "Fjord", "Cinder", "Wildwood", "Meridian", "Solstice", "Tundra",
       "Vista"]
NOUNS = {
    9: ["2-Person Tent", "3-Person Dome Tent", "4-Person Family Tent",
        "Ultralight 1P Tent", "Backpacking Tent 2P", "3-Season Tent",
        "4-Season Expedition Tent", "Bivy Shelter", "Canopy Shelter"],
    10: ["20F Down Sleeping Bag", "0F Winter Sleeping Bag",
         "35F Synthetic Sleeping Bag", "Ultralight Quilt",
         "Double Sleeping Bag", "Kids Sleeping Bag", "Mummy Bag 15F",
         "Sleeping Bag Liner"],
    11: ["2-Burner Camp Stove", "Backpacking Stove", "Cook Set",
         "Camp Coffee Press", "Titanium Pot 900ml", "Camp Grill",
         "Utensil Kit", "Camp Kettle"],
    12: ["65L Backpack", "50L Backpack", "Daypack 22L", "Hydration Pack 12L",
         "Ultralight 40L Pack", "Kids Daypack", "Travel Pack 35L",
         "Summit Pack 18L"],
    13: ["Carbon Trekking Poles", "Aluminum Trekking Poles",
         "Folding Trekking Poles", "Trail Staff", "Shock-Absorber Poles",
         "Ultralight Z-Poles"],
    14: ["Baseplate Compass", "Sighting Compass", "Handheld GPS",
         "Altimeter Watch", "Map Case", "Satellite Messenger"],
    15: ["9.8mm Dynamic Rope 60m", "9.5mm Dynamic Rope 70m",
         "Static Rope 40m", "Climbing Harness", "Big Wall Harness",
         "Kids Harness", "Chalk Bag", "Rope Bag"],
    16: ["Locking Carabiner", "Wiregate Carabiner 4-Pack", "Quickdraw Set",
         "Belay Device", "Ascender", "Rappel Ring", "Cam Set", "Nut Tool"],
    17: ["Touring Kayak 14ft", "Recreational Kayak 10ft",
         "Inflatable Kayak 2P", "Fishing Kayak", "Folding Kayak",
         "Whitewater Kayak"],
    18: ["Carbon Kayak Paddle", "Aluminum Kayak Paddle", "PFD Vest",
         "Youth PFD", "Paddle Leash", "Dry Bag 20L", "Spray Skirt"],
    19: ["Rain Jacket", "Down Jacket", "Softshell Jacket", "Fleece Jacket",
         "Insulated Parka", "Wind Shell", "3-in-1 Jacket"],
    20: ["Merino Base Layer Top", "Merino Base Layer Bottom",
         "Synthetic Crew Top", "Thermal Leggings", "Midweight Half-Zip",
         "Lightweight Tee"],
    21: ["Waterproof Hiking Boots", "Mid Hiking Boots",
         "Leather Backpacking Boots", "Insulated Winter Boots",
         "Approach Shoes"],
    22: ["Trail Running Shoes", "Cushioned Trail Runners",
         "Rocky Terrain Runners", "Waterproof Trail Shoes",
         "Zero-Drop Trail Runners"],
    23: ["All-Mountain Skis", "Backcountry Touring Skis", "Powder Skis",
         "All-Mountain Snowboard 156cm", "Splitboard", "Cross-Country Skis"],
    24: ["32oz Water Bottle", "Insulated Bottle 20oz", "Collapsible Flask",
         "Filter Bottle", "Steel Growler 64oz", "Bike Bottle 24oz"],
}
COLORS = ["Red", "Blue", "Forest Green", "Charcoal", "Slate", "Orange",
          "Teal", "Black", "Sand", "Olive", "Burgundy", "Yellow"]
DISCONTINUED = (["N"] * 460 + ["Y"] * 130 + ["0"] * 85 + ["1"] * 70 +
                ["yes"] * 60 + ["no "] * 45)  # D14: 6 distinct values

CAT_NAME = {cid: name for cid, name, _ in contract.CATEGORIES}


def cat3(cid):
    return "".join(ch for ch in CAT_NAME[cid].upper() if ch.isalpha())[:3]


def gen_products():
    r = rng("products")
    ids = list(contract.PRODUCT_IDS)
    n = len(ids)

    # supplier skew: top 8 suppliers ~50% of SKUs
    top8 = rng("products:top-suppliers").sample(
        range(1, contract.SUPPLIER_COUNT + 1), 8)
    sup_weights = {sid: (6.25 if sid in top8 else 50.0 / 37.0)
                   for sid in range(1, contract.SUPPLIER_COUNT + 1)}

    legacy, = dirt_slices(ids, "products:sku-legacy", [85])          # 10%
    w_null, w_neg = dirt_slices(ids, "products:weight-dirt", [51, 9])  # D13
    nm_dbl, nm_trail, nm_caps = dirt_slices(
        ids, "products:name-dirt", [26, 17, 9])                       # D15
    flags = DISCONTINUED[:]
    rng("products:flag").shuffle(flags)

    sr = rng("products:sku")
    used_skus = set()
    rows = []
    for i, pid in enumerate(ids):
        cid = r.choice(contract.CHILD_CATEGORY_IDS)
        name = f"{r.choice(ADJ)} {r.choice(NOUNS[cid])}"
        if r.random() < 0.25:
            name += f" {r.choice(['Pro', 'XT', 'II', 'Lite', 'SE'])}"
        if pid in nm_dbl:
            name = name.replace(" ", "  ", 1)
        elif pid in nm_trail:
            name += " "
        elif pid in nm_caps:
            name = name.upper()

        while True:
            sku = (f"SKU{sr.randrange(0, 1000000):06d}" if pid in legacy
                   else f"OAK-{cat3(cid)}-{sr.randrange(0, 10000):04d}")
            if sku not in used_skus:
                used_skus.add(sku)
                break

        supplier = r.choices(list(sup_weights), list(sup_weights.values()))[0]
        if pid in w_null:
            weight = NULL
        elif pid in w_neg:
            weight = "-999.00"
        else:
            weight = money(r.uniform(0.05, 28.0))
        intro = rand_date(r, date(2018, 6, 1), date(2026, 3, 31))
        if r.random() < 0.15:
            color = NULL
        else:
            color = r.choice(COLORS)
            cx = r.random()
            if cx < 0.05:
                color = color.lower()
            elif cx < 0.08:
                color = color.upper()
        rows.append([pid, sku, name, cid, supplier,
                     money(contract.product_unit_cost(pid)),
                     money(contract.product_list_price(pid)),
                     weight, iso(intro), flags[i], color])
    write_csv("products",
              ["product_id", "sku", "product_name", "category_id",
               "supplier_id", "unit_cost", "list_price", "weight_kg",
               "intro_date", "discontinued_flag", "color"], rows)


# --------------------------------------------------------------- customers

STATE_DATA = {  # state -> (weight, cities, zip prefixes, area codes)
    "WA": (40, ["Seattle", "Tacoma", "Spokane", "Bellevue", "Olympia",
                "Bellingham", "Everett", "Kirkland", "Renton", "Vancouver"],
           ["980", "981", "982", "983", "984", "985", "988", "990", "992"],
           [206, 253, 360, 425, 509]),
    "OR": (25, ["Portland", "Eugene", "Salem", "Bend", "Corvallis",
                "Medford", "Gresham", "Hood River"],
           ["970", "971", "972", "973", "974", "977"],
           [503, 541, 971]),
    "ID": (10, ["Boise", "Meridian", "Idaho Falls", "Coeur d'Alene",
                "Nampa", "Twin Falls"],
           ["836", "837", "838"], [208]),
    "MT": (8, ["Missoula", "Bozeman", "Billings", "Helena", "Kalispell",
               "Butte"],
           ["590", "591", "594", "597", "598"], [406]),
    "CA": (17, ["Sacramento", "Redding", "San Francisco", "Eureka", "Chico",
                "Truckee"],
           ["940", "941", "943", "945", "949", "950", "952", "956", "959",
            "960"], [916, 530, 415, 510]),
}
STATE_FULL = {"WA": ("Washington", "Wash."), "OR": ("Oregon", "Ore."),
              "ID": ("Idaho", "Ida."), "MT": ("Montana", "Mont."),
              "CA": ("California", "Calif.")}
EMAIL_DOMAINS = ["gmail.com"] * 45 + ["yahoo.com"] * 15 + \
    ["outlook.com"] * 12 + ["hotmail.com"] * 10 + ["icloud.com"] * 10 + \
    ["aol.com"] * 4 + ["comcast.net"] * 4
TIERS = ["Basic", "Silver", "Gold", "Platinum"]
TIER_W = [60, 22, 13, 5]
OPT_IN = ["Y"] * 30 + ["N"] * 25 + ["TRUE"] * 12 + ["FALSE"] * 10 + \
    ["1"] * 13 + ["0"] * 10
PHONE_FMTS = ["({npa}) 555-{line}", "{npa}-555-{line}", "{npa}.555.{line}",
              "+1 {npa} 555 {line}"]
STREET_ABBR = [("Street", "St"), ("Avenue", "Ave"), ("Drive", "Dr"),
               ("Boulevard", "Blvd"), ("Road", "Rd"), ("Court", "Ct"),
               ("Lane", "Ln")]

N_CUST = contract.CUSTOMER_COUNT          # 12000
N_ORIG = 11850                            # dupes are 11851..12000 (D7)


def gen_customers():
    r = rng("customers")
    states = list(STATE_DATA)
    state_w = [STATE_DATA[s][0] for s in states]

    cust = {}
    for cid in range(1, N_ORIG + 1):       # fixed Faker call order
        st = r.choices(states, state_w)[0]
        _, cities, zips, npas = STATE_DATA[st]
        first, last = fake.first_name(), fake.last_name()
        has_middle = r.random() < 0.40      # 60% NULL
        middle = fake.first_name() if has_middle else None
        local = email_local(first, last)
        if r.random() < 0.70:
            local += f"{r.randrange(100):02d}"
        cust[cid] = {
            "first": first, "middle": middle, "last": last,
            "email": f"{local}@{r.choice(EMAIL_DOMAINS)}",
            "npa": r.choice(npas), "line": f"{r.randrange(10000):04d}",
            "street": fake.street_address(),
            "city": r.choice(cities), "state": st,
            "zip": f"{r.choice(zips)}{r.randrange(100):02d}",
            "birth": rand_date(r, date(1936, 7, 1), date(2008, 6, 30)),
            "signup": rand_date(r, contract.DATE_START, contract.DATE_END),
            "tier": r.choices(TIERS, TIER_W)[0],
            "opt": r.choice(OPT_IN),
        }

    # D7 near-dupes: ids 11851-12000 fuzzy-copy 150 originals (SS3.6 key)
    rd = random.Random(f"{SEED}:dupes")
    originals = rd.sample(range(1, N_ORIG + 1), 150)
    dupe_of = {}
    for i, oid in enumerate(originals):
        cid = N_ORIG + 1 + i
        dupe_of[cid] = oid
        o = cust[oid]
        first, last = o["first"], o["last"]
        v = rd.randrange(4)
        if v == 0 and len(first) > 3:       # adjacent-letter swap
            k = rd.randrange(1, len(first) - 1)
            first = first[:k] + first[k + 1] + first[k] + first[k + 2:]
        elif v == 1 and len(first) > 3:     # dropped letter
            k = rd.randrange(1, len(first) - 1)
            first = first[:k] + first[k + 1:]
        elif v == 2:
            first = first[0] + "."
        else:
            first = first.lower()
        if rd.random() < 0.30:
            last = last.upper() if rd.random() < 0.5 else last + " "
        local = email_local(o["first"], o["last"])
        ev = rd.randrange(3)
        if ev == 0:
            email = f"{local.replace('.', '')}@{rd.choice(EMAIL_DOMAINS)}"
        elif ev == 1:
            email = f"{o['first'][0].lower()}{email_local('', o['last'])[1:]}" \
                    f"@{rd.choice(EMAIL_DOMAINS)}"
        else:
            email = f"{local}{rd.randrange(100):02d}@{rd.choice(EMAIL_DOMAINS)}"
        street = o["street"]
        for full, abbr in STREET_ABBR:
            if rd.random() < 0.5:
                street = street.replace(full, abbr)
        cust[cid] = {
            "first": first, "last": last,
            "middle": None if rd.random() < 0.70 else o["middle"],
            "email": email,
            "npa": o["npa"], "line": o["line"],   # same digits (D2/D7)
            "street": street, "city": o["city"], "state": o["state"],
            "zip": o["zip"], "birth": o["birth"],
            "signup": rand_date(rd, o["signup"], contract.DATE_END),
            "tier": o["tier"], "opt": rd.choice(OPT_IN),
        }

    ids = list(range(1, N_CUST + 1))
    # D1 email: NULL 2% / N-A-or-none 1.5% / UPPER 3% / trailing space 2%
    em_null, em_na, em_up, em_tr = dirt_slices(
        ids, "customers:email-dirt", [240, 180, 360, 240])
    # D2 phone: fmt1 60 / fmt2 20 / fmt3 10 / fmt4 5 / N-A 1 / NULL 4 (%)
    ph = dirt_slices(ids, "customers:phone-fmt",
                     [7200, 2400, 1200, 600, 120, 480])
    phone_fmt = {}
    for k, s in enumerate(ph):
        for cid in s:
            phone_fmt[cid] = k                  # 0-3 fmt, 4 N/A, 5 NULL
    # D3 state: full name 10% / abbrev-period 5%
    st_full, st_abbr = dirt_slices(ids, "customers:state-dirt", [1200, 600])
    # D4 city: space 2% / ALLCAPS 2% / lowercase 2%
    ci_sp, ci_up, ci_lo = dirt_slices(ids, "customers:city-dirt",
                                      [240, 240, 240])
    # D5 birth: NULL 5% / 1900-01-01 0.5% / future 0.2% / age>95 0.3%
    b_null, b_1900, b_fut, b_old = dirt_slices(
        ids, "customers:birth-dirt", [600, 60, 24, 36])
    # D6 loyalty casing 5%
    tier_dirt, = dirt_slices(ids, "customers:tier-dirt", [600])
    # postal 2% four-digit (lost leading digit)
    zip_dirt, = dirt_slices(ids, "customers:zip-dirt", [240])

    # dupes keep the original's digits but must render a DIFFERENT format
    fr = rng("customers:dupe-phone")
    for cid in sorted(dupe_of):
        ofmt = phone_fmt[dupe_of[cid]]
        if ofmt <= 3:                            # original renders digits
            choices = [k for k in range(4) if k != ofmt]
            phone_fmt[cid] = fr.choice(choices)

    br = rng("customers:birth-values")
    rows = []
    for cid in ids:
        c = cust[cid]
        email = c["email"]
        if cid in em_null:
            email = NULL
        elif cid in em_na:
            email = "N/A" if cid % 2 else "none"
        elif cid in em_up:
            email = email.upper()
        elif cid in em_tr:
            email = email + " "
        k = phone_fmt[cid]
        if k <= 3:
            phone = PHONE_FMTS[k].format(npa=c["npa"], line=c["line"])
        else:
            phone = "N/A" if k == 4 else NULL
        state = c["state"]
        if cid in st_full:
            state = STATE_FULL[state][0]
        elif cid in st_abbr:
            state = STATE_FULL[state][1]
        city = c["city"]
        if cid in ci_sp:
            city = f" {city}" if cid % 2 else f"{city} "
        elif cid in ci_up:
            city = city.upper()
        elif cid in ci_lo:
            city = city.lower()
        zipc = c["zip"][1:] if cid in zip_dirt else c["zip"]
        if cid in b_null:
            birth = NULL
        elif cid in b_1900:
            birth = "1900-01-01"
        elif cid in b_fut:
            birth = iso(rand_date(br, date(2027, 1, 1), date(2030, 12, 31)))
        elif cid in b_old:
            birth = iso(rand_date(br, date(1922, 1, 1), date(1930, 6, 30)))
        else:
            birth = iso(c["birth"])
        tier = c["tier"]
        if cid in tier_dirt:
            tier = [tier.upper(), tier.lower(), tier + " ",
                    tier.lower() + " "][cid % 4]
        rows.append([cid, c["first"],
                     NULL if c["middle"] is None else c["middle"],
                     c["last"], email, phone, c["street"], city, state,
                     zipc, birth, iso(c["signup"]), tier, c["opt"]])
    write_csv("customers",
              ["customer_id", "first_name", "middle_name", "last_name",
               "email", "phone", "street_address", "city", "state",
               "postal_code", "birth_date", "signup_date", "loyalty_tier",
               "marketing_opt_in"], rows)


# -------------------------------------------------------------- promotions

PROMO_THEMES = ["camping gear", "hiking essentials", "climbing hardware",
                "paddling gear", "outdoor apparel", "footwear",
                "winter sports equipment", "trail accessories",
                "select tents and shelters", "backpacks and daypacks"]
PROMO_TAGS = ["while supplies last", "in stores and online",
              "members save even more", "limited time only",
              "no code stacking", "excludes clearance items"]


def gen_promotions():
    r = rng("promotions:description")
    ids = [p[0] for p in contract.PROMOS]
    null_ids = frozenset(rng("promotions:desc-null").sample(ids, 7))  # 10%
    lower_ids = frozenset(rng("promotions:code-case").sample(ids, 3))  # ~4%
    rows = []
    for pid, code, start, end, pct in contract.PROMOS:
        if pid in lower_ids:
            code = code.lower()
        if pid in null_ids:
            desc = NULL
        else:
            desc = (f"Save {pct}% on {r.choice(PROMO_THEMES)} -- "
                    f"{r.choice(PROMO_TAGS)}.")
        rows.append([pid, code, iso(start), iso(end), f"{pct:.1f}", desc])
    write_csv("promotions",
              ["promo_id", "promo_code", "start_date", "end_date",
               "discount_pct", "description"], rows)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    gen_stores()
    gen_product_categories()
    gen_suppliers()
    gen_employees()
    gen_products()
    gen_customers()
    gen_promotions()


if __name__ == "__main__":
    main()
