#!/usr/bin/env bash
# scan-db-sql.sh — Database & SQL Catalog Scanner & Terminal Launcher
#
# Modes:
#   --render          Print formatted ANSI catalog dashboard to stdout and exit.
#   --json            Output catalog as structured JSON.
#   --csv             Output catalog as CSV records.
#   --type [db|sql]   Filter by file extension.
#   --layer [name]    Filter by architectural layer or folder.
#   (no args)         Opens a placed Ptyxis window running --render (using lib/ptyxis-place.sh)
#                     and drops into an interactive shell.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PY_SCRIPT="$SCRIPT_DIR/scan_db_sql.py"

run_py() {
  if [ -x "$REPO_DIR/.venv/bin/python" ]; then
    "$REPO_DIR/.venv/bin/python" "$PY_SCRIPT" "$@"
  elif command -v python3 >/dev/null 2>&1; then
    python3 "$PY_SCRIPT" "$@"
  else
    python "$PY_SCRIPT" "$@"
  fi
}

# If explicit flags provided (or running in non-interactive piped shell without terminal launch intent)
if [ $# -gt 0 ]; then
  case "${1:-}" in
    --render|--json|--csv|--type|--layer|-h|--help)
      run_py "$@"
      exit 0
      ;;
  esac
fi

# Launcher mode: open in placed Ptyxis terminal
source "$SCRIPT_DIR/lib/ptyxis-place.sh"

ptyxis_place_window 105 45 top-left "$REPO_DIR" bash -c '
  "'"$SCRIPT_DIR"'/scan-db-sql.sh" --render
  echo
  exec "$SHELL"
'
