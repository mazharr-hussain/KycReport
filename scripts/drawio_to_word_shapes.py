#!/usr/bin/env python3
"""Render a .drawio page as NATIVE, editable Word drawing shapes (rectangles,
ellipses, rhombuses, and connectors with arrowheads) instead of a picture --
each box and arrow is a real Word shape you can click, drag, and re-text.

Reuses the same mxGraph XML parsing and routing logic as render_drawio.py
(they must be kept in sync if the .drawio structure assumptions change).
"""
import re, html
from lxml import etree

NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
    'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
    'wps': 'http://schemas.microsoft.com/office/word/2010/wordprocessingShape',
    'wpg': 'http://schemas.microsoft.com/office/word/2010/wordprocessingGroup',
}
EMU_PER_PX = 9525

# ---------- mxGraph XML parsing (same approach as render_drawio.py) ----------

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
    return html.unescape(v.replace("&#xa;", "\n"))

def edge_points(e, nodes):
    src, tgt = nodes[e['source']], nodes[e['target']]
    style = e['style']
    def pt(node, prefix):
        xm = re.search(prefix + r'X=([\d.]+)', style)
        ym = re.search(prefix + r'Y=([\d.]+)', style)
        fx = float(xm.group(1)) if xm else 0.5
        fy = float(ym.group(1)) if ym else 0.5
        return (node['x'] + fx * node['w'], node['y'] + fy * node['h'], fx, fy)
    x1, y1, ex, ey = pt(src, 'exit')
    x2, y2, tx, ty = pt(tgt, 'entry')
    p1, p2 = (x1, y1), (x2, y2)
    waypoints = e.get('waypoints', [])
    if waypoints:
        return [p1] + waypoints + [p2]
    if x1 == x2 or y1 == y2:
        return [p1, p2]
    exit_vertical, entry_vertical = ey in (0.0, 1.0), ty in (0.0, 1.0)
    exit_horizontal, entry_horizontal = ex in (0.0, 1.0), tx in (0.0, 1.0)
    if exit_vertical and entry_vertical:
        mid_y = (y1 + y2) / 2
        return [p1, (x1, mid_y), (x2, mid_y), p2]
    if exit_horizontal and entry_horizontal:
        mid_x = (x1 + x2) / 2
        return [p1, (mid_x, y1), (mid_x, y2), p2]
    elbow = (x2, y1) if exit_horizontal else (x1, y2)
    return [p1, elbow, p2]

# ---------- OOXML shape construction ----------

def make_el(tag, attrs=None):
    prefix, local = tag.split(":")
    el = etree.Element(f"{{{NS[prefix]}}}{local}")
    if attrs:
        for k, v in attrs.items():
            el.set(k, str(v))
    return el

def sub_el(parent, tag, attrs=None):
    prefix, local = tag.split(":")
    el = etree.SubElement(parent, f"{{{NS[prefix]}}}{local}")
    if attrs:
        for k, v in attrs.items():
            el.set(k, str(v))
    return el

_shape_id_counter = [100]
def next_id():
    _shape_id_counter[0] += 1
    return _shape_id_counter[0]

PRESET_GEOM = {
    "ellipse": "ellipse",
    "rhombus": "diamond",
    "note": "roundRect",
    "rect": "roundRect",
}

