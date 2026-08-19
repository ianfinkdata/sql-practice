#!/usr/bin/env python3
"""
parse_tmdl.py - TMDL Metadata AST Parser, M Code Data Source & Lineage Compiler

Parses Power BI TMDL (.tmdl) syntax, extracts deep Data Source Connectors,
M Code transformation steps (let...in), parameters, and populates database catalogs.
"""

import os
import re
import sys
import json
import sqlite3
import argparse
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

REPO_ROOT = Path(__file__).parent.parent.parent.resolve()
PROJECTS_DIR = REPO_ROOT / "pbip" / "projects"
OUTPUT_JSON_FILE = REPO_ROOT / "pbip" / "tmdl_parsed_schema.json"
OUTPUT_DDL_FILE = REPO_ROOT / "pbip" / "tmdl_schema_ddl.sql"
# PROJECT_DDL_FILE = REPO_ROOT / "project" / "tmdl_schema.sql"


# Official Oakhaven Business Descriptions for Columns & Measures
COLUMN_DESCRIPTIONS = {
    "customer_id": "Unique sequential identifier (1..600) for each customer.",
    "first_name": "Customer given name.",
    "last_name": "Customer family surname.",
    "full_name": "Concatenated customer full name (first + last).",
    "customer_name": "Full name of the purchasing customer.",
    "email": "Primary email address associated with customer account.",
    "phone": "Standardized 10-digit customer contact phone number.",
    "state": "Customer geographic state or province code.",
    "customer_state": "State code of the customer location.",
    "signup_date": "Date on which the customer account was first registered.",
    "is_active": "Boolean status indicator (1 = Active account, 0 = Inactive/Closed).",
    "customer_segment": "Market segment classification (Retail, Wholesale, VIP).",

    "product_id": "Unique surrogate key (1..150) identifying each merchandise item.",
    "product_name": "Catalog description and product title.",
    "category": "High-level merchandise category (e.g. Footwear, Apparel, Climbing).",
    "product_category": "Merchandise category of the ordered item.",
    "subcategory": "Detailed merchandise subcategory (e.g. Hiking Boots, Chalk Bags).",
    "brand": "Manufacturer or outdoor gear brand name.",
    "product_brand": "Brand name of the ordered merchandise item.",
    "unit_cost": "Wholesale acquisition cost per unit ($).",
    "unit_price": "Retail selling price per unit ($) at time of order.",
    "is_discontinued": "Flag indicating if the product is no longer actively manufactured.",
    "sku": "Stock Keeping Unit item tracking code.",
    "sku_is_duplicate": "Data quality flag indicating duplicated SKU codes across products.",
    "weight_kg": "Product package shipping weight in kilograms.",
    "created_at": "Timestamp when product was added to catalog.",

    "employee_id": "Unique employee identification number (1..35).",
    "sales_rep_name": "Full name of the assigned sales representative.",
    "department": "Company department (Sales, Support, Warehouse, Management).",
    "region": "Assigned geographical sales territory (West, East, Central, South).",
    "sales_region": "Sales region of the assigned employee.",
    "hire_date": "Official employment start date.",
    "termination_date": "Date of departure (NULL for currently active staff).",
    "is_manager": "Flag indicating supervisory or management status.",

    "datekey": "Integer surrogate key in YYYYMMDD format for date joins.",
    "date": "Standard ISO 8601 calendar date (YYYY-MM-DD).",
    "order_date": "Transaction date on which order was placed.",
    "ship_date": "Date order was packed and shipped to customer.",
    "year": "Four-digit calendar year (e.g. 2026).",
    "month": "Numeric calendar month (1..12).",
    "month_name": "Full English month name (e.g. January, February).",
    "quarter": "Calendar quarter identifier (Q1, Q2, Q3, Q4).",
    "day_of_month": "Numeric day of the month (1..31).",
    "day_of_week": "Numeric day of the week (1..7).",
    "day_name": "Full English day name (e.g. Monday, Tuesday).",
    "is_weekend": "Boolean flag indicating Saturday or Sunday (1 = Weekend, 0 = Weekday).",

    "order_id": "Unique sales order transaction header identifier.",
    "order_line_id": "Line item sequence number (1..N) within an order.",
    "quantity": "Number of units purchased in order line.",
    "discount_pct": "Percentage discount applied (0.00 to 0.30).",
    "gross_amount": "Pre-discount gross revenue (Quantity * Unit Price).",
    "net_amount": "Actual net revenue earned after applying discounts.",
    "discount_tier": "Categorical discount bracket (Full Price, Standard Discount, High Discount 20%+).",
    "payment_method": "Payment tender channel (Credit Card, PayPal, Cash, Debit Card).",
    "order_status": "Current status of transaction (Completed, Processing, Canceled, Returned).",
    "channel": "Sales channel origination (Web, Mobile App, In-Store Retail).",
    "is_customer_orphan": "Data quality flag identifying orders with unmapped customer IDs.",
    "is_product_orphan": "Data quality flag identifying order lines with unmapped product IDs."
}

