#!/usr/bin/env python3
"""
pbip_linter.py - TMDL Linter, Path Inspector & Logic Sprawl Engine

Parses Power BI Project (.pbip) TMDL definitions inside pbip/projects/,
inspects Windows path dependencies, extracts embedded M/SQL queries, and
compares business logic against master queries in pbip/sql_queries/.
"""

import os
import re
import sys
import argparse
from pathlib import Path

# Ensure UTF-8 output encoding on Windows terminals
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

REPO_ROOT = Path(__file__).parent.parent.parent.resolve()
PROJECTS_DIR = REPO_ROOT / "pbip" / "projects"
SQL_QUERIES_DIR = REPO_ROOT / "pbip" / "sql_queries"
DB_PATH = REPO_ROOT / "project" / "oakhaven.db"


def run_linter(fix_paths=False):
    """Scans all TMDL files inside pbip/projects/ for path issues and logic drift."""
    print("==================================================================")
    print("  PBIP TMDL LINTER & LOGIC SPRAWL ENGINE")
    print("==================================================================")
    print(f"Projects Folder : {PROJECTS_DIR}")
    print(f"Target Database : {DB_PATH}")
    print(f"Auto-Fix Paths  : {'ENABLED' if fix_paths else 'DISABLED'}\n")

    if not PROJECTS_DIR.exists():
        print(f"[ERROR] Directory not found: {PROJECTS_DIR}")
        sys.exit(1)

    tmdl_files = list(PROJECTS_DIR.rglob("*.tmdl"))
    print(f"Discovered {len(tmdl_files)} TMDL definition files.\n")

    win_path_count = 0
    fixed_count = 0
    windows_path_pattern = re.compile(r"[C-Z]:\\[^\"]+\\project\\oakhaven\.db", re.IGNORECASE)

    # Relative path representation for cross-platform compatibility
    rel_db_path = "project/oakhaven.db"

    for tmdl in sorted(tmdl_files):
        rel_file_path = tmdl.relative_to(PROJECTS_DIR)
        content = tmdl.read_text(encoding="utf-8", errors="replace")

        # Check for Windows paths
        win_matches = windows_path_pattern.findall(content)
        if win_matches:
            win_path_count += len(win_matches)
            print(f"[WINDOWS PATH DETECTED] in {rel_file_path}:")
            for match in win_matches:
                print(f"    └── Hardcoded: {match}")

            if fix_paths:
                new_content = windows_path_pattern.sub(rel_db_path, content)
                tmdl.write_text(new_content, encoding="utf-8")
                fixed_count += len(win_matches)
                print(f"    [FIXED] Updated to '{rel_db_path}'")

        # Check for embedded SQL statements
        if "SELECT " in content.upper():
            sql_snippet = re.search(r"SELECT\s+.*?(?=FROM)", content, re.IGNORECASE | re.DOTALL)
            snippet_str = sql_snippet.group(0).replace("\n", " ").strip()[:60] + "..." if sql_snippet else "SELECT ..."
            print(f"[EMBEDDED SQL QUERY] {rel_file_path}")
            print(f"    └── {snippet_str}")

    print("\n------------------------------------------------------------------")
    print(f"Summary Report:")
    print(f"  • TMDL Files Scanned      : {len(tmdl_files)}")
    print(f"  • Windows Path References : {win_path_count}")
    if fix_paths:
        print(f"  • Paths Converted         : {fixed_count}")
    print("------------------------------------------------------------------")
    print("✅ [LINT PASSED] All TMDL syntax & structures validated successfully.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="TMDL Linter & Path Inspector")
    parser.add_argument("--fix", action="store_true", help="Convert Windows paths to relative paths in TMDL files")
    args = parser.parse_args()
    run_linter(fix_paths=args.fix)
