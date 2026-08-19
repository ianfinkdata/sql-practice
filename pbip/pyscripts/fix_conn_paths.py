#!/usr/bin/env python3
import glob
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent.resolve()
PROJECTS_DIR = REPO_ROOT / "pbip" / "projects"

old_str_1 = 'conn = sqlite3.connect(""project/oakhaven.db"")'
new_str_1 = 'conn = sqlite3.connect(""C:\\Github\\sql-practice\\project\\oakhaven.db"")'

old_str_2 = '"project/oakhaven.db"'
new_str_2 = '"C:\\Github\\sql-practice\\project\\oakhaven.db"'

files = list(PROJECTS_DIR.rglob("*.tmdl"))
count = 0

for filepath in files:
    content = filepath.read_text(encoding="utf-8")
    new_content = content.replace(old_str_1, new_str_1)
    new_content = new_content.replace(old_str_2, new_str_2)
    
    if new_content != content:
        filepath.write_text(new_content, encoding="utf-8")
        print(f"✅ Updated: {filepath.relative_to(PROJECTS_DIR)}")
        count += 1

print(f"\nDone. Updated {count} files with absolute Windows connection string.")
