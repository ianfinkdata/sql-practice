#!/usr/bin/env python3
"""
extract_report_lineage.py - Extract Columns, Measures, and Field Lineage from Power BI Report JSONs

Parses all pages, visuals, and filters across PBIP .Report definitions:
- report.json (Report-level metadata & filters)
- pages.json & page.json (Page names, layout, and page-level filters)
- visual.json (Visual-level projections, data roles, measures, columns, and visual filters)

Outputs a comprehensive field dependency catalog to CSV (report_visual_dependencies.csv).
"""

import os
import json
import sys
import csv
import argparse
from pathlib import Path
from typing import Dict, List, Any, Optional, Set, Tuple

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

BASE_DIR = Path(__file__).parent.resolve()
DEFAULT_SCAN_DIR = BASE_DIR.parent
DEFAULT_OUTPUT_CSV = BASE_DIR.parent / "report_visual_dependencies.csv"

# Aggregation function mapping (Fabric / Power BI AST Enum values)
AGG_FUNCTION_MAP = {
    0: "SUM",
    1: "AVG",
    2: "COUNT",
    3: "MIN",
    4: "MAX",
    5: "COUNT_DISTINCT",
    6: "MEDIAN",
    7: "VARIANCE",
    8: "STDEV"
}


# =============================================================================
# 1. RECURSIVE FIELD EXTRACTOR (COLUMNS, MEASURES, HIERARCHIES)
# =============================================================================

def extract_field_details(field_obj: Any) -> List[Dict[str, Any]]:
    """
    Recursively inspects a Power BI field node or filter node and extracts
    all referenced (table_name, field_name, field_type, aggregation).
    """
    results = []

    if not isinstance(field_obj, dict):
        return results

    # 1. Direct Column Reference: field.Column
    if "Column" in field_obj and isinstance(field_obj["Column"], dict):
        col_node = field_obj["Column"]
        prop = col_node.get("Property")
        expr = col_node.get("Expression", {})
        entity = None
        if "SourceRef" in expr:
            entity = expr["SourceRef"].get("Entity")
        elif "PropertyVariationSourceRef" in expr:
            entity = expr["PropertyVariationSourceRef"].get("Entity")

        if prop and entity:
            results.append({
                "field_type": "COLUMN",
                "table_name": entity,
                "field_name": prop,
                "aggregation": "NONE"
            })

    # 2. Direct Measure Reference: field.Measure
    elif "Measure" in field_obj and isinstance(field_obj["Measure"], dict):
        measure_node = field_obj["Measure"]
        prop = measure_node.get("Property")
        expr = measure_node.get("Expression", {})
        entity = expr.get("SourceRef", {}).get("Entity", "_measures")

        if prop:
            results.append({
                "field_type": "MEASURE",
                "table_name": entity or "_measures",
                "field_name": prop,
                "aggregation": "EXPLICIT_MEASURE"
            })

    # 3. Aggregation (Implicit Measure on a Column): field.Aggregation
    elif "Aggregation" in field_obj and isinstance(field_obj["Aggregation"], dict):
        agg_node = field_obj["Aggregation"]
        fn_code = agg_node.get("Function", 0)
        agg_name = AGG_FUNCTION_MAP.get(fn_code, f"FUNC_{fn_code}")
        inner_expr = agg_node.get("Expression", {})

        # Unwrap inner column if present
        if "Column" in inner_expr:
            inner_col = inner_expr["Column"]
            prop = inner_col.get("Property")
            entity = inner_col.get("Expression", {}).get("SourceRef", {}).get("Entity")
            if prop and entity:
                results.append({
                    "field_type": "AGGREGATION",
                    "table_name": entity,
                    "field_name": prop,
                    "aggregation": agg_name
                })

    # 4. Hierarchy Level: field.HierarchyLevel
    elif "HierarchyLevel" in field_obj and isinstance(field_obj["HierarchyLevel"], dict):
        hier_node = field_obj["HierarchyLevel"]
        level = hier_node.get("Level")
        hier_expr = hier_node.get("Expression", {}).get("Hierarchy", {})
        hier_name = hier_expr.get("Hierarchy")
        entity = hier_expr.get("Expression", {}).get("SourceRef", {}).get("Entity")

        if level and entity:
            results.append({
                "field_type": "HIERARCHY_LEVEL",
                "table_name": entity,
                "field_name": f"{hier_name}.{level}" if hier_name else level,
                "aggregation": "NONE"
            })

    # 5. Fallback Recursive Scan across all dictionary keys
    if not results:
        for k, v in field_obj.items():
            if isinstance(v, dict):
                results.extend(extract_field_details(v))
            elif isinstance(v, list):
                for item in v:
                    if isinstance(item, dict):
                        results.extend(extract_field_details(item))

    return results


# =============================================================================
# 2. REPORT, PAGE & VISUAL JSON PARSER
# =============================================================================

