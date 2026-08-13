#!/usr/bin/env python3
"""
parse_tmdl.py - TMDL Metadata AST Parser, Schema Compiler & Description Enricher

Parses Power BI TMDL (.tmdl) language syntax (tables, columns, data types, 
measures, relationships, partitions) and enriches all columns and measures with
verified, business-ready descriptions from the Oakhaven Data Dictionary.
"""

import os
import re
import sys
import json
import sqlite3
import argparse
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent.resolve()
PROJECTS_DIR = REPO_ROOT / "pbip_poc" / "projects"
OUTPUT_JSON_FILE = REPO_ROOT / "pbip_poc" / "tmdl_parsed_schema.json"
OUTPUT_DDL_FILE = REPO_ROOT / "pbip_poc" / "tmdl_schema_ddl.sql"
PROJECT_DDL_FILE = REPO_ROOT / "project" / "tmdl_schema.sql"


# Official Oakhaven Business Descriptions for Columns & Measures
COLUMN_DESCRIPTIONS = {
    # Customer Dimension
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

    # Product Dimension
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

    # Employee Dimension
    "employee_id": "Unique employee identification number (1..35).",
    "sales_rep_name": "Full name of the assigned sales representative.",
    "department": "Company department (Sales, Support, Warehouse, Management).",
    "region": "Assigned geographical sales territory (West, East, Central, South).",
    "sales_region": "Sales region of the assigned employee.",
    "hire_date": "Official employment start date.",
    "termination_date": "Date of departure (NULL for currently active staff).",
    "is_manager": "Flag indicating supervisory or management status.",

    # Date / Calendar Dimension
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

    # Sales Fact Table
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
    "Average Order Value": "Mean net revenue earned per distinct sales order.",
    "Total Orders": "Count of distinct sales order transaction IDs.",
    "Active Customer Count": "Count of unique customers placing orders in selected period.",
    "Overall Discount Rate": "Weighted average discount percentage across all order lines."
}

# Map Power BI TMDL Data Types ➔ SQL Column Data Types
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


