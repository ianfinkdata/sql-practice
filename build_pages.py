#!/usr/bin/env python3
"""
build_pages.py - Markdown to HTML converter for GitHub Pages

Converts all Markdown files (.md) in the repository into structured,
responsive HTML pages in the docs/ directory with dark-mode glassmorphism styling,
BLUF callout cards, and sequential book-style navigation.
"""

import os
import re
import html
import shutil
from pathlib import Path

REPO_ROOT = Path(__file__).parent.resolve()
DOCS_DIR = REPO_ROOT / "docs"

# HTML Template with theme toggle, responsive layout, and navigation
HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title} | SQL Practice</title>
  <link rel="stylesheet" href="{css_path}">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
</head>
<body>
  <header class="site-header">
    <div class="header-inner">
      <a href="{root_path}index.html" class="site-logo">
        <span class="logo-icon">⚡</span>
        <span class="logo-text">SQL Practice</span>
      </a>
      <nav class="header-nav">
        <a href="{root_path}index.html">📖 Book Index</a>
        <a href="{root_path}curriculum/README.html">🎓 Curriculum</a>
        <a href="{root_path}exercises/README.html">💪 Exercises</a>
        <a href="{root_path}portfolio/README.html">💼 Portfolio</a>
        <a href="{root_path}project/docs/schema_ontology_mapping.html">🗺️ Schema & Ontology</a>
        <button id="theme-toggle" class="theme-toggle-btn" aria-label="Toggle theme">🌙</button>
      </nav>
    </div>
  </header>

  <main class="main-content">
    <div class="content-wrapper">
      {content}
    </div>
  </main>

  <footer class="site-footer">
    <div class="footer-inner">
      <p><strong>SQL Practice</strong> — Self-paced SQL Curriculum & Medallion Pipeline Architecture.</p>
      <p class="footer-links">
        <a href="{root_path}index.html">Home</a> • 
        <a href="https://github.com/ianfinkdata/sql-practice" target="_blank" rel="noopener">GitHub Repository</a> • 
        <a href="{root_path}project/docs/data_dictionary.html">Data Dictionary</a>
      </p>
    </div>
  </footer>

  <script>
    // Simple theme switcher script
    const toggleBtn = document.getElementById('theme-toggle');
    const currentTheme = localStorage.getItem('theme') || 'dark';
    document.documentElement.setAttribute('data-theme', currentTheme);
    toggleBtn.textContent = currentTheme === 'dark' ? '☀️' : '🌙';

    toggleBtn.addEventListener('click', () => {{
      const theme = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', theme);
      localStorage.setItem('theme', theme);
      toggleBtn.textContent = theme === 'dark' ? '☀️' : '🌙';
    }});
  </script>
