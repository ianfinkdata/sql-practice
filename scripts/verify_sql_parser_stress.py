#!/usr/bin/env python3
"""
verify_sql_parser_stress.py - SQL AST Complexity & Parser Stress Tester

Analyzes SQL queries for anti-patterns that stress or break semantic AST parsers,
TMDL schema compilers, and column lineage engines. Measures subquery nesting depth,
chained alias lineage, nested CASE expressions, and subquery window functions.
"""

import re
import sys
import json
import argparse
from pathlib import Path
from typing import Dict, Any, List

REPO_ROOT = Path(__file__).parent.parent.resolve()


def analyze_sql_complexity(sql_text: str) -> Dict[str, Any]:
    """Analyzes structural and AST complexity metrics of a SQL query."""
    
    # Strip comments
    clean_lines = []
    for line in sql_text.splitlines():
        line_no_comment = re.sub(r"--.*$", "", line)
        clean_lines.append(line_no_comment)
    clean_sql = "\n".join(clean_lines)
    clean_sql_norm = " ".join(clean_sql.split())

    # 1. Count SELECT statements
    select_matches = list(re.finditer(r"\bSELECT\b", clean_sql, re.IGNORECASE))
    total_selects = len(select_matches)

    # 2. Measure max subquery nesting depth by tracking parentheses containing SELECT
    max_depth = 0
    current_depth = 0
    paren_stack = []
    
    # Scan characters to find nested (SELECT ...)
    i = 0
    n = len(clean_sql)
    while i < n:
        char = clean_sql[i]
        if char == "(":
            # Check if followed by whitespace and SELECT
            substr = clean_sql[i+1:i+100]
            if re.match(r"^\s*SELECT\b", substr, re.IGNORECASE):
                current_depth += 1
                paren_stack.append(True)
                if current_depth > max_depth:
                    max_depth = current_depth
            else:
                paren_stack.append(False)
        elif char == ")":
            if paren_stack:
                is_subq = paren_stack.pop()
                if is_subq:
                    current_depth = max(0, current_depth - 1)
        i += 1

    # 3. Analyze CASE expressions and nested CASE depth
    case_matches = list(re.finditer(r"\bCASE\b", clean_sql, re.IGNORECASE))
    end_matches = list(re.finditer(r"\bEND\b", clean_sql, re.IGNORECASE))
    total_cases = len(case_matches)

    max_case_nesting = 0
    current_case_nesting = 0
    # Token scan for CASE / END
    tokens = re.findall(r"\b(CASE|END)\b", clean_sql, re.IGNORECASE)
    for tok in tokens:
        if tok.upper() == "CASE":
            current_case_nesting += 1
            if current_case_nesting > max_case_nesting:
                max_case_nesting = current_case_nesting
        elif tok.upper() == "END":
            current_case_nesting = max(0, current_case_nesting - 1)

    # 4. Count Window Functions (OVER clauses)
    window_matches = list(re.finditer(r"\bOVER\s*\(", clean_sql, re.IGNORECASE))
    total_windows = len(window_matches)

    # 5. Detect CTEs vs Subqueries
    has_with_cte = bool(re.search(r"^\s*WITH\b", clean_sql, re.IGNORECASE))

    # 6. Extract Table/Subquery aliases (e.g., FROM (...) l1, JOIN ... p)
    subquery_aliases = re.findall(r"\)\s+([a-zA-Z0-9_]+)", clean_sql)
    table_joins = len(re.findall(r"\b(JOIN|LEFT\s+JOIN|INNER\s+JOIN)\b", clean_sql, re.IGNORECASE))

    # 7. Compute Parser Stress Risk Score
    risk_points = 0
    risk_factors = []

    if max_depth >= 5:
        risk_points += 40
        risk_factors.append(f"CRITICAL Subquery Nesting Depth ({max_depth} levels deep; exceeds standard recursion budget)")
    elif max_depth >= 3:
        risk_points += 20
        risk_factors.append(f"Moderate Subquery Nesting Depth ({max_depth} levels deep)")

    if max_case_nesting >= 3:
        risk_points += 25
        risk_factors.append(f"Deeply Nested CASE expressions ({max_case_nesting} levels deep)")
    elif max_case_nesting >= 2:
        risk_points += 10
        risk_factors.append(f"Multi-tier CASE expressions ({max_case_nesting} levels deep)")

    if total_windows > 0 and max_depth > 0:
        risk_points += 20
        risk_factors.append(f"Window functions declared inside subquery layers ({total_windows} window calls)")

    if not has_with_cte and max_depth >= 4:
        risk_points += 15
        risk_factors.append("Pure Monolithic Subquery architecture without modular CTE boundaries")

    if risk_points >= 70:
        risk_level = "CRITICAL (High Parser Failure Probability)"
    elif risk_points >= 40:
        risk_level = "HIGH (Requires Advanced Scope Tracking)"
    elif risk_points >= 20:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW (Standard Parse Complexity)"

    return {
        "total_select_clauses": total_selects,
        "max_subquery_nesting_depth": max_depth,
        "total_case_expressions": total_cases,
        "max_case_nesting_depth": max_case_nesting,
        "window_functions_count": total_windows,
        "table_joins_count": table_joins,
        "is_cte_architecture": has_with_cte,
        "subquery_aliases_detected": list(set(subquery_aliases)),
        "parser_stress_score": min(100, risk_points),
        "parser_stress_risk_level": risk_level,
        "identified_risk_factors": risk_factors
    }


