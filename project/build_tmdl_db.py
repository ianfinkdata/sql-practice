#!/usr/bin/env python3
"""
build_tmdl_db.py - Stands up project/tmdl_catalog.db from TMDL Schema DDL

Compiles TMDL definitions and writes the enriched TMDL tables, 
relationships, and metadata catalog directly into project/tmdl_catalog.db.
"""

import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).parent.resolve()
REPO_ROOT = PROJECT_DIR.parent
TOOLS_DIR = REPO_ROOT / "pbip_poc" / "tools"

# Add tools folder to path
sys.path.insert(0, str(TOOLS_DIR))
import parse_tmdl

TARGET_DB = PROJECT_DIR / "tmdl_catalog.db"

def main():
    print("==================================================================")
    print("  STANDING UP TMDL CATALOG DATABASE (project/tmdl_catalog.db)")
    print("==================================================================")
    
    projects = parse_tmdl.parse_all_projects()
    full_sql = parse_tmdl.generate_sql_ddl_and_catalogs(projects)
    parse_tmdl.test_push_to_db(full_sql, TARGET_DB)
    
    print(f"\n✅ Standup Complete! Database file location:")
    print(f"   └── {TARGET_DB.resolve()}")

if __name__ == "__main__":
    main()
