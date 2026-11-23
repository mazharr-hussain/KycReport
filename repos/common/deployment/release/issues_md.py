#!/usr/bin/env python3
"""repos/ISSUES.md mirror of the GitHub issues - nobody edits its rows by hand.

main accepts pull requests only, so the file is brought up to date inside each release PR (pipeline step 9.2a,
release/carry.sh), never pushed to main by itself:

issues_md.py sync   (env GH_TOKEN, GH_REPO; FIXES = the PR's "Fixes #n" numbers, RELEASE = "<APP> Release <N>")
  - every open COMMON / KYC issue without a row gets one in "Open and agreed (backlog)": I-number and summary from the
    title ("I-062 COMMON: ..."), the app from the label, Area / Source from the body lines "**Area:**" / "**Source:**",
    Type / Priority from "Type:" / "Priority:"
  - an issue this PR fixes (FIXES) gets the status "Fix in <RELEASE>" (it closes when the PR merges)
  - a closed issue whose row is still open moves to "Fixed" with its closing date ("not planned" when closed so)
Prints "changed" when the file changed.
"""
import json, os, re, subprocess, sys

P = 'repos/ISSUES.md'


def cell(text):
    return re.sub(r'\s+', ' ', (text or '').replace('|', '/')).strip()[:160] or '-'


def line(body, key):
    m = re.search(r'(?mi)^\**' + key + r':\**\s*(.+)$', body or '')
    return m.group(1).strip() if m else ''


def row_re(n):
    return re.compile(r'(?m)^\| (I-[0-9A-Z?]+) \[#' + str(n) + r'\]\([^)]*\) \|.*$')


def add_open(s, issue):
    n = issue['number']
    if row_re(n).search(s):
        return s
    labels = [x['name'] for x in issue['labels'] if x['name'] in ('COMMON', 'KYC')]
    m = re.match(r'(I-[0-9A-Z]+)\s+(?:(?:COMMON|KYC):\s*)?(.*)$', issue['title'])
    ino, summary = (m.group(1), m.group(2)) if m else ('I-?', issue['title'])
    body = issue.get('body') or ''
    row = (f"| {ino} [#{n}]({issue['html_url']}) | {labels[0]} | {cell(line(body, 'Area').strip('*'))} | {cell(summary)} | "
           f"{cell(line(body, 'Type')).lower()} | {cell(line(body, 'Priority')).upper()} | Open | {cell(line(body, 'Source').strip('*'))} |")
    a, b = s.find('## Open'), s.find('## Fixed')
    end = s.rfind('\n|', a, b)
    end = s.index('\n', end + 1)
    return s[:end] + '\n' + row + s[end:]


def set_status(s, n, status):
    a, b = s.find('## Open'), s.find('## Fixed')
    m = row_re(n).search(s)
    if not m or not (a < m.start() < b):
        return s
    cells = [c.strip() for c in m.group(0).strip('|').split('|')]
    if len(cells) < 8 or cells[6] == status:
        return s
    cells[6] = status
    return s[:m.start()] + '| ' + ' | '.join(cells) + ' |' + s[m.end():]


def move_fixed(s, issue):
    a, b = s.find('## Open'), s.find('## Fixed')
    m = row_re(issue['number']).search(s)
    if not m or not (a < m.start() < b):
        return s
    closed = issue.get('closed_at') or ''
    day = subprocess.run(['date', '-d', closed, '+%d-%b-%Y'], capture_output=True, text=True).stdout.strip() if closed else ''
    cells = [c.strip() for c in m.group(0).strip('|').split('|')]
    row = (f"| {cells[0]} | {cells[1]} | {cells[2]} | {cells[3]} | Closed {day}"
           f"{' (not planned)' if issue.get('state_reason') == 'not_planned' else ''} |")
    s = s[:m.start()] + s[m.end() + 1:]
    b = s.find('## Fixed'); h = s.find('\n|---', b); h = s.find('\n', h + 1) + 1
    return s[:h] + row + '\n' + s[h:]


def issues():
    out = subprocess.run(['gh', 'api', '--paginate', f"repos/{os.environ['GH_REPO']}/issues?state=all&per_page=100",
                          '--jq', '.[] | select(.pull_request == null)'], capture_output=True, text=True, check=True).stdout
    items = [json.loads(x) for x in out.splitlines() if x.strip()]
    return sorted((i for i in items if any(x['name'] in ('COMMON', 'KYC') for x in i['labels'])), key=lambda i: i['number'])


if __name__ == '__main__':
    if sys.argv[1:] != ['sync']:
        sys.exit('usage: issues_md.py sync')
    before = s = open(P).read()
    fixes = {int(x) for x in os.environ.get('FIXES', '').split() if x.isdigit()}
    release = os.environ.get('RELEASE', '')
    for issue in issues():
        if issue['state'] == 'open':
            s = add_open(s, issue)
            if issue['number'] in fixes and release:
                s = set_status(s, issue['number'], f'Fix in {release}')
        else:
            s = move_fixed(s, issue)
    if s != before:
        open(P, 'w').write(s)
        print('changed')
