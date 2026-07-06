#!/usr/bin/env python3
"""Convert each page of a .drawio file into a standalone, fully editable
Visio (.vsdx) file: real Visio shapes (rectangles/diamonds/ellipses) and
connector lines, not a picture.

Built by cloning the minimal VSDX package that ships with the `vsdx` pip
package (masters/document/windows parts are boilerplate and reused as-is)
and generating our own `visio/pages/page1.xml` + `visio/pages/pages.xml`
from the same mxGraph parsing logic used for the Word-native-shapes export
(scripts/drawio_to_word_shapes.py) and the static SVG renderer
(scripts/render_drawio.py) -- keep all three in sync if the .drawio
structure assumptions change.

VSDX page coordinates are inches, Y-axis pointing UP (opposite of SVG/
drawio's top-down px), which is why every Y coordinate below is flipped
against the page height.
"""
import os, re, sys, math, shutil, zipfile, glob

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drawio_to_word_shapes import parse_page, style_get, unescape_val, edge_points

import vsdx
TEMPLATE_VSDX = os.path.join(os.path.dirname(vsdx.__file__), "media", "media.vsdx")

PX_PER_IN = 96.0
MARGIN_IN = 0.5

VISIO_NS_OPEN = ("<?xml version='1.0' encoding='utf-8' ?>\n"
                 "<PageContents xmlns='http://schemas.microsoft.com/office/visio/2012/main' "
                 "xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships' "
                 "xml:space='preserve'>")

def esc(s):
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
             .replace('"', "&quot;"))

def clean_hex(raw, default):
    v = (raw or "").lstrip("#")
    return v if re.fullmatch(r"[0-9A-Fa-f]{6}", v) else default

_id_counter = [0]
def next_id():
    _id_counter[0] += 1
    return _id_counter[0]

def rect_geometry():
    return ("<Row T='RelMoveTo' IX='1'><Cell N='X' V='0'/><Cell N='Y' V='0'/></Row>"
            "<Row T='RelLineTo' IX='2'><Cell N='X' V='1'/><Cell N='Y' V='0'/></Row>"
            "<Row T='RelLineTo' IX='3'><Cell N='X' V='1'/><Cell N='Y' V='1'/></Row>"
            "<Row T='RelLineTo' IX='4'><Cell N='X' V='0'/><Cell N='Y' V='1'/></Row>"
            "<Row T='RelLineTo' IX='5'><Cell N='X' V='0'/><Cell N='Y' V='0'/></Row>")

def diamond_geometry():
    return ("<Row T='RelMoveTo' IX='1'><Cell N='X' V='0.5'/><Cell N='Y' V='0'/></Row>"
            "<Row T='RelLineTo' IX='2'><Cell N='X' V='1'/><Cell N='Y' V='0.5'/></Row>"
            "<Row T='RelLineTo' IX='3'><Cell N='X' V='0.5'/><Cell N='Y' V='1'/></Row>"
            "<Row T='RelLineTo' IX='4'><Cell N='X' V='0'/><Cell N='Y' V='0.5'/></Row>"
            "<Row T='RelLineTo' IX='5'><Cell N='X' V='0.5'/><Cell N='Y' V='0'/></Row>")

def ellipse_geometry(w_in, h_in):
    return (f"<Row T='Ellipse' IX='1'><Cell N='X' V='{w_in/2}'/><Cell N='Y' V='{h_in/2}'/>"
            f"<Cell N='A' V='{w_in}'/><Cell N='B' V='{h_in/2}'/>"
            f"<Cell N='C' V='{w_in/2}'/><Cell N='D' V='{h_in}'/></Row>")

def text_block(text):
    lines = text.split("\n") if text else [""]
    return "".join(esc(line) + "&#10;" for line in lines)

