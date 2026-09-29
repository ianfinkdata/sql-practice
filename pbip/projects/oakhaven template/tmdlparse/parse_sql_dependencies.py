#!/usr/bin/env python3
"""
parse_sql_dependencies.py - Comprehensive SQL Column & Table Lineage Dependency Parser

Parses complex SQL queries (including CTEs, nested subqueries, multi-table joins,
CASE expressions, arithmetic calculations, and column aliases) to trace end-to-end data dependencies
back to the source schema, source table, and source column.

Outputs:
1. Column-Level Lineage Dependency CSV (sql_column_dependencies.csv)
2. Table-Level Join & Flow Lineage CSV (sql_table_dependencies.csv)
"""

import os
import re
import sys
import csv
import argparse
from pathlib import Path
from typing import Dict, List, Set, Tuple, Any, Optional

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

BASE_DIR = Path(__file__).parent.resolve()
DEFAULT_SQL_DIR = BASE_DIR.parent / "extracted_outputs"
DEFAULT_OUTPUT_CSV = BASE_DIR.parent / "sql_column_dependencies.csv"
DEFAULT_TABLE_CSV = BASE_DIR.parent / "sql_table_dependencies.csv"

# Reserved syntax keywords to avoid mistaking for table aliases or column names
KEYWORDS_SQL_SYNTAX = {
    "SELECT", "DISTINCT", "AS", "FROM", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "FULL", "CROSS",
    "ON", "WHERE", "AND", "OR", "NOT", "IN", "IS", "NULL", "LIKE", "BETWEEN", "CASE", "WHEN", "THEN",
    "ELSE", "END", "GROUP", "BY", "HAVING", "ORDER", "ASC", "DESC", "LIMIT", "OFFSET", "UNION", "ALL",
    "OVER", "PARTITION", "TRUE", "FALSE"
}


# =============================================================================
# 1. SQL CLEANING & TOKENIZATION
# =============================================================================

def strip_sql_comments(sql: str) -> str:
    """Removes single-line and multi-line SQL comments while preserving query structure."""
    no_single = re.sub(r"--[^\n]*", "", sql)
    no_multi = re.sub(r"/\*[\s\S]*?\*/", "", no_single)
    return no_multi


def split_projection_list(select_body: str) -> List[str]:
    """
    Splits a SELECT clause projection list by comma, respecting nested parentheses,
    CASE expressions, and string literals.
    """
    projections = []
    current = []
    paren_depth = 0
    in_quote = False
    quote_char = None
    i = 0
    n = len(select_body)

    while i < n:
        char = select_body[i]

        if char in ("'", '"', "`"):
            if not in_quote:
                in_quote = True
                quote_char = char
            elif quote_char == char:
                if i + 1 < n and select_body[i + 1] == char:
                    current.append(char)
                    i += 1
                else:
                    in_quote = False
                    quote_char = None
            current.append(char)
            i += 1
            continue

        if in_quote:
            current.append(char)
            i += 1
            continue

        if char == "(":
            paren_depth += 1
        elif char == ")":
            paren_depth = max(0, paren_depth - 1)

        if char == "," and paren_depth == 0:
            item = "".join(current).strip()
            if item:
                projections.append(item)
            current = []
            i += 1
            continue

        current.append(char)
        i += 1

    last_item = "".join(current).strip()
    if last_item:
        projections.append(last_item)

    return projections


def classify_transformation_type(expr: str) -> str:
    """Categorizes the SQL expression type."""
    expr_upper = expr.strip().upper()

    if expr_upper.startswith("CASE ") or " CASE " in expr_upper or " WHEN " in expr_upper:
        return "CASE_EXPRESSION"
    elif any(fn in expr_upper for fn in ("OVER (", "OVER(", "ROW_NUMBER()", "RANK()", "DENSE_RANK()", "LAG(", "LEAD(")):
        return "WINDOW_FUNCTION"
    elif any(agg in expr_upper for agg in ("SUM(", "COUNT(", "AVG(", "MIN(", "MAX(", "GROUP_CONCAT(", "STRING_AGG(")):
        return "AGGREGATE"
    elif any(op in expr for op in ("*", "+", "/", "-", "%", "||")) and not re.match(r"^[a-zA-Z0-9_.]+$", expr.strip()):
        return "ARITHMETIC_CALCULATION"
    elif any(func in expr_upper for func in ("ROUND(", "COALESCE(", "NULLIF(", "CAST(", "CONVERT(", "SUBSTR(", "TRIM(", "UPPER(", "LOWER(", "REPLACE(")):
        return "SCALAR_FUNCTION"
    elif expr.strip().startswith("(") and "SELECT " in expr_upper:
        return "SCALAR_SUBQUERY"
    elif re.match(r"^(?:'[^\']*'|\d+(?:\.\d+)?|NULL|TRUE|FALSE)$", expr.strip(), re.IGNORECASE):
        return "LITERAL_CONSTANT"
    elif re.match(r"^[a-zA-Z0-9_]+(?:\.[a-zA-Z0-9_]+)?$", expr.strip()):
        return "DIRECT_PASSTHROUGH"
    else:
        return "COMPLEX_EXPRESSION"