</body>
</html>
"""

def parse_markdown_to_html(md_text, current_rel_dir="."):
    """Converts basic Markdown to clean HTML with custom BLUF and Navigation styling."""
    
    # 1. Process navigation blocks <!-- nav --> ... <!-- /nav -->
    def convert_nav_block(match):
        nav_content = match.group(1).strip()
        # Convert links inside nav
        nav_content = re.sub(
            r'\[(.*?)\]\((.*?)\)',
            lambda m: f'<a href="{convert_link_path(m.group(2))}" class="nav-btn">{m.group(1)}</a>',
            nav_content
        )
        # Split links separated by '|'
        parts = [p.strip() for p in nav_content.split('|') if p.strip()]
        links_html = " ".join(parts)
        return f'<nav class="book-nav">{links_html}</nav>'

    md_text = re.sub(r'<!-- nav -->\s*(.*?)\s*<!-- /nav -->', convert_nav_block, md_text, flags=re.DOTALL)

    # 2. Process BLUF blockquote callouts (> **BLUF...)
    def convert_bluf_block(match):
        bluf_content = match.group(1).strip()
        # Parse inline markdown inside BLUF
        bluf_content = parse_inline_markdown(bluf_content)
        return f'<div class="bluf-card"><div class="bluf-badge">⚡ BLUF (Bottom Line Up Front)</div><div class="bluf-body">{bluf_content}</div></div>'

    md_text = re.sub(r'^\>\s*\*\*BLUF\s*\(Bottom Line Up Front\):\*\*\s*(.*(?:\n\>\s*.*)*)', convert_bluf_block, md_text, flags=re.MULTILINE)
    # Remove leading '>' from captured lines in BLUF
    md_text = re.sub(r'<div class="bluf-body">(.*?)</div>', lambda m: '<div class="bluf-body">' + re.sub(r'^\>\s*', '', m.group(1), flags=re.MULTILINE) + '</div>', md_text, flags=re.DOTALL)

    # 3. Code blocks (```lang ... ```)
    def convert_code_block(match):
        lang = match.group(1) or 'text'
        code = html.escape(match.group(2).strip())
        return f'<div class="code-block-wrapper"><div class="code-header"><span class="code-lang">{lang.upper()}</span></div><pre><code class="language-{lang}">{code}</code></pre></div>'

    md_text = re.sub(r'```(\w*)\n(.*?)```', convert_code_block, md_text, flags=re.DOTALL)

    # 4. Standard Blockquotes
    def convert_blockquote(match):
        bq = match.group(1).strip()
        lines = [line.lstrip('> ').strip() for line in bq.split('\n')]
        bq_content = "<br>".join(lines)
        bq_content = parse_inline_markdown(bq_content)
        return f'<blockquote class="custom-blockquote">{bq_content}</blockquote>'

    md_text = re.sub(r'(^\>.*(?:\n\>.*)*)', convert_blockquote, md_text, flags=re.MULTILINE)

    # 5. Tables
    def convert_table(match):
        table_str = match.group(0).strip()
        lines = [l.strip() for l in table_str.split('\n') if l.strip()]
        if len(lines) < 2:
            return table_str
        
        headers = [c.strip() for c in lines[0].strip('|').split('|')]
        # Skip line 1 (delimiter |---|---|)
        rows = []
        for line in lines[2:]:
            cols = [c.strip() for c in line.strip('|').split('|')]
            rows.append(cols)
        
        header_html = "".join([f'<th>{parse_inline_markdown(h)}</th>' for h in headers])
        rows_html = ""
        for r in rows:
            cells_html = "".join([f'<td>{parse_inline_markdown(c)}</td>' for c in r])
            rows_html += f'<tr>{cells_html}</tr>'
        
        return f'<div class="table-container"><table class="styled-table"><thead><tr>{header_html}</tr></thead><tbody>{rows_html}</tbody></table></div>'

    md_text = re.sub(r'(?:^\|.+\|\n){2,}', convert_table, md_text, flags=re.MULTILINE)

    # 6. Headers (# .. ######)
    def convert_headers(match):
        level = len(match.group(1))
        header_text = match.group(2).strip()
        header_id = re.sub(r'[^\w\-]', '', header_text.lower().replace(' ', '-'))
        inline_html = parse_inline_markdown(header_text)
        return f'<h{level} id="{header_id}">{inline_html}</h{level}>'

    md_text = re.sub(r'^(#{1,6})\s+(.*)$', convert_headers, md_text, flags=re.MULTILINE)

    # 7. Unordered lists
    def convert_lists(match):
        list_str = match.group(0).strip()
        items = re.findall(r'^\s*[\-\*]\s+(.*)$', list_str, flags=re.MULTILINE)
        items_html = "".join([f'<li>{parse_inline_markdown(i)}</li>' for i in items])
        return f'<ul class="styled-list">{items_html}</ul>'

    md_text = re.sub(r'(?:^\s*[\-\*]\s+.*$\n?)+', convert_lists, md_text, flags=re.MULTILINE)

    # 8. Paragraphs
    paragraphs = []
    for block in md_text.split('\n\n'):
        block = block.strip()
        if not block:
            continue
        if block.startswith(('<h', '<div', '<blockquote', '<ul', '<ol', '<table', '<nav', '<pre')):
            paragraphs.append(block)
        elif block == '---':
            paragraphs.append('<hr class="divider">')
        else:
            paragraphs.append(f'<p>{parse_inline_markdown(block)}</p>')

    return "\n\n".join(paragraphs)

def parse_inline_markdown(text):
    """Converts inline markdown like bold, italics, code, and links."""
    # Convert .md links to .html links
    def link_repl(m):
        label = m.group(1)
        url = m.group(2)
        new_url = convert_link_path(url)
        return f'<a href="{new_url}">{label}</a>'

    # Code
    text = re.sub(r'`([^`]+)`', r'<code class="inline-code">\1</code>', text)
    # Bold
    text = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', text)
    # Italic
    text = re.sub(r'\*([^*]+)\*', r'<em>\1</em>', text)
    # Links
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', link_repl, text)
    return text

def convert_link_path(url):
    """Converts local markdown relative paths to html relative paths."""
    if url.startswith(('http://', 'https://', '#', 'mailto:')):
        return url
    if url.endswith('.md'):
        return url[:-3] + '.html'
    return url

def process_file(file_path):
    """Reads a markdown file and writes the rendered HTML file to docs/."""
    rel_path = file_path.relative_to(REPO_ROOT)
    
    # Target path inside docs/
    if file_path.name == "README.md" and file_path.parent == REPO_ROOT:
        target_path = DOCS_DIR / "index.html"
    else:
        target_rel = rel_path.with_suffix('.html')
        target_path = DOCS_DIR / target_rel

    target_path.parent.mkdir(parents=True, exist_ok=True)

    # Compute relative paths for CSS and Root
    depth = len(target_path.relative_to(DOCS_DIR).parts) - 1
    root_path = "../" * depth if depth > 0 else "./"
    css_path = f"{root_path}styles.css"

    with open(file_path, "r", encoding="utf-8") as f:
        md_text = f.read()

    # Extract title from first H1 if present
    title_match = re.search(r'^#\s+(.*)$', md_text, flags=re.MULTILINE)
    title = title_match.group(1).strip() if title_match else file_path.stem

    body_html = parse_markdown_to_html(md_text, current_rel_dir=str(rel_path.parent))
    
    full_html = HTML_TEMPLATE.format(
        title=html.escape(title),
        css_path=css_path,
        root_path=root_path,
        content=body_html
    )

    with open(target_path, "w", encoding="utf-8") as f:
        f.write(full_html)

    print(f"Generated: {target_path.relative_to(REPO_ROOT)}")

def main():
    print("🚀 Building GitHub Pages static site from Markdown...")
    DOCS_DIR.mkdir(exist_ok=True)
    
    # Make sure .nojekyll exists
    (DOCS_DIR / ".nojekyll").touch()

    # Walk markdown files
    dirs_to_scan = ["curriculum", "exercises", "portfolio", "project/docs"]
    md_files = [REPO_ROOT / "README.md"]
    
    for d in dirs_to_scan:
        scan_dir = REPO_ROOT / d
        if scan_dir.exists():
            md_files.extend(list(scan_dir.rglob("*.md")))

    for file_path in md_files:
        process_file(file_path)

    print("✨ Build completed successfully!")

if __name__ == "__main__":
    main()
