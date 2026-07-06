#!/usr/bin/env python3
"""Render mxGraph .drawio pages to static SVG (then PNG) directly from XML,
without needing the JS viewer. Reuses the same parsing logic as review_diagrams.py."""
import re, sys, os, html, subprocess

def parse_page(body):
    raw = {}
    for m in re.finditer(
        r'<mxCell id="([^"]+)" value="([^"]*)" style="([^"]*)"[^>]*vertex="1"[^>]*parent="([^"]+)">\s*'
        r'<mxGeometry x="(-?\d+)" y="(-?\d+)" width="(\d+)" height="(\d+)"',
        body):
        nid, val, style, parent, x, y, w, h = m.groups()
        raw[nid] = dict(x=int(x), y=int(y), w=int(w), h=int(h), val=val, style=style, parent=parent)
    nodes = {}
    for nid, n in raw.items():
        x, y = n['x'], n['y']
        p = n['parent']; depth = 0
        while p != "1" and p in raw and depth < 10:
            x += raw[p]['x']; y += raw[p]['y']; p = raw[p]['parent']; depth += 1
        nodes[nid] = dict(x=x, y=y, w=n['w'], h=n['h'], val=n['val'], style=n['style'])

    edges = []
    for m in re.finditer(r'<mxCell id="([^"]+)"([^>]*)edge="1"([^>]*)>(.*?)</mxCell>', body, re.S):
        eid, pre, post, inner = m.groups()
        attrs = pre + post
        sm = re.search(r'source="([^"]+)"', attrs)
        tm = re.search(r'target="([^"]+)"', attrs)
        stym = re.search(r'style="([^"]*)"', attrs)
        valm = re.search(r'value="([^"]*)"', attrs)
        waypoints = [(int(x), int(y)) for x, y in re.findall(r'<mxPoint x="(-?\d+)" y="(-?\d+)"\s*/>', inner)]
        if sm and tm:
            edges.append(dict(id=eid, source=sm.group(1), target=tm.group(1),
                               style=stym.group(1) if stym else "",
                               val=valm.group(1) if valm else "", waypoints=waypoints))
    m = re.search(r'pageWidth="(\d+)" pageHeight="(\d+)"', body)
    pw, ph = (int(m.group(1)), int(m.group(2))) if m else (1000, 700)
    return nodes, edges, pw, ph

def style_get(style, key, default=None):
    m = re.search(re.escape(key) + r'=([^;]*)', style)
    return m.group(1) if m else default

def unescape_val(v):
    v = v.replace("&#xa;", "\n")
    return html.unescape(v)

def wrap_text(text, max_chars=26):
    lines = []
    for para in text.split("\n"):
        words = para.split(" ")
        cur = ""
        for w in words:
            if len(cur) + len(w) + 1 <= max_chars:
                cur = (cur + " " + w).strip()
            else:
                if cur:
                    lines.append(cur)
                cur = w
        if cur:
            lines.append(cur)
    return lines or [""]

