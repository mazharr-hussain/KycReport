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

## 3. Export a business guide to Word (with editable Visio diagrams)

```
pip install vsdx pillow
python3 scripts/md_to_docx.py docs/V2_BUS_AsIs_Process.md docs/diagrams/drawio docs/exports/V2_As-Is_Process.docx "V2 — As-Is Process Guide"
python3 scripts/md_to_docx.py docs/V3_BUS_BestPractice.md docs/diagrams/drawio docs/exports/V3_Best_Practice_Process.docx "V3 — Best Practice Process Guide"
```

For every `![alt](...drawio)` image reference in the markdown, this:

1. matches it to a `.drawio` page by alt-text-to-page-name (`build_page_index`),
2. renders that page to its own standalone `.vsdx` (`drawio_to_vsdx.py`) — real Visio
   shapes/connectors, not a picture — plus a PNG preview (`render_drawio.py`),
3. converts MkDocs-only syntax (`!!! admonition`, `=== tabs`) to plain Pandoc markdown,
4. runs Pandoc for all text/tables/headings, then
5. embeds each `.vsdx` as a genuine Word **OLE object** (`embed_vsdx_ole.py`) at the
   diagram's position: the PNG shows as a static preview in the document, and
   double-clicking it opens the diagram for editing in Microsoft Visio.

## 4. Generate standalone .vsdx files only

```
python3 scripts/drawio_to_vsdx.py docs/diagrams/drawio /tmp/vsdx_out
```

Writes one `.vsdx` per page, independent of the Word export, if you just want Visio
files to open/edit directly.

## Known limitations

- The renderer/vsdx-builder are a simplified mxGraph interpreter (rectangles, ellipses,
  rhombuses, orthogonal edges with auto-elbow routing) — they do not support every
  drawio shape or style option, only what this repo's diagrams currently use.
- Edge label placement can crowd against a nearby box when two shapes are very close
  together (a pre-existing density issue in a couple of pages, not a rendering bug).
- Embedded diagram edges are drawn as plain lines (not glued to their shapes), so
  dragging a box in Visio won't drag its connectors with it — reposition both together
  if you edit the layout.
- Opening the embedded object requires Microsoft Visio (or a compatible viewer) on the
  editor's machine; this sandbox cannot render either format visually, so all
  validation here is structural (reopening via `python-docx`/`vsdx`, XML well-formedness,
  relationship/content-type consistency) rather than a rendered screenshot.