def node_to_shape(n):
    style = n['style']
    def clean_hex(raw, default):
        v = (raw or "").lstrip("#")
        return v if re.fullmatch(r"[0-9A-Fa-f]{6}", v) else default

    fill_raw = style_get(style, "fillColor", "#DAE8FC")
    fill_none = (fill_raw or "").lower() == "none"
    fill = clean_hex(fill_raw, "DAE8FC")
    stroke = clean_hex(style_get(style, "strokeColor", "#6C8EBF"), "6C8EBF")
    fontcolor = clean_hex(style_get(style, "fontColor", "#000000"), "000000")
    bold = "fontStyle=1" in style
    is_text_only = style.startswith("text;")

    if is_text_only:
        prst = "rect"
        fill = None
    elif "ellipse" in style:
        prst = "ellipse"
    elif "rhombus" in style:
        prst = "diamond"
    elif "shape=note" in style:
        prst = "roundRect"
    else:
        prst = "roundRect"

    wsp = make_el("wps:wsp")
    nvSpPr = sub_el(wsp, "wps:nvSpPr")
    sub_el(nvSpPr, "wps:cNvPr", {"id": next_id(), "name": "Shape"})
    sub_el(nvSpPr, "wps:cNvSpPr")

    spPr = sub_el(wsp, "wps:spPr")
    xfrm = sub_el(spPr, "a:xfrm")
    sub_el(xfrm, "a:off", {"x": int(n['x'] * EMU_PER_PX), "y": int(n['y'] * EMU_PER_PX)})
    sub_el(xfrm, "a:ext", {"cx": int(n['w'] * EMU_PER_PX), "cy": int(n['h'] * EMU_PER_PX)})
    prstGeom = sub_el(spPr, "a:prstGeom", {"prst": prst})
    sub_el(prstGeom, "a:avLst")
    if fill and not is_text_only and not fill_none:
        solidFill = sub_el(spPr, "a:solidFill")
        sub_el(solidFill, "a:srgbClr", {"val": fill})
    else:
        sub_el(spPr, "a:noFill")
    ln = sub_el(spPr, "a:ln")
    if is_text_only:
        sub_el(ln, "a:noFill")
    else:
        lnFill = sub_el(ln, "a:solidFill")
        sub_el(lnFill, "a:srgbClr", {"val": stroke})
        if "dashed=1" in style:
            sub_el(ln, "a:prstDash", {"val": "dash"})

    text = unescape_val(n['val'])
    txbx = sub_el(wsp, "wps:txbx")
    txbxContent = sub_el(txbx, "w:txbxContent")
    for line in text.split("\n") or [""]:
        p = sub_el(txbxContent, "w:p")
        pPr = sub_el(p, "w:pPr")
        halign = style_get(style, "align", "center")
        sub_el(pPr, "w:jc", {"val": "left" if halign == "left" else "center"})
        r = sub_el(p, "w:r")
        rPr = sub_el(r, "w:rPr")
        if bold:
            sub_el(rPr, "w:b")
        sub_el(rPr, "w:color", {"val": fontcolor})
        sz = style_get(style, "fontSize", "12")
        sub_el(rPr, "w:sz", {"val": str(int(float(sz) * 2))})
        t = sub_el(r, "w:t")
        t.set("{http://www.w3.org/XML/1998/namespace}space", "preserve")
        t.text = line
    bodyPr_attrs = {"anchor": "t" if style_get(style, "verticalAlign", "middle") == "top" else "ctr",
                    "lIns": "45720" if style_get(style, "align") == "left" else "91440",
                    "tIns": "45720", "rIns": "91440", "bIns": "45720", "wrap": "square"}
    sub_el(wsp, "wps:bodyPr", bodyPr_attrs)
    return wsp

def make_connector_segment(x1, y1, x2, y2, color="333333", with_arrow=False, width=12700):
    cxn = make_el("wps:cxnSp")
    nvCxnSpPr = sub_el(cxn, "wps:nvCxnSpPr")
    sub_el(nvCxnSpPr, "wps:cNvPr", {"id": next_id(), "name": "Connector"})
    sub_el(nvCxnSpPr, "wps:cNvCxnSpPr")
    spPr = sub_el(cxn, "wps:spPr")
    x, y = min(x1, x2), min(y1, y2)
    w, h = abs(x2 - x1) or 1, abs(y2 - y1) or 1
    xfrm = sub_el(spPr, "a:xfrm")
    if x2 < x1:
        xfrm.set("flipH", "1")
    if y2 < y1:
        xfrm.set("flipV", "1")
    sub_el(xfrm, "a:off", {"x": int(x * EMU_PER_PX), "y": int(y * EMU_PER_PX)})
    sub_el(xfrm, "a:ext", {"cx": int(w * EMU_PER_PX), "cy": int(h * EMU_PER_PX)})
    prstGeom = sub_el(spPr, "a:prstGeom", {"prst": "line"})
    sub_el(prstGeom, "a:avLst")
    ln = sub_el(spPr, "a:ln", {"w": str(width)})
    lnFill = sub_el(ln, "a:solidFill")
    sub_el(lnFill, "a:srgbClr", {"val": color})
    if with_arrow:
        sub_el(ln, "a:tailEnd", {"type": "triangle", "w": "med", "len": "med"})
    return cxn

