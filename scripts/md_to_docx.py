#!/usr/bin/env python3
"""Convert a V2/V3 KYC markdown doc to .docx, substituting drawio image
embeds with the pre-rendered static PNGs (by matching alt text to page name),
and converting MkDocs-specific admonition syntax to something Pandoc understands.
"""
import re, sys, os, subprocess, glob

def safe_name(name):
    return re.sub(r'[^a-zA-Z0-9]+', '_', name).strip('_')

def build_png_index(rendered_root):
    """page name -> png path, searched across all rendered subfolders."""
    idx = {}
    for png in glob.glob(os.path.join(rendered_root, "*", "*.png")):
        base = os.path.splitext(os.path.basename(png))[0]
        idx[base] = png
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

def substitute_images(md, png_index, base_dir):
    def repl(m):
        alt, path = m.group(1), m.group(2)
        if not path.endswith(".drawio"):
            return m.group(0)
        key = safe_name(alt)
        png = png_index.get(key)
        if not png:
            return f"\n> *[Diagram not found for rendering: {alt}]*\n"
        rel = os.path.relpath(png, base_dir)
        return f"![{alt}]({rel})"
    return re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', repl, md)

def strip_mkdocs_only_syntax(md):
    # tabs "=== \"Label\"" -> a bold label line, dedent the body
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
    md = re.sub(r'\{\.[\w-]+(\s+[\w-]+="[^"]*")*\}', '', md)  # attr_list leftovers
    return md

def main(md_path, rendered_root, out_docx, title):
    md = open(md_path).read()
    base_dir = os.path.dirname(os.path.abspath(md_path))
    png_index = build_png_index(rendered_root)
    md = convert_admonitions(md)
    md = strip_mkdocs_only_syntax(md)
    md = substitute_images(md, png_index, base_dir)

    tmp_md = out_docx + ".tmp.md"
    with open(tmp_md, "w") as f:
        f.write(f"% {title}\n\n")
        f.write(md)

    subprocess.run([
        "pandoc", tmp_md,
        "-o", out_docx,
        "--from", "markdown+pipe_tables+grid_tables",
        "--toc", "--toc-depth=2",
        "--resource-path", base_dir,
    ], check=True)
    os.remove(tmp_md)
    print(f"wrote {out_docx}")

if __name__ == "__main__":
    main(*sys.argv[1:5])