def parse_report_directory(report_dir: Path, project_name: str = "default_project") -> List[Dict[str, Any]]:
    """
    Parses an individual .Report folder hierarchy and extracts all visual & filter field references.
    """
    records: List[Dict[str, Any]] = []
    report_name = report_dir.name
    definition_dir = report_dir / "definition"

    if not definition_dir.exists():
        # Check if root is already the definition folder
        definition_dir = report_dir

    pages_dir = definition_dir / "pages"
    if not pages_dir.exists():
        return records

    # 1. Build Page Display Name Map from pages.json and individual page.json files
    page_name_map: Dict[str, Dict[str, Any]] = {}
    pages_meta_file = pages_dir / "pages.json"
    page_order_list = []

    if pages_meta_file.exists():
        try:
            p_data = json.loads(pages_meta_file.read_text(encoding="utf-8", errors="replace"))
            page_order_list = p_data.get("pageOrder", [])
        except Exception:
            pass

    for p_folder in pages_dir.iterdir():
        if p_folder.is_dir():
            p_json = p_folder / "page.json"
            page_id = p_folder.name
            display_name = page_id
            page_order = page_order_list.index(page_id) if page_id in page_order_list else 999

            if p_json.exists():
                try:
                    p_content = json.loads(p_json.read_text(encoding="utf-8", errors="replace"))
                    display_name = p_content.get("displayName", page_id)
                    # Page-level filters
                    p_filters = p_content.get("filterConfig", {}).get("filters", [])
                    for flt in p_filters:
                        f_fields = extract_field_details(flt.get("field", {}))
                        for f_info in f_fields:
                            records.append({
                                "project_name": project_name,
                                "report_folder": report_name,
                                "page_name": display_name,
                                "page_id": page_id,
                                "visual_id": "N/A (Page Filter)",
                                "visual_type": "PAGE_FILTER",
                                "data_role": "PageFilter",
                                "field_type": f_info["field_type"],
                                "table_name": f_info["table_name"],
                                "field_name": f_info["field_name"],
                                "aggregation": f_info["aggregation"],
                                "query_ref": f"{f_info['table_name']}.{f_info['field_name']}",
                                "usage_type": "PAGE_FILTER"
                            })
                except Exception:
                    pass

            page_name_map[page_id] = {
                "display_name": display_name,
                "order": page_order,
                "folder": p_folder
            }

    # 2. Iterate through visuals in each page
    for page_id, page_meta in page_name_map.items():
        page_folder = page_meta["folder"]
        display_name = page_meta["display_name"]
        visuals_dir = page_folder / "visuals"

        if not visuals_dir.exists():
            continue

        for v_folder in sorted(visuals_dir.iterdir()):
            if not v_folder.is_dir():
                continue

            v_json = v_folder / "visual.json"
            if not v_json.exists():
                continue

            try:
                v_data = json.loads(v_json.read_text(encoding="utf-8", errors="replace"))
            except Exception:
                continue

            visual_id = v_folder.name
            visual_obj = v_data.get("visual", {})
            visual_type = visual_obj.get("visualType", "unknown")

            # Extract Projections / Data Roles (Values, Category, Series, X, Y, Tooltips, etc.)
            query_state = visual_obj.get("query", {}).get("queryState", {})
            for role_name, role_data in query_state.items():
                if not isinstance(role_data, dict):
                    continue

                projections = role_data.get("projections", [])
                for proj in projections:
                    f_node = proj.get("field", {})
                    q_ref = proj.get("queryRef")
                    native_q_ref = proj.get("nativeQueryRef")

                    extracted_fields = extract_field_details(f_node)
                    for f_info in extracted_fields:
                        records.append({
                            "project_name": project_name,
                            "report_folder": report_name,
                            "page_name": display_name,
                            "page_id": page_id,
                            "visual_id": visual_id,
                            "visual_type": visual_type,
                            "data_role": role_name,
                            "field_type": f_info["field_type"],
                            "table_name": f_info["table_name"],
                            "field_name": f_info["field_name"],
                            "aggregation": f_info["aggregation"],
                            "query_ref": q_ref or f"{f_info['table_name']}.{f_info['field_name']}",
                            "usage_type": "VISUAL_PROJECTION"
                        })

            # Extract Visual-Level Filters
            v_filters = v_data.get("filterConfig", {}).get("filters", [])
            for flt in v_filters:
                flt_name = flt.get("name", "filter")
                f_fields = extract_field_details(flt.get("field", {}))
                for f_info in f_fields:
                    records.append({
                        "project_name": project_name,
                        "report_folder": report_name,
                        "page_name": display_name,
                        "page_id": page_id,
                        "visual_id": visual_id,
                        "visual_type": visual_type,
                        "data_role": "VisualFilter",
                        "field_type": f_info["field_type"],
                        "table_name": f_info["table_name"],
                        "field_name": f_info["field_name"],
                        "aggregation": f_info["aggregation"],
                        "query_ref": f"{f_info['table_name']}.{f_info['field_name']}",
                        "usage_type": "VISUAL_FILTER"
                    })

    # 3. Report-Level Filters (report.json)
    report_json_file = definition_dir / "report.json"
    if report_json_file.exists():
        try:
            r_data = json.loads(report_json_file.read_text(encoding="utf-8", errors="replace"))
            r_filters = r_data.get("filterConfig", {}).get("filters", []) or r_data.get("filters", [])
            for flt in r_filters:
                f_fields = extract_field_details(flt.get("field", {}))
                for f_info in f_fields:
                    records.append({
                        "project_name": project_name,
                        "report_folder": report_name,
                        "page_name": "N/A (All Pages)",
                        "page_id": "report_level",
                        "visual_id": "N/A (Report Filter)",
                        "visual_type": "REPORT_FILTER",
                        "data_role": "ReportFilter",
                        "field_type": f_info["field_type"],
                        "table_name": f_info["table_name"],
                        "field_name": f_info["field_name"],
                        "aggregation": f_info["aggregation"],
                        "query_ref": f"{f_info['table_name']}.{f_info['field_name']}",
                        "usage_type": "REPORT_FILTER"
                    })
        except Exception:
            pass

    return records