def parse_tmdl_table_file(tmdl_path):
    """Parses a table .tmdl file into a structured dictionary with enriched descriptions."""
    lines = tmdl_path.read_text(encoding="utf-8", errors="replace").splitlines()
    
    table_data = {
        "file": str(tmdl_path),
        "name": tmdl_path.stem,
        "lineageTag": None,
        "columns": [],
        "measures": [],
        "partitions": []
    }
    
    current_object = None
    current_col = None
    current_measure = None
    
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
            
        t_match = re.match(r"^table\s+([^\s]+)", stripped)
        if t_match:
            table_data["name"] = t_match.group(1)
            current_object = "table"
            continue
            
        c_match = re.match(r"^column\s+(.+)$", stripped)
        if c_match:
            col_name = c_match.group(1).strip()
            desc = COLUMN_DESCRIPTIONS.get(col_name.lower(), f"Attribute column representing {col_name}.")
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
            m_name = m_match.group(1).strip()
            m_expr = m_match.group(2).strip()
            m_desc = MEASURE_DESCRIPTIONS.get(m_name, f"Calculated metric for {m_name}.")
            current_measure = {
                "name": m_name,
                "expression": m_expr,
                "description": m_desc,
                "formatString": None,
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
            elif stripped.startswith("description:"):
                current_col["description"] = stripped.split(":", 1)[1].strip().strip('"')

        if current_object == "measure" and current_measure:
            if stripped.startswith("formatString:"):
                current_measure["formatString"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("lineageTag:"):
                current_measure["lineageTag"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("description:"):
                current_measure["description"] = stripped.split(":", 1)[1].strip().strip('"')
                
        if current_object == "table" and stripped.startswith("lineageTag:"):
            table_data["lineageTag"] = stripped.split(":", 1)[1].strip()

    return table_data


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
            elif stripped.startswith("crossFilteringBehavior:"):
                current_rel["crossFilteringBehavior"] = stripped.split(":", 1)[1].strip()
            elif stripped.startswith("toCardinality:"):
                current_rel["toCardinality"] = stripped.split(":", 1)[1].strip()
                
    return relationships


def parse_all_projects():
    """Recursively scans pbip_poc/projects/ and builds an enriched TMDL AST."""
    print("==================================================================")
    print("  PBIP TMDL METADATA PARSER & DESCRIPTION ENRICHER ENGINE")
    print("==================================================================")
    print(f"Projects Folder : {PROJECTS_DIR}")
    print(f"Target JSON     : {OUTPUT_JSON_FILE}")
    print(f"Target DDL SQL  : {OUTPUT_DDL_FILE}\n")

    projects = {}

    for project_dir in sorted(PROJECTS_DIR.iterdir()):
        if not project_dir.is_dir():
            continue
            
        project_name = project_dir.name
        tables = []
        relationships = []
        
        table_files = list(project_dir.rglob("definition/tables/*.tmdl"))
        for t_file in sorted(table_files):
            t_data = parse_tmdl_table_file(t_file)
            tables.append(t_data)
            
        rel_files = list(project_dir.rglob("definition/relationships.tmdl"))
        for r_file in rel_files:
            r_data = parse_tmdl_relationships_file(r_file)
            relationships.extend(r_data)
            
        projects[project_name] = {
            "name": project_name,
            "tableCount": len(tables),
            "relationshipCount": len(relationships),
            "tables": tables,
            "relationships": relationships
        }

    OUTPUT_JSON_FILE.write_text(json.dumps(projects, indent=2), encoding="utf-8")
    print(f"✅ Exported enriched TMDL AST to JSON: {OUTPUT_JSON_FILE}")

    return projects


def generate_sql_ddl_and_catalogs(projects):
    """Generates SQL CREATE TABLE statements + metadata catalog tables with descriptions."""
    sql_statements = [
        "-- =============================================================================",
        "-- AUTOMATICALLY GENERATED DDL & ENRICHED CATALOG FROM POWER BI TMDL METADATA",
        "-- Generated by: pbip_poc/tools/parse_tmdl.py",
        "-- =============================================================================\n",
        "-- -----------------------------------------------------------------------------",
        "-- 1. ENRICHED DATABASE METADATA CATALOG TABLES WITH DESCRIPTIONS",
        "-- -----------------------------------------------------------------------------",
        "CREATE TABLE IF NOT EXISTS _tmdl_projects (project_name TEXT PRIMARY KEY, table_count INT, relationship_count INT);",
        "CREATE TABLE IF NOT EXISTS _tmdl_tables (project_name TEXT, table_name TEXT, lineage_tag TEXT, PRIMARY KEY (project_name, table_name));",
        "CREATE TABLE IF NOT EXISTS _tmdl_columns (project_name TEXT, table_name TEXT, column_name TEXT, data_type TEXT, summarize_by TEXT, source_column TEXT, description TEXT);",
        "CREATE TABLE IF NOT EXISTS _tmdl_measures (project_name TEXT, table_name TEXT, measure_name TEXT, expression TEXT, format_string TEXT, description TEXT);",
        "CREATE TABLE IF NOT EXISTS _tmdl_relationships (project_name TEXT, rel_name TEXT, from_table TEXT, from_column TEXT, to_table TEXT, to_column TEXT, cardinality TEXT);\n"
    ]

    for p_name, p_data in projects.items():
        clean_p_name = p_name.replace(" ", "_").replace(".", "_").lower()
        sql_statements.append(f"-- -----------------------------------------------------------------------------")
        sql_statements.append(f"-- PROJECT: {p_name}")
        sql_statements.append(f"-- -----------------------------------------------------------------------------")
        
        sql_statements.append(f"INSERT OR REPLACE INTO _tmdl_projects VALUES ('{p_name}', {p_data['tableCount']}, {p_data['relationshipCount']});")

        rel_fk_map = {}
        for r in p_data["relationships"]:
            if r["fromTable"] and r["toTable"]:
                rel_fk_map.setdefault(r["fromTable"], []).append(r)
                
            sql_statements.append(
                f"INSERT INTO _tmdl_relationships VALUES ('{p_name}', '{r['name']}', '{r['fromTable']}', '{r['fromColumn']}', '{r['toTable']}', '{r['toColumn']}', '{r['toCardinality']}');"
            )

        for t in p_data["tables"]:
            t_name = t["name"]
            table_sql_name = f"tmdl_{clean_p_name}_{t_name}".replace(" ", "_").replace(".", "_").lower()
            
            sql_statements.append(f"INSERT OR REPLACE INTO _tmdl_tables VALUES ('{p_name}', '{t_name}', '{t['lineageTag']}');")
            
            col_definitions = []
            for c in t["columns"]:
                sql_type = TMDL_TO_SQL_TYPES.get(c["dataType"].lower(), "TEXT")
                col_definitions.append(f"    {c['name']} {sql_type}")
                
                clean_desc = c['description'].replace("'", "''")
                sql_statements.append(
                    f"INSERT INTO _tmdl_columns VALUES ('{p_name}', '{t_name}', '{c['name']}', '{c['dataType']}', '{c['summarizeBy']}', '{c['sourceColumn']}', '{clean_desc}');"
                )

            for m in t["measures"]:
                clean_expr = m["expression"].replace("'", "''")
                clean_m_desc = m["description"].replace("'", "''")
                sql_statements.append(
                    f"INSERT INTO _tmdl_measures VALUES ('{p_name}', '{t_name}', '{m['name']}', '{clean_expr}', '{m['formatString']}', '{clean_m_desc}');"
                )

            if t_name in rel_fk_map:
                for r in rel_fk_map[t_name]:
                    target_table_sql_name = f"tmdl_{clean_p_name}_{r['toTable']}".replace(" ", "_").replace(".", "_").lower()
                    col_definitions.append(f"    FOREIGN KEY ({r['fromColumn']}) REFERENCES {target_table_sql_name}({r['toColumn']})")

            table_ddl = f"CREATE TABLE IF NOT EXISTS {table_sql_name} (\n" + ",\n".join(col_definitions) + "\n);"
            sql_statements.append(table_ddl + "\n")

    full_sql = "\n".join(sql_statements)
    OUTPUT_DDL_FILE.write_text(full_sql, encoding="utf-8")
    PROJECT_DDL_FILE.write_text(full_sql, encoding="utf-8")
    print(f"✅ Exported TMDL DDL & Enriched Catalog SQL to: {PROJECT_DDL_FILE}")

    return full_sql


def test_push_to_db(full_sql, target_db_path):
    """Executes the enriched TMDL DDL and Catalog SQL statements against a target SQLite DB."""
    target_db = Path(target_db_path)
    if target_db.name.startswith("scratch") and target_db.exists():
        target_db.unlink()

    conn = sqlite3.connect(target_db)
    cursor = conn.cursor()
    
    print("\n------------------------------------------------------------------")
    print(f"Executing Enriched TMDL DDL & Catalog Creation against ({target_db}):")
    print("------------------------------------------------------------------")

    try:
        cursor.executescript(full_sql)
        conn.commit()
        
        cursor.execute("SELECT count(*) FROM _tmdl_projects;")
        proj_cnt = cursor.fetchone()[0]
        
        cursor.execute("SELECT count(*) FROM _tmdl_tables;")
        tbl_cnt = cursor.fetchone()[0]
        
        cursor.execute("SELECT count(*) FROM _tmdl_columns WHERE description IS NOT NULL;")
        col_cnt = cursor.fetchone()[0]

        cursor.execute("SELECT count(*) FROM _tmdl_relationships;")
        rel_cnt = cursor.fetchone()[0]

        print(f"  ✅ [SUCCESS] Enriched TMDL Schema Pushed to Database!")
        print(f"     • Database Target           : {target_db.resolve()}")
        print(f"     • Projects Registered       : {proj_cnt}")
        print(f"     • Tables Created            : {tbl_cnt}")
        print(f"     • Columns Described         : {col_cnt}")
        print(f"     • Relationships Mapped      : {rel_cnt}")
    except Exception as e:
        print(f"  ❌ [DDL ERROR]: {e}")
        
    conn.close()
    print("------------------------------------------------------------------")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Parse TMDL schema and generate enriched SQL DDL & Catalog tables")
    parser.add_argument("--test-db", action="store_true", help="Execute DDL & Catalog inserts against scratch DB (/tmp/scratch_tmdl_schema.db)")
    parser.add_argument("--db-path", type=str, help="Specify custom target SQLite database file to write tables and metadata catalog into")
    args = parser.parse_args()

    projects = parse_all_projects()
    full_sql = generate_sql_ddl_and_catalogs(projects)
    
    if args.db_path:
        test_push_to_db(full_sql, args.db_path)
    elif args.test_db:
        test_push_to_db(full_sql, "/tmp/scratch_tmdl_schema.db")