MEASURE_DESCRIPTIONS = {
    "Total Gross Revenue": "Sum of pre-discount revenue across all sales lines.",
    "Total Net Revenue": "Sum of actual net sales revenue earned after discounts.",
    "Total Units Sold": "Total sum of merchandise item quantities sold.",
    "Total Orders": "Count of distinct sales order transaction IDs.",
    "Average Order Value": "Mean net revenue earned per distinct sales order.",
    "Active Customer Count": "Count of unique customers placing orders in selected period.",
    "Overall Discount Rate": "Weighted average discount percentage across all order lines.",
    "Total Cost of Goods Sold": "Total wholesale acquisition cost of all merchandise units sold.",
    "Gross Margin": "Total gross profit (Net Revenue minus Cost of Goods Sold).",
    "Gross Margin %": "Gross profit percentage of total net revenue.",
    "Net Revenue PY": "Total net revenue for the prior year comparable calendar period.",
    "Net Revenue YoY %": "Year-over-year percentage growth in total net revenue."
}


def extract_measure_referenced_tables(expression, all_measures_exprs=None, doc_desc=None, visited=None):
    """
    Extracts a sorted, unique list of all tables referenced in a DAX measure,
    resolving direct table/column references, DAX table function arguments,
    explicit [Tables: ...] comment tags, and transitive measure dependencies.
    """
    if visited is None:
        visited = set()
        
    tables = set()
    
    # 1. Parse explicit [Tables: table1, table2] from doc comments / descriptions
    if doc_desc:
        tag_match = re.search(r'\[Tables:\s*([^\]]+)\]', doc_desc, re.IGNORECASE)
        if not tag_match:
            tag_match = re.search(r'Tables:\s*([a-zA-Z0-9_, ]+)(?:\||\-|\.|$)', doc_desc, re.IGNORECASE)
        if tag_match:
            for t in tag_match.group(1).split(','):
                clean_t = t.strip().strip("'").strip('"')
                if clean_t and clean_t.lower() not in ('_measures', 'measures', 'none'):
                    tables.add(clean_t)

    if not expression:
        return sorted(list(tables))

    # 2. Direct Table[Column] references (quoted 'Table Name'[Col] or unquoted Table[Col])
    col_refs = re.findall(r"(?:'([^']+)'|([a-zA-Z0-9_]+))\[([^\]]+)\]", expression)
    for q_tbl, u_tbl, col in col_refs:
        tbl = q_tbl or u_tbl
        if tbl and tbl.lower() not in ('_measures', 'measures'):
            tables.add(tbl)

    # 3. Direct Table arguments in DAX table functions
    tbl_funcs = re.findall(
        r"\b(?:SUMX|AVERAGEX|MINX|MAXX|COUNTX|COUNTA|FILTER|ALL|ALLSELECTED|VALUES|DISTINCT|CALCULATETABLE|RELATEDTABLE)\s*\(\s*(?:'([^']+)'|([a-zA-Z0-9_]+))\b",
        expression,
        re.IGNORECASE
    )
    for q_tbl, u_tbl in tbl_funcs:
        tbl = q_tbl or u_tbl
        if tbl and tbl.lower() not in ('_measures', 'measures'):
            tables.add(tbl)

    # 4. Transitive measure dependencies [Measure Name]
    if all_measures_exprs:
        m_refs = re.findall(r"(?<![a-zA-Z0-9_'])\[([a-zA-Z0-9_ %]+)\]", expression)
        for m_name in m_refs:
            if m_name in all_measures_exprs and m_name not in visited:
                visited.add(m_name)
                transitive_tables = extract_measure_referenced_tables(
                    all_measures_exprs[m_name],
                    all_measures_exprs,
                    doc_desc=None,
                    visited=visited
                )
                tables.update(transitive_tables)

    return sorted(list(tables))