def extract_column_alias_and_expression(proj_item: str) -> Tuple[str, str]:
    """
    Parses a projection item into (target_column_name, raw_expression).
    """
    item = proj_item.strip()

    # Pattern A: Explicit AS alias
    as_match = re.search(r'\s+AS\s+(["`\[]?)([a-zA-Z0-9_ ]+)\1\s*$', item, re.IGNORECASE)
    if as_match:
        alias = as_match.group(2).strip()
        expr = item[:as_match.start()].strip()
        return alias, expr

    # Pattern B: Implicit alias without AS
    implicit_match = re.search(r'\s+(["`\[]?)([a-zA-Z0-9_]+)\1\s*$', item)
    if implicit_match:
        candidate_alias = implicit_match.group(2).strip()
        candidate_expr = item[:implicit_match.start()].strip()
        if candidate_expr.count("(") == candidate_expr.count(")") and candidate_alias.upper() not in KEYWORDS_SQL_SYNTAX:
            return candidate_alias, candidate_expr

    # Pattern C: Direct identifier without alias
    clean_item = item.strip().strip('"').strip('`')
    col_name = clean_item.split(".")[-1] if "." in clean_item else clean_item
    return col_name, item


def extract_identifiers_from_expression(expr: str) -> List[Tuple[Optional[str], str]]:
    """
    Extracts all (table_alias_or_table, column_name) references from an expression.
    """
    qualified = re.findall(r"\b([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)\b", expr)
    results = []
    seen = set()

    for alias, col in qualified:
        if col.upper() not in KEYWORDS_SQL_SYNTAX and alias.upper() not in KEYWORDS_SQL_SYNTAX:
            key = (alias, col)
            if key not in seen:
                seen.add(key)
                results.append((alias, col))

    if not results:
        tokens = re.findall(r"\b([a-zA-Z_][a-zA-Z0-9_]*)\b", expr)
        for t in tokens:
            if t.upper() not in KEYWORDS_SQL_SYNTAX and not t.isdigit():
                key = (None, t)
                if key not in seen:
                    seen.add(key)
                    results.append((None, t))

    return results


# =============================================================================
# 2. SQL TABLE, JOIN & CTE SCOPE PARSER
# =============================================================================