def node_svg(nid, n):
    style = n['style']
    x, y, w, h = n['x'], n['y'], n['w'], n['h']
    fill = style_get(style, "fillColor", "#dae8fc")
    stroke = style_get(style, "strokeColor", "#6c8ebf")
    fontcolor = style_get(style, "fontColor", "#000000")
    is_ellipse = "ellipse" in style
    is_rhombus = "rhombus" in style
    is_note = "shape=note" in style
    is_text_only = style.startswith("text;")
    fontsize = style_get(style, "fontSize", "12")
    bold = "fontStyle=1" in style

    parts = []
    if is_text_only:
        pass  # no shape, just text below
    elif is_ellipse:
        parts.append(f'<ellipse cx="{x+w/2}" cy="{y+h/2}" rx="{w/2}" ry="{h/2}" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
    elif is_rhombus:
        pts = f"{x+w/2},{y} {x+w},{y+h/2} {x+w/2},{y+h} {x},{y+h/2}"
        parts.append(f'<polygon points="{pts}" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
    elif is_note:
        parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="{fill}" stroke="{stroke}" stroke-width="1.5" stroke-dasharray="4,2"/>')
    else:
        dashed = 'stroke-dasharray="6,4"' if "dashed=1" in style else ""
        parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill}" stroke="{stroke}" stroke-width="1.5" {dashed}/>')

    text = unescape_val(n['val'])
    lines = wrap_text(text, max_chars=max(14, int(w/7)))
    line_h = 14
    total_h = len(lines) * line_h
    weight = "bold" if bold else "normal"

    valign = style_get(style, "verticalAlign", "middle")
    halign = style_get(style, "align", "center")
    pad = 12
    if valign == "top":
        start_y = y + pad + line_h*0.8
    else:
        start_y = y + h/2 - total_h/2 + line_h*0.8
    if halign == "left":
        tx = x + style_get_num(style, "spacingLeft", pad)
        anchor = "start"
    else:
        tx = x + w/2
        anchor = "middle"

    for i, line in enumerate(lines):
        ly = start_y + i*line_h
        esc = html.escape(line)
        parts.append(f'<text x="{tx}" y="{ly}" font-family="Arial" font-size="{fontsize}" font-weight="{weight}" fill="{fontcolor}" text-anchor="{anchor}">{esc}</text>')
    return "\n".join(parts)

def style_get_num(style, key, default):
    v = style_get(style, key, None)
    try:
        return float(v)
    except (TypeError, ValueError):
        return default

def edge_points(e, nodes):
    src, tgt = nodes[e['source']], nodes[e['target']]
    style = e['style']
    def pt(node, prefix):
        xm = re.search(prefix+r'X=([\d.]+)', style)
        ym = re.search(prefix+r'Y=([\d.]+)', style)
        fx = float(xm.group(1)) if xm else 0.5
        fy = float(ym.group(1)) if ym else 0.5
        return (node['x'] + fx*node['w'], node['y'] + fy*node['h'], fx, fy)
    x1, y1, ex, ey = pt(src, 'exit')
    x2, y2, tx, ty = pt(tgt, 'entry')
    p1 = (x1, y1)
    p2 = (x2, y2)
    waypoints = e.get('waypoints', [])
    if waypoints:
        return [p1] + waypoints + [p2]
    if x1 == x2 or y1 == y2:
        return [p1, p2]

    exit_vertical = ey in (0.0, 1.0)
    entry_vertical = ty in (0.0, 1.0)
    exit_horizontal = ex in (0.0, 1.0)
    entry_horizontal = tx in (0.0, 1.0)

    if exit_vertical and entry_vertical:
        # travel through the gap between the two rows, not through either row
        mid_y = (y1 + y2) / 2
        return [p1, (x1, mid_y), (x2, mid_y), p2]
    if exit_horizontal and entry_horizontal:
        mid_x = (x1 + x2) / 2
        return [p1, (mid_x, y1), (mid_x, y2), p2]
    # perpendicular mix: simple 2-segment elbow is safe (no shared row/column)
    if exit_horizontal:
        elbow = (x2, y1)
    else:
        elbow = (x1, y2)
    return [p1, elbow, p2]

def edge_svg(e, nodes):
    pts = edge_points(e, nodes)
    stroke = style_get(e['style'], "strokeColor", "#333333")
    sw = style_get(e['style'], "strokeWidth", "1.2")
    path = f'M {pts[0][0]},{pts[0][1]} ' + " ".join(f'L {x},{y}' for x, y in pts[1:])
    parts = [f'<path d="{path}" fill="none" stroke="{stroke}" stroke-width="{sw}" marker-end="url(#arrow)"/>']
    if e['val']:
        mx, my = pts[len(pts)//2]
        # midpoint of the middle segment for label placement
        i = max(0, len(pts)//2 - 1)
        mx = (pts[i][0] + pts[i+1][0]) / 2
        my = (pts[i][1] + pts[i+1][1]) / 2 - 6
        label = html.escape(unescape_val(e['val']).replace("\n", " "))
        parts.append(f'<rect x="{mx-len(label)*3.2-3}" y="{my-11}" width="{len(label)*6.4+6}" height="14" fill="white" opacity="0.85"/>')
        parts.append(f'<text x="{mx}" y="{my}" font-family="Arial" font-size="10.5" fill="#333333" text-anchor="middle">{label}</text>')
    return "\n".join(parts)

def render_page(name, nodes, edges, pw, ph):
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{pw}" height="{ph}" viewBox="0 0 {pw} {ph}">']
    svg.append('<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="3" orient="auto" markerUnits="strokeWidth"><path d="M0,0 L0,6 L7,3 z" fill="#333333"/></marker></defs>')
    svg.append(f'<rect x="0" y="0" width="{pw}" height="{ph}" fill="white"/>')
    # containers first (dashed group boxes), then regular nodes, then edges+labels
    # on top so a node's fill never occludes an edge label that lands near its border.
    containers = {k: v for k, v in nodes.items() if 'dashed=1' in v['style'] and ('rounded=1' in v['style'])}
    others = {k: v for k, v in nodes.items() if k not in containers}
    for nid, n in containers.items():
        svg.append(node_svg(nid, n))
    for nid, n in others.items():
        svg.append(node_svg(nid, n))
    for e in edges:
        if e['source'] in nodes and e['target'] in nodes:
            svg.append(edge_svg(e, nodes))
    svg.append('</svg>')
    return "\n".join(svg)

def main(drawio_path, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    content = open(drawio_path).read()
    diagrams = re.findall(r'<diagram id="([^"]*)" name="([^"]*)">(.*?)</diagram>', content, re.S)
    results = []
    for did, name, body in diagrams:
        nodes, edges, pw, ph = parse_page(body)
        svg = render_page(name, nodes, edges, pw, ph)
        safe_name = re.sub(r'[^a-zA-Z0-9]+', '_', name).strip('_')
        svg_path = os.path.join(out_dir, f"{safe_name}.svg")
        png_path = os.path.join(out_dir, f"{safe_name}.png")
        open(svg_path, "w").write(svg)
        subprocess.run(["rsvg-convert", "-w", str(pw*1), "-o", png_path, svg_path], check=True)
        results.append((did, name, svg_path, png_path))
        print(f"rendered: {name} -> {png_path}")
    return results

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