TMDL_TO_SQL_TYPES = {
    "string": "TEXT",
    "int64": "INTEGER",
    "integer": "INTEGER",
    "double": "REAL",
    "decimal": "NUMERIC",
    "datetime": "TIMESTAMP",
    "date": "DATE",
    "boolean": "BOOLEAN",
    "binary": "BLOB"
}


def parse_m_data_source(partition_source):
    """Parses a Power Query M partition expression to classify the Data Source & Connector."""
    if not partition_source:
        return {"connector": "Unknown", "target": "N/A", "query_type": "None"}
        
    src_str = partition_source.replace("#(cr)#(lf)", "\n").replace("#(lf)", "\n")
    
    raw_clean = src_str.strip('`').strip()
    # SQLite via Python Execute
    if "Python.Execute" in src_str and "sqlite3" in src_str:
        db_match = re.search(r'sqlite3\.connect\("(.*?)"\)', src_str)
        target = db_match.group(1) if db_match else "project/oakhaven.db"
        return {"connector": "SQLite (Python Connector)", "target": target, "query_type": "Native SQL Pushdown", "raw_m_code": raw_clean}
        
    # SQL Server
    if "Sql.Database" in src_str:
        srv_match = re.search(r'Sql\.Database\(\s*"([^"]+)"\s*,\s*"([^"]+)"', src_str)
        target = f"{srv_match.group(1)}.{srv_match.group(2)}" if srv_match else "SQL Server"
        return {"connector": "Microsoft SQL Server", "target": target, "query_type": "Native SQL Query" if "Query=" in src_str else "Table Direct", "raw_m_code": raw_clean}

    # Snowflake
    if "Snowflake.Databases" in src_str:
        return {"connector": "Snowflake Data Warehouse", "target": "Snowflake Account", "query_type": "DirectQuery / Import", "raw_m_code": raw_clean}

    # OData / Web API
    if "OData.Feed" in src_str or "Web.Contents" in src_str:
        url_match = re.search(r'https?://[^\s"]+', src_str)
        target = url_match.group(0) if url_match else "Web REST API"
        return {"connector": "Web REST API / OData", "target": target, "query_type": "JSON Feed", "raw_m_code": raw_clean}

    # Excel / CSV File
    if "Csv.Document" in src_str or "Excel.Workbook" in src_str:
        file_match = re.search(r'File\.Contents\(\s*"([^"]+)"', src_str)
        target = file_match.group(1) if file_match else "Flat File"
        return {"connector": "File (CSV / Excel)", "target": target, "query_type": "File Import", "raw_m_code": raw_clean}

    # Generic M string
    if "SELECT " in src_str.upper():
        return {"connector": "Relational SQL Source", "target": "project/oakhaven.db", "query_type": "Native SQL Pushdown", "raw_m_code": raw_clean}

    return {"connector": "Power Query M Transformation", "target": "In-Memory", "query_type": "M Expression", "raw_m_code": raw_clean}


