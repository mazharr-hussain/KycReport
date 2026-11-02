#!/bin/bash
# Job 3.6 - PMD (PL/SQL rules in pmd-plsql.xml) on every COMMON package (features/*/db/package_specs|package_bodies;
# db/deploy is generated from them). Warnings only: each finding becomes a GitHub warning annotation.
# PMD's PL/SQL grammar does not know every Oracle 23ai construct (e.g. BOOLEAN expressions in SQL): a package it cannot
# parse is listed as a notice, not an error - the database compile in jobs 6-7 is the real syntax check.
# The step fails only when PMD itself cannot run. Env: PMD = PMD launcher (pmd-bin-<version>/bin/pmd).
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
report=$(mktemp); files=$(mktemp)
find "$ROOT/repos/common/features" -path '*/db/package_*/*' -type f \( -name '*.pks' -o -name '*.pkb' \) | sort > "$files"
"${PMD:?PMD is not set}" check --no-progress --no-fail-on-violation --no-fail-on-error --format json \
  --rulesets "$HERE/pmd-plsql.xml" --file-list "$files" --report-file "$report"
rc=$?
if [ "$rc" -eq 0 ]; then
  python3 - "$report" "$ROOT" "$(wc -l < "$files")" <<'PY'
import json, os, sys
report, root, total = sys.argv[1], sys.argv[2], int(sys.argv[3])
data = json.load(open(report))
n = 0
for f in data.get('files', []):
    path = os.path.relpath(f['filename'], root)
    for v in f.get('violations', []):
        n += 1
        msg = v['description'].replace('\n', ' ')
        print(f"::warning file={path},line={v['beginline']},title=PMD {v['rule']}::{msg}")
skipped = sorted({os.path.basename(e['filename']) for e in data.get('processingErrors', [])})
if skipped:
    print(f"::notice title=PMD::{len(skipped)} of {total} package files use syntax PMD cannot parse and were not "
          f"analysed: {', '.join(skipped)}")
print(f'PMD: {total - len(skipped)} of {total} package files analysed, {n} finding(s) (warnings only)')
PY
  rc=$?
fi
rm -f "$report" "$files"
exit "$rc"