# =============================================================================
# 3. REPOSITORY SCANNER & PIPELINE
# =============================================================================

def get_project_name(file_path: Path, base_scan_dir: Path) -> Optional[str]:
    """Infers project name safely without swallowing unexpected exceptions."""
    try:
        rel = file_path.relative_to(base_scan_dir)
        if len(rel.parts) > 1:
            first_part = rel.parts[0]
            if not first_part.endswith(".Report") and not first_part.endswith(".pbip"):
                return first_part
    except ValueError:
        pass
    return None


def run_report_lineage_pipeline(scan_dir: Path, output_csv: Path) -> None:
    """
    Discovers all .Report directories across a workspace and generates the visual field lineage catalog.
    """
    scan_dir = Path(scan_dir).resolve()
    output_csv = Path(output_csv).resolve()

    if not scan_dir.exists():
        print(f"[ERROR] Directory not found: {scan_dir}")
        sys.exit(1)

    # Discover all .Report folders
    report_folders = sorted(list(scan_dir.glob("**/*.Report")))
    if not report_folders and scan_dir.name.endswith(".Report"):
        report_folders = [scan_dir]

    if not report_folders:
        print(f"No .Report folders found under: {scan_dir}")
        return

    print("==================================================================")
    print(f"  POWER BI REPORT VISUAL & FIELD LINEAGE EXTRACTOR")
    print("==================================================================")
    print(f"Scanning Workspace   : {scan_dir}")
    print(f"Discovered Reports   : {len(report_folders)} report folder(s)\n")

    all_records: List[Dict[str, Any]] = []

    for idx, r_path in enumerate(report_folders, start=1):
        proj = get_project_name(r_path, scan_dir) or r_path.stem.replace(".Report", "")
        recs = parse_report_directory(r_path, project_name=proj)
        all_records.extend(recs)

        unique_tables = set(r["table_name"] for r in recs)
        unique_fields = set(r["query_ref"] for r in recs)
        visual_count = len(set(r["visual_id"] for r in recs if not r["visual_id"].startswith("N/A")))

        print(f"[{idx}/{len(report_folders)}] 📊 Report: '{r_path.name}'")
        print(f"       ├── Visuals Tracked    : {visual_count} visual(s)")
        print(f"       ├── Unique Fields Used : {len(unique_fields)} fields across {len(unique_tables)} tables")
        print(f"       └── Total References   : {len(recs)} visual/filter mappings\n")

    # Export to CSV
    output_csv.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "project_name", "report_folder", "page_name", "page_id",
        "visual_id", "visual_type", "data_role", "field_type",
        "table_name", "field_name", "aggregation", "query_ref", "usage_type"
    ]

    with open(output_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(all_records)

    print("------------------------------------------------------------------")
    print(f"✅ Report Visual Lineage Catalog Generated Successfully!")
    print(f"   • Total Visual Field Usages Tracked : {len(all_records):,}")
    print(f"   • CSV Destination File              : {output_csv}")
    print("------------------------------------------------------------------")


def main():
    parser = argparse.ArgumentParser(description="Extract columns, measures, and field lineage from Power BI Report JSON definitions")
    parser.add_argument("--input-dir", "-d", type=str, help="Workspace root or .Report directory to scan")
    parser.add_argument("--output-csv", "-o", type=str, help="Destination CSV file path")

    args = parser.parse_args()

    scan_p = Path(args.input_dir) if args.input_dir else DEFAULT_SCAN_DIR
    out_csv = Path(args.output_csv) if args.output_csv else DEFAULT_OUTPUT_CSV

    run_report_lineage_pipeline(scan_p, out_csv)


if __name__ == "__main__":
    main()
