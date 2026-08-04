"""
Generates bronze_customers: ~600 rows, ~30 of which are intentional
near-duplicate people (same real person, different customer_id, varied
name casing/whitespace/email) to support a later dedup-with-ROW_NUMBER
lesson.

customer_id is a contiguous 1..N_CUSTOMERS sequence -- callers elsewhere
in the build (bronze_sales orphan FK generation) rely on that contiguity.
"""

import random
from datetime import timedelta

from build_lib import messiness as mz
from build_lib.config import (
    CUSTOMER_SEGMENTS,
    CUSTOMER_SIGNUP_START,
    N_CUSTOMER_DUPLICATE_PEOPLE,
    N_CUSTOMERS,
    SNAPSHOT_DATE,
    US_STATES,
    fake,
)


def _random_date_between(start, end):
    delta_days = (end - start).days
    offset = random.randint(0, delta_days)
    return start + timedelta(days=offset)


def _make_phone():
    if random.random() < 0.08:
        return None
    area = random.randint(200, 989)
    prefix = random.randint(200, 999)
    line = random.randint(1000, 9999)
    return mz.messy_phone(f"{area}", f"{prefix}", f"{line}")


_EMAIL_DOMAINS = ["gmail.com", "yahoo.com", "outlook.com", "hotmail.com", "icloud.com", "oakmail.com"]


def _make_email(first, last):
    domain = random.choice(_EMAIL_DOMAINS)
    local = f"{first}.{last}".lower().replace(" ", "")
    return f"{local}@{domain}"


def _base_row(customer_id):
    first = fake.first_name()
    last = fake.last_name()
    email_clean = _make_email(first, last)
    state_full, state_abbr = random.choice(US_STATES)
    signup = _random_date_between(CUSTOMER_SIGNUP_START, SNAPSHOT_DATE)
    is_active_true = random.random() < 0.85
    segment = random.choice(CUSTOMER_SEGMENTS)

    email = mz.maybe_null(email_clean, 0.04)
    if email is not None:
        email = mz.maybe_empty(email, 0.02)

    state = mz.messy_state(state_full, state_abbr)
    state = mz.maybe_null(state, 0.03)
    if state is not None:
        state = mz.maybe_empty(state, 0.02)

    row = {
        "customer_id": customer_id,
        "first_name": mz.inject_whitespace(mz.random_name_casing(first)),
        "last_name": mz.inject_whitespace(mz.random_name_casing(last)),
        "email": email,
        "phone": _make_phone(),
        "state": state,
        "signup_date": mz.messy_date(signup),
        "is_active": mz.messy_bool(is_active_true),
        "customer_segment": mz.maybe_null(mz.scramble_casing(segment), 0.03),
    }
    return row, first, last, email_clean


def _duplicate_row(customer_id, first, last, email_clean):
    state_full, state_abbr = random.choice(US_STATES)
    signup = _random_date_between(CUSTOMER_SIGNUP_START, SNAPSHOT_DATE)
    is_active_true = random.random() < 0.85
    segment = random.choice(CUSTOMER_SEGMENTS)

    dup_first = mz.inject_whitespace(mz.random_name_casing(first), prob=0.5)
    dup_last = mz.inject_whitespace(mz.random_name_casing(last), prob=0.5)
    email_variant = random.choice(
        [email_clean.upper(), email_clean.title(), " " + email_clean, email_clean + " ", email_clean]
    )

    return {
        "customer_id": customer_id,
        "first_name": dup_first,
        "last_name": dup_last,
        "email": email_variant,
        "phone": _make_phone(),
        "state": mz.messy_state(state_full, state_abbr),
        "signup_date": mz.messy_date(signup),
        "is_active": mz.messy_bool(is_active_true),
        "customer_segment": mz.scramble_casing(segment),
    }


def generate(conn):
    """Generate and insert bronze_customers. Returns the list of row dicts."""
    base_count = N_CUSTOMERS - N_CUSTOMER_DUPLICATE_PEOPLE
    rows = []
    base_people = []  # (first, last, email_clean) per base customer_id, in order

    for i in range(1, base_count + 1):
        row, first, last, email_clean = _base_row(i)
        rows.append(row)
        base_people.append((first, last, email_clean))

    dup_source_indices = sorted(random.sample(range(base_count), N_CUSTOMER_DUPLICATE_PEOPLE))
    next_id = base_count + 1
    for idx in dup_source_indices:
        first, last, email_clean = base_people[idx]
        rows.append(_duplicate_row(next_id, first, last, email_clean))
        next_id += 1

    conn.executemany(
        """INSERT INTO bronze_customers
           (customer_id, first_name, last_name, email, phone, state, signup_date, is_active, customer_segment)
           VALUES (:customer_id, :first_name, :last_name, :email, :phone, :state, :signup_date, :is_active, :customer_segment)""",
        rows,
    )
    return rows
