#!/usr/bin/env python3
"""Embed a .vsdx (Visio) file as a real, double-click-editable OLE object
inside a .docx, at each '(PLACEHOLDER_PREFIX)key(PLACEHOLDER_PREFIX)'
paragraph -- shown as a static preview image until double-clicked, at which
point Word launches Visio to edit the embedded copy.

Works by unzipping the docx package, patching word/document.xml (swap the
placeholder paragraph for a w:object/o:OLEObject block), copying in the
.vsdx as word/embeddings/oleObjectN.vsdx and a PNG preview as
word/media/imageN.png, registering both as relationships + content types,
then re-zipping. Deliberately bypasses python-docx for this step since it
has no first-class API for adding arbitrary OLE package parts.
"""
import os, re, shutil, tempfile, zipfile
from lxml import etree
from PIL import Image

W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
R = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
V = 'urn:schemas-microsoft-com:vml'
O = 'urn:schemas-microsoft-com:office:office'
PKG_REL = 'http://schemas.openxmlformats.org/package/2006/relationships'
CT_NS = 'http://schemas.openxmlformats.org/package/2006/content-types'

NSMAP = {'w': W, 'v': V, 'o': O, 'r': R}
EMU_PER_PX = 9525
PT_PER_PX = 0.75  # 96px/in -> 72pt/in

def qn(prefix, local, nsmap=NSMAP):
    return f"{{{nsmap[prefix]}}}{local}"

def build_object_paragraph(rid_img, rid_obj, shape_id, object_id, width_pt, height_pt):
    p = etree.Element(qn('w', 'p'))
    r = etree.SubElement(p, qn('w', 'r'))
    obj = etree.SubElement(r, qn('w', 'object'))
    obj.set(qn('w', 'dxaOrig'), str(int(width_pt * 20)))
    obj.set(qn('w', 'dyaOrig'), str(int(height_pt * 20)))
    shape = etree.SubElement(obj, qn('v', 'shape'), nsmap={'v': V, 'o': O})
    shape.set('id', shape_id)
    shape.set('type', '#_x0000_t75')
    shape.set('style', f'width:{width_pt}pt;height:{height_pt}pt')
    imgdata = etree.SubElement(shape, qn('v', 'imagedata'))
    imgdata.set(qn('r', 'id', {'r': R}), rid_img)
    imgdata.set(qn('o', 'title', {'o': O}), '')
    ole = etree.SubElement(obj, qn('o', 'OLEObject', {'o': O}), nsmap={'o': O})
    ole.set('Type', 'Embed')
    ole.set('ProgID', 'Visio.Drawing.15')
    ole.set('ShapeID', shape_id)
    ole.set('DrawAspect', 'Content')
    ole.set('ObjectID', object_id)
    ole.set(qn('r', 'id', {'r': R}), rid_obj)
    return p

def embed_diagrams(docx_path, placeholder_prefix, page_index, out_path=None):
    """page_index: {key: {vsdx_path, png_path}}. Returns (embedded_count, missing_keys)."""
    out_path = out_path or docx_path
    workdir = tempfile.mkdtemp(prefix="docx_ole_")
    try:
        with zipfile.ZipFile(docx_path) as z:
            z.extractall(workdir)

        doc_xml_path = os.path.join(workdir, "word", "document.xml")
        tree = etree.parse(doc_xml_path)
        root = tree.getroot()
        pattern = re.compile(re.escape(placeholder_prefix) + r'(\w+)' + re.escape(placeholder_prefix))

        rels_path = os.path.join(workdir, "word", "_rels", "document.xml.rels")
        rels_tree = etree.parse(rels_path)
        rels_root = rels_tree.getroot()
        existing_ids = [r.get('Id') for r in rels_root]
        max_id = max((int(i[3:]) for i in existing_ids if i.startswith('rId') and i[3:].isdigit()), default=0)

        media_dir = os.path.join(workdir, "word", "media")
        emb_dir = os.path.join(workdir, "word", "embeddings")
        os.makedirs(media_dir, exist_ok=True)
        os.makedirs(emb_dir, exist_ok=True)
        existing_media = len(os.listdir(media_dir)) if os.path.isdir(media_dir) else 0
        existing_emb = len(os.listdir(emb_dir)) if os.path.isdir(emb_dir) else 0

        embedded, missing = 0, []
        for p in root.iter(qn('w', 'p')):
            texts = p.findall('.//' + qn('w', 't'))
            full_text = "".join(t.text or "" for t in texts)
            m = pattern.search(full_text)
            if not m:
                continue
            key = m.group(1)
            entry = page_index.get(key)
            if not entry:
                missing.append(key)
                continue

            max_id += 1
            rid_img = f"rId{max_id}"
            max_id += 1
            rid_obj = f"rId{max_id}"

            existing_media += 1
            img_name = f"image{existing_media}.png"
            shutil.copy(entry['png_path'], os.path.join(media_dir, img_name))

            existing_emb += 1
            vsdx_name = f"oleObject{existing_emb}.vsdx"
            shutil.copy(entry['vsdx_path'], os.path.join(emb_dir, vsdx_name))

            with Image.open(entry['png_path']) as im:
                px_w, px_h = im.size
            width_pt = px_w * PT_PER_PX
            height_pt = px_h * PT_PER_PX
            max_dim = 468.0  # ~6.5in content width in points
            if width_pt > max_dim:
                scale = max_dim / width_pt
                width_pt *= scale
                height_pt *= scale

            etree.SubElement(rels_root, qn('_', 'Relationship', {'_': PKG_REL}),
                              Id=rid_img, Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
                              Target=f'media/{img_name}')
            etree.SubElement(rels_root, qn('_', 'Relationship', {'_': PKG_REL}),
                              Id=rid_obj, Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/oleObject',
                              Target=f'embeddings/{vsdx_name}')

            new_p = build_object_paragraph(rid_img, rid_obj, f"_x0000_i{1024 + embedded}",
                                            f"_{1600000000 + embedded}", width_pt, height_pt)
            p.getparent().replace(p, new_p)
            embedded += 1

        tree.write(doc_xml_path, xml_declaration=True, encoding="UTF-8", standalone=True)
        rels_tree.write(rels_path, xml_declaration=True, encoding="UTF-8", standalone=True)

        ct_path = os.path.join(workdir, "[Content_Types].xml")
        ct_tree = etree.parse(ct_path)
        ct_root = ct_tree.getroot()
        have_ext = {d.get('Extension') for d in ct_root if d.tag == qn('_', 'Default', {'_': CT_NS})}
        if 'png' not in have_ext:
            etree.SubElement(ct_root, qn('_', 'Default', {'_': CT_NS}), Extension='png', ContentType='image/png')
        if 'vsdx' not in have_ext:
            etree.SubElement(ct_root, qn('_', 'Default', {'_': CT_NS}), Extension='vsdx',
                              ContentType='application/vnd.ms-visio.drawing.main+xml')
        ct_tree.write(ct_path, xml_declaration=True, encoding="UTF-8", standalone=True)

        tmp_out = out_path + ".tmp"
        with zipfile.ZipFile(tmp_out, "w", zipfile.ZIP_DEFLATED) as zout:
            for base, _, files in os.walk(workdir):
                for fn in files:
                    full = os.path.join(base, fn)
                    arcname = os.path.relpath(full, workdir)
                    zout.write(full, arcname)
        shutil.move(tmp_out, out_path)
        return embedded, missing
    finally:
        shutil.rmtree(workdir, ignore_errors=True)