def parse_m_transformation_steps(partition_source):
    """Parses let...in blocks in Power Query M to extract individual transformation steps."""
    if not partition_source:
        return []
        
    src_str = partition_source.replace("#(cr)#(lf)", "\n").replace("#(lf)", "\n")
    
    # Extract lines between let and in
    steps = []
    let_match = re.search(r'let\s+(.*?)\s+in\s+', src_str, re.DOTALL | re.IGNORECASE)
    if let_match:
        body = let_match.group(1)
        # Split on step assignments (e.g. StepName = Expression)
        raw_steps = re.findall(r'(#"[^"]+"|[a-zA-Z0-9_]+)\s*=\s*(.*?)(?=,\s*\n|,\s*#|,\s*[a-zA-Z0-9_]+\s*=|,\s*//|\s*$)', body, re.DOTALL)
        
        for idx, (s_name, s_code) in enumerate(raw_steps, 1):
            clean_name = s_name.strip('#"').strip()
            clean_code = s_code.strip()[:100] + "..." if len(s_code.strip()) > 100 else s_code.strip()
            
            step_type = "Source Ingestion"
            if "Filter" in clean_code or "SelectRows" in clean_code or "WHERE" in clean_code.upper():
                step_type = "Filter Transformation"
            elif "Join" in clean_code or "Merge" in clean_code:
                step_type = "Table Join / Merge"
            elif "Rename" in clean_code:
                step_type = "Column Rename"
            elif "Group" in clean_code:
                step_type = "Aggregation / Group By"
            elif "AddColumn" in clean_code:
                step_type = "Add Calculated Column"

            steps.append({
                "step_index": idx,
                "step_name": clean_name,
                "step_type": step_type,
                "code_snippet": clean_code
            })
            
    return steps


