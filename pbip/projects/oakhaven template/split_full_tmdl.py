#!/usr/bin/env python3
"""
split_full_tmdl.py - Generic Batch TMDL Full Script Splitter into PBIP Semantic Model Folder Structure

Completely generic and dynamic:
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
        # Check *.FullTMDL subfolders
        for full_dir in d.glob("*.FullTMDL"):
            if full_dir.is_dir():
                for f in full_dir.glob("*.*"):
                    if f.is_file() and f.suffix.lower() in (".tmdl", ".txt") and f.stat().st_size > 0:
                        return f
        # Check files directly in directory
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
        # Check if sibling *.SemanticModel exists
        for p in [source_path.parent, source_path.parent.parent]:
            sem_models = list(p.glob("*.SemanticModel"))
            if sem_models:
                return sem_models[0] / "definition"
        return source_path.parent.parent / f"{model_name}.SemanticModel" / "definition"

    return BASE_DIR / "definition"


def parse_and_split_tmdl(source_path, output_base_dir):
    """
    Parses a single monolithic TMDL file and splits it into definition/ subfolders.
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

    # Detect if wrapped in createOrReplace
    start_idx = 0
    is_wrapped = False
    for i, line in enumerate(raw_lines):
        stripped = line.strip()
        if stripped.lower() == "createorreplace":
            is_wrapped = True
            start_idx = i + 1
            break
        elif stripped:
            break

    content_lines = raw_lines[start_idx:]

    base_indent_len = 0
    if is_wrapped:
        for line in content_lines:
            if line.strip():
                match = re.match(r"^(\s+)", line)
                if match:
                    base_indent_len = len(match.group(1))
                break

    def unindent_line(line):
        if not is_wrapped or not line.strip():
            return line
        if line.startswith("\t"):
            return line[1:]
        elif line.startswith("    "):
            return line[4:]
        elif len(line) >= base_indent_len and line[:base_indent_len].isspace():
            return line[base_indent_len:]
        return line

    normalized_lines = [unindent_line(l) for l in content_lines]

    object_blocks = []
    current_obj = None
    top_level_pattern = re.compile(r"^([a-zA-Z_]+)\s+(.+)$")

    for line in normalized_lines:
        if line and not line[0].isspace() and not line.startswith("//"):
            m = top_level_pattern.match(line)
            if m:
                keyword = m.group(1).lower()
                target_name = m.group(2).strip()

                if keyword in ("table", "database", "model", "relationship", "expression", "cultureinfo", "culture"):
                    if current_obj:
                        object_blocks.append(current_obj)
                    current_obj = {
                        "type": keyword,
                        "raw_name": target_name,
                        "lines": [line]
                    }
                    continue

        if current_obj is not None:
            current_obj["lines"].append(line)

    if current_obj:
        object_blocks.append(current_obj)

    tables_dir = output_base_dir / "tables"
    cultures_dir = output_base_dir / "cultures"
    tables_dir.mkdir(parents=True, exist_ok=True)
    cultures_dir.mkdir(parents=True, exist_ok=True)

    written_files = []
    accumulated_relationships = []
    accumulated_expressions = []

    for block in object_blocks:
        b_type = block["type"]
        raw_name = block["raw_name"]
        clean_name = clean_identifier(raw_name)
        content = "\n".join(block["lines"]).strip() + "\n"

        if b_type == "table":
            target_file = tables_dir / f"{clean_name}.tmdl"
            target_file.write_text(content, encoding="utf-8")
            written_files.append((f"table: {clean_name}", target_file))

        elif b_type == "database":
            target_file = output_base_dir / "database.tmdl"
            target_file.write_text(content, encoding="utf-8")
            written_files.append(("database", target_file))

        elif b_type == "model":
            target_file = output_base_dir / "model.tmdl"
            target_file.write_text(content, encoding="utf-8")
            written_files.append(("model", target_file))

        elif b_type in ("culture", "cultureinfo"):
            target_file = cultures_dir / f"{clean_name}.tmdl"
            target_file.write_text(content, encoding="utf-8")
            written_files.append((f"culture: {clean_name}", target_file))

        elif b_type == "relationship":
            accumulated_relationships.append(content)

        elif b_type == "expression":
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