def make_label(text, cx, cy, w=140, h=18):
    wsp = make_el("wps:wsp")
    nvSpPr = sub_el(wsp, "wps:nvSpPr")
    sub_el(nvSpPr, "wps:cNvPr", {"id": next_id(), "name": "Label"})
    sub_el(nvSpPr, "wps:cNvSpPr")
    spPr = sub_el(wsp, "wps:spPr")
    xfrm = sub_el(spPr, "a:xfrm")
    sub_el(xfrm, "a:off", {"x": int((cx - w/2) * EMU_PER_PX), "y": int((cy - h/2) * EMU_PER_PX)})
    sub_el(xfrm, "a:ext", {"cx": int(w * EMU_PER_PX), "cy": int(h * EMU_PER_PX)})
    prstGeom = sub_el(spPr, "a:prstGeom", {"prst": "rect"})
    sub_el(prstGeom, "a:avLst")
    solidFill = sub_el(spPr, "a:solidFill")
    sub_el(solidFill, "a:srgbClr", {"val": "FFFFFF"})
    ln = sub_el(spPr, "a:ln")
    sub_el(ln, "a:noFill")
    txbx = sub_el(wsp, "wps:txbx")
    txbxContent = sub_el(txbx, "w:txbxContent")
    p = sub_el(txbxContent, "w:p")
    pPr = sub_el(p, "w:pPr")
    sub_el(pPr, "w:jc", {"val": "center"})
    r = sub_el(p, "w:r")
    rPr = sub_el(r, "w:rPr")
    sub_el(rPr, "w:sz", {"val": "18"})
    t = sub_el(r, "w:t")
    t.set("{http://www.w3.org/XML/1998/namespace}space", "preserve")
    t.text = text
    sub_el(wsp, "wps:bodyPr", {"anchor": "ctr", "lIns": "0", "tIns": "0", "rIns": "0", "bIns": "0"})
    return wsp

def build_group_drawing(children, group_w, group_h, name="Diagram"):
    drawing = make_el("w:drawing")
    inline = sub_el(drawing, "wp:inline", {"distT": "0", "distB": "0", "distL": "0", "distR": "0"})
    sub_el(inline, "wp:extent", {"cx": int(group_w * EMU_PER_PX), "cy": int(group_h * EMU_PER_PX)})
    sub_el(inline, "wp:effectExtent", {"l": "0", "t": "0", "r": "0", "b": "0"})
    sub_el(inline, "wp:docPr", {"id": next_id(), "name": name})
    cNvGraphicFramePr = sub_el(inline, "wp:cNvGraphicFramePr")
    graphic = sub_el(inline, "a:graphic")
    graphicData = sub_el(graphic, "a:graphicData", {"uri": NS['wpg']})
    wgp = sub_el(graphicData, "wpg:wgp")
    sub_el(wgp, "wpg:cNvGrpSpPr")
    grpSpPr = sub_el(wgp, "wpg:grpSpPr")
    xfrm = sub_el(grpSpPr, "a:xfrm")
    sub_el(xfrm, "a:off", {"x": 0, "y": 0})
    sub_el(xfrm, "a:ext", {"cx": int(group_w * EMU_PER_PX), "cy": int(group_h * EMU_PER_PX)})
    sub_el(xfrm, "a:chOff", {"x": 0, "y": 0})
    sub_el(xfrm, "a:chExt", {"cx": int(group_w * EMU_PER_PX), "cy": int(group_h * EMU_PER_PX)})
    for c in children:
        wgp.append(c)
    return drawing

def render_page_to_drawing(name, nodes, edges, pw, ph):
    children = []
    containers = {k: v for k, v in nodes.items() if 'dashed=1' in v['style'] and ('rounded=1' in v['style'])}
    others = {k: v for k, v in nodes.items() if k not in containers}
    for nid, n in containers.items():
        children.append(node_to_shape(n))
    for nid, n in others.items():
        children.append(node_to_shape(n))
    for e in edges:
        if e['source'] not in nodes or e['target'] not in nodes:
            continue
        pts = edge_points(e, nodes)
        for i in range(len(pts) - 1):
            is_last = (i == len(pts) - 2)
            (x1, y1), (x2, y2) = pts[i], pts[i+1]
            if abs(x1 - x2) < 1 and abs(y1 - y2) < 1:
                continue
            children.append(make_connector_segment(x1, y1, x2, y2, with_arrow=is_last))
        if e['val']:
            mid_i = max(0, len(pts) // 2 - 1)
            mx = (pts[mid_i][0] + pts[mid_i+1][0]) / 2
            my = (pts[mid_i][1] + pts[mid_i+1][1]) / 2
            label_text = unescape_val(e['val']).replace("\n", " ")
            children.append(make_label(label_text, mx, my))
    return build_group_drawing(children, pw, ph, name)

def render_drawio_pages(drawio_path):
    """Returns list of (page_name, w:drawing element, pw, ph)."""
    content = open(drawio_path).read()
    diagrams = re.findall(r'<diagram id="([^"]*)" name="([^"]*)">(.*?)</diagram>', content, re.S)
    results = []
    for did, name, body in diagrams:
        nodes, edges, pw, ph = parse_page(body)
        drawing = render_page_to_drawing(name, nodes, edges, pw, ph)
        results.append((name, drawing, pw, ph))
    return results
