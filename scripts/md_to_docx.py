#!/usr/bin/env python3
"""Convert a V2/V3 KYC markdown doc to .docx, replacing drawio image embeds
with NATIVE, editable Word shapes (rectangles/diamonds/ellipses + connectors,
not pictures) rendered directly from the .drawio XML, and converting
MkDocs-specific admonition/tab syntax to something Pandoc understands.

Two-pass approach: Pandoc handles all normal text/tables/headings (it has no
concept of native Word shapes), then this script re-opens the resulting
.docx and swaps a placeholder paragraph per diagram for the real shape
drawing, built by scripts/drawio_to_word_shapes.py.
"""
import re, sys, os, subprocess, glob, tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drawio_to_vsdx import render_drawio_to_vsdx_files, safe_name
import render_drawio
from embed_vsdx_ole import embed_diagrams

PLACEHOLDER_PREFIX = "■DIAGRAM■"

def build_page_index(drawio_dir, work_dir):
    """page-name-key -> {vsdx_path, png_path}. Renders both a .vsdx (for the
    editable OLE object) and a .png (as the static preview shown until it's
    double-clicked) for every page of every .drawio file in drawio_dir."""
    vsdx_dir = os.path.join(work_dir, "vsdx")
    png_dir = os.path.join(work_dir, "png")
    os.makedirs(vsdx_dir, exist_ok=True)
    os.makedirs(png_dir, exist_ok=True)
    idx = {}
    for path in glob.glob(os.path.join(drawio_dir, "*.drawio")):
        vsdx_paths = render_drawio_to_vsdx_files(path, vsdx_dir)
        render_drawio.main(path, png_dir)
        for key, vsdx_path in vsdx_paths.items():
            png_path = os.path.join(png_dir, key + ".png")
            if not os.path.isfile(png_path):
                continue
            idx[key] = dict(vsdx_path=vsdx_path, png_path=png_path)
    return idx

def convert_admonitions(md):
    """Convert MkDocs '!!! type "Title"' blocks (4-space indented body) into
    a blockquote with a bold title line, which Pandoc renders natively."""
    lines = md.split("\n")
    out = []
    i = 0
    while i < len(lines):
        m = re.match(r'!!!\s+(\w+)\s*"([^"]*)"', lines[i])
        if m:
            kind, title = m.groups()
            out.append(f"> **{title}**")
            out.append(">")
            i += 1
            while i < len(lines) and (lines[i].startswith("    ") or lines[i].strip() == ""):
                body = lines[i][4:] if lines[i].startswith("    ") else ""
                out.append("> " + body if body else ">")
                i += 1
            continue
        out.append(lines[i])
        i += 1
    return "\n".join(out)

def substitute_images(md, page_index):
    missing = []
    def repl(m):
        alt, path = m.group(1), m.group(2)
        if not path.endswith(".drawio"):
            return m.group(0)
        key = safe_name(alt)
        if key not in page_index:
            missing.append(alt)
            return f"\n> *[Diagram not found for rendering: {alt}]*\n"
        return f"\n{PLACEHOLDER_PREFIX}{key}{PLACEHOLDER_PREFIX}\n"
    new_md = re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', repl, md)
    return new_md, missing

def strip_mkdocs_only_syntax(md):
    lines = md.split("\n")
    out = []
    i = 0
    while i < len(lines):
        m = re.match(r'=== "([^"]*)"', lines[i])
        if m:
            out.append(f"**{m.group(1)}**")
            out.append("")
            i += 1
            while i < len(lines) and (lines[i].startswith("    ") or lines[i].strip() == ""):
                body = lines[i][4:] if lines[i].startswith("    ") else ""
                out.append(body)
                i += 1
            continue
        out.append(lines[i])
        i += 1
    md = "\n".join(out)
    md = re.sub(r'\{\.[\w-]+(\s+[\w-]+="[^"]*")*\}', '', md)
    return md

def main(md_path, drawio_dir, out_docx, title):
    md = open(md_path).read()
    with tempfile.TemporaryDirectory(prefix="md_to_docx_") as work_dir:
        page_index = build_page_index(drawio_dir, work_dir)
        md = convert_admonitions(md)
        md = strip_mkdocs_only_syntax(md)
        md, missing = substitute_images(md, page_index)
        if missing:
            print("WARNING: no diagram page found for:", missing)

        tmp_md = out_docx + ".tmp.md"
        with open(tmp_md, "w") as f:
            f.write(f"% {title}\n\n")
            f.write(md)

        subprocess.run([
            "pandoc", tmp_md,
            "-o", out_docx,
            "--from", "markdown+pipe_tables+grid_tables",
            "--toc", "--toc-depth=2",
        ], check=True)
        os.remove(tmp_md)

        embedded, unmatched = embed_diagrams(out_docx, PLACEHOLDER_PREFIX, page_index)
    if unmatched:
        print("WARNING: placeholder found but no matching page for:", unmatched)
    print(f"wrote {out_docx} ({embedded} editable Visio diagrams embedded as OLE objects)")

if __name__ == "__main__":
    main(*sys.argv[1:5])
