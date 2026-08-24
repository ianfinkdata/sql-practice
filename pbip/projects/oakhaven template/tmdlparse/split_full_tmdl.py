#!/usr/bin/env python3
"""
split_full_tmdl.py - Split Monolithic TMDL Text into PBIP Semantic Model Folder Structure

Reads fulltmdl.txt (or oakhaventemplateFullTMDL.txt) from oakhaven template.FullTMDL,
parses top-level TMDL objects (database, model, tables, relationships, expressions, cultures),
normalizes indentation, and writes them into the definition/ folder structure.
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
FULL_TMDL_DIR = BASE_DIR / "oakhaven template.FullTMDL"
OUTPUT_DEF_DIR = BASE_DIR / "oakhaven template.SemanticModel" / "definition"

# Candidates for full TMDL file
SOURCE_FILES = [
    FULL_TMDL_DIR / "oakhaventemplateFullTMDL.txt",
    FULL_TMDL_DIR / "fulltmdl.txt"
]


def find_source_file():
    for f in SOURCE_FILES:
        if f.exists() and f.stat().st_size > 0:
            return f
    # Fallback to any txt or tmdl file in the FullTMDL folder
    if FULL_TMDL_DIR.exists():
        for f in FULL_TMDL_DIR.glob("*.*"):
            if f.is_file() and f.stat().st_size > 0:
                return f
    return None


def clean_identifier(raw_name):
    """Cleans single quotes, double quotes, and leading/trailing whitespace."""
    name = raw_name.strip()
    if (name.startswith("'") and name.endswith("'")) or (name.startswith('"') and name.endswith('"')):
        name = name[1:-1]
    return name.strip()


def parse_and_split_tmdl(source_path, output_base_dir):
    """
    Parses a monolithic TMDL text file and extracts individual TMDL definition components.
    """
    text = source_path.read_text(encoding="utf-8", errors="replace")
    raw_lines = text.splitlines()

    print(f"Reading: {source_path}")
    print(f"Total Lines: {len(raw_lines)}")

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

    # If wrapped, determine base indentation of top-level objects (usually 1 tab or 4 spaces)
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

    # Object categories
    # Top-level declarations start at col 0 (no leading whitespace)
    # Types: table <name>, model <name>, database <name>, relationship <name>, expression <name>, cultureInfo <name>, culture <name>
    object_blocks = []
    current_obj = None

    top_level_pattern = re.compile(r"^([a-zA-Z_]+)\s+(.+)$")

    for line in normalized_lines:
        # Check for top-level declaration starting at column 0
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
        elif line.strip():
            # Leading unattached comments or properties
            pass

    if current_obj:
        object_blocks.append(current_obj)

    print(f"\nDiscovered {len(object_blocks)} top-level TMDL object block(s):")

    # Map object blocks to target folder paths
    # tables/ -> definition/tables/<table_name>.tmdl
    # database -> definition/database.tmdl
    # model -> definition/model.tmdl
    # relationship -> appended or definition/relationships.tmdl
    # expression -> appended or definition/expressions.tmdl
    # culture/cultureInfo -> definition/cultures/<culture>.tmdl

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
            print(f"  [TABLE]        -> {target_file.relative_to(BASE_DIR)}")

        elif b_type == "database":
            target_file = output_base_dir / "database.tmdl"
            target_file.write_text(content, encoding="utf-8")
            written_files.append(("database", target_file))
            print(f"  [DATABASE]     -> {target_file.relative_to(BASE_DIR)}")

        elif b_type == "model":
            target_file = output_base_dir / "model.tmdl"
            target_file.write_text(content, encoding="utf-8")
            written_files.append(("model", target_file))
            print(f"  [MODEL]        -> {target_file.relative_to(BASE_DIR)}")

        elif b_type in ("culture", "cultureinfo"):
            target_file = cultures_dir / f"{clean_name}.tmdl"
            target_file.write_text(content, encoding="utf-8")
            written_files.append((f"culture: {clean_name}", target_file))
            print(f"  [CULTURE]      -> {target_file.relative_to(BASE_DIR)}")

        elif b_type == "relationship":
            accumulated_relationships.append(content)

        elif b_type == "expression":
            accumulated_expressions.append(content)

    if accumulated_relationships:
        target_file = output_base_dir / "relationships.tmdl"
        target_file.write_text("\n".join(accumulated_relationships), encoding="utf-8")
        written_files.append(("relationships", target_file))
        print(f"  [RELATIONSHIPS] -> {target_file.relative_to(BASE_DIR)} ({len(accumulated_relationships)} relationships)")

    if accumulated_expressions:
        target_file = output_base_dir / "expressions.tmdl"
        target_file.write_text("\n".join(accumulated_expressions), encoding="utf-8")
        written_files.append(("expressions", target_file))
        print(f"  [EXPRESSIONS]   -> {target_file.relative_to(BASE_DIR)} ({len(accumulated_expressions)} expressions)")

    return written_files


def main():
    print("==================================================================")
    print("  SECTION 1: TMDL FULL SCRIPT SPLITTER")
    print("==================================================================")
    
    src = find_source_file()
    if not src:
        print(f"[ERROR] No non-empty source Full TMDL file found in {FULL_TMDL_DIR}")
        sys.exit(1)

    print(f"Target Output Folder: {OUTPUT_DEF_DIR}\n")
    written = parse_and_split_tmdl(src, OUTPUT_DEF_DIR)

    print("\n------------------------------------------------------------------")
    print(f"✅ Section 1 Complete! Successfully split and structured {len(written)} file(s).")
    print("------------------------------------------------------------------")


if __name__ == "__main__":
    main()
