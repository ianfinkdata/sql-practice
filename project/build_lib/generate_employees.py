"""
Generates bronze_employees: ~35 rows. termination_date is the SCD Type 2
hook for a later lesson -- NULL for ~85% (still employed), populated with
a date strictly after hire_date for ~15%.
"""

import random
from datetime import timedelta

from build_lib import messiness as mz
from build_lib.config import DEPARTMENTS, EMPLOYEE_HIRE_START, N_EMPLOYEES, REGIONS, SNAPSHOT_DATE, fake


def _random_date_between(start, end):
    delta_days = (end - start).days
    offset = random.randint(0, delta_days)
    return start + timedelta(days=offset)


def generate(conn):
    rows = []
    for employee_id in range(1, N_EMPLOYEES + 1):
        first = fake.first_name()
        last = fake.last_name()
        department = random.choice(DEPARTMENTS)
        region = random.choice(REGIONS)

        hire_date = _random_date_between(EMPLOYEE_HIRE_START, SNAPSHOT_DATE)

        termination_date = None
        if random.random() < 0.15:
            max_days_after = (SNAPSHOT_DATE - hire_date).days
            if max_days_after > 1:
                offset = random.randint(1, max_days_after)
                termination_date = hire_date + timedelta(days=offset)

        email_clean = f"{first}.{last}@oakhaven.com".lower()

        row = {
            "employee_id": employee_id,
            "first_name": mz.random_name_casing(first),
            "last_name": mz.random_name_casing(last),
            "department": mz.scramble_casing(department),
            "region": mz.scramble_casing(region),
            "hire_date": mz.messy_date(hire_date),
            "termination_date": mz.messy_date(termination_date) if termination_date else None,
            "is_manager": mz.messy_bool(random.random() < 0.25),
            "email": mz.maybe_null(email_clean, 0.05),
        }
        rows.append(row)

    conn.executemany(
        """INSERT INTO bronze_employees
           (employee_id, first_name, last_name, department, region, hire_date,
            termination_date, is_manager, email)
           VALUES (:employee_id, :first_name, :last_name, :department, :region, :hire_date,
                   :termination_date, :is_manager, :email)""",
        rows,
    )
    return rows