def make_shape_xml(n, page_h_in):
    style = n['style']
    is_text_only = style.startswith("text;")
    if is_text_only:
        prst = "rect"
    elif "ellipse" in style:
        prst = "ellipse"
    elif "rhombus" in style:
        prst = "diamond"
    else:
        prst = "rect"

    x_in = n['x'] / PX_PER_IN
    y_in = n['y'] / PX_PER_IN
    w_in = max(n['w'] / PX_PER_IN, 0.05)
    h_in = max(n['h'] / PX_PER_IN, 0.05)
    pin_x = MARGIN_IN + x_in + w_in / 2
    pin_y = page_h_in - MARGIN_IN - (y_in + h_in / 2)

    fill_raw = style_get(style, "fillColor", "#DAE8FC")
    fill_none = is_text_only or (fill_raw or "").lower() == "none"
    fill = clean_hex(fill_raw, "DAE8FC")
    stroke_none = is_text_only
    stroke = clean_hex(style_get(style, "strokeColor", "#6C8EBF"), "6C8EBF")
    fontcolor = clean_hex(style_get(style, "fontColor", "#000000"), "000000")
    bold = "fontStyle=1" in style
    fontsize_pt = float(style_get(style, "fontSize", "12"))
    fontsize_in = fontsize_pt / 72.0

    if prst == "diamond":
        geom = diamond_geometry()
    elif prst == "ellipse":
        geom = ellipse_geometry(w_in, h_in)
    else:
        geom = rect_geometry()

    sid = next_id()
    is_dashed = "dashed=1" in style and not stroke_none
    fill_cells = (f"<Cell N='FillForegnd' V='{'#FFFFFF' if fill_none else '#' + fill}'/>"
                  f"<Cell N='FillPattern' V='{'0' if fill_none else '1'}'/>")
    line_cells = (f"<Cell N='LineColor' V='{'#FFFFFF' if stroke_none else '#' + stroke}'/>"
                  f"<Cell N='LinePattern' V='{'2' if is_dashed else ('0' if stroke_none else '1')}'/>")
    dash_cell = ""

    return (
        f"<Shape ID='{sid}' Type='Shape' LineStyle='3' FillStyle='3' TextStyle='3'>"
        f"<Cell N='PinX' V='{pin_x}'/><Cell N='PinY' V='{pin_y}'/>"
        f"<Cell N='Width' V='{w_in}'/><Cell N='Height' V='{h_in}'/>"
        f"<Cell N='LocPinX' V='{w_in/2}'/><Cell N='LocPinY' V='{h_in/2}'/>"
        f"<Cell N='Angle' V='0'/>"
        f"{fill_cells}{line_cells}{dash_cell}"
        f"<Cell N='Color' V='#{fontcolor}'/>"
        f"<Cell N='Style' V='{1 if bold else 0}'/>"
        f"<Cell N='Size' V='{fontsize_in}'/>"
        f"<Section N='Geometry' IX='0'>{geom}</Section>"
        f"<Text>{text_block(unescape_val(n['val']))}</Text>"
        f"</Shape>"
    )

def make_line_xml(x1, y1, x2, y2, page_h_in, with_arrow):
    bx, by = MARGIN_IN + x1 / PX_PER_IN, page_h_in - MARGIN_IN - y1 / PX_PER_IN
    ex, ey = MARGIN_IN + x2 / PX_PER_IN, page_h_in - MARGIN_IN - y2 / PX_PER_IN
    dx, dy = ex - bx, ey - by
    length = math.hypot(dx, dy) or 0.001
    angle = math.atan2(dy, dx)
    pin_x, pin_y = (bx + ex) / 2, (by + ey) / 2
    sid = next_id()
    arrow_cell = "<Cell N='EndArrow' V='5'/><Cell N='EndArrowSize' V='1'/>" if with_arrow else ""
    return (
        f"<Shape ID='{sid}' Type='Shape' LineStyle='3' FillStyle='3' TextStyle='3'>"
        f"<Cell N='PinX' V='{pin_x}'/><Cell N='PinY' V='{pin_y}'/>"
        f"<Cell N='Width' V='{length}'/><Cell N='Height' V='0'/>"
        f"<Cell N='LocPinX' V='{length/2}'/><Cell N='LocPinY' V='0'/>"
        f"<Cell N='Angle' V='{angle}'/>"
        f"<Cell N='LineColor' V='#333333'/><Cell N='LinePattern' V='1'/>"
        f"{arrow_cell}"
        f"<Section N='Geometry' IX='0'><Cell N='NoFill' V='1'/>"
        f"<Row T='MoveTo' IX='1'><Cell N='X' V='0'/><Cell N='Y' V='0'/></Row>"
        f"<Row T='LineTo' IX='2'><Cell N='X' V='{length}'/><Cell N='Y' V='0'/></Row>"
        f"</Section></Shape>"
    )

def make_label_xml(text, cx, cy, page_h_in):
    pin_x = MARGIN_IN + cx / PX_PER_IN
    pin_y = page_h_in - MARGIN_IN - cy / PX_PER_IN
    w_in, h_in = 1.4, 0.2
    sid = next_id()
    return (
        f"<Shape ID='{sid}' Type='Shape' LineStyle='2' FillStyle='2' TextStyle='3'>"
        f"<Cell N='PinX' V='{pin_x}'/><Cell N='PinY' V='{pin_y}'/>"
        f"<Cell N='Width' V='{w_in}'/><Cell N='Height' V='{h_in}'/>"
        f"<Cell N='LocPinX' V='{w_in/2}'/><Cell N='LocPinY' V='{h_in/2}'/>"
        f"<Cell N='Angle' V='0'/>"
        f"<Cell N='FillForegnd' V='#FFFFFF'/><Cell N='FillPattern' V='1'/>"
        f"<Cell N='LinePattern' V='0'/>"
        f"<Cell N='Size' V='0.11'/>"
        f"<Section N='Geometry' IX='0'>{rect_geometry()}</Section>"
        f"<Text>{text_block(text)}</Text>"
        f"</Shape>"
    )

