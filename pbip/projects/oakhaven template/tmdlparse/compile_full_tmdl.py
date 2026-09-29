#!/usr/bin/env python3
"""
compile_full_tmdl.py - Generic TMDL Recompiler & Monolithic Script Assembler

Parses existing PBIP .SemanticModel/definition/ folder structures and recompiles
them into a single, valid monolithic Full TMDL script (with optional createOrReplace wrapper).

Completely generic and dynamic:
1. Single project compilation (--input path/to/.SemanticModel or definition/ --output file.tmdl)
2. Batch 'for each' multi-project compilation (--input-dir path/to/pbip/projects/ --output-dir path/)
3. Intelligent object ordering (database -> model -> tables -> relationships -> expressions -> cultures)
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


def find_default_definition_dir():
    """Dynamically finds any .SemanticModel/definition folder in current or parent directory."""
    for p in [BASE_DIR, BASE_DIR.parent]:
        for sem in p.glob("*.SemanticModel"):
            def_dir = sem / "definition"
            if def_dir.exists():
                return def_dir
        if (p / "definition").exists():
            return p / "definition"
    return None


def resolve_output_full_tmdl_file(def_dir, custom_output=None):
    """Dynamically determines the output file path for a compiled Full TMDL."""
    if custom_output:
        out_p = Path(custom_output)
        if out_p.suffix.lower() in (".tmdl", ".txt"):
            return out_p
        # If a directory was provided
        proj_name = def_dir.parent.name.replace(".SemanticModel", "").strip() or def_dir.parent.parent.name
        return out_p / f"{proj_name}FullTMDL.tmdl"

    proj_dir = def_dir.parent.parent if def_dir.parent.name.endswith(".SemanticModel") else def_dir.parent
    proj_name = def_dir.parent.name.replace(".SemanticModel", "").strip() or proj_dir.name
    full_tmdl_dir = proj_dir / f"{proj_name}.FullTMDL"
    return full_tmdl_dir / f"{proj_name}FullTMDL.tmdl"


def indent_block(content_str, indent="\t"):
    """
    Indents non-empty lines with a leading tab for createOrReplace script compatibility.
    """
    lines = content_str.strip().splitlines()
    indented = []
    for l in lines:
        if l.strip():
            indented.append(f"{indent}{l}")
        else:
            indented.append("")
    return "\n".join(indented)


def get_table_order_from_model(model_path):
    """
    Extracts preferred table ordering from model.tmdl annotations or ref statements if present.
    """
    if not model_path.exists():
        return []
    content = model_path.read_text(encoding="utf-8", errors="replace")
    
    # 1. Check PBI_QueryOrder annotation
    order_match = re.search(r'annotation\s+PBI_QueryOrder\s*=\s*(\[[^\]]+\])', content)
    if order_match:
        try:
            import json
            return json.loads(order_match.group(1))
        except Exception:
            pass

    # 2. Check ref table statements
    ref_tables = re.findall(r'ref\s+table\s+([^\s\n]+)', content)
    if ref_tables:
        return [t.strip().strip("'").strip('"') for t in ref_tables]

    return []


def compile_semantic_model_to_full_tmdl(def_dir, wrap_create_or_replace=True):
    """
    Assembles definition/ folder files into a single monolithic TMDL script.
    """
    def_dir = Path(def_dir)
    if def_dir.name != "definition" and (def_dir / "definition").exists():
        def_dir = def_dir / "definition"

    if not def_dir.exists():
        print(f"[ERROR] Definition folder not found: {def_dir}")
        return None

    ordered_sections = []

    # 1. Database
    db_file = def_dir / "database.tmdl"
    if db_file.exists():
        db_content = db_file.read_text(encoding="utf-8", errors="replace").strip()
        if db_content:
            ordered_sections.append(("database", db_content))

    # 2. Model
    model_file = def_dir / "model.tmdl"
    table_order_hints = []
    if model_file.exists():
        model_content = model_file.read_text(encoding="utf-8", errors="replace").strip()
        if model_content:
            ordered_sections.append(("model", model_content))
            table_order_hints = get_table_order_from_model(model_file)

    # 3. Tables (Sorted by model query order hints, then alphabetically)
    tables_dir = def_dir / "tables"
    if tables_dir.exists():
        all_table_files = {f.stem: f for f in tables_dir.glob("*.tmdl")}
        sorted_table_names = []

        # Add tables that appear in hints first
        for name in table_order_hints:
            if name in all_table_files and name not in sorted_table_names:
                sorted_table_names.append(name)

        # Add remaining tables alphabetically (placing _measures last if not already added)
        remaining = sorted([n for n in all_table_files if n not in sorted_table_names and n != "_measures"])
        sorted_table_names.extend(remaining)
        if "_measures" in all_table_files and "_measures" not in sorted_table_names:
            sorted_table_names.append("_measures")

        for tbl_name in sorted_table_names:
            t_file = all_table_files[tbl_name]
            t_content = t_file.read_text(encoding="utf-8", errors="replace").strip()
            if t_content:
                ordered_sections.append((f"table: {tbl_name}", t_content))

    # 4. Relationships
    rel_file = def_dir / "relationships.tmdl"
    if rel_file.exists():
        rel_content = rel_file.read_text(encoding="utf-8", errors="replace").strip()
        if rel_content:
            ordered_sections.append(("relationships", rel_content))

    # 5. Expressions / Parameters
    expr_file = def_dir / "expressions.tmdl"
    if expr_file.exists():
        expr_content = expr_file.read_text(encoding="utf-8", errors="replace").strip()
        if expr_content:
            ordered_sections.append(("expressions", expr_content))

    # 6. Cultures
    cultures_dir = def_dir / "cultures"
    if cultures_dir.exists():
        for c_file in sorted(cultures_dir.glob("*.tmdl")):
            c_content = c_file.read_text(encoding="utf-8", errors="replace").strip()
            if c_content:
                ordered_sections.append((f"culture: {c_file.stem}", c_content))

    if not ordered_sections:
        print(f"[WARNING] No TMDL content found in: {def_dir}")
        return None

    # Assemble full document
    doc_lines = []
    if wrap_create_or_replace:
        doc_lines.append("createOrReplace\n")
        for sec_name, sec_body in ordered_sections:
            doc_lines.append(indent_block(sec_body, indent="\t"))
            doc_lines.append("")
    else:
        for sec_name, sec_body in ordered_sections:
            doc_lines.append(sec_body)
            doc_lines.append("")

    full_tmdl = "\n".join(doc_lines).rstrip() + "\n"
    return full_tmdl, ordered_sections


def process_batch_compilation(scan_root, output_dir, wrap_create_or_replace=True):
    """
    Recursively scans a directory for all .SemanticModel folders and compiles a full TMDL for each.
    """
    scan_root = Path(scan_root).resolve()
    output_dir = Path(output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    # Find all definition folders
    def_folders = sorted(list(scan_root.rglob("definition")))
    def_folders = [d for d in def_folders if (d / "tables").exists() or (d / "model.tmdl").exists()]

    if not def_folders:
        print(f"No valid PBIP definition folders found under: {scan_root}")
        return

    print("==================================================================")
    print(f"  BATCH TMDL COMPILER: Found {len(def_folders)} Semantic Model(s)")
    print("==================================================================")
    print(f"Scan Directory   : {scan_root}")
    print(f"Output Directory : {output_dir}\n")

    compiled_count = 0

    for idx, d_path in enumerate(def_folders, start=1):
        parent_model_dir = d_path.parent
        proj_name = parent_model_dir.name.replace(".SemanticModel", "").strip() or parent_model_dir.parent.name
        
        result = compile_semantic_model_to_full_tmdl(d_path, wrap_create_or_replace=wrap_create_or_replace)
        if result:
            full_text, sections = result
            out_file = output_dir / f"{proj_name}.FullTMDL.tmdl"
            out_file.write_text(full_text, encoding="utf-8")
            compiled_count += 1
            print(f"[{idx}/{len(def_folders)}] 📦 Compiled '{proj_name}' -> {out_file.name} ({len(sections)} sections, {len(full_text.splitlines()):,} lines)")

    print("\n------------------------------------------------------------------")
    print(f"✅ Batch Compilation Complete! Compiled {compiled_count} Full TMDL script(s).")
    print(f"   Destination: {output_dir}")
    print("------------------------------------------------------------------")


def main():
    parser = argparse.ArgumentParser(description="Recompile PBIP .SemanticModel definition/ folders into monolithic Full TMDL scripts")
    parser.add_argument("--input", "-i", type=str, help="Path to a single .SemanticModel or definition/ directory")
    parser.add_argument("--input-dir", "-d", type=str, help="Path to parent folder containing multiple PBIP projects for batch compilation")
    parser.add_argument("--output", "-o", type=str, help="Path to target output file or output directory")
    parser.add_argument("--no-wrap", action="store_true", help="Do not wrap in 'createOrReplace' header with indented blocks")

    args = parser.parse_args()
    wrap = not args.no_wrap

    # 1. Batch directory mode
    if args.input_dir:
        out_root = Path(args.output) if args.output else BASE_DIR / "compiled_full_tmdls"
        process_batch_compilation(args.input_dir, out_root, wrap_create_or_replace=wrap)
        return

    # 2. Single model mode
    if args.input:
        src = Path(args.input)
        result = compile_semantic_model_to_full_tmdl(src, wrap_create_or_replace=wrap)
        if result:
            full_text, sections = result
            out_path = resolve_output_full_tmdl_file(src if src.name == "definition" else (src / "definition"), custom_output=args.output)
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_text(full_text, encoding="utf-8")
            print(f"✅ Compiled {len(sections)} sections into: {out_path} ({len(full_text.splitlines()):,} lines)")
        return

    # 3. Dynamic auto mode
    default_def = find_default_definition_dir()
    if default_def:
        proj_dir_name = default_def.parent.name.replace(".SemanticModel", "").strip() or default_def.parent.parent.name
        print("==================================================================")
        print(f"  TMDL RECOMPILER: Compiling '{proj_dir_name}'")
        print("==================================================================")
        result = compile_semantic_model_to_full_tmdl(default_def, wrap_create_or_replace=wrap)
        if result:
            full_text, sections = result
            out_file = resolve_output_full_tmdl_file(default_def, custom_output=args.output)
            out_file.parent.mkdir(parents=True, exist_ok=True)
            out_file.write_text(full_text, encoding="utf-8")
            print(f"✅ Successfully compiled {len(sections)} sections into:")
            print(f"   -> {out_file}")
            print(f"   -> Total Lines: {len(full_text.splitlines()):,}")
            print("------------------------------------------------------------------")
    else:
        print("[ERROR] No definition folder found. Use --input <path> or --input-dir <path>")


if __name__ == "__main__":
    main()
