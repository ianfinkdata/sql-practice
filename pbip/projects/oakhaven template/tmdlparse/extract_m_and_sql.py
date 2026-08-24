#!/usr/bin/env python3
"""
extract_m_and_sql.py - Power Query M Code Extractor & SQL Statement Restorer

Processes Power BI TMDL files in 'oakhaven template':
- Section 2: Extracts full raw 'let...in' M expressions from table partitions.
- Section 3: Extracts embedded SQL queries, strips Power Query M formatting/escapes,
             and restores clean, standard ANSI SQL queries.
"""

import os
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

BASE_DIR = Path(__file__).parent.resolve()
TABLES_DIR = BASE_DIR / "oakhaven template.SemanticModel" / "definition" / "tables"
OUTPUT_DIR = BASE_DIR / "extracted_outputs"


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
    
    # 5. Clean trailing semicolon if followed by view formatting or standalone
    return clean.strip()


def format_sql(sql_str):
    """
    Standardizes whitespace and indentation for clean presentation.
    """
    lines = [l.rstrip() for l in sql_str.splitlines()]
    # Remove common leading indentation if any
    non_empty = [l for l in lines if l.strip()]
    if non_empty:
        min_indent = min(len(l) - len(l.lstrip()) for l in non_empty)
        lines = [l[min_indent:] if len(l) >= min_indent and l[:min_indent].isspace() else l for l in lines]
    return "\n".join(lines).strip()


def extract_m_expression(tmdl_content):
    """
    Extracts the full raw text of the M 'let...in' block from a TMDL table file.
    """
    # 1. Check for backtick-wrapped source: source = ``` ... ```
    bt_match = re.search(r"partition\s+[^\n]+=\s*m\b.*?source\s*=\s*```(.*?)```", tmdl_content, re.DOTALL | re.IGNORECASE)
    if bt_match:
        m_body = bt_match.group(1)
        return clean_m_indentation(m_body)

    # 2. Check for standard unbackticked let...in block after partition ... = m
    part_match = re.search(r"partition\s+[^\n]+=\s*m\b(.*)", tmdl_content, re.DOTALL | re.IGNORECASE)
    if part_match:
        part_content = part_match.group(1)
        # Find let ... in <return_var>
        let_match = re.search(r"(let\b.*?\bin\s+(?:#\"[^\"]+\"|[a-zA-Z0-9_]+))", part_content, re.DOTALL | re.IGNORECASE)
        if let_match:
            return clean_m_indentation(let_match.group(1))

    return None


