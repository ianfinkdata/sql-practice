"""
Central configuration for the Oakhaven build.

Everything that affects determinism or row counts lives here so later
lessons/exercises can cite exact numbers without re-deriving them.

IMPORTANT: this module seeds both the stdlib `random` module and Faker's
shared random instance the moment it is first imported. Every generator
module does `from build_lib.config import fake, ...`, and because Python
caches module imports, the seeding below runs exactly once per build,
before any generation happens -- regardless of which generator imports
config.py first. Do not seed random/Faker anywhere else.
"""

import random
from datetime import date

from faker import Faker

# --- Determinism -----------------------------------------------------------
# Applied to both `random.seed(SEED)` and `Faker.seed(SEED)` before ANY
# generation happens. Never call datetime.now() / date.today() anywhere in
# the generators -- use SNAPSHOT_DATE below instead.
SEED = 20260630
SNAPSHOT_DATE = date(2026, 6, 30)

random.seed(SEED)
Faker.seed(SEED)
fake = Faker("en_US")

# --- Row counts --------------------------------------------------------
N_CUSTOMERS = 600
N_CUSTOMER_DUPLICATE_PEOPLE = 30  # near-duplicate people injected into bronze_customers
N_PRODUCTS = 150
N_EMPLOYEES = 35
N_SALES_LINES = 12000

# --- Date bounds -------------------------------------------------------
CUSTOMER_SIGNUP_START = date(2018, 1, 1)
EMPLOYEE_HIRE_START = date(2018, 1, 1)
SALES_START = date(2021, 1, 1)
CALENDAR_START = date(2018, 1, 1)
CALENDAR_END = date(2038, 12, 31)

# --- Canonical business vocab ------------------------------------------
# These are the "true" values behind the messy casing/spacing variants
# that generators will scramble via messiness.py.
CATEGORIES = [
    "Footwear",
    "Apparel",
    "Camping & Hiking",
    "Climbing",
    "Water Sports",
    "Winter Sports",
    "Accessories",
    "Nutrition & Hydration",
]

US_STATES = [
    ("Alabama", "AL"), ("Alaska", "AK"), ("Arizona", "AZ"), ("Arkansas", "AR"),
    ("California", "CA"), ("Colorado", "CO"), ("Connecticut", "CT"), ("Delaware", "DE"),
    ("Florida", "FL"), ("Georgia", "GA"), ("Hawaii", "HI"), ("Idaho", "ID"),
    ("Illinois", "IL"), ("Indiana", "IN"), ("Iowa", "IA"), ("Kansas", "KS"),
    ("Kentucky", "KY"), ("Louisiana", "LA"), ("Maine", "ME"), ("Maryland", "MD"),
    ("Massachusetts", "MA"), ("Michigan", "MI"), ("Minnesota", "MN"), ("Mississippi", "MS"),
    ("Missouri", "MO"), ("Montana", "MT"), ("Nebraska", "NE"), ("Nevada", "NV"),
    ("New Hampshire", "NH"), ("New Jersey", "NJ"), ("New Mexico", "NM"), ("New York", "NY"),
    ("North Carolina", "NC"), ("North Dakota", "ND"), ("Ohio", "OH"), ("Oklahoma", "OK"),
    ("Oregon", "OR"), ("Pennsylvania", "PA"), ("Rhode Island", "RI"), ("South Carolina", "SC"),
    ("South Dakota", "SD"), ("Tennessee", "TN"), ("Texas", "TX"), ("Utah", "UT"),
    ("Vermont", "VT"), ("Virginia", "VA"), ("Washington", "WA"), ("West Virginia", "WV"),
    ("Wisconsin", "WI"), ("Wyoming", "WY"),
]

CUSTOMER_SEGMENTS = ["Retail", "Wholesale", "VIP"]

DEPARTMENTS = ["Sales", "Support", "Warehouse", "Management"]
REGIONS = ["West", "East", "Central", "South", "Northeast"]

PAYMENT_METHODS = ["Credit Card", "Cash", "Debit Card", "Gift Card", "PayPal"]
ORDER_STATUSES = ["Completed", "Cancelled", "Returned"]
CHANNELS = ["Online", "In-Store"]

DB_PATH = "project/oakhaven.db"
