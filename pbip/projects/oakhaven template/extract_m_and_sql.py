#!/usr/bin/env python3
"""
extract_m_and_sql.py - Generic Multi-Project Power Query M Code Extractor & ANSI SQL Query Restorer

Completely generic and dynamic:
1. Single table file extraction (--input table.tmdl --output path/)
2. Single model extraction (--input-dir path/to/tables/ --output path/)
3. Full repository / multi-PBIP project scanning (--input-dir path/to/pbip/projects/ --output path/)
   - Automatically detects PBIP project folders
   - Namespaces outputs by project to prevent overwrites
   - Scans all table TMDLs recursively
"""

import os
import re
import sys
import argparse
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

BASE_DIR = Path(__file__).parent.resolve()
DEFAULT_OUTPUT_DIR = BASE_DIR / "extracted_outputs"


def find_default_tables_dir():
    """Dynamically finds any definition/tables directory in current or parent folders."""
    for p in [BASE_DIR, BASE_DIR.parent]:
        for sem in p.glob("*.SemanticModel"):
            t_dir = sem / "definition" / "tables"
            if t_dir.exists():
                return t_dir
        if (p / "definition" / "tables").exists():
            return p / "definition" / "tables"
    return None


def unescape_m_sql(raw_sql):
    """
    Strips Power Query M formatting tokens, unescapes characters, and cleans whitespace.
    """
    if not raw_sql:
        return ""
    # 1. Unescape M carriage returns, line feeds, tabs
    clean = raw_sql.replace("#(cr)#(lf)", "\n").replace("#(lf)", "\n").replace("#(cr)", "\n").replace("#(tab)", "    ")
    
    # 2. Unescape doubled double-quotes
    clean = clean.replace('""', '"')
    
    # 3. Unescape escaped quotes and backslashes
    clean = clean.replace('\\"', '"').replace("\\'", "'")
    
    # 4. Strip extra surrounding quotes and whitespace
    clean = clean.strip().strip('`').strip('"').strip("'")
    
    return clean.strip()


def format_sql(sql_str):
    """
    Standardizes whitespace and indentation for clean presentation.
    """
    lines = [l.rstrip() for l in sql_str.splitlines()]
    non_empty = [l for l in lines if l.strip()]
    if non_empty:
        min_indent = min(len(l) - len(l.lstrip()) for l in non_empty)
        lines = [l[min_indent:] if len(l) >= min_indent and l[:min_indent].isspace() else l for l in lines]
    return "\n".join(lines).strip()


def extract_m_expression(tmdl_content):
    """
    Extracts the full raw text of the M 'let...in' block from a TMDL table file.
    """
    # 1. Backtick-wrapped source: source = ``` ... ```
    bt_match = re.search(r"partition\s+[^\n]+=\s*m\b.*?source\s*=\s*```(.*?)```", tmdl_content, re.DOTALL | re.IGNORECASE)
    if bt_match:
        return clean_m_indentation(bt_match.group(1))

    # 2. Unbackticked let...in block after partition ... = m
    part_match = re.search(r"partition\s+[^\n]+=\s*m\b(.*)", tmdl_content, re.DOTALL | re.IGNORECASE)
    if part_match:
        part_content = part_match.group(1)
        let_match = re.search(r"(let\b.*?\bin\s+(?:#\"[^\"]+\"|[a-zA-Z0-9_]+))", part_content, re.DOTALL | re.IGNORECASE)
        if let_match:
            return clean_m_indentation(let_match.group(1))

    return None


def clean_m_indentation(raw_m):
    """Normalizes TMDL indentation so that 'let' starts at column 0."""
    lines = raw_m.splitlines()
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
        
    if not lines:
        return ""
        
    first_non_empty = lines[0]
    match = re.match(r"^(\s*)", first_non_empty)
    indent_len = len(match.group(1)) if match else 0
    
    cleaned = []
    for l in lines:
        if not l.strip():
            cleaned.append("")
        elif len(l) >= indent_len and l[:indent_len].isspace():
            cleaned.append(l[indent_len:])
        else:
            cleaned.append(l.lstrip())
            
    return "\n".join(cleaned)


def extract_sql_from_m(raw_m_code):
    """
    Parses embedded SQL statements out of the raw Power Query M code.
    """
    if not raw_m_code:
        return None

    # Pattern A: Python read_sql_query
    py_match = re.search(r'read_sql_query\(\s*(?:"""""|"""|""|")\s*(SELECT\s+.*?)(?:"""""|"""|""|")\s*,', raw_m_code, re.IGNORECASE | re.DOTALL)
    if py_match:
        return format_sql(unescape_m_sql(py_match.group(1)))

    # Pattern B: Source = "SELECT ... "
    src_match = re.search(r'Source\s*=\s*"(SELECT\s+.*?)"(?=\s*\r?\n\s*in|\s*$)', raw_m_code, re.IGNORECASE | re.DOTALL)
    if src_match:
        return format_sql(unescape_m_sql(src_match.group(1)))

    # Pattern C: Generic SELECT
    if "SELECT " in raw_m_code.upper():
        gen_match = re.search(r'(SELECT\s+.*?(?:;|"(?=\s*in)))', raw_m_code, re.IGNORECASE | re.DOTALL)
        if gen_match:
            return format_sql(unescape_m_sql(gen_match.group(1)))

    return None


