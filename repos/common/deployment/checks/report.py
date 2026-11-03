#!/usr/bin/env python3
"""Pipeline report for the PR comment (jobs 9 and 10): the warnings and notices of this run, from the step logs.

report.py <logs dir> <out.md>
<logs dir> holds the downloaded step-log artifacts (logs-<job>/<step>.log, written by lib/step.sh). Collected:
  - warnings in this change   lines "::warning..." (the GitHub annotations: findings in the files the PR changes)
  - notices                   lines "info: ..." and "::notice..." (information: PMD limits, dependency / restore
                              reports, DBSAT not set up, ...)
  - existing findings         lines "existing: ..." (findings in files the PR does not touch - existing code)
Each line is reported once, with the step it came from.
"""
import os, re, sys

logs, out = sys.argv[1], sys.argv[2]
warn, info, existing = {}, {}, {}
for root, _, files in os.walk(logs):
    for name in sorted(files):
        if not name.endswith('.log'):
            continue
        step = name[:-4]
        for line in open(os.path.join(root, name), errors='ignore'):
            line = re.sub(r'^\S+Z ', '', line.rstrip())        # timestamps, if any
            m = re.match(r'::warning(?: [^:]*)?::(.*)', line)
            if m:
                warn.setdefault(m.group(1), step)
                continue
            m = re.match(r'::notice(?: [^:]*)?::(.*)|info: (.*)', line)
            if m:
                info.setdefault(m.group(1) or m.group(2), step)
                continue
            if line.startswith('existing: '):
                existing.setdefault(line[10:], step)


def section(title, items, empty, collapsed=False):
    rows = [f'- `{step}` {text}' for text, step in items.items()]
    body = '\n'.join(rows) if rows else f'_{empty}_'
    if collapsed and rows:
        return f'<details><summary><b>{title} ({len(rows)})</b></summary>\n\n{body}\n</details>\n'
    return f'**{title} ({len(rows)})**\n{body}\n'


with open(out, 'w') as fh:
    fh.write(section('Warnings in this change', warn, 'none') + '\n')
    fh.write(section('Notices', info, 'none') + '\n')
    fh.write(section('Existing findings in unchanged files (fixed in their own release)', existing, 'none',
                     collapsed=True))
print(f'report: {len(warn)} warning(s), {len(info)} notice(s), {len(existing)} existing finding(s)')