def parse_tmdl_table_file(tmdl_path):
    """Parses a table .tmdl file into a structured dictionary with enriched metadata & M lineage."""
    lines = tmdl_path.read_text(encoding="utf-8", errors="replace").splitlines()
    
    table_data = {
        "file": str(tmdl_path),
        "name": tmdl_path.stem,
        "lineageTag": None,
        "description": None,
        "columns": [],
        "measures": [],
        "partitions": [],
        "dataSource": None,
        "mSteps": []
    }
    
    current_object = None
    current_col = None
    current_measure = None
    raw_partition_code = []
    in_partition = False
    pending_doc_comments = []
    
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
            
        if stripped.startswith("///"):
            doc_text = stripped[3:].strip()
            if doc_text:
                pending_doc_comments.append(doc_text)
            continue

        if stripped.startswith("//"):
            continue
            
        t_match = re.match(r"^table\s+(.+)$", stripped)
        if t_match:
            table_data["name"] = t_match.group(1).strip().strip("'").strip('"')
            if pending_doc_comments:
                table_data["description"] = " ".join(pending_doc_comments)
                pending_doc_comments = []
            current_object = "table"
            continue

        p_match = re.match(r"^partition\s+(.+?)\s*=\s*(.+)$", stripped)
        if p_match:
            in_partition = True
            current_object = "partition"
            pending_doc_comments = []
            continue
            
        if in_partition:
            if stripped.startswith("annotation") or stripped.startswith("table ") or stripped.startswith("column ") or stripped.startswith("measure "):
                in_partition = False
            else:
                raw_partition_code.append(stripped)

        c_match = re.match(r"^column\s+(.+)$", stripped)
        if c_match:
            in_partition = False
            col_name = c_match.group(1).strip().strip("'").strip('"')
            doc_desc = " ".join(pending_doc_comments) if pending_doc_comments else None
            pending_doc_comments = []
            desc = doc_desc or COLUMN_DESCRIPTIONS.get(col_name.lower(), f"Attribute column representing {col_name}.")
            current_col = {
                "name": col_name,
                "dataType": "string",
                "sourceColumn": col_name,
                "summarizeBy": "none",
                "description": desc,
                "lineageTag": None,
                "expression": None
            }
            table_data["columns"].append(current_col)
            current_object = "column"
            continue
            
        m_match = re.match(r"^measure\s+(.+?)\s*=\s*(.+)$", stripped)
        if m_match:
            in_partition = False
            m_name = m_match.group(1).strip().strip("'").strip('"')
            m_expr = m_match.group(2).strip()
            doc_desc = " ".join(pending_doc_comments) if pending_doc_comments else None
            pending_doc_comments = []
            m_desc = doc_desc or MEASURE_DESCRIPTIONS.get(m_name, f"Calculated metric for {m_name}.")
            current_measure = {
                "name": m_name,
                "expression": m_expr,
                "description": m_desc,
                "formatString": None,
                "displayFolder": None,
                "lineageTag": None
            }
            table_data["measures"].append(current_measure)
            current_object = "measure"
            continue
            
        if current_object == "column" and current_col:
            if stripped.startswith("dataType:"):
                current_col["dataType"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("sourceColumn:"):
                current_col["sourceColumn"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("summarizeBy:"):
                current_col["summarizeBy"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("lineageTag:"):
                current_col["lineageTag"] = stripped.split(":", 1)[1].strip()

        if current_object == "measure" and current_measure:
            if stripped.startswith("formatString:"):
                current_measure["formatString"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("displayFolder:"):
                current_measure["displayFolder"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("lineageTag:"):
                current_measure["lineageTag"] = stripped.split(":", 1)[1].strip()

    # Parse partition source & lineage
    partition_text = "\n".join(raw_partition_code)
    table_data["dataSource"] = parse_m_data_source(partition_text)
    table_data["mSteps"] = parse_m_transformation_steps(partition_text)

    return table_data


def parse_tmdl_expressions_file(expr_path):
    """Parses definition/expressions.tmdl to extract parameters and data source connections."""
    lines = expr_path.read_text(encoding="utf-8", errors="replace").splitlines()
    parameters = []
    
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("expression "):
            p_match = re.match(r"^expression\s+([^\s=]+)\s*=\s*\"([^\"]+)\"", stripped)
            if p_match:
                parameters.append({
                    "name": p_match.group(1),
                    "type": "Text",
                    "defaultValue": p_match.group(2),
                    "isParameter": True
                })
    return parameters


def parse_tmdl_relationships_file(rel_path):
    """Parses a relationships.tmdl file to extract table join keys and cardinalities."""
    lines = rel_path.read_text(encoding="utf-8", errors="replace").splitlines()
    relationships = []
    
    current_rel = None
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
            
        r_match = re.match(r"^relationship\s+(.+)$", stripped)
        if r_match:
            current_rel = {
                "name": r_match.group(1).strip(),
                "fromTable": None,
                "fromColumn": None,
                "toTable": None,
                "toColumn": None,
                "crossFilteringBehavior": "single",
                "toCardinality": "one"
            }
            relationships.append(current_rel)
            continue
            
        if current_rel:
            if stripped.startswith("fromColumn:"):
                val = stripped.split(":", 1)[1].strip()
                parts = val.split(".", 1)
                current_rel["fromTable"] = parts[0]
                current_rel["fromColumn"] = parts[1] if len(parts) > 1 else parts[0]
            elif stripped.startswith("toColumn:"):
                val = stripped.split(":", 1)[1].strip()
                parts = val.split(".", 1)
                current_rel["toTable"] = parts[0]
                current_rel["toColumn"] = parts[1] if len(parts) > 1 else parts[0]
                
    return relationships


def parse_all_projects():
    """Recursively scans pbip/projects/ and builds a complete TMDL AST with M Data Source Lineage & Measure Table Mapping."""
    print("==================================================================")
    print("  PBIP TMDL AST PARSER & M CODE DATA SOURCE LINEAGE ENGINE")
    print("==================================================================")

    projects = {}

    for project_dir in sorted(PROJECTS_DIR.iterdir()):
        if not project_dir.is_dir():
            continue
            
        project_name = project_dir.name
        tables = []
        relationships = []
        parameters = []
        
        table_files = list(project_dir.rglob("definition/tables/*.tmdl"))
        for t_file in sorted(table_files):
            t_data = parse_tmdl_table_file(t_file)
            tables.append(t_data)
            
        rel_files = list(project_dir.rglob("definition/relationships.tmdl"))
        for r_file in rel_files:
            r_data = parse_tmdl_relationships_file(r_file)
            relationships.extend(r_data)

        expr_files = list(project_dir.rglob("definition/expressions.tmdl"))
        for e_file in expr_files:
            p_data = parse_tmdl_expressions_file(e_file)
            parameters.extend(p_data)

        # Build project-level measure expressions lookup for transitive lineage resolution
        all_measures_exprs = {
            m["name"]: m["expression"]
            for t in tables
            for m in t["measures"]
        }
        available_tables = {
            t["name"]
            for t in tables
            if t["name"].lower() not in ("_measures", "measures")
        }

        # Map referenced tables and auto-tag descriptions for all measures
        for t in tables:
            for m in t["measures"]:
                ref_tables = extract_measure_referenced_tables(
                    m["expression"],
                    all_measures_exprs,
                    doc_desc=m.get("description")
                )
                m["referencedTables"] = ", ".join(ref_tables)
                
                # Ensure description includes [Tables: ...] prefix
                if ref_tables:
                    table_tag = f"[Tables: {', '.join(ref_tables)}]"
                    curr_desc = m.get("description") or MEASURE_DESCRIPTIONS.get(m["name"], f"Calculated metric for {m['name']}.")
                    if not curr_desc.startswith("[Tables:"):
                        m["description"] = f"{table_tag} {curr_desc}"
                    else:
                        # Normalize tag if already present
                        clean_desc = re.sub(r"^\[Tables:\s*[^\]]+\]\s*", "", curr_desc).strip()
                        m["description"] = f"{table_tag} {clean_desc}"
                
                # Model validation status
                missing_tables = [tbl for tbl in ref_tables if tbl not in available_tables]
                m["isValidInModel"] = len(missing_tables) == 0
                m["missingTables"] = ", ".join(missing_tables) if missing_tables else ""
            
        projects[project_name] = {
            "name": project_name,
            "tableCount": len(tables),
            "relationshipCount": len(relationships),
            "parameterCount": len(parameters),
            "tables": tables,
            "relationships": relationships,
            "parameters": parameters
        }

    OUTPUT_JSON_FILE.write_text(json.dumps(projects, indent=2), encoding="utf-8")
    print(f"✅ Exported enriched TMDL AST with M Data Sources & Measure Table Mappings to JSON: {OUTPUT_JSON_FILE}")

    return projects


def generate_sql_ddl_and_catalogs(projects):
    """Generates SQL CREATE TABLE statements + Data Source & M Step metadata catalog tables."""
    sql_statements = [
        "-- =============================================================================",
        "-- AUTOMATICALLY GENERATED DDL & METADATA CATALOG FROM POWER BI TMDL & M METADATA",
        "-- Generated by: pbip/pyscripts/parse_tmdl.py",
        "-- =============================================================================\n",
        "DROP TABLE IF EXISTS _tmdl_projects;",
        "DROP TABLE IF EXISTS _tmdl_tables;",
        "DROP TABLE IF EXISTS _tmdl_columns;",
        "DROP TABLE IF EXISTS _tmdl_measures;",
        "DROP TABLE IF EXISTS _tmdl_relationships;",
        "DROP TABLE IF EXISTS _tmdl_data_sources;",
        "DROP TABLE IF EXISTS _tmdl_m_steps;",
        "DROP TABLE IF EXISTS _tmdl_parameters;",
        "DROP TABLE IF EXISTS _tmdl_advanced_editor;",
        "CREATE TABLE IF NOT EXISTS _tmdl_projects (project_name TEXT PRIMARY KEY, table_count INT, relationship_count INT, parameter_count INT);",
        "CREATE TABLE IF NOT EXISTS _tmdl_tables (project_name TEXT, table_name TEXT, lineage_tag TEXT, PRIMARY KEY (project_name, table_name));",
        "CREATE TABLE IF NOT EXISTS _tmdl_columns (project_name TEXT, table_name TEXT, column_name TEXT, data_type TEXT, summarize_by TEXT, source_column TEXT, description TEXT);",
        "CREATE TABLE IF NOT EXISTS _tmdl_measures (project_name TEXT, table_name TEXT, measure_name TEXT, expression TEXT, format_string TEXT, description TEXT, referenced_tables TEXT);",
        "CREATE TABLE IF NOT EXISTS _tmdl_relationships (project_name TEXT, rel_name TEXT, from_table TEXT, from_column TEXT, to_table TEXT, to_column TEXT, cardinality TEXT);",
        "CREATE TABLE IF NOT EXISTS _tmdl_data_sources (project_name TEXT, table_name TEXT, connector TEXT, connection_target TEXT, query_type TEXT, advanced_editor_script TEXT);",
        "CREATE TABLE IF NOT EXISTS _tmdl_advanced_editor (project_name TEXT, table_name TEXT, advanced_editor_script TEXT, PRIMARY KEY (project_name, table_name));",
        "CREATE TABLE IF NOT EXISTS _tmdl_m_steps (project_name TEXT, table_name TEXT, step_index INT, step_name TEXT, step_type TEXT, code_snippet TEXT);",
        "CREATE TABLE IF NOT EXISTS _tmdl_parameters (project_name TEXT, param_name TEXT, data_type TEXT, default_value TEXT);\n"
    ]

    for p_name, p_data in projects.items():
        clean_p_name = p_name.replace(" ", "_").replace(".", "_").lower()
        sql_statements.append(f"-- PROJECT: {p_name}")
        sql_statements.append(f"INSERT OR REPLACE INTO _tmdl_projects VALUES ('{p_name}', {p_data['tableCount']}, {p_data['relationshipCount']}, {p_data['parameterCount']});")

        for param in p_data["parameters"]:
            sql_statements.append(f"INSERT INTO _tmdl_parameters VALUES ('{p_name}', '{param['name']}', '{param['type']}', '{param['defaultValue']}');")

        rel_fk_map = {}
        for r in p_data["relationships"]:
            if r["fromTable"] and r["toTable"]:
                rel_fk_map.setdefault(r["fromTable"], []).append(r)
            sql_statements.append(f"INSERT INTO _tmdl_relationships VALUES ('{p_name}', '{r['name']}', '{r['fromTable']}', '{r['fromColumn']}', '{r['toTable']}', '{r['toColumn']}', '{r['toCardinality']}');")

        for t in p_data["tables"]:
            t_name = t["name"]
            table_sql_name = f"tmdl_{clean_p_name}_{t_name}".replace(" ", "_").replace(".", "_").lower()
            sql_statements.append(f"INSERT OR REPLACE INTO _tmdl_tables VALUES ('{p_name}', '{t_name}', '{t['lineageTag']}');")

            # Data Source & Advanced Editor Catalog Inserts
            ds = t["dataSource"]
            clean_raw_m = ds.get('raw_m_code', '').replace("'", "''")
            sql_statements.append(f"INSERT INTO _tmdl_data_sources VALUES ('{p_name}', '{t_name}', '{ds['connector']}', '{ds['target']}', '{ds['query_type']}', '{clean_raw_m}');")
            sql_statements.append(f"INSERT OR REPLACE INTO _tmdl_advanced_editor VALUES ('{p_name}', '{t_name}', '{clean_raw_m}');")

            # M Steps Catalog Inserts
            for step in t["mSteps"]:
                clean_code = step["code_snippet"].replace("'", "''")
                sql_statements.append(f"INSERT INTO _tmdl_m_steps VALUES ('{p_name}', '{t_name}', {step['step_index']}, '{step['step_name']}', '{step['step_type']}', '{clean_code}');")

            col_definitions = []
            for c in t["columns"]:
                sql_type = TMDL_TO_SQL_TYPES.get(c["dataType"].lower(), "TEXT")
                col_definitions.append(f"    \"{c['name']}\" {sql_type}")
                clean_c_name = c['name'].replace("'", "''")
                clean_c_source = (c['sourceColumn'] or '').replace("'", "''")
                clean_desc = c['description'].replace("'", "''")
                sql_statements.append(f"INSERT INTO _tmdl_columns VALUES ('{p_name}', '{t_name}', '{clean_c_name}', '{c['dataType']}', '{c['summarizeBy']}', '{clean_c_source}', '{clean_desc}');")

            for m in t["measures"]:
                clean_m_name = m["name"].replace("'", "''")
                clean_expr = m["expression"].replace("'", "''")
                clean_m_desc = m["description"].replace("'", "''")
                format_str = (m.get("formatString") or '').replace("'", "''")
                clean_ref_tables = (m.get("referencedTables") or '').replace("'", "''")
                sql_statements.append(f"INSERT INTO _tmdl_measures VALUES ('{p_name}', '{t_name}', '{clean_m_name}', '{clean_expr}', '{format_str}', '{clean_m_desc}', '{clean_ref_tables}');")

            if t_name in rel_fk_map:
                for r in rel_fk_map[t_name]:
                    target_table_sql_name = f"tmdl_{clean_p_name}_{r['toTable']}".replace(" ", "_").replace(".", "_").lower()
                    col_definitions.append(f"    FOREIGN KEY (\"{r['fromColumn']}\") REFERENCES {target_table_sql_name}(\"{r['toColumn']}\")")

            if col_definitions:
                table_ddl = f"CREATE TABLE IF NOT EXISTS {table_sql_name} (\n" + ",\n".join(col_definitions) + "\n);"
                sql_statements.append(table_ddl + "\n")

    full_sql = "\n".join(sql_statements)
    OUTPUT_DDL_FILE.write_text(full_sql, encoding="utf-8")
    print(f"✅ Exported DDL & Data Source Catalogs to: {OUTPUT_DDL_FILE}")

    return full_sql


def test_push_to_db(full_sql, target_db_path):
    """Executes the enriched TMDL DDL and Catalog SQL statements against a target SQLite DB."""
    target_db = Path(target_db_path)
    if target_db.name.startswith("scratch") and target_db.exists():
        target_db.unlink()

    conn = sqlite3.connect(target_db)
    cursor = conn.cursor()
    
    print("\n------------------------------------------------------------------")
    print(f"Executing TMDL DDL & M Data Source Catalog Creation against ({target_db}):")
    print("------------------------------------------------------------------")

    try:
        cursor.executescript(full_sql)
        conn.commit()
        
        cursor.execute("SELECT count(*) FROM _tmdl_data_sources;")
        ds_cnt = cursor.fetchone()[0]
        
        cursor.execute("SELECT count(*) FROM _tmdl_m_steps;")
        step_cnt = cursor.fetchone()[0]

        cursor.execute("SELECT count(*) FROM _tmdl_parameters;")
        param_cnt = cursor.fetchone()[0]

        print(f"  ✅ [SUCCESS] TMDL & M Lineage Catalogs Pushed to Database!")
        print(f"     • Data Sources Cataloged    : {ds_cnt}")
        print(f"     • M Code Steps Tracked      : {step_cnt}")
        print(f"     • Parameters Registered     : {param_cnt}")
    except Exception as e:
        print(f"  ❌ [DDL ERROR]: {e}")
        
    conn.close()
    print("------------------------------------------------------------------")


if __name__ == "__main__":
    import tempfile
    parser = argparse.ArgumentParser(description="Parse TMDL & M Data Sources into Database Catalogs")
    parser.add_argument("--test-db", action="store_true", help="Execute DDL & Catalog inserts against scratch DB")
    parser.add_argument("--db-path", type=str, help="Specify custom target SQLite database file")
    args = parser.parse_args()

    projects = parse_all_projects()
    full_sql = generate_sql_ddl_and_catalogs(projects)
    
    if args.db_path:
        test_push_to_db(full_sql, args.db_path)
    elif args.test_db:
        scratch_path = Path(tempfile.gettempdir()) / "scratch_tmdl_schema.db"
        test_push_to_db(full_sql, str(scratch_path))