def get_project_name(file_path, base_scan_dir):
    """
    Infers the PBIP project name from file path relative to scan directory.
    """
    try:
        rel = file_path.relative_to(base_scan_dir)
        if len(rel.parts) > 1:
            first_part = rel.parts[0]
            if not first_part.endswith(".tmdl") and first_part not in ("definition", "tables"):
                return first_part
    except Exception:
        pass
    return None


def process_repository(scan_dir, output_root):
    """
    Recursively scans any directory, detects PBIP projects, and extracts M + SQL.
    """
    scan_dir = Path(scan_dir).resolve()
    output_root = Path(output_root).resolve()

    if not scan_dir.exists():
        print(f"[ERROR] Directory not found: {scan_dir}")
        return {}, {}

    tmdl_files = sorted(list(scan_dir.rglob("*.tmdl")))
    table_files = []
    for f in tmdl_files:
        if "tables" in f.parts or f.name.endswith(".tmdl"):
            table_files.append(f)

    if not table_files:
        print(f"No .tmdl files found in: {scan_dir}")
        return {}, {}

    projects_map = {}
    for f in table_files:
        proj = get_project_name(f, scan_dir) or "default_project"
        projects_map.setdefault(proj, []).append(f)

    is_multi_project = len(projects_map) > 1 or (len(projects_map) == 1 and "default_project" not in projects_map)

    print("==================================================================")
    print(f"  M CODE & SQL RESTORER: Discovered {len(table_files)} TMDL File(s) across {len(projects_map)} Project(s)")
    print("==================================================================")
    print(f"Scan Root        : {scan_dir}")
    print(f"Output Root      : {output_root}")
    print(f"Multi-Project    : {'YES (Outputs grouped per project)' if is_multi_project else 'NO (Single project output)'}\n")

    total_m_count = 0
    total_sql_count = 0

    for proj_name, files in sorted(projects_map.items()):
        proj_out = (output_root / proj_name) if is_multi_project else output_root
        m_out = proj_out / "m_code"
        sql_out = proj_out / "sql_queries"
        m_out.mkdir(parents=True, exist_ok=True)
        sql_out.mkdir(parents=True, exist_ok=True)

        proj_m_count = 0
        proj_sql_count = 0

        for t_path in files:
            table_name = t_path.stem
            if table_name in ("database", "model", "relationships", "expressions", "en-US"):
                continue

            content = t_path.read_text(encoding="utf-8", errors="replace")
            m_code = extract_m_expression(content)
            
            if m_code:
                proj_m_count += 1
                (m_out / f"{table_name}.m").write_text(m_code + "\n", encoding="utf-8")
                
                sql_query = extract_sql_from_m(m_code)
                if sql_query:
                    proj_sql_count += 1
                    (sql_out / f"{table_name}.sql").write_text(sql_query + "\n", encoding="utf-8")

        total_m_count += proj_m_count
        total_sql_count += proj_sql_count

        status_tag = f"[{proj_name}]"
        print(f"📦 Project: {status_tag:<32} -> {len(files):>2} tables scanned | {proj_m_count:>2} M scripts | {proj_sql_count:>2} SQL queries")

    print("\n------------------------------------------------------------------")
    print(f"✅ Scanning Complete!")
    print(f"   • Total Power Query M Scripts Extracted : {total_m_count}")
    print(f"   • Total Clean ANSI SQL Queries Restored  : {total_sql_count}")
    print(f"   • Destination Directory                 : {output_root}")
    print("------------------------------------------------------------------")


def main():
    parser = argparse.ArgumentParser(description="Extract raw Power Query M code and restore clean ANSI SQL queries across single models or entire repositories")
    parser.add_argument("--input", "-i", type=str, help="Path to a single table .tmdl file")
    parser.add_argument("--input-dir", "-d", type=str, help="Path to folder containing table .tmdl files or a parent directory with multiple PBIP projects")
    parser.add_argument("--output", "-o", type=str, help="Destination directory for m_code/ and sql_queries/")

    args = parser.parse_args()
    out_dir = Path(args.output) if args.output else DEFAULT_OUTPUT_DIR

    # 1. Batch directory / repo scan mode
    if args.input_dir:
        process_repository(args.input_dir, out_dir)
        return

    # 2. Single file mode
    if args.input:
        src = Path(args.input)
        if not src.exists():
            print(f"[ERROR] File not found: {src}")
            return
        content = src.read_text(encoding="utf-8", errors="replace")
        m_code = extract_m_expression(content)
        if m_code:
            m_out = out_dir / "m_code"
            sql_out = out_dir / "sql_queries"
            m_out.mkdir(parents=True, exist_ok=True)
            sql_out.mkdir(parents=True, exist_ok=True)
            
            (m_out / f"{src.stem}.m").write_text(m_code + "\n", encoding="utf-8")
            print(f"✅ Extracted M script: {m_out / f'{src.stem}.m'}")
            
            sql = extract_sql_from_m(m_code)
            if sql:
                (sql_out / f"{src.stem}.sql").write_text(sql + "\n", encoding="utf-8")
                print(f"✅ Restored SQL query: {sql_out / f'{src.stem}.sql'}")
        else:
            print(f"No M partition expression found in: {src.name}")
        return

    # 3. Dynamic auto mode
    default_tables = find_default_tables_dir()
    if default_tables:
        process_repository(default_tables, out_dir)
    else:
        print("[ERROR] No tables directory found. Please provide --input-dir <path>")


if __name__ == "__main__":
    main()
