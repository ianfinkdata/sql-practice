#!/usr/bin/env python3
"""
split_full_tmdl.py - Generic TMDL Full Script Splitter into PBIP Semantic Model Folder Structure

Parses any monolithic Full TMDL script (flat or nested under 'model') and splits it into
the standard Power BI / Fabric .SemanticModel/definition/ folder layout:
- definition/database.tmdl
- definition/model.tmdl (with ref table / ref cultureInfo links)
- definition/tables/*.tmdl
- definition/relationships.tmdl
- definition/expressions.tmdl
- definition/cultures/*.tmdl

Supports:
1. Single file splitting (--input file.tmdl --output path/to/definition)
2. Batch 'for each' directory looping (--input-dir folder/ --output path/to/models/)
3. Dynamic auto-discovery of full TMDL files and target .SemanticModel folders
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


def clean_identifier(raw_name):
    """Cleans quotes and whitespace from TMDL identifiers."""
    name = raw_name.strip()
    if (name.startswith("'") and name.endswith("'")) or (name.startswith('"') and name.endswith('"')):
        name = name[1:-1]
    return name.strip()


def find_default_source_file():
    """Dynamically finds any Full TMDL file in current or parent directories."""
    search_dirs = [BASE_DIR, BASE_DIR.parent]
    for d in search_dirs:
        for full_dir in d.glob("*.FullTMDL"):
            if full_dir.is_dir():
                for f in full_dir.glob("*.*"):
                    if f.is_file() and f.suffix.lower() in (".tmdl", ".txt") and f.stat().st_size > 0:
                        return f
        for f in d.glob("*.*"):
            if f.is_file() and f.suffix.lower() in (".tmdl", ".txt") and f.stat().st_size > 0 and "full" in f.name.lower():
                return f
    return None


def resolve_output_definition_dir(source_file, custom_output=None):
    """Dynamically determines the output definition/ path for a given TMDL file."""
    if custom_output:
        out_p = Path(custom_output)
        return out_p if out_p.name == "definition" else (out_p / "definition")

    if source_file:
        source_path = Path(source_file)
        model_name = source_path.stem.replace("FullTMDL", "").replace("fulltmdl", "").strip() or source_path.stem
        for p in [source_path.parent, source_path.parent.parent]:
            sem_models = list(p.glob("*.SemanticModel"))
            if sem_models:
                return sem_models[0] / "definition"
        return source_path.parent.parent / f"{model_name}.SemanticModel" / "definition"

    return BASE_DIR / "definition"


def count_leading_tabs(line):
    """Counts leading tabs or converts 4 leading spaces to 1 tab level."""
    if not line:
        return 0
    match = re.match(r"^(\t+| +)", line)
    if not match:
        return 0
    ws = match.group(1)
    if "\t" in ws:
        return len(ws)
    return len(ws) // 4


def dedent_lines(lines, indent_level):
    """Removes `indent_level` leading tabs from a list of lines."""
    result = []
    for l in lines:
        if not l.strip():
            result.append("")
            continue
        # Strip tabs
        tabs_to_remove = indent_level
        cur_l = l
        while tabs_to_remove > 0 and cur_l.startswith("\t"):
            cur_l = cur_l[1:]
            tabs_to_remove -= 1
        # Also handle leading 4-space blocks
        while tabs_to_remove > 0 and cur_l.startswith("    "):
            cur_l = cur_l[4:]
            tabs_to_remove -= 1
        result.append(cur_l)
    return result


def parse_and_split_tmdl(source_path, output_base_dir):
    """
    Parses a monolithic TMDL file (flat or nested) and splits it into definition/ subfolders.
    """
    source_path = Path(source_path)
    output_base_dir = Path(output_base_dir)

    if not source_path.exists():
        print(f"  ❌ [ERROR] File not found: {source_path}")
        return []

    text = source_path.read_text(encoding="utf-8", errors="replace")
    raw_lines = text.splitlines()

    if not text.strip():
        print(f"  ⚠️ [SKIPPED] File is empty (0 bytes): {source_path.name}")
        return []

    # Strip createOrReplace header
    start_idx = 0
    for i, line in enumerate(raw_lines):
        if line.strip().lower() == "createorreplace":
            start_idx = i + 1
            break
        elif line.strip():
            break

    content_lines = raw_lines[start_idx:]
    if not content_lines:
        return []

    # Identify object boundaries by parsing declaration keywords
    # Keywords: database, model, table, relationship, expression, cultureInfo, culture
    DECLARATION_KEYWORDS = ("database", "model", "table", "relationship", "expression", "cultureinfo", "culture")

    sections = []
    current_section = None
    model_header_lines = []
    discovered_tables = []
    discovered_cultures = []

    for line_idx, line in enumerate(content_lines):
        stripped = line.strip()
        if not stripped:
            if current_section:
                current_section["lines"].append(line)
            elif model_header_lines:
                model_header_lines.append(line)
            continue

        # Check if line starts an object declaration
        first_token = stripped.split()[0].lower() if stripped.split() else ""
        if first_token in DECLARATION_KEYWORDS:
            indent = count_leading_tabs(line)
            kw = first_token
            raw_target = stripped.split(maxsplit=1)[1] if len(stripped.split()) > 1 else ""

            # If inside model, lines before child objects belong to model header
            if kw == "model":
                current_section = {
                    "type": "model",
                    "raw_name": raw_target,
                    "indent": indent,
                    "lines": [line]
                }
                sections.append(current_section)
                continue

            # Child object (table, relationship, expression, culture, database)
            if current_section and current_section["type"] == "model" and indent > current_section["indent"]:
                # Save model header lines
                model_header_lines = list(current_section["lines"])

            new_sec = {
                "type": kw,
                "raw_name": raw_target,
                "indent": indent,
                "lines": [line]
            }
            if kw == "table":
                discovered_tables.append(clean_identifier(raw_target.split()[0]))
            elif kw in ("cultureinfo", "culture"):
                discovered_cultures.append(clean_identifier(raw_target.split()[0]))

            sections.append(new_sec)
            current_section = new_sec
            continue

        if current_section:
            current_section["lines"].append(line)

    # Prepare output directories
    tables_dir = output_base_dir / "tables"
    cultures_dir = output_base_dir / "cultures"
    tables_dir.mkdir(parents=True, exist_ok=True)
    cultures_dir.mkdir(parents=True, exist_ok=True)

    written_files = []
    accumulated_relationships = []
    accumulated_expressions = []

    for sec in sections:
        s_type = sec["type"]
        raw_name = sec["raw_name"]
        clean_name = clean_identifier(raw_name.split()[0] if raw_name else "")
        indent = sec["indent"]
        cleaned_lines = dedent_lines(sec["lines"], indent)
        content = "\n".join(cleaned_lines).strip() + "\n"

        if s_type == "table":
            target_file = tables_dir / f"{clean_name}.tmdl"
            target_file.write_text(content, encoding="utf-8")
            written_files.append((f"table: {clean_name}", target_file))

        elif s_type == "database":
            target_file = output_base_dir / "database.tmdl"
            target_file.write_text(content, encoding="utf-8")
            written_files.append(("database", target_file))

        elif s_type == "model":
            # Clean model content to retain only model-level properties
            model_lines = []
            for l in cleaned_lines:
                # Stop if child declaration starts
                s_l = l.strip().split()[0].lower() if l.strip().split() else ""
                if s_l in ("table", "relationship", "expression", "cultureinfo", "culture"):
                    break
                model_lines.append(l)

            # Ensure ref table and ref cultureInfo are present
            model_text = "\n".join(model_lines).strip()
            for t_name in discovered_tables:
                ref_stmt = f"ref table {t_name}"
                if ref_stmt not in model_text:
                    model_text += f"\n\n{ref_stmt}"
            for c_name in discovered_cultures:
                ref_stmt = f"ref cultureInfo {c_name}"
                if ref_stmt not in model_text and f"ref culture {c_name}" not in model_text:
                    model_text += f"\n\n{ref_stmt}"

            target_file = output_base_dir / "model.tmdl"
            target_file.write_text(model_text.strip() + "\n", encoding="utf-8")
            written_files.append(("model", target_file))

        elif s_type in ("culture", "cultureinfo"):
            target_file = cultures_dir / f"{clean_name}.tmdl"
            target_file.write_text(content, encoding="utf-8")
            written_files.append((f"culture: {clean_name}", target_file))

        elif s_type == "relationship":
            accumulated_relationships.append(content)

        elif s_type == "expression":
            accumulated_expressions.append(content)

    if accumulated_relationships:
        target_file = output_base_dir / "relationships.tmdl"
        target_file.write_text("\n".join(accumulated_relationships), encoding="utf-8")
        written_files.append(("relationships", target_file))

    if accumulated_expressions:
        target_file = output_base_dir / "expressions.tmdl"
        target_file.write_text("\n".join(accumulated_expressions), encoding="utf-8")
        written_files.append(("expressions", target_file))

    return written_files


def process_batch(source_dir, output_root=None):
    """
    Loops through all .tmdl and .txt files in a directory and splits each one generically.
    """
    source_dir = Path(source_dir).resolve()
    if not source_dir.exists():
        print(f"[ERROR] Source directory does not exist: {source_dir}")
        return

    candidates = sorted([
        f for f in source_dir.glob("**/*")
        if f.is_file() and f.suffix.lower() in (".tmdl", ".txt") and f.stat().st_size > 0
    ])

    if not candidates:
        print(f"No non-empty .tmdl or .txt files found in: {source_dir}")
        return

    print("==================================================================")
    print(f"  BATCH TMDL SPLITTER: Discovered {len(candidates)} File(s) to Process")
    print("==================================================================")
    print(f"Source Directory : {source_dir}")
    print(f"Output Base      : {output_root or 'Auto-mapped per model'}\n")

    total_objects_created = 0

    for idx, f_path in enumerate(candidates, start=1):
        clean_model_name = f_path.stem.replace("FullTMDL", "").replace("fulltmdl", "").strip() or f_path.stem
        if output_root:
            out_dir = Path(output_root) / f"{clean_model_name}.SemanticModel" / "definition"
        else:
            out_dir = resolve_output_definition_dir(f_path)

        print(f"[{idx}/{len(candidates)}] Processing: '{f_path.name}'")
        print(f"       └── Target: {out_dir}")
        
        written = parse_and_split_tmdl(f_path, out_dir)
        total_objects_created += len(written)
        print(f"       └── Created {len(written)} definition file(s)\n")

    print("------------------------------------------------------------------")
    print(f"✅ Batch Processing Complete! Total Definition Files Created: {total_objects_created}")
    print("------------------------------------------------------------------")


def main():
    parser = argparse.ArgumentParser(description="Split monolithic Full TMDL files into PBIP Semantic Model folders")
    parser.add_argument("--input", "-i", type=str, help="Path to a single .tmdl or .txt full script file")
    parser.add_argument("--input-dir", "-d", type=str, help="Path to folder containing multiple full TMDL files for batch 'for each' processing")
    parser.add_argument("--output", "-o", type=str, help="Destination definition/ folder (or root output directory for batch)")

    args = parser.parse_args()

    # 1. Batch directory mode
    if args.input_dir:
        process_batch(args.input_dir, output_root=args.output)
        return

    # 2. Single file mode
    if args.input:
        src = Path(args.input)
        out_dir = resolve_output_definition_dir(src, custom_output=args.output)
        print(f"Processing single file: {src}")
        written = parse_and_split_tmdl(src, out_dir)
        print(f"✅ Split {len(written)} object(s) into {out_dir}")
        return

    # 3. Dynamic auto-mode
    default_src = find_default_source_file()
    if default_src:
        out_dir = resolve_output_definition_dir(default_src, custom_output=args.output)
        print("==================================================================")
        print(f"  TMDL SPLITTER (Auto-detected: {default_src.name})")
        print("==================================================================")
        written = parse_and_split_tmdl(default_src, out_dir)
        print(f"\n✅ Created {len(written)} definition file(s) in: {out_dir}")
    else:
        print("[ERROR] No input file specified and no default full TMDL script found.")
        print("Usage: python split_full_tmdl.py --input <path_to_file> OR --input-dir <path_to_folder>")


if __name__ == "__main__":
    main()
