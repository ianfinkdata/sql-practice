#!/usr/bin/env python3
"""
One-command build entry point for the Oakhaven practice database.

Usage (from the repo root):
    pip install -r project/requirements.txt
    python project/build.py

Deletes and recreates project/oakhaven.db every run. Safe to rerun --
given the fixed SEED/SNAPSHOT_DATE in build_lib/config.py, every rerun
produces byte-identical bronze data (row counts, generated values, and
downstream query results are all deterministic).
"""

import os
import sqlite3
import sys
import time

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

from build_lib import generate_customers, generate_employees, generate_products, generate_sales, validate  # noqa: E402
from build_lib.config import DB_PATH as _CONFIG_DB_PATH  # noqa: E402,F401
from build_lib.config import SEED, SNAPSHOT_DATE  # noqa: E402

DB_PATH = os.path.join(BASE_DIR, "oakhaven.db")
BRONZE_DIR = os.path.join(BASE_DIR, "bronze")
SILVER_DIR = os.path.join(BASE_DIR, "silver")
GOLD_DIR = os.path.join(BASE_DIR, "gold")


def _read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def _run_sql_dir(conn, directory, label):
    filenames = sorted(os.listdir(directory))
    sql_files = [f for f in filenames if f.endswith(".sql")]
    for filename in sql_files:
        path = os.path.join(directory, filename)
        print(f"  -> executing {label}/{filename}")
        conn.executescript(_read(path))


def main():
    t0 = time.time()
    print(f"Oakhaven build starting. SEED={SEED} SNAPSHOT_DATE={SNAPSHOT_DATE}")

    # (1) delete existing db if present
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
        print(f"Removed existing {DB_PATH}")

    # (2) connect
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = OFF;")  # bronze has no FK constraints by design

    # (3) bronze schema
    print("Creating bronze schema...")
    conn.executescript(_read(os.path.join(BRONZE_DIR, "schema.sql")))

    # (4)-(7) generate + insert bronze data, in a fixed order
    print("Generating bronze_customers...")
    generate_customers.generate(conn)

    print("Generating bronze_products...")
    product_rows = generate_products.generate(conn)

    print("Generating bronze_employees...")
    generate_employees.generate(conn)

    print("Generating bronze_sales...")
    generate_sales.generate(conn, product_rows)

    # (8) calendar spine, via recursive CTE SQL (not a Python loop)
    print("Building bronze_calendar via recursive CTE...")
    conn.executescript(_read(os.path.join(BRONZE_DIR, "calendar_recursive_cte.sql")))

    # (9) silver views
    print("Creating silver views...")
    _run_sql_dir(conn, SILVER_DIR, "silver")

    # (10) gold views
    print("Creating gold views...")
    _run_sql_dir(conn, GOLD_DIR, "gold")

    conn.commit()

    # (11) validate + summary
    print()
    print("Running validation checks...")
    summary_lines = validate.run(conn)
    print()
    print("\n".join(summary_lines))

    # (12) commit + close
    conn.commit()
    conn.close()

    elapsed = time.time() - t0
    print()
    print(f"Build complete in {elapsed:.1f}s. Database: {DB_PATH}")


if __name__ == "__main__":
    main()