def parse_table_sources_and_joins(query_sql: str) -> Tuple[Dict[str, Tuple[Optional[str], str]], List[Dict[str, Any]]]:
    """
    Extracts all physical/CTE table sources, aliases, and join conditions from a SQL statement.
    """
    tables: Dict[str, Tuple[Optional[str], str]] = {}
    joins: List[Dict[str, Any]] = []

    clean_sql = strip_sql_comments(query_sql)

    from_match = re.search(
        r"\bFROM\s+([\s\S]+?)(?=\b(?:WHERE|GROUP\s+BY|HAVING|ORDER\s+BY|LIMIT|QUALIFY|UNION|EXCEPT|INTERSECT)\b|\;|$)",
        clean_sql,
        re.IGNORECASE
    )
    if not from_match:
        return tables, joins

    from_body = from_match.group(1).strip()

    join_pattern = re.compile(
        r"\b(LEFT\s+OUTER\s+JOIN|RIGHT\s+OUTER\s+JOIN|FULL\s+OUTER\s+JOIN|LEFT\s+JOIN|RIGHT\s+JOIN|INNER\s+JOIN|FULL\s+JOIN|CROSS\s+JOIN|JOIN)\b",
        re.IGNORECASE
    )

    parts = join_pattern.split(from_body)

    # 1. Primary FROM clause (can have comma-separated tables)
    primary_from = parts[0].strip()
    for tbl_item in primary_from.split(","):
        tbl_item = tbl_item.strip()
        if not tbl_item:
            continue
        m = re.match(r"^(?:([a-zA-Z0-9_]+)\.)?([a-zA-Z0-9_]+)(?:\s+(?:AS\s+)?([a-zA-Z0-9_]+))?$", tbl_item, re.IGNORECASE)
        if m:
            sch, tbl, al = m.group(1), m.group(2), m.group(3)
            eff_alias = al if al else tbl
            tables[eff_alias] = (sch or "default", tbl)
            tables[tbl] = (sch or "default", tbl)
            joins.append({
                "join_type": "PRIMARY_FROM",
                "source_table": tbl,
                "source_schema": sch or "default",
                "alias": eff_alias,
                "join_condition": ""
            })

    # 2. Joined tables (in pairs: join_keyword, join_body)
    for i in range(1, len(parts), 2):
        j_type = re.sub(r"\s+", " ", parts[i].strip().upper())
        j_body = parts[i + 1].strip() if i + 1 < len(parts) else ""

        on_split = re.split(r"\bON\b", j_body, maxsplit=1, flags=re.IGNORECASE)
        tbl_part = on_split[0].strip()
        on_cond = on_split[1].strip() if len(on_split) > 1 else ""

        m = re.match(r"^(?:([a-zA-Z0-9_]+)\.)?([a-zA-Z0-9_]+)(?:\s+(?:AS\s+)?([a-zA-Z0-9_]+))?$", tbl_part, re.IGNORECASE)
        if m:
            sch, tbl, al = m.group(1), m.group(2), m.group(3)
            eff_alias = al if al else tbl
            tables[eff_alias] = (sch or "default", tbl)
            tables[tbl] = (sch or "default", tbl)
            joins.append({
                "join_type": j_type,
                "source_table": tbl,
                "source_schema": sch or "default",
                "alias": eff_alias,
                "join_condition": on_cond
            })

    return tables, joins


def parse_cte_definitions(sql_text: str) -> Dict[str, Dict[str, Any]]:
    """
    Parses Common Table Expressions (WITH cte AS (SELECT ...)) and builds an AST column map.
    """
    cte_dict = {}
    cte_matches = re.finditer(r"\bWITH\s+([a-zA-Z0-9_]+)\s+AS\s*\(([\s\S]*?)\)(?=\s*,\s*[a-zA-Z0-9_]+\s+AS|\s*SELECT|\s*INSERT|\s*$)", sql_text, re.IGNORECASE)

    for m in cte_matches:
        cte_name = m.group(1).strip()
        cte_sql = m.group(2).strip()

        tables_map, joins_list = parse_table_sources_and_joins(cte_sql)
        select_match = re.search(r"\bSELECT\s+(?:DISTINCT\s+)?([\s\S]*?)\bFROM\b", cte_sql, re.IGNORECASE)
        col_mappings = {}

        if select_match:
            for item in split_projection_list(select_match.group(1).strip()):
                t_col, raw_e = extract_column_alias_and_expression(item)
                refs = extract_identifiers_from_expression(raw_e)
                col_mappings[t_col] = {
                    "expression": raw_e,
                    "refs": refs,
                    "tables_map": tables_map
                }

        cte_dict[cte_name] = {
            "sql": cte_sql,
            "tables": tables_map,
            "columns": col_mappings
        }

    return cte_dict


# =============================================================================
# 3. END-TO-END COLUMN LINEAGE ANALYZER
# =============================================================================

