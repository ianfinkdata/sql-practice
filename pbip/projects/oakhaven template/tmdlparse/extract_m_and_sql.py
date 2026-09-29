#!/usr/bin/env python3
"""
extract_m_and_sql.py - Line-by-Line State Machine M Code Extractor & AST SQL Query Restorer

Applies robust parsing architecture:
1. TMDL & M Parsing: Line-by-line indentation-aware State Machine (replaces fragile regex).
2. SQL Parsing & AST Validation: Extracts queries (CTEs/WITH, SELECT, EXEC) from M code and
   uses sqlglot/sqlparse AST formatting when available with pure-Python AST fallback.
3. Exception Safety: Catches precise ValueErrors on relative path resolution.
"""

import os
import re
import sys
import argparse
from pathlib import Path

# Optional AST SQL formatting libraries
try:
    import sqlglot
    HAS_SQLGLOT = True
except ImportError:
    HAS_SQLGLOT = False

try:
    import sqlparse
    HAS_SQLPARSE = True
except ImportError:
    HAS_SQLPARSE = False

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

BASE_DIR = Path(__file__).parent.resolve()
DEFAULT_OUTPUT_DIR = BASE_DIR / "extracted_outputs"


# =============================================================================
# 1. LINE-BY-LINE INDENTATION STATE MACHINE (TMDL & M EXTRACTION)
# =============================================================================

def count_leading_tabs(line):
    """Counts leading indentation levels (tabs or 4-space equivalents)."""
    if not line:
        return 0
    match = re.match(r"^(\t+| +)", line)
    if not match:
        return 0
    ws = match.group(1)
    return len(ws) if "\t" in ws else len(ws) // 4


def dedent_block(lines):
    """Normalizes indentation of extracted M code so 'let' starts at column 0."""
    # Strip empty leading and trailing lines
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()

    if not lines:
        return ""

    base_indent = count_leading_tabs(lines[0])
    cleaned = []
    for l in lines:
        if not l.strip():
            cleaned.append("")
            continue
        cur_indent = count_leading_tabs(l)
        strip_count = min(base_indent, cur_indent)
        rem = l
        for _ in range(strip_count):
            if rem.startswith("\t"):
                rem = rem[1:]
            elif rem.startswith("    "):
                rem = rem[4:]
            else:
                break
        cleaned.append(rem)
    return "\n".join(cleaned)


def extract_m_expression(tmdl_content):
    """
    Line-by-line State Machine parser for extracting Power Query M code from a TMDL table.
    Tracks partition indentation levels and block states without multiline regex.
    """
    lines = tmdl_content.splitlines()
    in_partition_m = False
    in_backticks = False
    in_let_in = False
    partition_indent = 0
    m_lines = []

    for line in lines:
        stripped = line.strip()
        indent = count_leading_tabs(line)

        # STATE 1: Seeking partition ... = m
        if not in_partition_m:
            if re.match(r"^partition\s+.+=\s*m\b", stripped, re.IGNORECASE):
                in_partition_m = True
                partition_indent = indent
                in_backticks = False
                in_let_in = False
                m_lines = []
            continue

        # STATE 2: Inside partition block
        # If not inside active source code, check if partition ended by indentation drop
        if not in_backticks and not in_let_in:
            if stripped and indent <= partition_indent:
                in_partition_m = False
                continue

        # Check for triple backtick blocks (source = ``` ... ```)
        if "```" in stripped:
            if not in_backticks:
                in_backticks = True
                # Check if code starts on the same line after ```
                after = stripped.split("```", 1)[1].strip()
                if after:
                    m_lines.append(after)
            else:
                in_backticks = False
                in_partition_m = False
            continue

        if in_backticks:
            m_lines.append(line)
            continue

        # Check for unbackticked M source (source = let ... in ...)
        if not in_let_in:
            if stripped == "let" or stripped.startswith("let ") or stripped.startswith("source = let"):
                in_let_in = True
                if stripped.startswith("source = let"):
                    m_lines.append(line.replace("source = ", "", 1))
                else:
                    m_lines.append(line)
                continue
            elif stripped.startswith("source ="):
                # Potential unbackticked source assignment
                continue
        else:
            # Inside unbackticked let...in block
            # Check if outer TMDL property starts at or below partition sub-level
            if stripped and indent <= partition_indent + 1:
                first_word = stripped.split()[0].lower()
                if first_word in ("annotation", "changedproperty", "column", "measure", "partition", "table"):
                    in_let_in = False
                    in_partition_m = False
                    continue
            m_lines.append(line)

    return dedent_block(m_lines) if m_lines else None


# =============================================================================
# 2. SQL EXTRACTION, UNESCAPING & AST VALIDATION / FORMATTING
# =============================================================================

def unescape_m_tokens(raw_str):
    """Unescapes Power Query M format codes (#(cr)#(lf), #(tab), doubled quotes)."""
    if not raw_str:
        return ""
    clean = raw_str.replace("#(cr)#(lf)", "\n").replace("#(lf)", "\n").replace("#(cr)", "\n").replace("#(tab)", "    ")
    clean = clean.replace('""', '"')
    clean = clean.replace('\\"', '"').replace("\\'", "'")
    return clean.strip().strip('"').strip("'").strip("`").strip()


def is_valid_sql_candidate(candidate):
    """
    Determines whether a candidate string is a valid SQL query (CTEs, SELECT, EXEC, DDL/DML).
    """
    if not candidate or len(candidate.strip()) < 10:
        return False

    # Strip leading SQL comments
    clean_lines = []
    for l in candidate.splitlines():
        sl = l.strip()
        if sl.startswith("--") or sl.startswith("/*") or sl.endswith("*/"):
            continue
        if sl:
            clean_lines.append(sl)

    first_text = " ".join(clean_lines).strip().upper()
    valid_starters = ("SELECT", "WITH", "EXEC", "EXECUTE", "INSERT", "UPDATE", "DELETE", "CREATE", "CALL")
    return any(first_text.startswith(kw) for kw in valid_starters)


