# Publishing / previewing this site

This is a static site with no build step and no external dependencies —
`index.html` and `styles.css` are ready to serve as-is.

## Enable GitHub Pages on your fork

1. Fork this repository.
2. In your fork, go to **Settings &rarr; Pages**.
3. Under **Build and deployment &rarr; Source**, choose
   **Deploy from a branch**.
4. Under **Branch**, choose **`main`** and the folder **`/docs`**, then
   **Save**.
5. GitHub will publish the site at
   `https://<your-username>.github.io/<repo-name>/` within a minute or
   two. Re-visit **Settings &rarr; Pages** to get the exact URL.

A `.nojekyll` file is included in `docs/` so GitHub Pages serves the
files directly instead of running them through Jekyll.

## Preview it locally

No installation is required — `index.html` has no server-side
dependencies, so you can just open it directly in a browser:

```bash
open docs/index.html        # macOS
xdg-open docs/index.html    # Linux
```

Or, for a closer match to how it's served over HTTP (recommended, since
some browsers restrict relative links opened via `file://`), run a
throwaway local web server from inside `docs/`:

```bash
cd docs
python3 -m http.server
```

Then visit `http://localhost:8000/` in a browser.
