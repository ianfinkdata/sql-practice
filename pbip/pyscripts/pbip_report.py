#!/usr/bin/env python3
"""
pbip_report.py - Unified Power BI Project (.pbip) Report AST Parser, Impact Analyzer & Template Scaffolder

Inspects .Report JSON definitions (PBIR format), audits downstream visual impact of semantic model changes,
lists modular visual/page templates, and injects validated PBIR templates into target reports.
"""

import os
import sys
import json
import secrets
import argparse
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent.resolve()
PROJECTS_DIR = REPO_ROOT / "pbip" / "projects"
TEMPLATES_DIR = REPO_ROOT / "pbip" / "templates" / "reports"


def find_all_reports(base_dir=PROJECTS_DIR):
    """Discovers all .Report directories under the target base directory."""
    if not base_dir.exists():
        return []
    return sorted(list(base_dir.rglob("*.Report")))


def parse_visual_references(visual_data):
    """Extracts entity, property, and measure references from a visual.json dictionary."""
    references = []
    
    # 1. Inspect query projections
    query_state = visual_data.get("visual", {}).get("query", {}).get("queryState", {})
    for clause_name, clause_data in query_state.items():
        if not isinstance(clause_data, dict):
            continue
        projections = clause_data.get("projections", [])
        for proj in projections:
            field = proj.get("field", {})
            # Column reference
            col_info = field.get("Column", {})
            if col_info:
                entity = col_info.get("Expression", {}).get("SourceRef", {}).get("Entity", "")
                prop = col_info.get("Property", "")
                if entity or prop:
                    references.append({
                        "type": "Column",
                        "entity": entity,
                        "property": prop,
                        "queryRef": proj.get("queryRef", f"{entity}.{prop}"),
                        "clause": clause_name
                    })
            # Measure reference
            measure_info = field.get("Measure", {})
            if measure_info:
                entity = measure_info.get("Expression", {}).get("SourceRef", {}).get("Entity", "")
                prop = measure_info.get("Property", "")
                if entity or prop:
                    references.append({
                        "type": "Measure",
                        "entity": entity,
                        "property": prop,
                        "queryRef": proj.get("queryRef", f"{entity}.{prop}"),
                        "clause": clause_name
                    })
            # Aggregation reference
            agg_info = field.get("Aggregation", {})
            if agg_info:
                expr_col = agg_info.get("Expression", {}).get("Column", {})
                entity = expr_col.get("Expression", {}).get("SourceRef", {}).get("Entity", "")
                prop = expr_col.get("Property", "")
                func = agg_info.get("Function", 0)
                func_name = "Sum" if func == 0 else f"Agg_{func}"
                if entity or prop:
                    references.append({
                        "type": f"Aggregation({func_name})",
                        "entity": entity,
                        "property": prop,
                        "queryRef": proj.get("queryRef", f"{func_name}({entity}.{prop})"),
                        "clause": clause_name
                    })

    # 2. Inspect visual filters
    filters = visual_data.get("filterConfig", {}).get("filters", [])
    for f in filters:
        field = f.get("field", {})
        col_info = field.get("Column", {})
        if col_info:
            entity = col_info.get("Expression", {}).get("SourceRef", {}).get("Entity", "")
            prop = col_info.get("Property", "")
            if entity or prop:
                references.append({
                    "type": "Filter",
                    "entity": entity,
                    "property": prop,
                    "queryRef": f"{entity}.{prop}",
                    "clause": "filterConfig"
                })

    return references