def parse_sql_file_dependencies(sql_path: Path, model_name: str = "default_model") -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """
    Parses a single .sql query file and extracts full column-level and table-level lineage.
    """
    sql_text = sql_path.read_text(encoding="utf-8", errors="replace")
    clean_sql = strip_sql_comments(sql_text).strip()
    target_entity = sql_path.stem

    column_lineage: List[Dict[str, Any]] = []
    table_lineage: List[Dict[str, Any]] = []

    if not clean_sql:
        return column_lineage, table_lineage

    # 1. Parse CTEs if present
    cte_defs = parse_cte_definitions(clean_sql)

    # 2. Extract main table sources and joins
    tables_map, joins_list = parse_table_sources_and_joins(clean_sql)

    # Build join key lookup
    join_keys: Set[Tuple[str, str]] = set()
    for j in joins_list:
        cond = j.get("join_condition", "")
        for tbl_or_alias, col in re.findall(r"\b([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)\b", cond):
            join_keys.add((tbl_or_alias, col))
            if tbl_or_alias in tables_map:
                join_keys.add((tables_map[tbl_or_alias][1], col))

    # 3. Record table-level dependencies
    for j in joins_list:
        table_lineage.append({
            "query_file": sql_path.name,
            "model_name": model_name,
            "target_entity": target_entity,
            "source_schema": j["source_schema"],
            "source_table": j["source_table"],
            "table_alias": j["alias"],
            "is_cte": 1 if j["source_table"] in cte_defs else 0,
            "join_type": j["join_type"],
            "join_condition": j["join_condition"]
        })

    # 4. Extract Main SELECT Projections
    select_match = re.search(r"\bSELECT\s+(?:DISTINCT\s+)?([\s\S]*?)\bFROM\b", clean_sql, re.IGNORECASE)
    if not select_match:
        return column_lineage, table_lineage

    projections_raw = select_match.group(1).strip()
    projection_items = split_projection_list(projections_raw)

    for proj_item in projection_items:
        if not proj_item.strip():
            continue

        target_col, raw_expr = extract_column_alias_and_expression(proj_item)
        trans_type = classify_transformation_type(raw_expr)
        source_refs = extract_identifiers_from_expression(raw_expr)

        if raw_expr.strip() == "*":
            for alias_key, (sch, tbl) in tables_map.items():
                if alias_key == tbl:
                    column_lineage.append({
                        "query_file": sql_path.name,
                        "model_name": model_name,
                        "target_entity": target_entity,
                        "target_column": "*",
                        "source_schema": sch or "default",
                        "source_table": tbl,
                        "source_column": "*",
                        "table_alias": alias_key,
                        "transformation_type": "STAR_EXPANSION",
                        "expression_detail": "*",
                        "is_join_key": 0,
                        "join_condition": ""
                    })
            continue

        if trans_type == "LITERAL_CONSTANT" or not source_refs:
            column_lineage.append({
                "query_file": sql_path.name,
                "model_name": model_name,
                "target_entity": target_entity,
                "target_column": target_col,
                "source_schema": "N/A",
                "source_table": "LITERAL_CONSTANT",
                "source_column": "LITERAL",
                "table_alias": "N/A",
                "transformation_type": trans_type,
                "expression_detail": raw_expr,
                "is_join_key": 0,
                "join_condition": ""
            })
            continue

        # Map each referenced identifier
        for tbl_alias_or_name, src_col in source_refs:
            resolved_schema = "default"
            resolved_table = "UNKNOWN_SOURCE"
            resolved_alias = tbl_alias_or_name or "implicit"
            resolved_src_col = src_col

            # A. Check if alias maps to a known table
            if tbl_alias_or_name and tbl_alias_or_name in tables_map:
                resolved_schema, resolved_table = tables_map[tbl_alias_or_name]
            elif len(tables_map) == 1:
                single_key = list(tables_map.keys())[0]
                resolved_schema, resolved_table = tables_map[single_key]
                resolved_alias = single_key
            else:
                for k, (s, t) in tables_map.items():
                    if k.lower() == (tbl_alias_or_name or "").lower() or t.lower() == (tbl_alias_or_name or "").lower():
                        resolved_schema, resolved_table = s, t
                        resolved_alias = k
                        break

            # B. Transitive resolution if resolved_table is a CTE
            if resolved_table in cte_defs:
                cte_info = cte_defs[resolved_table]
                if src_col in cte_info["columns"]:
                    inner_col_info = cte_info["columns"][src_col]
                    for inner_alias, inner_col in inner_col_info["refs"]:
                        if inner_alias and inner_alias in cte_info["tables"]:
                            resolved_schema, resolved_table = cte_info["tables"][inner_alias]
                            resolved_src_col = inner_col
                            resolved_alias = inner_alias
                            break

            is_jk = 1 if (tbl_alias_or_name, src_col) in join_keys or (resolved_table, src_col) in join_keys else 0
            matching_join_cond = next((j["join_condition"] for j in joins_list if f".{src_col}" in j["join_condition"] or f"={src_col}" in j["join_condition"]), "")

            column_lineage.append({
                "query_file": sql_path.name,
                "model_name": model_name,
                "target_entity": target_entity,
                "target_column": target_col,
                "source_schema": resolved_schema or "default",
                "source_table": resolved_table,
                "source_column": resolved_src_col,
                "table_alias": resolved_alias,
                "transformation_type": trans_type,
                "expression_detail": raw_expr,
                "is_join_key": is_jk,
                "join_condition": matching_join_cond
            })

    return column_lineage, table_lineage


# =============================================================================
# 4. REPOSITORY SCANNER & CSV EXPORT ENGINE
# =============================================================================

