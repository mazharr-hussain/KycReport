#!/usr/bin/env python3
"""Pipeline report for the PR comment (jobs 7 and 8): the warnings and notices of this run, from the step logs.

report.py <logs dir> <out.md>
<logs dir> holds the downloaded step-log artifacts (logs-<job>/<step>.log, written by lib/step.sh). Collected:
  - warnings in this change   lines "::warning..." (the GitHub annotations: findings in the files the PR changes)
  - notices                   lines "info: ..." and "::notice..." (information: PMD limits, dependency / restore
                              reports, DBSAT not set up, ...)
  - existing findings         lines "existing: ..." (findings in files the PR does not touch - existing code)
Each line is reported once, with the step it came from.
Also the step times (logs-<job>/timings, written by lib/step.sh): one collapsed table, slowest first, with each job's
total - where the run's time went.
"""
import os, re, sys

logs, out = sys.argv[1], sys.argv[2]
warn, info, existing = {}, {}, {}
times, totals = [], {}
for root, _, files in os.walk(logs):
    if 'timings' in files:
        job = os.path.basename(root).replace('logs-', '')
        for line in open(os.path.join(root, 'timings'), errors='ignore'):
            p = line.split()
            if len(p) == 3 and p[1].isdigit():
                times.append((int(p[1]), job, p[0], p[2]))
                totals[job] = totals.get(job, 0) + int(p[1])
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
    if times:
        mmss = lambda x: f'{x // 60}:{x % 60:02d}'
        rows = '\n'.join(f'| {job} | `{step}` | {mmss(t)} | {res} |' for t, job, step, res in sorted(times, reverse=True))
        tot = ', '.join(f'{job} {mmss(t)}' for job, t in sorted(totals.items()))
        fh.write(f'\n<details><summary><b>Step times</b> (scripted steps: {tot})</summary>\n\n'
                 f'| Job | Step | Time | Result |\n|---|---|---|---|\n{rows}\n</details>\n')
print(f'report: {len(warn)} warning(s), {len(info)} notice(s), {len(existing)} existing finding(s), {len(times)} step time(s)')