def inspect_report(report_path):
    """Parses and prints a detailed structure of a single .Report folder."""
    report_dir = Path(report_path)
    if not report_dir.exists():
        print(f"[ERROR] Report directory not found: {report_dir}")
        return

    definition_dir = report_dir / "definition"
    report_json_path = definition_dir / "report.json"
    pages_json_path = definition_dir / "pages" / "pages.json"

    print("==================================================================")
    print(f"  PBIP REPORT INSPECTOR: {report_dir.name}")
    print("==================================================================")
    print(f"Directory: {report_dir}")

    if report_json_path.exists():
        try:
            r_data = json.loads(report_json_path.read_text(encoding="utf-8"))
            theme = r_data.get("themeCollection", {}).get("customTheme", {}).get("name", "Default")
            base_theme = r_data.get("themeCollection", {}).get("baseTheme", {}).get("name", "Default")
            print(f"Theme    : Base='{base_theme}', Custom='{theme}'")
        except Exception as e:
            print(f"Theme    : [Error reading theme: {e}]")

    if not pages_json_path.exists():
        print("[WARNING] No definition/pages/pages.json found.")
        return

    pages_data = json.loads(pages_json_path.read_text(encoding="utf-8"))
    page_order = pages_data.get("pageOrder", [])
    print(f"Pages    : {len(page_order)} registered page(s)\n")

    pages_dir = definition_dir / "pages"
    for idx, page_id in enumerate(page_order, start=1):
        page_dir = pages_dir / page_id
        page_json_file = page_dir / "page.json"
        display_name = page_id
        dimensions = "1920x1080"
        if page_json_file.exists():
            p_data = json.loads(page_json_file.read_text(encoding="utf-8"))
            display_name = p_data.get("displayName", page_id)
            dimensions = f"{p_data.get('width', 1920)}x{p_data.get('height', 1080)}"

        visuals_dir = page_dir / "visuals"
        visual_files = list(visuals_dir.glob("*/visual.json")) if visuals_dir.exists() else []

        print(f"┌─ [{idx}] Page: '{display_name}' (ID: {page_id}, Canvas: {dimensions})")
        print(f"│  └── Visual Containers: {len(visual_files)}")

        for v_file in visual_files:
            try:
                v_data = json.loads(v_file.read_text(encoding="utf-8"))
                v_name = v_data.get("name", v_file.parent.name)
                v_type = v_data.get("visual", {}).get("visualType", "unknown")
                pos = v_data.get("position", {})
                pos_str = f"x={int(pos.get('x',0))}, y={int(pos.get('y',0))}, w={int(pos.get('width',0))}, h={int(pos.get('height',0))}"
                refs = parse_visual_references(v_data)
                ref_summary = ", ".join([f"{r['entity']}.{r['property']}" for r in refs]) if refs else "none"

                print(f"│     • [{v_type}] ID: {v_name[:12]}... ({pos_str})")
                print(f"│       └── Bindings: {ref_summary}")
            except Exception as ex:
                print(f"│     • Visual parse error ({v_file.name}): {ex}")
        print("└" + "─" * 60)


def analyze_impact(target_query):
    """
    Finds all visual containers across all PBIP reports referencing a given table,
    column, or measure (e.g. 'dim_customer.state', 'dim_calendar', 'net_amount').
    """
    print("==================================================================")
    print(f"  DOWNSTREAM REPORT IMPACT ANALYZER: Target '{target_query}'")
    print("==================================================================")
    
    target_clean = target_query.strip().lower()
    target_parts = target_clean.split(".")
    
    reports = find_all_reports(PROJECTS_DIR)
    if not reports:
        print(f"[ERROR] No .Report projects found under {PROJECTS_DIR}")
        return

    matches = []
    
    for report_dir in reports:
        report_name = report_dir.name
        pages_json_file = report_dir / "definition" / "pages" / "pages.json"
        if not pages_json_file.exists():
            continue
        
        pages_data = json.loads(pages_json_file.read_text(encoding="utf-8"))
        page_order = pages_data.get("pageOrder", [])
        
        for page_id in page_order:
            page_dir = report_dir / "definition" / "pages" / page_id
            page_json_file = page_dir / "page.json"
            page_title = page_id
            if page_json_file.exists():
                try:
                    p_meta = json.loads(page_json_file.read_text(encoding="utf-8"))
                    page_title = p_meta.get("displayName", page_id)
                except Exception:
                    pass
            
            visuals_dir = page_dir / "visuals"
            if not visuals_dir.exists():
                continue
            
            for v_file in visuals_dir.glob("*/visual.json"):
                try:
                    v_data = json.loads(v_file.read_text(encoding="utf-8"))
                    v_name = v_data.get("name", v_file.parent.name)
                    v_type = v_data.get("visual", {}).get("visualType", "unknown")
                    refs = parse_visual_references(v_data)
                    
                    for r in refs:
                        entity_match = (len(target_parts) == 1 and target_parts[0] in (r["entity"].lower(), r["property"].lower())) or \
                                       (len(target_parts) == 2 and target_parts[0] == r["entity"].lower() and target_parts[1] == r["property"].lower())
                        
                        if entity_match or target_clean in r["queryRef"].lower():
                            matches.append({
                                "report": report_name,
                                "page": page_title,
                                "page_id": page_id,
                                "visual_id": v_name,
                                "visual_type": v_type,
                                "ref_type": r["type"],
                                "binding": f"{r['entity']}.{r['property']}",
                                "clause": r["clause"]
                            })
                except Exception:
                    continue

    if not matches:
        print(f"✅ No downstream report visuals reference '{target_query}'. Safe to modify or drop.\n")
        return

    print(f"⚠️  Found {len(matches)} downstream visual reference(s) impacted:\n")
    print(f"{'Report Name':<28} | {'Page':<22} | {'Visual Type':<18} | {'Binding':<26} | {'Clause':<12}")
    print("-" * 115)
    for m in matches:
        print(f"{m['report']:<28} | {m['page'][:20]:<22} | {m['visual_type']:<18} | {m['binding']:<26} | {m['clause']:<12}")
    print("-" * 115)
    print(f"\n💡 Summary: Modifying '{target_query}' affects {len(set(m['report'] for m in matches))} report(s) and {len(matches)} visual container(s).\n")


