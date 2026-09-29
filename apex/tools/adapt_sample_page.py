#!/usr/bin/env python3
"""Adapt an APEX-generated page from Oracle's Sample Workflow Approvals app (APEX 26.1, APEXlang)
to this application: page number, item prefix, name/alias, authorization, page links; drops the
sample's "About this page" region. Usage from other scripts: adapt(src, dst, ...)."""
import re

def drop_region(t, rid):
    m = re.search(r'(?ms)^    region %s \(\n.*?^    \)\n\n' % re.escape(rid), t)
    return t[:m.start()] + t[m.end():] if m else t

def adapt(src, dst, old_id, new_id, name, alias, page_auth='@page-view', page_map=None, auth_map=None,
          page_group=None, help_text=None):
    t = open(src).read()
    t = drop_region(t, 'about-this-page')
    t = re.sub(r'^page %d \(\n    name: .*\n    alias: .*\n    title: .*\n' % old_id,
               f'page {new_id} (\n    name: {name}\n    alias: {alias}\n    title: {name}\n'
               + (f'    pageGroup: @{page_group}\n' if page_group else ''), t, count=1)
    t = re.sub(r'\bP%d_' % old_id, f'P{new_id}_', t)
    for o, n in (page_map or {}).items():
        t = re.sub(r'(\b(?:page|clearCache): )%d\b' % o, r'\g<1>%d' % n, t)
        t = re.sub(r'\bP%d_' % o, f'P{n}_', t)
    t = re.sub(r'(\b(?:page|clearCache): )%d\b' % old_id, r'\g<1>%d' % new_id, t)
    # page-level authorization (first occurrence inside the page security group)
    t = re.sub(r'(?m)^(    security \{\n        authorizationScheme: )\S+', r'\g<1>' + page_auth, t, count=1)
    for o, n in (auth_map or {}).items():
        t = t.replace(f'authorizationScheme: {o}', f'authorizationScheme: {n}')
    if help_text:
        t = t.replace('    security {', f'    help {{\n        helpText: {help_text}\n    }}\n    security {{', 1) \
            if '\n    help {' not in t[:t.find('\n    region ')] else t
    open(dst, 'w').write(t)
    return t