def clean_m_indentation(raw_m):
    """Normalizes TMDL indentation so that 'let' starts at column 0."""
    lines = raw_m.splitlines()
    # Strip empty leading/trailing lines
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
    Handles:
    - Python Execute / pandas pd.read_sql_query("SELECT...", conn)
    - Native M string queries: Source = "SELECT..."
    - Generic embedded SELECT statements
    """
    if not raw_m_code:
        return None

    # Pattern A: Python read_sql_query (triple or single quoted)
    py_match = re.search(r'read_sql_query\(\s*(?:"""""|"""|""|")\s*(SELECT\s+.*?)(?:"""""|"""|""|")\s*,', raw_m_code, re.IGNORECASE | re.DOTALL)
    if py_match:
        return format_sql(unescape_m_sql(py_match.group(1)))

    # Pattern B: Source = "SELECT ... "
    src_match = re.search(r'Source\s*=\s*"(SELECT\s+.*?)"(?=\s*\r?\n\s*in|\s*$)', raw_m_code, re.IGNORECASE | re.DOTALL)
    if src_match:
        return format_sql(unescape_m_sql(src_match.group(1)))

    # Pattern C: Generic SELECT in M
    if "SELECT " in raw_m_code.upper():
        gen_match = re.search(r'(SELECT\s+.*?(?:;|"(?=\s*in)))', raw_m_code, re.IGNORECASE | re.DOTALL)
        if gen_match:
            return format_sql(unescape_m_sql(gen_match.group(1)))

    return None


def run_extraction():
    print("==================================================================")
    print("  SECTION 2 & 3: M CODE PARSER & SQL QUERY RESTORER")
    print("==================================================================")
    print(f"Scanning Tables Directory: {TABLES_DIR}\n")

    if not TABLES_DIR.exists():
        print(f"[ERROR] Directory not found: {TABLES_DIR}")
        sys.exit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    m_output_dir = OUTPUT_DIR / "m_code"
    sql_output_dir = OUTPUT_DIR / "sql_queries"
    m_output_dir.mkdir(parents=True, exist_ok=True)
    sql_output_dir.mkdir(parents=True, exist_ok=True)

    tmdl_files = sorted(list(TABLES_DIR.glob("*.tmdl")))
    
    m_results = {}
    sql_results = {}

    for t_path in tmdl_files:
        table_name = t_path.stem
        content = t_path.read_text(encoding="utf-8", errors="replace")
        
        # Section 2: Extract M let...in expression
        m_code = extract_m_expression(content)
        if m_code:
            m_results[table_name] = m_code
            (m_output_dir / f"{table_name}.m").write_text(m_code, encoding="utf-8")
            
            # Section 3: Extract & unescape embedded SQL query
            sql_query = extract_sql_from_m(m_code)
            if sql_query:
                sql_results[table_name] = sql_query
                (sql_output_dir / f"{table_name}.sql").write_text(sql_query + "\n", encoding="utf-8")

    # Display Section 2 Results
    print("------------------------------------------------------------------")
    print(f"  SECTION 2 RESULTS: Extracted M Code ({len(m_results)} Tables)")
    print("------------------------------------------------------------------")
    for tbl, code in m_results.items():
        step_count = len(re.findall(r"^[ \t]*(?:#\"[^\"]+\"|[a-zA-Z0-9_]+)\s*=", code, re.MULTILINE))
        has_sql = "SQL" if tbl in sql_results else "M Transform"
        print(f"  • Table: {tbl:<26} | Steps: {step_count:>2} | Type: {has_sql}")

    # Display Section 3 Results
    print("\n------------------------------------------------------------------")
    print(f"  SECTION 3 RESULTS: Restored Clean SQL Queries ({len(sql_results)} Queries)")
    print("------------------------------------------------------------------")
    for tbl, query in sql_results.items():
        line_count = len(query.splitlines())
        print(f"  • Query: {tbl:<26} | Lines: {line_count:>2}")

    # Print sample of the full TMDL target table: sql_fact_sales
    if "sql_fact_sales" in m_results:
        print("\n==================================================================")
        print("  SPOTLIGHT SAMPLE: `sql_fact_sales`")
        print("==================================================================")
        print("\n[Raw M Code (Section 2)]:")
        print("------------------------------------------------------------------")
        print(m_results["sql_fact_sales"])
        print("\n[Restored Clean Formatted SQL (Section 3)]:")
        print("------------------------------------------------------------------")
        print(sql_results["sql_fact_sales"])
        print("==================================================================")

    # Print sample of a Python/pandas SQL table: flat_sales_all
    if "flat_sales_all" in sql_results:
        print("\n==================================================================")
        print("  SPOTLIGHT SAMPLE: `flat_sales_all` (Extracted from Python / M)")
        print("==================================================================")
        print("[Restored Clean Formatted SQL]:")
        print("------------------------------------------------------------------")
        print(sql_results["flat_sales_all"])
        print("==================================================================")

    print("\n------------------------------------------------------------------")
    print(f"✅ Extracted files saved to: {OUTPUT_DIR.relative_to(BASE_DIR)}")
    print(f"   • M Scripts   : {m_output_dir.relative_to(BASE_DIR)} (*.m)")
    print(f"   • SQL Queries : {sql_output_dir.relative_to(BASE_DIR)} (*.sql)")
    print("------------------------------------------------------------------")


if __name__ == "__main__":
    run_extraction()
