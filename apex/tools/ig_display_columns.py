#!/usr/bin/env python3
"""Interactive grids: the primary saved report shows only the columns listed as displayColumn; without them
every column renders hidden. Adds a displayColumn for each shown column (not hidden, not the row selector)
in column sequence, the row actions menu frozen first. Idempotent: reports that already list columns are kept.
Usage: ig_display_columns.py [pages-dir]"""
import os, re, sys

PAGES = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src', 'pages')


def blocks(text, indent, keyword):
    """(start, end, name) of blocks 'keyword NAME (' at the given indent, closed by ')' at the same indent."""
    pad = ' ' * indent
    for m in re.finditer(rf'^{pad}{keyword} (\S+) \(\n', text, re.M):
        end = text.index(f'\n{pad})\n', m.end()) + len(pad) + 2
        yield m.start(), end, m.group(1)


def fix_region(region):
    if 'type: interactiveGrid\n' not in region:
        return region
    rpts = list(blocks(region, 8, 'savedReport'))
    if not rpts or 'displayColumn (' in region:
        return region
    cols = []
    for s, e, name in blocks(region, 8, 'column'):
        body = region[s:e]
        typ = re.search(r'^            type: (\S+)', body, re.M).group(1)
        seq = int(re.search(r'^                sequence: (\d+)', body, re.M).group(1))
        if typ not in ('hidden', 'rowSelector'):
            cols.append((0 if typ == 'actionsMenu' else seq, name, typ))
    out = ''
    for i, (_, name, typ) in enumerate(sorted(cols), 1):
        frozen = '                    frozen: true\n' if typ == 'actionsMenu' else ''
        out += f'''
            displayColumn (
                column: @{name}
                layout {{
{frozen}                    sequence: {i}
                }}
            )
'''
    s, e, _ = rpts[0]
    close = region.rindex('        )', s, e)
    return region[:close] + out + region[close:]


changed = 0
for f in sorted(os.listdir(PAGES)):
    if not f.endswith('.apx'):
        continue
    path = os.path.join(PAGES, f)
    text = open(path).read()
    new = text
    for s, e, _ in sorted(blocks(text, 4, 'region'), reverse=True):
        new = new[:s] + fix_region(new[s:e]) + new[e:]
    if new != text:
        open(path, 'w').write(new)
        changed += 1
        print('display columns added:', f)
print(f'{changed} page(s) changed')