def list_templates():
    """Lists available modular visual and page templates in pbip/templates/reports/."""
    print("==================================================================")
    print("  PBIP MODULAR REPORT TEMPLATE LIBRARY")
    print("==================================================================")
    print(f"Location: {TEMPLATES_DIR}\n")

    if not TEMPLATES_DIR.exists():
        print(f"[ERROR] Templates directory not found: {TEMPLATES_DIR}")
        return

    templates = [d for d in TEMPLATES_DIR.iterdir() if d.is_dir()]
    if not templates:
        print("No templates found.")
        return

    for t_dir in sorted(templates):
        page_json = t_dir / "page.json"
        display_name = t_dir.name
        if page_json.exists():
            try:
                p_data = json.loads(page_json.read_text(encoding="utf-8"))
                display_name = p_data.get("displayName", t_dir.name)
            except Exception:
                pass
        
        visual_files = list((t_dir / "visuals").glob("*.json")) if (t_dir / "visuals").exists() else []
        has_readme = (t_dir / "README.md").exists()
        
        print(f"📦 Template: '{t_dir.name}'")
        print(f"   • Display Name : {display_name}")
        print(f"   • Visual Count : {len(visual_files)} pre-configured visual container(s)")
        for vf in sorted(visual_files):
            print(f"     ├── {vf.name}")
        if has_readme:
            print(f"   • Docs Guide   : README.md (Includes Azure Maps & Footprint Guide)")
        print()