def print_report(metrics: Dict[str, Any], filepath: str = "Input SQL"):
    print("=" * 80)
    print(f"SQL AST COMPLEXITY & PARSER STRESS REPORT: {filepath}")
    print("=" * 80)
    print(f"  • Total SELECT Clauses:            {metrics['total_select_clauses']}")
    print(f"  • Max Subquery Nesting Depth:      {metrics['max_subquery_nesting_depth']} levels")
    print(f"  • Total CASE Expressions:          {metrics['total_case_expressions']}")
    print(f"  • Max CASE Nesting Depth:          {metrics['max_case_nesting_depth']} levels")
    print(f"  • Window Functions (OVER clauses): {metrics['window_functions_count']}")
    print(f"  • Relational Joins:                {metrics['table_joins_count']}")
    print(f"  • Uses Modular CTEs (WITH):        {metrics['is_cte_architecture']}")
    print(f"  • Subquery Scopes / Aliases:       {', '.join(metrics['subquery_aliases_detected']) if metrics['subquery_aliases_detected'] else 'None'}")
    print("-" * 80)
    print(f"  • Parser Stress Risk Score:        {metrics['parser_stress_score']} / 100")
    print(f"  • Risk Classification:             {metrics['parser_stress_risk_level']}")
    print("-" * 80)
    if metrics["identified_risk_factors"]:
        print("  Identified AST Parser Friction Factors:")
        for factor in metrics["identified_risk_factors"]:
            print(f"    [!] {factor}")
    else:
        print("  No major parser bottlenecks detected.")
    print("=" * 80)


def main():
    parser = argparse.ArgumentParser(description="Audit SQL AST complexity and parser stress factors.")
    parser.add_argument("--file", "-f", type=str, help="Path to SQL file to inspect")
    parser.add_argument("--json", action="store_true", help="Output metrics in JSON format")
    parser.add_argument("--benchmark-all", action="store_true", help="Audit all analytical queries in portfolio/")

    args = parser.parse_args()

    if args.benchmark_all:
        portfolio_dir = REPO_ROOT / "portfolio" / "05-analytical-query-patterns"
        sql_files = list(portfolio_dir.glob("*.sql"))
        results = {}
        for sf in sorted(sql_files):
            text = sf.read_text(encoding="utf-8")
            metrics = analyze_sql_complexity(text)
            results[sf.name] = metrics
            if not args.json:
                print_report(metrics, filepath=sf.name)
                print()
        if args.json:
            print(json.dumps(results, indent=2))
        return

    if args.file:
        file_path = Path(args.file)
        if not file_path.exists():
            print(f"Error: File {file_path} does not exist.", file=sys.stderr)
            sys.exit(1)
        sql_text = file_path.read_text(encoding="utf-8")
        target_name = file_path.name
    else:
        # Default to lasagna portfolio file
        default_file = REPO_ROOT / "portfolio" / "05-analytical-query-patterns" / "lasagna-retail-fulfillment-margin-leakage.sql"
        if default_file.exists():
            sql_text = default_file.read_text(encoding="utf-8")
            target_name = default_file.name
        else:
            print("Usage: python verify_sql_parser_stress.py --file <path_to_sql>", file=sys.stderr)
            sys.exit(1)

    metrics = analyze_sql_complexity(sql_text)

    if args.json:
        print(json.dumps(metrics, indent=2))
    else:
        print_report(metrics, filepath=target_name)


if __name__ == "__main__":
    main()