def build_page_xml(name, nodes, edges, pw, ph):
    _id_counter[0] = 0
    page_w_in = pw / PX_PER_IN + 2 * MARGIN_IN
    page_h_in = ph / PX_PER_IN + 2 * MARGIN_IN

    containers = {k: v for k, v in nodes.items() if 'dashed=1' in v['style'] and 'rounded=1' in v['style']}
    others = {k: v for k, v in nodes.items() if k not in containers}

    shapes_xml = []
    for nid, n in containers.items():
        shapes_xml.append(make_shape_xml(n, page_h_in))
    for nid, n in others.items():
        shapes_xml.append(make_shape_xml(n, page_h_in))
    for e in edges:
        if e['source'] not in nodes or e['target'] not in nodes:
            continue
        pts = edge_points(e, nodes)
        for i in range(len(pts) - 1):
            is_last = (i == len(pts) - 2)
            (x1, y1), (x2, y2) = pts[i], pts[i + 1]
            if abs(x1 - x2) < 1 and abs(y1 - y2) < 1:
                continue
            shapes_xml.append(make_line_xml(x1, y1, x2, y2, page_h_in, with_arrow=is_last))
        if e['val']:
            mid_i = max(0, len(pts) // 2 - 1)
            mx = (pts[mid_i][0] + pts[mid_i + 1][0]) / 2
            my = (pts[mid_i][1] + pts[mid_i + 1][1]) / 2
            label_text = unescape_val(e['val']).replace("\n", " ")
            shapes_xml.append(make_label_xml(label_text, mx, my, page_h_in))

    page_xml = VISIO_NS_OPEN + "<Shapes>" + "".join(shapes_xml) + "</Shapes></PageContents>"
    return page_xml, page_w_in, page_h_in

def build_pages_xml(name, page_w_in, page_h_in):
    return (
        "<?xml version='1.0' encoding='utf-8' ?>\n"
        "<Pages xmlns='http://schemas.microsoft.com/office/visio/2012/main' "
        "xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships' xml:space='preserve'>"
        f"<Page ID='0' NameU='{esc(name)}' Name='{esc(name)}' ViewScale='1' "
        f"ViewCenterX='{page_w_in/2}' ViewCenterY='{page_h_in/2}'>"
        "<PageSheet LineStyle='0' FillStyle='0' TextStyle='0'>"
        f"<Cell N='PageWidth' V='{page_w_in}'/><Cell N='PageHeight' V='{page_h_in}'/>"
        "<Cell N='ShdwOffsetX' V='0.1181102362204724'/><Cell N='ShdwOffsetY' V='-0.1181102362204724'/>"
        "<Cell N='PageScale' V='0.03937007874015748' U='MM'/><Cell N='DrawingScale' V='0.03937007874015748' U='MM'/>"
        "<Cell N='DrawingSizeType' V='0'/><Cell N='DrawingScaleType' V='0'/>"
        "</PageSheet><Rel r:id='rId1'/></Page></Pages>"
    )

def safe_name(name):
    return re.sub(r'[^a-zA-Z0-9]+', '_', name).strip('_')

def render_drawio_to_vsdx_files(drawio_path, out_dir):
    """Writes one .vsdx per page, returns {safe_name(page_name): vsdx_path}."""
    os.makedirs(out_dir, exist_ok=True)
    content = open(drawio_path).read()
    diagrams = re.findall(r'<diagram id="([^"]*)" name="([^"]*)">(.*?)</diagram>', content, re.S)
    results = {}
    for did, name, body in diagrams:
        nodes, edges, pw, ph = parse_page(body)
        page_xml, page_w_in, page_h_in = build_page_xml(name, nodes, edges, pw, ph)
        pages_xml = build_pages_xml(name, page_w_in, page_h_in)

        out_path = os.path.join(out_dir, safe_name(name) + ".vsdx")
        with zipfile.ZipFile(TEMPLATE_VSDX, "r") as zin, zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                data = zin.read(item.filename)
                if item.filename == "visio/pages/page1.xml":
                    data = page_xml.encode("utf-8")
                elif item.filename == "visio/pages/pages.xml":
                    data = pages_xml.encode("utf-8")
                zout.writestr(item, data)
        results[safe_name(name)] = out_path
    return results

def main(drawio_dir, out_dir):
    total = 0
    for path in glob.glob(os.path.join(drawio_dir, "*.drawio")):
        results = render_drawio_to_vsdx_files(path, out_dir)
        for key, out_path in results.items():
            print(f"wrote {out_path}")
            total += 1
    print(f"{total} .vsdx files generated in {out_dir}")

if __name__ == "__main__":
    main(*sys.argv[1:3])