def add_template_page(report_path, template_name, custom_name=None, dry_run=False):
    """
    Injects a modular page template into a target PBIP report definition,
    generating unique hex GUIDs for page and visuals and updating pages.json.
    """
    report_dir = Path(report_path)
    if not report_dir.exists():
        print(f"[ERROR] Target report directory does not exist: {report_dir}")
        return False

    template_dir = TEMPLATES_DIR / template_name
    if not template_dir.exists() or not (template_dir / "page.json").exists():
        print(f"[ERROR] Template '{template_name}' not found at {template_dir}")
        return False

    print("==================================================================")
    print(f"  SCAFFOLDING TEMPLATE PAGE: '{template_name}' ➔ '{report_dir.name}'")
    print("==================================================================")
    print(f"Dry Run: {'ENABLED (No files will be modified)' if dry_run else 'DISABLED'}\n")

    # 1. Generate unique 20-character hex IDs
    new_page_id = secrets.token_hex(10)
    target_pages_dir = report_dir / "definition" / "pages"
    target_page_dir = target_pages_dir / new_page_id
    target_visuals_dir = target_page_dir / "visuals"

    # 2. Read template page.json
    page_content = (template_dir / "page.json").read_text(encoding="utf-8")
    page_content = page_content.replace("{{PAGE_ID}}", new_page_id)
    page_obj = json.loads(page_content)
    if custom_name:
        page_obj["displayName"] = custom_name

    # 3. Read template visuals
    template_visuals = sorted(list((template_dir / "visuals").glob("*.json")))
    processed_visuals = []

    for idx, v_path in enumerate(template_visuals, start=1):
        v_id = secrets.token_hex(10)
        v_raw = v_path.read_text(encoding="utf-8")
        # Replace placeholder IDs
        for i in range(1, 10):
            v_raw = v_raw.replace(f"{{{{VISUAL_ID_{i}}}}}", v_id)
        v_obj = json.loads(v_raw)
        v_obj["name"] = v_id
        processed_visuals.append((v_id, v_obj, v_path.name))

    print(f"• Generated New Page ID : {new_page_id}")
    print(f"• Display Name          : {page_obj.get('displayName')}")
    print(f"• Visual Containers ({len(processed_visuals)}):")
    for v_id, v_obj, v_fname in processed_visuals:
        print(f"  └── [{v_obj.get('visual', {}).get('visualType')}] {v_fname} ➔ ID: {v_id}")

    if dry_run:
        print("\n✅ Dry run completed successfully. No changes written to disk.")
        return True

    # Write files to disk
    target_visuals_dir.mkdir(parents=True, exist_ok=True)
    (target_page_dir / "page.json").write_text(json.dumps(page_obj, indent=2), encoding="utf-8")

    for v_id, v_obj, _ in processed_visuals:
        v_dir = target_visuals_dir / v_id
        v_dir.mkdir(parents=True, exist_ok=True)
        (v_dir / "visual.json").write_text(json.dumps(v_obj, indent=2), encoding="utf-8")

    # Update pages.json
    pages_json_path = target_pages_dir / "pages.json"
    if pages_json_path.exists():
        pages_meta = json.loads(pages_json_path.read_text(encoding="utf-8"))
    else:
        pages_meta = {
            "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json",
            "pageOrder": [],
            "activePageName": new_page_id
        }

    if new_page_id not in pages_meta.get("pageOrder", []):
        pages_meta.setdefault("pageOrder", []).append(new_page_id)

    pages_json_path.write_text(json.dumps(pages_meta, indent=2), encoding="utf-8")
    print(f"\n✅ Injected page into {report_dir.name}/definition/pages/{new_page_id}")
    return True


def main():
    parser = argparse.ArgumentParser(description="PBIP Report AST Parser, Impact Analyzer & Template Tool")
    subparsers = parser.add_subparsers(dest="command", help="Subcommand to execute")

    # inspect
    inspect_parser = subparsers.add_parser("inspect", help="Inspect a .Report definition tree")
    inspect_parser.add_argument("path", help="Path to .Report folder")

    # impact
    impact_parser = subparsers.add_parser("impact", help="Audit downstream report visuals for a table/column/measure")
    impact_parser.add_argument("query", help="Entity.Property or keyword to search (e.g. dim_customer.state, net_amount)")

    # list-templates
    subparsers.add_parser("list-templates", help="List all pre-built modular report templates")

    # add-page
    add_parser = subparsers.add_parser("add-page", help="Scaffold/inject a template page into a target report")
    add_parser.add_argument("--report", required=True, help="Path to target .Report folder")
    add_parser.add_argument("--template", required=True, help="Template name (time_series, comparative_analysis, kpi_percentage_change, demographic_analysis)")
    add_parser.add_argument("--name", help="Custom display name for the new page")
    add_parser.add_argument("--dry-run", action="store_true", help="Simulate scaffolding without modifying files")

    args = parser.parse_args()

    if args.command == "inspect":
        inspect_report(args.path)
    elif args.command == "impact":
        analyze_impact(args.query)
    elif args.command == "list-templates":
        list_templates()
    elif args.command == "add-page":
        add_template_page(args.report, args.template, custom_name=args.name, dry_run=args.dry_run)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
