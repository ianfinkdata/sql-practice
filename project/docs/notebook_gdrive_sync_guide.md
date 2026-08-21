# Google Drive & NotebookLM Sync Automation Guide

This guide documents the architecture, workflows, and scheduling options (both local and cloud-based) for syncing repository curriculum and documentation between **sql-practice**, **Google Drive**, and **Google NotebookLM**.

---

## 📌 Architecture Overview

Google Drive serves as the live cloud staging bridge between the local Git workspace and Google's AI ecosystem (NotebookLM):

```
 ┌───────────────────────────┐                           ┌───────────────────────────┐
 │   Local sql-practice      │     rclone sync --push    │   Google Drive Staging    │
 │ (curriculum, exercises,   │ ────────────────────────> │ (gdrive:sql-practice/     │
 │  project docs, portfolio) │                           │         sources/)         │
 └───────────────────────────┘                           └─────────────┬─────────────┘
               ▲                                                       │
               │                                                 Add as Source
               │                                                       ▼
               │                                         ┌───────────────────────────┐
               │                                         │   Google NotebookLM       │
               │                                         │ (Mind maps, Study Guides, │
               │                                         │  Briefing Docs, FAQs)     │
               │                                         └─────────────┬─────────────┘
               │                                                       │
               │                                                 Export to Doc
               │                                                       ▼
 ┌─────────────┴─────────────┐                           ┌───────────────────────────┐
 │   Local Markdown Notes    │     rclone copy --pull    │   Google Drive Notes      │
 │    (docs/notebooks/*.md)  │ <──────────────────────── │ (gdrive:sql-practice/     │
 │                           │  --drive-export-formats   │          notes/)          │
 └───────────────────────────┘                           └───────────────────────────┘
```

---

## 🛠️ CLI Script Reference

The repository provides [`scripts/sync-gdrive-notebooks.sh`](../../scripts/sync-gdrive-notebooks.sh):

```bash
# 1. Push local markdown files up to Google Drive (for NotebookLM sources)
./scripts/sync-gdrive-notebooks.sh --push

# 2. Pull exported NotebookLM Google Docs down to local repo as Markdown (.md)
./scripts/sync-gdrive-notebooks.sh --pull

# 3. Check status of remote Drive folders and local notebooks
./scripts/sync-gdrive-notebooks.sh --status
```

---

## ⏰ Option 1: Local Weekly Scheduling

Because `rclone` uses your local authentication token stored at `~/.config/rclone/rclone.conf`, you can schedule automated weekly synchronizations directly on your machine.

### A. User `cron` (Easiest)
Edit your user crontab:
```bash
crontab -e
```
Add the following entry to sync every Monday morning at 8:00 AM:
```cron
# Run weekly Google Drive push on Mondays at 8:00 AM
0 8 * * 1 /home/ian/github/sql-practice/scripts/sync-gdrive-notebooks.sh --push >> /tmp/gdrive-sync.log 2>&1
```

### B. Systemd User Timer
Create a user service and timer under `~/.config/systemd/user/`:

1. **Service File (`~/.config/systemd/user/sql-notebook-sync.service`)**:
   ```ini
   [Unit]
   Description=Weekly sql-practice Google Drive Source Sync

   [Service]
   Type=oneshot
   WorkingDirectory=/home/ian/github/sql-practice
   ExecStart=/home/ian/github/sql-practice/scripts/sync-gdrive-notebooks.sh --push
   ```

2. **Timer File (`~/.config/systemd/user/sql-notebook-sync.timer`)**:
   ```ini
   [Unit]
   Description=Run sql-notebook-sync weekly on Monday morning

   [Timer]
   OnCalendar=Mon *-*-* 08:00:00
   Persistent=true

   [Install]
   WantedBy=timers.target
   ```

3. **Enable and Start Timer**:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now sql-notebook-sync.timer
   ```

### C. Antigravity CLI `/schedule`
Inside an active Antigravity CLI session, you can schedule recurring checks:
```
/schedule CronExpression="0 8 * * 1", Prompt="Run ./scripts/sync-gdrive-notebooks.sh --push and verify sync state"
```

---

## ☁️ Option 2: Cloud Scheduling (GitHub Actions)

To synchronize automatically in the cloud without requiring your local workstation to be running, use a scheduled GitHub Actions workflow with an on-demand button trigger.

### 1. Configure GitHub Repository Secrets
Navigate to **GitHub Repo > Settings > Secrets and variables > Actions > New repository secret**:
- `GDRIVE_CLIENT_ID`: Your Google OAuth Client ID
- `GDRIVE_CLIENT_SECRET`: Your Google OAuth Client Secret
- `GDRIVE_TOKEN`: Your current OAuth JSON token string from `~/.config/rclone/rclone.conf`

### 2. Workflow Definition (`.github/workflows/sync-notebooks.yml`)
```yaml
name: Weekly Google Drive & NotebookLM Sync

on:
  schedule:
    - cron: '0 13 * * 1' # Runs every Monday at 1:00 PM UTC
  workflow_dispatch:     # Enables manual 'Run workflow' button in GitHub UI

permissions:
  contents: write

jobs:
  sync-sources:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install rclone
        run: sudo apt-get install -y rclone

      - name: Sync sources to Google Drive
        env:
          RCLONE_CONFIG_GDRIVE_TYPE: drive
          RCLONE_CONFIG_GDRIVE_CLIENT_ID: ${{ secrets.GDRIVE_CLIENT_ID }}
          RCLONE_CONFIG_GDRIVE_CLIENT_SECRET: ${{ secrets.GDRIVE_CLIENT_SECRET }}
          RCLONE_CONFIG_GDRIVE_TOKEN: ${{ secrets.GDRIVE_TOKEN }}
        run: |
          ./scripts/sync-gdrive-notebooks.sh --push

  pull-notes:
    runs-on: ubuntu-latest
    needs: sync-sources
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install rclone
        run: sudo apt-get install -y rclone

      - name: Pull exported notes from Google Drive
        env:
          RCLONE_CONFIG_GDRIVE_TYPE: drive
          RCLONE_CONFIG_GDRIVE_CLIENT_ID: ${{ secrets.GDRIVE_CLIENT_ID }}
          RCLONE_CONFIG_GDRIVE_CLIENT_SECRET: ${{ secrets.GDRIVE_CLIENT_SECRET }}
          RCLONE_CONFIG_GDRIVE_TOKEN: ${{ secrets.GDRIVE_TOKEN }}
        run: |
          ./scripts/sync-gdrive-notebooks.sh --pull

      - name: Commit and push changes
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add docs/notebooks/
          if git diff --staged --quiet; then
            echo "No new notes to commit."
          else
            git commit -m "chore(notebooks): sync latest NotebookLM export notes from Google Drive"
            git push
          fi
```

---

## 🔧 Maintenance & Token Refresh

Google OAuth refresh tokens for personal test apps may expire periodically. If `rclone` returns `invalid_grant` or `token expired`, refresh the token locally with:

```bash
rclone config reconnect gdrive:
```
Follow the browser prompts to re-authorize, and if using GitHub Actions, update the `GDRIVE_TOKEN` secret with the refreshed JSON token block.