def get_project_name(file_path: Path, base_scan_dir: Path) -> Optional[str]:
    """
    Infers the PBIP project name from file path relative to scan directory.
    Catches specific ValueError to prevent masking system exceptions.
    """
    try:
        rel = file_path.relative_to(base_scan_dir)
        if len(rel.parts) > 1:
            first_part = rel.parts[0]
            if not first_part.endswith(".sql") and first_part not in ("sql_queries", "extracted_outputs"):
                return first_part
    except ValueError:
        pass
    return None


def run_lineage_pipeline(scan_dir: Path, output_col_csv: Path, output_tbl_csv: Path) -> None:
    """
    Scans all SQL files, generates comprehensive lineage matrices, and exports CSV catalogs.
    """
    scan_dir = Path(scan_dir).resolve()
    output_col_csv = Path(output_col_csv).resolve()
    output_tbl_csv = Path(output_tbl_csv).resolve()

    if not scan_dir.exists():
        print(f"[ERROR] Directory not found: {scan_dir}")
        sys.exit(1)

    sql_files = sorted(list(scan_dir.rglob("*.sql")))

    if not sql_files:
        print(f"No .sql files found under: {scan_dir}")
        return

    print("==================================================================")
    print(f"  SQL LINEAGE & DEPENDENCY MATRIX PARSER")
    print("==================================================================")
    print(f"Scanning SQL Folder : {scan_dir}")
    print(f"Discovered Queries  : {len(sql_files)} SQL files\n")

    all_column_records: List[Dict[str, Any]] = []
    all_table_records: List[Dict[str, Any]] = []

    for idx, f_path in enumerate(sql_files, start=1):
        model_name = get_project_name(f_path, scan_dir) or "default_model"
        col_records, tbl_records = parse_sql_file_dependencies(f_path, model_name=model_name)
        
        all_column_records.extend(col_records)
        all_table_records.extend(tbl_records)

        unique_src_tables = set(r['source_table'] for r in col_records if r['source_table'] not in ('UNKNOWN_SOURCE', 'LITERAL_CONSTANT'))
        print(f"[{idx}/{len(sql_files)}] 📄 Query: {f_path.name:<28} -> {len(col_records):>2} column dependencies | Sources: {', '.join(sorted(unique_src_tables)) or 'None'}")

    # 1. Export Column Lineage CSV
    output_col_csv.parent.mkdir(parents=True, exist_ok=True)
    col_fieldnames = [
        "query_file", "model_name", "target_entity", "target_column",
        "source_schema", "source_table", "source_column", "table_alias",
        "transformation_type", "expression_detail", "is_join_key", "join_condition"
    ]

    with open(output_col_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=col_fieldnames)
        writer.writeheader()
        writer.writerows(all_column_records)

    # 2. Export Table Lineage CSV
    output_tbl_csv.parent.mkdir(parents=True, exist_ok=True)
    tbl_fieldnames = [
        "query_file", "model_name", "target_entity", "source_schema",
        "source_table", "table_alias", "is_cte", "join_type", "join_condition"
    ]

    with open(output_tbl_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=tbl_fieldnames)
        writer.writeheader()
        writer.writerows(all_table_records)

    print("\n------------------------------------------------------------------")
    print(f"✅ Dependency Lineage Matrix Generated Successfully!")
    print(f"   • Total Column Dependencies Tracked : {len(all_column_records):,}")
    print(f"   • Total Table Ingestions & Joins    : {len(all_table_records):,}")
    print(f"   • Column Lineage CSV File           : {output_col_csv}")
    print(f"   • Table Lineage CSV File            : {output_tbl_csv}")
    print("------------------------------------------------------------------")


def main():
    parser = argparse.ArgumentParser(description="Parse SQL queries and export column-level & table-level dependency lineage to CSV")
    parser.add_argument("--input-dir", "-d", type=str, help="Directory containing .sql query files to parse")
    parser.add_argument("--output-col-csv", "-c", type=str, help="Destination path for column dependencies CSV")
    parser.add_argument("--output-tbl-csv", "-t", type=str, help="Destination path for table dependencies CSV")

    args = parser.parse_args()

    scan_dir = Path(args.input_dir) if args.input_dir else DEFAULT_SQL_DIR
    col_csv = Path(args.output_col_csv) if args.output_col_csv else DEFAULT_OUTPUT_CSV
    tbl_csv = Path(args.output_tbl_csv) if args.output_tbl_csv else DEFAULT_TABLE_CSV

    run_lineage_pipeline(scan_dir, col_csv, tbl_csv)


if __name__ == "__main__":
    main()
