#!/usr/bin/env python3
"""repos/ISSUES.md mirror of the GitHub issues (issues-sync.yml) - nobody edits its rows by hand.

issues_md.py opened|closed   (env NUM, TITLE, BODY, LABELS = comma list, URL, REASON = state reason of a close)
  opened: a row in "Open and agreed (backlog)" - I-number and summary from the title ("I-062 COMMON: ..."), the app from
          the label, Area / Source from the body lines "**Area:**" / "**Source:**", Type / Priority from "Type:" /
          "Priority:"; nothing when the issue already has a row
  closed: the row moves to "Fixed" with the date ("not planned" when closed so)
"""
import datetime, os, re, sys

p = 'repos/ISSUES.md'
s = open(p).read()
mode, n = sys.argv[1], os.environ['NUM']
a, b = s.find('## Open'), s.find('## Fixed')
row_re = re.compile(r'(?m)^\| (I-[0-9A-Z?]+) \[#' + n + r'\]\([^)]*\) \|.*$')


def cell(text):
    return re.sub(r'\s+', ' ', (text or '').replace('|', '/')).strip()[:160] or '-'


def line(key):
    m = re.search(r'(?mi)^\**' + key + r':\**\s*(.+)$', os.environ.get('BODY', ''))
    return m.group(1).strip() if m else ''


if mode == 'opened':
    if row_re.search(s):
        sys.exit(f'#{n}: already in ISSUES.md')
    labels = [x for x in os.environ.get('LABELS', '').split(',') if x in ('COMMON', 'KYC')]
    if not labels:
        sys.exit(f'#{n}: no COMMON / KYC label - not an application issue')
    m = re.match(r'(I-[0-9A-Z]+)\s+(?:(?:COMMON|KYC):\s*)?(.*)$', os.environ['TITLE'])
    ino, summary = (m.group(1), m.group(2)) if m else ('I-?', os.environ['TITLE'])
    row = (f"| {ino} [#{n}]({os.environ['URL']}) | {labels[0]} | {cell(line('Area').strip('*'))} | {cell(summary)} | "
           f"{cell(line('Type')).lower()} | {cell(line('Priority')).upper()} | Open | {cell(line('Source').strip('*'))} |")
    end = s.rfind('\n|', a, b)
    end = s.index('\n', end + 1)
    s = s[:end] + '\n' + row + s[end:]
elif mode == 'closed':
    m = row_re.search(s)
    if not m or not (a < m.start() < b):
        sys.exit(f'#{n}: no open row - nothing to do')
    reason = os.environ.get('REASON') or 'completed'
    cells = [c.strip() for c in m.group(0).strip('|').split('|')]
    row = (f"| {cells[0]} | {cells[1]} | {cells[2]} | {cells[3]} | Closed {datetime.date.today():%d-%b-%Y}"
           f"{' (not planned)' if reason == 'not_planned' else ''} |")
    s = s[:m.start()] + s[m.end() + 1:]
    b = s.find('## Fixed'); h = s.find('\n|---', b); h = s.find('\n', h + 1) + 1
    s = s[:h] + row + '\n' + s[h:]
open(p, 'w').write(s)
print(f'#{n}: ISSUES.md {mode}')
