#!/usr/bin/env bash
# scan-db-sql-terminal.sh — Opens a placed Ptyxis terminal displaying the DB & SQL catalog.
# 105×45 cells, placed top-left (or standalone) via lib/ptyxis-place.sh.
# Runnable standalone or via the scan-db-sql-files skill.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/ptyxis-place.sh"

ptyxis_place_window 105 45 top-left "$REPO_DIR" bash -c '
  "'"$SCRIPT_DIR"'/scan-db-sql.sh" --render
  echo
  exec "$SHELL"
'