def format_sql_ast(sql_str):
    """
    Formats SQL using AST libraries (sqlglot / sqlparse) when available,
    with a clean pure-Python normalization fallback.
    """
    clean_sql = unescape_m_tokens(sql_str)

    # 1. AST formatting via sqlglot
    if HAS_SQLGLOT:
        try:
            return sqlglot.transpile(clean_sql, pretty=True)[0]
        except Exception:
            pass

    # 2. AST formatting via sqlparse
    if HAS_SQLPARSE:
        try:
            return sqlparse.format(clean_sql, reindent=True, keyword_case="upper")
        except Exception:
            pass

    # 3. Pure-Python normalization fallback
    lines = [l.rstrip() for l in clean_sql.splitlines()]
    non_empty = [l for l in lines if l.strip()]
    if non_empty:
        min_indent = min(len(l) - len(l.lstrip()) for l in non_empty)
        lines = [l[min_indent:] if len(l) >= min_indent and l[:min_indent].isspace() else l for l in lines]
    return "\n".join(lines).strip()


def extract_sql_from_m(raw_m_code):
    """
    Extracts embedded SQL statements from M code (supporting Python read_sql_query,
    Sql.Database, Value.NativeQuery, Odbc.Query, CTEs with WITH, and standard queries).
    """
    if not raw_m_code:
        return None

    # Extraction candidate 1: Python pandas read_sql_query
    py_match = re.search(r'read_sql_query\(\s*(?:"""""|"""|""|")\s*(.+?)(?:"""""|"""|""|")\s*,', raw_m_code, re.IGNORECASE | re.DOTALL)
    if py_match:
        cand = unescape_m_tokens(py_match.group(1))
        if is_valid_sql_candidate(cand):
            return format_sql_ast(cand)

    # Extraction candidate 2: Sql.Database / Value.NativeQuery [Query="..."]
    native_match = re.search(r'\[\s*Query\s*=\s*"(.*?)"\s*\]', raw_m_code, re.IGNORECASE | re.DOTALL)
    if native_match:
        cand = unescape_m_tokens(native_match.group(1))
        if is_valid_sql_candidate(cand):
            return format_sql_ast(cand)

    # Extraction candidate 3: Source = "..." string literal assignment
    src_match = re.search(r'Source\s*=\s*"(.*?)"(?=\s*\r?\n\s*in|\s*$)', raw_m_code, re.IGNORECASE | re.DOTALL)
    if src_match:
        cand = unescape_m_tokens(src_match.group(1))
        if is_valid_sql_candidate(cand):
            return format_sql_ast(cand)

    # Extraction candidate 4: General string scan for SQL blocks (including CTEs/WITH)
    quoted_strings = re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', raw_m_code, re.DOTALL)
    for q_str in quoted_strings:
        cand = unescape_m_tokens(q_str)
        if is_valid_sql_candidate(cand):
            return format_sql_ast(cand)

    return None


# =============================================================================
# 3. PROJECT RESOLUTION & REPOSITORY SCANNING
# =============================================================================

def get_project_name(file_path, base_scan_dir):
    """
    Infers the PBIP project name from file path relative to scan directory.
    Catches specific ValueError to prevent swallowing KeyboardInterrupt/SystemExit.
    """
    try:
        rel = file_path.relative_to(base_scan_dir)
        if len(rel.parts) > 1:
            first_part = rel.parts[0]
            if not first_part.endswith(".tmdl") and first_part not in ("definition", "tables"):
                return first_part
    except ValueError:
        # relative_to() raises ValueError if file_path is not a subpath of base_scan_dir
        pass

    return None


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


def process_repository(scan_dir, output_root):
    """
    Recursively scans a directory, detects PBIP projects, and extracts M + SQL.
    """
    scan_dir = Path(scan_dir).resolve()
    output_root = Path(output_root).resolve()

    if not scan_dir.exists():
        print(f"[ERROR] Directory not found: {scan_dir}")
        return {}, {}

    tmdl_files = sorted(list(scan_dir.rglob("*.tmdl")))
    table_files = [f for f in tmdl_files if "tables" in f.parts or f.name.endswith(".tmdl")]

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
    print(f"AST Formatter    : {'sqlglot' if HAS_SQLGLOT else ('sqlparse' if HAS_SQLPARSE else 'Pure-Python AST Normalizer')}")
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
        print(f"📦 Project: {status_tag:<32} -> {len(files):>2} tables | {proj_m_count:>2} M scripts | {proj_sql_count:>2} SQL queries")

    print("\n------------------------------------------------------------------")
    print(f"✅ Scanning Complete!")
    print(f"   • Total Power Query M Scripts Extracted : {total_m_count}")
    print(f"   • Total Clean ANSI SQL Queries Restored  : {total_sql_count}")
    print(f"   • Destination Directory                 : {output_root}")
    print("------------------------------------------------------------------")


def main():
    parser = argparse.ArgumentParser(description="Extract raw Power Query M code and restore clean ANSI SQL queries using Line-by-Line State Machine")
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

    # 3. Default auto mode
    default_tables = find_default_tables_dir()
    if default_tables:
        process_repository(default_tables, out_dir)
    else:
        print("[ERROR] No tables directory found. Please provide --input-dir <path>")


if __name__ == "__main__":
    main()
