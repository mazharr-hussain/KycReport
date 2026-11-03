#!/bin/bash
# Job 1.6 - PMD (PL/SQL rules in pmd-plsql.xml) on every COMMON package (features/*/db/package_specs|package_bodies;
# db/deploy is generated from them). Warnings only: a finding in a file the PR changes becomes a GitHub warning
# annotation; findings in unchanged files are listed in the step log only. PMD's PL/SQL grammar does not know every
# Oracle 23ai construct (e.g. BOOLEAN expressions in SQL): a package it cannot parse is listed in the log (info) - the
# database compile in jobs 4-5 is the real syntax check.
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
  python3 - "$report" "$ROOT" "$(wc -l < "$files")" "${BASE:-}" <<'PY'
import json, os, subprocess, sys
report, root, total, base = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
data = json.load(open(report))
# only findings in files this PR changes become GitHub annotations; the others are existing code (step log only)
changed = set(subprocess.run(['git', 'diff', '--name-only', base, 'HEAD'], cwd=root, capture_output=True,
                             text=True).stdout.split()) if base else set()
new = old = 0
for f in data.get('files', []):
    path = os.path.relpath(f['filename'], root)
    for v in f.get('violations', []):
        msg = v['description'].replace('\n', ' ')
        if path in changed:
            new += 1
            print(f"::warning file={path},line={v['beginline']},title=PMD {v['rule']}::{msg}")
        else:
            old += 1
            print(f"existing: {path}:{v['beginline']}: PMD {v['rule']}: {msg}")
skipped = sorted({os.path.basename(e['filename']) for e in data.get('processingErrors', [])})
if skipped:   # PMD's grammar does not know every Oracle 23ai construct - a tool limit, not a code problem
    print(f"info: {len(skipped)} of {total} package files use syntax PMD cannot parse (not analysed): {', '.join(skipped)}")
print(f'PMD: {total - len(skipped)} of {total} package files analysed - {new} finding(s) in this change, '
      f'{old} existing finding(s) in unchanged files (listed above, not annotated)')
PY
  rc=$?
fi
rm -f "$report" "$files"
exit "$rc"
