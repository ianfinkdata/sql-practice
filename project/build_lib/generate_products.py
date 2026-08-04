"""
Generates bronze_products: ~150 rows across the 8 canonical Oakhaven
categories, with messy category casing, dirty weight_kg text, and a
deliberate ~2% SKU collision rate across different product_ids.
"""

import random
from datetime import timedelta

from build_lib import messiness as mz
from build_lib.config import CATEGORIES, N_PRODUCTS, SNAPSHOT_DATE, CUSTOMER_SIGNUP_START

CATEGORY_SUBCATEGORIES = {
    "Footwear": ["Hiking Boots", "Trail Running Shoes", "Sandals", "Insulated Boots", "Approach Shoes"],
    "Apparel": ["Jackets", "Base Layers", "Pants", "Fleece", "Rain Shells"],
    "Camping & Hiking": ["Tents", "Sleeping Bags", "Backpacks", "Camp Stoves", "Trekking Poles"],
    "Climbing": ["Harnesses", "Ropes", "Carabiners", "Climbing Shoes", "Chalk Bags"],
    "Water Sports": ["Kayaks", "Paddles", "Life Jackets", "Wetsuits", "Dry Bags"],
    "Winter Sports": ["Skis", "Snowboards", "Snowshoes", "Goggles", "Winter Gloves"],
    "Accessories": ["Hats", "Sunglasses", "Water Bottles", "Headlamps", "Multi-Tools"],
    "Nutrition & Hydration": ["Energy Bars", "Hydration Packs", "Electrolyte Mixes", "Trail Mix", "Water Filters"],
}

PRODUCT_NAME_ADJECTIVES = [
    "Summit", "Alpine", "Ridge", "Trailhead", "Basecamp", "Cascade", "Highline",
    "Timberline", "Backcountry", "Switchback", "Granite", "Glacier", "Meridian",
    "Outrider", "Wayfinder", "Ironpeak", "Driftwood", "Northbound", "Canyon", "Foothill",
]

BRAND_POOL = [
    "Cairnwright", "Fjellborn", "Stonepine Gear", "Driftline Outfitters", "Kestrel Outdoor",
    "Northfell", "Wildstride", "Basalt & Birch", "Highmark Supply Co.", "Tundraworks",
    "Ridgeway Co.", "Bramblewood Gear", "Pinepack", "Crestline Outdoor", "Foghorn Supply",
    "Elkstone", "Sablecrest", "Ambervale Gear", "Thistledown Outfitters", "Ironwood Trail Co.",
    "Marrowpeak", "Windrow Gear", "Hollowridge", "Copperfen", "Silverbrook Outdoor",
]

DEFAULT_START = CUSTOMER_SIGNUP_START


def _weight_kg_text():
    if random.random() < 0.08:
        return None
    kg = round(random.uniform(0.05, 25.0), random.choice([1, 1, 2]))
    if random.random() < 0.4:
        return f"{kg} kg"
    return str(kg)


def _sku(product_id, category):
    code = "".join(ch for ch in category.upper() if ch.isalpha())[:3]
    return f"{code}-{product_id:04d}"


def generate(conn):
    rows = []
    for product_id in range(1, N_PRODUCTS + 1):
        category = CATEGORIES[(product_id - 1) % len(CATEGORIES)]
        # shuffle order across the run so category isn't perfectly striped
        category = random.choice(CATEGORIES) if product_id > len(CATEGORIES) else category
        subcats = CATEGORY_SUBCATEGORIES[category]
        subcategory = random.choice(subcats)

        adjective = random.choice(PRODUCT_NAME_ADJECTIVES)
        product_name = f"{adjective} {subcategory[:-1] if subcategory.endswith('s') and random.random() < 0.3 else subcategory}"

        brand = random.choice(BRAND_POOL)

        unit_cost = round(random.uniform(4.0, 320.0), 2)
        markup = random.uniform(1.3, 2.6)
        unit_price = round(unit_cost * markup, 2)

        if random.random() < 0.01:
            unit_cost = -abs(unit_cost)
        unit_cost_val = mz.maybe_null(unit_cost, 0.03)

        created = DEFAULT_START + timedelta(
            days=random.randint(0, (SNAPSHOT_DATE - DEFAULT_START).days)
        )

        row = {
            "product_id": product_id,
            "product_name": product_name,
            "category": mz.messy_category(category),
            "subcategory": mz.maybe_null(subcategory, 0.10),
            "brand": brand,
            "unit_cost": unit_cost_val,
            "unit_price": unit_price,
            "is_discontinued": mz.messy_bool(random.random() < 0.08),
            "sku": _sku(product_id, category),
            "weight_kg": _weight_kg_text(),
            "created_at": mz.messy_date(created),
        }
        rows.append(row)

    # Deliberate SKU collisions: each collision affects 2 product_ids
    # (the target + its donor), so picking ~1% of products as targets
    # yields ~2% of products total sharing a duplicated SKU.
    n_collisions = max(1, round(N_PRODUCTS * 0.01))
    collision_targets = random.sample(range(N_PRODUCTS), n_collisions)
    for idx in collision_targets:
        donor_idx = random.choice([i for i in range(N_PRODUCTS) if i != idx])
        rows[idx]["sku"] = rows[donor_idx]["sku"]

    conn.executemany(
        """INSERT INTO bronze_products
           (product_id, product_name, category, subcategory, brand, unit_cost, unit_price,
            is_discontinued, sku, weight_kg, created_at)
           VALUES (:product_id, :product_name, :category, :subcategory, :brand, :unit_cost, :unit_price,
                   :is_discontinued, :sku, :weight_kg, :created_at)""",
        rows,
    )
    return rows
