#!/usr/bin/env python3
"""Steps 5.2b, 6.3 and 6.7: the test data file into the database - insert the rows that are missing, update the rows
that are there (MERGE on the primary key). Writes the SQL that db/run.sh runs as the application schema.

load_data.py <test-data.json> <strict|tolerant> <out.sql>
  strict    (5.2b, 6.7, and 6.3 with the last release's own file) a table or column the database does not have, or a
            row that does not load, fails the step
  tolerant  (6.3 only, when the last release has no data file yet: this version's file on the old structure) a table
            or column the old release does not have is left out and reported (INFO); a row that does not load too

The data file (repos/common/db/admin/test-data.json, checked in job 1 by checks/test_data.py):
  {"tables": [{"table": "XXHR_EMPLOYEES", "rows": [{"employee_id": 900001, "user_name": "TD_ANNA", ...}]}, ...],
   "seeded": {"XXFND_FEATURES": "why the install's own seed is enough"},
   "no_data": {"XXFND_SCHEMA_RELEASES": "why the table has no test rows"},
   "removed": [{"table": "XXFND_ROLES", "column": "role_code", "only_if_role_of": "TDAPP", "value": "OLD_CODE"}]}   (I-097: deleted before the load)
Tables load in file order (parents first). Column names in any case. Values: JSON strings and numbers; DATE and
TIMESTAMP columns take 'YYYY-MM-DD' or 'YYYY-MM-DD HH24:MI:SS', a BLOB column 'hex:<hex digits>'. The WHO columns
(CREATED_BY ... OBJECT_VERSION_NUMBER) are filled when a row does not give them. During the load the triggers and the
VPD policies are off (the rows are test data, not user actions); afterwards identity columns and sequences are moved
past the loaded keys.
"""
import json, os, re, sys

src, mode, out = sys.argv[1:4]
assert mode in ('strict', 'tolerant'), mode
data = json.load(open(src))
rows = []   # (table, column, value) triples, one row number per row
n = 0
for t in data.get('tables', []):
    for r in t['rows']:
        n += 1
        for c, v in r.items():
            if v is None:
                continue
            rows.append((n, t['table'].upper(), c.upper(), v if isinstance(v, str) else json.dumps(v)))
# the data as one CLOB of lines "<row>|<table>|<column>|<value>"; a value keeps its line breaks as \n
lines = ''.join(f'{r}|{t}|{c}|{v.replace(chr(92), chr(92) * 2).replace(chr(10), chr(92) + "n")}\n'
                for r, t, c, v in rows)
delim = next(d for d in '~#^!@%' if f"{d}'" not in lines)
chunks, size = [], 8000
for i in range(0, len(lines), size):
    chunks.append(f"    dbms_lob.append(l_data, to_clob(q'{delim}{lines[i:i + size]}{delim}'));")
# I-097: "removed" - rows an earlier version of the file loaded and this one no longer has (deleted first, in file order:
# children first); each {"table", "column", "value"} and optionally "only_if_role_of": only while the role <value> belongs
# to that application; names checked here and again in the database
removes = []
for r in data.get('removed', []):
    t, c, v, a = r['table'].upper(), r['column'].upper(), str(r['value']), str(r.get('only_if_role_of', ''))
    assert re.fullmatch(r'[A-Z][A-Z0-9_$#]{0,127}', t) and re.fullmatch(r'[A-Z][A-Z0-9_$#]{0,127}', c), r
    assert "'" not in v + a, r
    removes.append(f"    remove_rows('{t}', '{c}', '{v}', '{a}');")
template = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'load-data.sql')).read()
sql = (template.replace('&mode', mode).replace('    --DATA--', '\n'.join(chunks))
       .replace('        --REMOVE--', '\n'.join('    ' + x for x in removes) or '        null;'))
open(out, 'w').write(sql)
print(f'{len(removes)} removal(s), {n} row(s) in {len(data.get("tables", []))} table(s) from {src} ({mode})')
