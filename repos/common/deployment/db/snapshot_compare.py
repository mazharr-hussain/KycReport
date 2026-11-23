#!/usr/bin/env python3
"""Step 6.6 (I-076): nothing lost by the upgrade - compares db/snapshot.sql's output before (6.4) and after the upgrade.

snapshot_compare.py <before> <after>     (lines "T <table> <rows>" and "R <table> <key> <hash>", TAB separated)
  FAIL  a table that is still there has fewer rows than before, or a row (by primary key) is gone
  INFO  a table removed by the release; rows whose values the upgrade changed (planned data changes)
Exit 1 when anything was lost.
"""
import sys


def read(path):
    tables, rows = {}, {}
    for line in open(path, errors='ignore'):
        p = line.rstrip('\n').split('\t')
        if p[0] == 'T' and len(p) == 3:
            tables[p[1]] = int(p[2])
        elif p[0] == 'R' and len(p) == 4:
            rows.setdefault(p[1], {})[p[2]] = p[3]
    return tables, rows


(bt, br), (at, ar) = read(sys.argv[1]), read(sys.argv[2])
if not bt:
    print('FAIL no snapshot before the upgrade (6.4)')
    sys.exit(1)
lost = 0
for t in sorted(bt):
    if t not in at:
        print(f'INFO removed by the release: {t} ({bt[t]} row(s) before)')
        continue
    if at[t] < bt[t]:
        print(f'FAIL data lost: {t} had {bt[t]} row(s), now {at[t]}')
        lost += 1
    gone = [k for k in br.get(t, {}) if k not in ar.get(t, {})]
    if gone:
        print(f'FAIL rows lost: {t} - {len(gone)} row(s) no longer there, e.g. key {gone[0]}')
        lost += 1
    changed = sum(1 for k, h in br.get(t, {}).items() if k in ar.get(t, {}) and ar[t][k] != h)
    if changed:
        print(f'INFO changed by the upgrade: {t} - {changed} row(s)')
print(f'compared {len([t for t in bt if t in at])} table(s) with the snapshot before the upgrade')
sys.exit(1 if lost else 0)
