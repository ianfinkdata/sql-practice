#!/usr/bin/env bash
# sync-gdrive-notebooks.sh — 2-Way Google Drive & NotebookLM Sync Bridge
#
# Workflows:
#   --push      Uploads local curriculum, exercises, and docs to gdrive:sql-practice/sources
#               so NotebookLM can import them as knowledge sources.
#   --pull      Downloads exported NotebookLM Google Docs from gdrive:sql-practice/notes
#               and converts them into local Markdown (.md) in docs/notebooks/.
#   --status    Displays remote and local folder sync state.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

REMOTE_NAME="gdrive"
REMOTE_BASE="${REMOTE_NAME}:sql-practice"
REMOTE_SOURCES="${REMOTE_BASE}/sources"
REMOTE_NOTES="${REMOTE_BASE}/notes"
LOCAL_NOTEBOOKS="${REPO_DIR}/docs/notebooks"

mkdir -p "$LOCAL_NOTEBOOKS"

# Colors
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

cmd="${1:---status}"

case "$cmd" in
  --push)
    echo -e "${CYAN}==> Pushing repository Markdown files to Google Drive (${REMOTE_SOURCES})...${RESET}"
    
    # 1. Sync Curriculum
    echo -e "${BLUE}➜ Syncing curriculum/...${RESET}"
    rclone sync "${REPO_DIR}/curriculum" "${REMOTE_SOURCES}/curriculum" \
      --include "*.md" --include "*.sql" --fast-list

    # 2. Sync Exercises
    echo -e "${BLUE}➜ Syncing exercises/...${RESET}"
    rclone sync "${REPO_DIR}/exercises" "${REMOTE_SOURCES}/exercises" \
      --include "*.md" --include "*.sql" --fast-list

    # 3. Sync Portfolio
    echo -e "${BLUE}➜ Syncing portfolio/...${RESET}"
    rclone sync "${REPO_DIR}/portfolio" "${REMOTE_SOURCES}/portfolio" \
      --include "*.md" --include "*.sql" --fast-list

    # 4. Sync Project Docs & Schema
    echo -e "${BLUE}➜ Syncing project/docs/...${RESET}"
    rclone sync "${REPO_DIR}/project/docs" "${REMOTE_SOURCES}/project_docs" \
      --include "*.md" --include "*.sql" --fast-list

    echo
    echo -e "${GREEN}✔ Push complete!${RESET} In NotebookLM (https://notebook.google.com):"
    echo "  Click 'Add Source' > 'Google Drive' > select 'sql-practice/sources'."
    ;;

  --pull)
    echo -e "${CYAN}==> Pulling NotebookLM Google Docs from Google Drive (${REMOTE_NOTES})...${RESET}"
    
    # Copies Google Docs and automatically converts them to Markdown format (.md)
    rclone copy "${REMOTE_NOTES}" "${LOCAL_NOTEBOOKS}" \
      --drive-export-formats md,txt \
      --fast-list -v

    echo
    echo -e "${GREEN}✔ Pull complete!${RESET} Synced files are located in:"
    echo "  ${LOCAL_NOTEBOOKS}"
    echo
    echo "Files currently in docs/notebooks/:"
    ls -lah "${LOCAL_NOTEBOOKS}"
    ;;

  --status|status|-s)
    echo -e "${CYAN}╔═════════════════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║             ⚡ GOOGLE DRIVE & NOTEBOOKLM SYNC BRIDGE STATUS ⚡                   ║${RESET}"
    echo -e "${CYAN}╚═════════════════════════════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${BLUE}📁 Remote Google Drive Layout (${REMOTE_BASE}):${RESET}"
    rclone lsd "${REMOTE_BASE}" || echo "  (remote folder not reachable)"
    echo
    echo -e "${BLUE}📄 Local Notebooks Directory (${LOCAL_NOTEBOOKS}):${RESET}"
    if [ -d "$LOCAL_NOTEBOOKS" ] && [ "$(ls -A "$LOCAL_NOTEBOOKS" 2>/dev/null)" ]; then
      ls -lah "$LOCAL_NOTEBOOKS"
    else
      echo "  (empty - run './scripts/sync-gdrive-notebooks.sh --pull' after exporting docs in NotebookLM)"
    fi
    echo
    echo -e "${YELLOW}Usage Commands:${RESET}"
    echo "  ./scripts/sync-gdrive-notebooks.sh --push   # Upload repo docs -> Google Drive (NotebookLM Sources)"
    echo "  ./scripts/sync-gdrive-notebooks.sh --pull   # Download NotebookLM exports -> local Markdown (.md)"
    echo "  ./scripts/sync-gdrive-notebooks.sh --status # Check connection and files"
    echo
    ;;

  *)
    echo "Unknown option: $cmd"
    echo "Usage: $0 [--push | --pull | --status]"
    exit 1
    ;;
esac
