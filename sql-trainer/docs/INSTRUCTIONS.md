# Setup & Operations Guide

Everything you need to (1) publish the web version, and (2) split this folder
into its own clean repository.

---

## Part 1 — Publish the GitHub Pages site

The web version lives entirely in this `docs/` folder (`index.html` +
`styles.css`). It is plain static HTML/CSS — no build step, no dependencies.

### Option A — Pages from the `docs/` folder (simplest)

> Use this if `sql-trainer/` is the **root** of its own repository (see Part 2).

1. Push the repo to GitHub.
2. Go to **Settings → Pages**.
3. Under **Build and deployment**, set:
   - **Source:** *Deploy from a branch*
   - **Branch:** `main` (or your default) and folder **`/docs`**
4. Click **Save**. After a minute, your site is live at
   `https://<username>.github.io/<repo>/`.

### Option B — Pages while `sql-trainer/` is a subfolder

GitHub Pages "deploy from a branch" can only serve the repo root or a `/docs`
folder at the repo root — not a nested `sql-trainer/docs`. Two ways around it:

- **Split first** (recommended) — follow Part 2 so `docs/` sits at the repo
  root, then use Option A.
- **GitHub Actions** — add a workflow that publishes
  `sql-trainer/docs/`. A ready-to-use workflow is below.

<details>
<summary>Show GitHub Actions workflow (.github/workflows/pages.yml)</summary>

```yaml
name: Deploy SQL Trainer Pages
on:
  push:
    branches: [main]
permissions:
  contents: read
  pages: write
  id-token: write
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: sql-trainer/docs   # change to "docs" if you split the folder out
      - id: deployment
        uses: actions/deploy-pages@v4
```

Then set **Settings → Pages → Source** to **GitHub Actions**.
</details>

### Local preview

Open `index.html` directly in a browser, or serve the folder:

```bash
cd sql-trainer/docs
python3 -m http.server 8000
# visit http://localhost:8000
```

> **Note on links:** the site's "Open on GitHub" buttons point at
> `github.com/ianfinkdata/sql-practice/.../sql-trainer/...`. If you split this
> into a standalone repo (Part 2), update those URLs in `index.html` to your new
> repo path.

---

## Part 2 — Split this folder into its own clean repository

This `sql-trainer/` folder is **fully self-contained** — it references nothing
outside itself. You can lift it into a brand-new repo in either of two ways.

### Method 1 — Simple copy (keeps a clean, fresh history)

Best when you don't need the old commit history.

```bash
# from anywhere
git clone https://github.com/ianfinkdata/sql-practice.git
cp -R sql-practice/sql-trainer ./sql-trainer-standalone
cd sql-trainer-standalone

git init
git add .
git commit -m "Initial commit: SQL Trainer"
# create an empty repo on GitHub first, then:
git remote add origin https://github.com/<you>/sql-trainer.git
git branch -M main
git push -u origin main
```

After this, `docs/` sits at the repo root, so **Pages Option A** works directly.

### Method 2 — Preserve history with `git subtree` / `filter-repo`

Best when you want the commit history that touched `sql-trainer/`.

```bash
# Using git subtree (built in):
git clone https://github.com/ianfinkdata/sql-practice.git
cd sql-practice
git subtree split --prefix=sql-trainer -b sql-trainer-only
# push that branch to a new repo:
git push https://github.com/<you>/sql-trainer.git sql-trainer-only:main
```

Or with the more thorough [`git-filter-repo`](https://github.com/newren/git-filter-repo):

```bash
git clone https://github.com/ianfinkdata/sql-practice.git sql-trainer-split
cd sql-trainer-split
git filter-repo --subdirectory-filter sql-trainer
git remote add origin https://github.com/<you>/sql-trainer.git
git push -u origin main
```

### After splitting — a quick checklist

- [ ] `docs/` is now at the repo root → enable Pages (Option A).
- [ ] Update the GitHub URLs in `docs/index.html` to your new repo.
- [ ] Update the `actions/upload-pages-artifact` `path:` to `docs` if you use the
      workflow.
- [ ] Skim `README.md` for any links that still point at the monorepo.
- [ ] You're done — the curriculum, decoder, persona guide, and exercises all
      use **relative** links, so they keep working unchanged.

---

## Why this folder splits cleanly

By design, everything in `sql-trainer/` uses **relative links** and depends on
**no files outside the folder**:

- `README.md` → links into `curriculum/`, `dialect-decoder/`, `exercises/`, `docs/`
- curriculum modules → link to each other and to `../../dialect-decoder/`
- the decoder → links within itself and back to `../curriculum/`
- the web site → self-contained `index.html` + `styles.css`

Nothing reaches up into the parent `sql-practice` project. Lift the folder out
and it just works.
