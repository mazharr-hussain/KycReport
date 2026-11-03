#!/usr/bin/env python3
"""Step 1.6b: the test data file (repos/common/db/admin/test-data.json) fits this version's database scripts.

test_data.py <repo root>   (after the build: reads repos/common/db/deploy/install)
  FAIL  the file is not valid JSON, or a row is not an object of column -> string / number
  FAIL  a table the install creates has no rows in the file and no reason ("no_data")  - a new table needs test rows
  FAIL  the file names a table the install does not create (or drops: XXFND_DDL_PKG.DROP_OBJECT ... 'TABLE'), or a column the table does not have (after every
        ADD_COLUMN / DROP_COLUMN of the install), or a column twice in a table's key data
Tables: the install's table-<name>.sql and ensure_table-<name>.sql files; columns: their CREATE TABLE plus the install's
XXFND_DDL_PKG.ADD_COLUMN / DROP_COLUMN calls. Prints PASS / FAIL lines; exit 1 on a FAIL.
"""
import json, os, re, sys

root = sys.argv[1] if len(sys.argv) > 1 else '.'
common = os.path.join(root, 'repos', 'common')
install = os.path.join(common, 'db', 'deploy', 'install')
path = os.path.join(common, 'db', 'admin', 'test-data.json')
TYPES = r'(varchar2|nvarchar2|char|number|integer|float|date|timestamp|clob|nclob|blob|raw|binary_double|json|xmltype)'
fails = []

tables, cols = set(), {}
for f in sorted(os.listdir(install)):
    m = re.search(r'-(?:table|ensure_table)-([a-z0-9_$#]+)\.sql$', f)
    text = open(os.path.join(install, f), errors='ignore').read()
    if m:
        t = m.group(1).upper()
        tables.add(t)
        body = re.search(r'create table(?: if not exists)?\s+\w+\s*\((.*)', text, re.S | re.I)
        for line in (body.group(1) if body else '').split('\n'):
            c = re.match(r'\s*([a-z][a-z0-9_$#]*)\s+' + TYPES + r'\b', line, re.I)
            if c and c.group(1).lower() != 'constraint':
                cols.setdefault(t, set()).add(c.group(1).upper())
    for t, c in re.findall(r"add_column\(\s*'([A-Z0-9_$#]+)'\s*,\s*'([A-Z0-9_$#]+)'", text, re.I):
        cols.setdefault(t.upper(), set()).add(c.upper())
for f in sorted(os.listdir(install)):   # drops last: a column added and later dropped is gone
    text = open(os.path.join(install, f), errors='ignore').read()
    for t, c in re.findall(r"drop_column\(\s*'([A-Z0-9_$#]+)'\s*,\s*'([A-Z0-9_$#]+)'", text, re.I):
        cols.get(t.upper(), set()).discard(c.upper())
    for t in re.findall(r"drop_object\(\s*'([A-Z0-9_$#]+)'\s*,\s*'TABLE'", text, re.I):   # a retired table is gone
        tables.discard(t.upper())

try:
    data = json.load(open(path, encoding='utf-8'))
except (OSError, ValueError) as e:
    print(f'FAIL test data: {path} - {e}')
    sys.exit(1)
covered = set()
for i, block in enumerate(data.get('tables', [])):
    t = str(block.get('table', '')).upper()
    if t not in tables:
        fails.append(f'{t or "(no name)"}: not a table the install creates (entry {i + 1})')
        continue
    if not block.get('rows'):
        fails.append(f'{t}: no rows (give rows, or move it to "no_data" with the reason)')
    covered.add(t)
    for n, row in enumerate(block.get('rows', []), 1):
        if not isinstance(row, dict):
            fails.append(f'{t} row {n}: not an object'); continue
        seen = set()
        for c, v in row.items():
            if c.upper() in seen:
                fails.append(f'{t} row {n}: column {c.upper()} given twice')
            seen.add(c.upper())
            if c.upper() not in cols.get(t, set()):
                fails.append(f'{t} row {n}: column {c.upper()} is not in the table (after the install\'s column changes)')
            if v is not None and not isinstance(v, (str, int, float)):
                fails.append(f'{t} row {n}: {c.upper()} is not a string or a number')
for t, why in data.get('no_data', {}).items():
    if t.upper() not in tables:
        fails.append(f'{t}: listed in "no_data" but not a table the install creates')
    elif not str(why).strip():
        fails.append(f'{t}: "no_data" needs the reason')
    covered.add(t.upper())
for t in sorted(tables - covered):
    fails.append(f'{t}: a table of the install without test rows - add its rows to {os.path.relpath(path, root)} '
                 '(or list it in "no_data" with the reason)')
for f in fails:
    print(f'FAIL test data: {f}')
if not fails:
    print(f'PASS test data: {len(covered)} table(s) of the install covered, '
          f'{sum(len(b.get("rows", [])) for b in data.get("tables", []))} row(s)')
sys.exit(1 if fails else 0)
