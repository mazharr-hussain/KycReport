# Documentation Build Scripts

These scripts render the `.drawio` diagrams to static images and export the V2/V3 business
guides to Word (`.docx`), independent of the mkdocs-drawio JS viewer (useful for CI,
offline export, or environments where the diagrams.net CDN is unreachable).

## Requirements

```
pip install python-docx cairosvg
apt-get install -y pandoc librsvg2-bin
```

## 1. Review diagrams for layout defects

Checks every page in a `.drawio` file for overlapping boxes, edges that cross through
unrelated nodes, out-of-bounds/clipped content, off-center layout, and tangled cycles.
Run this after any manual edit to a `.drawio` file.

```
python3 scripts/review_diagrams.py docs/diagrams/drawio/asis-process.drawio \
  docs/diagrams/drawio/best-practice-e2e.drawio \
  docs/diagrams/drawio/approval-workflow.drawio \
  docs/diagrams/drawio/intake-flow.drawio
```

Exits non-zero if any issues are found; prints a plain list of `PASS`/`FAIL` per page.

## 2. Render diagrams to static PNG/SVG

```
python3 scripts/render_drawio.py docs/diagrams/drawio/asis-process.drawio /tmp/rendered/asis-process
```

Produces one `.svg` and one `.png` per page in the file, named after the page's `name`
attribute. Repeat for each `.drawio` file you need images from.

## 3. Export a business guide to Word

```
python3 scripts/md_to_docx.py docs/V2_BUS_AsIs_Process.md /tmp/rendered docs/exports/V2_As-Is_Process.docx "V2 — As-Is Process Guide"
python3 scripts/md_to_docx.py docs/V3_BUS_BestPractice.md /tmp/rendered docs/exports/V3_Best_Practice_Process.docx "V3 — Best Practice Process Guide"
```

Matches each `![alt](...drawio)` image reference in the markdown to a rendered PNG by
alt-text-to-page-name, converts MkDocs-only syntax (`!!! admonition`, `=== tabs`) to
plain Pandoc-compatible markdown, then runs Pandoc to produce the `.docx`.

## Known limitations

- The renderer is a simplified mxGraph interpreter (rectangles, ellipses, rhombuses,
  orthogonal edges with auto-elbow routing) — it does not support every drawio shape or
  style option, only what this repo's diagrams currently use.
- Edge label placement can crowd against a nearby box when two shapes are very close
  together (a pre-existing density issue in a couple of pages, not a rendering bug).
