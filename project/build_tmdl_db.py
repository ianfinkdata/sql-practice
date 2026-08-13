#!/usr/bin/env python3
"""
build_tmdl_db.py - Stands up project/tmdl_catalog.db & Populates TMDL Tables

1. Compiles TMDL definitions and creates TMDL table schemas + metadata catalogs.
2. Attaches project/oakhaven.db and populates data rows directly into the TMDL tables.
"""

import sys
import sqlite3
from pathlib import Path

PROJECT_DIR = Path(__file__).parent.resolve()
REPO_ROOT = PROJECT_DIR.parent
TOOLS_DIR = REPO_ROOT / "pbip_poc" / "tools"

# Add tools folder to path
sys.path.insert(0, str(TOOLS_DIR))
import parse_tmdl

TARGET_DB = PROJECT_DIR / "tmdl_catalog.db"
OAKHAVEN_DB = PROJECT_DIR / "oakhaven.db"


def populate_tmdl_tables(conn):
    """Populates data from oakhaven.db into corresponding tmdl_* tables."""
    cursor = conn.cursor()
    cursor.execute(f"ATTACH DATABASE '{OAKHAVEN_DB}' AS oakhaven;")
    
    # Get all tmdl_* tables in target DB
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'tmdl_%';")
    tmdl_tables = [row[0] for row in cursor.fetchall()]
    
    populated_count = 0
    for tbl in tmdl_tables:
        # Determine matching source table in oakhaven.db
        source_tbl = None
        for base in ["fact_sales", "dim_customer", "dim_product", "dim_employee", "dim_date", "bronze_sales"]:
            if tbl.endswith(f"_{base}"):
                source_tbl = base
                break
                
        if source_tbl:
            cursor.execute(f"PRAGMA table_info({tbl});")
            target_cols = [r[1] for r in cursor.fetchall()]
            
            cursor.execute(f"PRAGMA oakhaven.table_info({source_tbl});")
            source_cols = [r[1] for r in cursor.fetchall()]
            
            common_cols = [c for c in target_cols if c in source_cols]
            if common_cols:
                col_str = ", ".join(common_cols)
                insert_sql = f"INSERT INTO {tbl} ({col_str}) SELECT {col_str} FROM oakhaven.{source_tbl};"
                cursor.execute(insert_sql)
                populated_count += cursor.rowcount

    conn.commit()
    cursor.execute("DETACH DATABASE oakhaven;")
    return populated_count


def main():
    print("==================================================================")
    print("  STANDING UP & POPULATING TMDL CATALOG DATABASE (project/tmdl_catalog.db)")
    print("==================================================================")
    
    projects = parse_tmdl.parse_all_projects()
    full_sql = parse_tmdl.generate_sql_ddl_and_catalogs(projects)
    parse_tmdl.test_push_to_db(full_sql, TARGET_DB)
    
    conn = sqlite3.connect(TARGET_DB)
    rows_inserted = populate_tmdl_tables(conn)
    conn.close()
    
    print("\n------------------------------------------------------------------")
    print(f"✅ Standup & Data Population Complete!")
    print(f"   • Database Target     : {TARGET_DB.resolve()}")
    print(f"   • Total Rows Inserted : {rows_inserted:,} data rows populated")
    print("------------------------------------------------------------------")

if __name__ == "__main__":
    main()
