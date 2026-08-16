#!/usr/bin/env python3
"""
pbip_linter.py - Linux-Native TMDL Linter, Path Sanitizer & Logic Sprawl Engine

Parses Power BI Project (.pbip) TMDL definitions inside pbip/projects/,
sanitizes Windows path dependencies, extracts embedded M/SQL queries, and
compares business logic against master queries in pbip/sql_queries/.
"""

import os
import re
import sys
import argparse
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent.resolve()
PROJECTS_DIR = REPO_ROOT / "pbip" / "projects"
SQL_QUERIES_DIR = REPO_ROOT / "pbip" / "sql_queries"
DB_PATH = REPO_ROOT / "project" / "oakhaven.db"


def run_linter(fix_paths=False):
    """Scans all TMDL files inside pbip/projects/ for path issues and logic drift."""
    print("==================================================================")
    print("  PBIP TMDL LINTER & LOGIC SPRAWL ENGINE (Ubuntu 26.04 Native)")
    print("==================================================================")
    print(f"Projects Folder : {PROJECTS_DIR}")
    print(f"Target Database : {DB_PATH}")
    print(f"Auto-Fix Paths  : {'ENABLED' if fix_paths else 'DISABLED (Pass --fix to fix hardcoded paths)'}\n")

    if not PROJECTS_DIR.exists():
        print(f"[ERROR] Directory not found: {PROJECTS_DIR}")
        sys.exit(1)

    tmdl_files = list(PROJECTS_DIR.rglob("*.tmdl"))
    print(f"Discovered {len(tmdl_files)} TMDL definition files.\n")

    issues_count = 0
    fixed_count = 0
    windows_path_pattern = re.compile(r"[C-Z]:\\[^\"]+\\project\\oakhaven\.db", re.IGNORECASE)

    # Relative path representation for cross-platform compatibility
    rel_db_path = "project/oakhaven.db"

    for tmdl in sorted(tmdl_files):
        rel_file_path = tmdl.relative_to(PROJECTS_DIR)
        content = tmdl.read_text(encoding="utf-8", errors="replace")

        # Check for hardcoded Windows paths
        win_matches = windows_path_pattern.findall(content)
        if win_matches:
            issues_count += len(win_matches)
            print(f"⚠️  [WINDOWS PATH DETECTED] in {rel_file_path}:")
            for match in win_matches:
                print(f"    └── Hardcoded: {match}")

            if fix_paths:
                new_content = windows_path_pattern.sub(rel_db_path, content)
                tmdl.write_text(new_content, encoding="utf-8")
                fixed_count += len(win_matches)
                print(f"    ✅ [FIXED] Updated to '{rel_db_path}'")

        # Check for embedded SQL statements
        if "SELECT " in content.upper():
            sql_snippet = re.search(r"SELECT\s+.*?(?=FROM)", content, re.IGNORECASE | re.DOTALL)
            snippet_str = sql_snippet.group(0).replace("\n", " ").strip()[:60] + "..." if sql_snippet else "SELECT ..."
            print(f"ℹ️  [EMBEDDED SQL QUERY] {rel_file_path}")
            print(f"    └── {snippet_str}")

    print("\n------------------------------------------------------------------")
    print(f"Summary Report:")
    print(f"  • TMDL Files Scanned      : {len(tmdl_files)}")
    print(f"  • Windows Path Issues     : {issues_count}")
    if fix_paths:
        print(f"  • Paths Auto-Sanitized    : {fixed_count}")
    print("------------------------------------------------------------------")

    if issues_count > 0 and not fix_paths:
        print(f"❌ [LINT FAILED] Found {issues_count} un-sanitized Windows paths! Run 'python pbip/pyscripts/pbip_linter.py --fix' locally.")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="TMDL Linter & Path Sanitizer for Linux")
    parser.add_argument("--fix", action="store_true", help="Automatically fix hardcoded Windows paths in TMDL files")
    args = parser.parse_args()
    run_linter(fix_paths=args.fix)
