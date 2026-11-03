#!/usr/bin/env python3
"""Pipeline job 9 - log the findings that belong to a future release as GitHub issues (they go on the project board).

issues.py <logs dir> <report.md>
The "existing:" lines of the step logs are findings in files the PR did not change (3.2 static checks, 3.6 PMD): they
are not this PR's work, so each one becomes a COMMON issue for a future release. Pipeline failures and the warnings in
the PR's own files are never logged as issues - they are fixed in the PR from the pipeline's PR comment.
  - one issue per finding key: file + rule (PMD) or file + message (static checks), line numbers left out, so a finding
    that only moves is the same finding; the key's hash is kept in the issue body (marker) to find it again
  - no new issue when an open issue, or one closed as "not planned", already has the marker
  - title "I-<next number> COMMON: <finding>", label COMMON, body lines "Type:" and "Priority:" (add-to-project.yml puts
    the issue on the board and fills those fields - only when the token is a person's token, see GITHUB-SETUP.md)
The issues created are appended to <report.md> for the PR comment. Env: GH_TOKEN, GITHUB_REPOSITORY, RUN_URL, PR.
Never fails the job: a GitHub error is reported as a notice.
"""
import hashlib, json, os, re, sys, urllib.request

API = 'https://api.github.com'
logs, report = sys.argv[1], sys.argv[2]
repo, token = os.environ['GITHUB_REPOSITORY'], os.environ['GH_TOKEN']


def gh(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body else None,
                                 headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github+json',
                                          'X-GitHub-Api-Version': '2022-11-28'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def findings():
    """{key: [lines]} from the "existing:" lines of every step log."""
    out = {}
    for root, _, files in os.walk(logs):
        for name in sorted(files):
            if not name.endswith('.log'):
                continue
            for line in open(os.path.join(root, name), errors='ignore'):
                line = re.sub(r'^\S+Z ', '', line.rstrip())
                if not line.startswith('existing: '):
                    continue
                text = line[10:]
                m = re.match(r'([^:\s]+)(?::\d+)?: (.*)$', text)
                if not m:
                    continue
                path, msg = m.groups()
                pmd = re.match(r'PMD (\w+):', msg)
                key = f'{path} | ' + (f'PMD {pmd.group(1)}' if pmd else re.sub(r'\d+', '#', msg))
                out.setdefault(key, [])
                if text not in out[key]:
                    out[key].append(text)
    return out


def kind(key):
    if 'injection' in key.lower():
        return 'Bug', 'P1'
    if 'unrestricted' in key.lower() or 'checksum' in key.lower():
        return 'Bug', 'P2'
    return 'Enhancement', 'P3'


def main():
    found = findings()
    if not found:
        print('no existing findings - no issue to log')
        return
    issues, page = [], 1
    while True:
        batch = gh('GET', f'/repos/{repo}/issues?state=all&per_page=100&page={page}')
        issues += [i for i in batch if 'pull_request' not in i]
        if len(batch) < 100:
            break
        page += 1
    known = set()
    for i in issues:
        if i['state'] == 'open' or i.get('state_reason') == 'not_planned':
            known.update(re.findall(r'pipeline-finding: ([0-9a-f]{12})', i.get('body') or ''))
    numbers = [int(n) for i in issues for n in re.findall(r'^I-(\d+)\b', i['title'])]
    next_no = max(numbers, default=0) + 1
    created = []
    for key, lines in sorted(found.items()):
        mark = hashlib.sha1(key.encode()).hexdigest()[:12]
        if mark in known:
            print(f'info: already logged: {key}')
            continue
        path, what = key.split(' | ', 1)
        typ, prio = kind(key)
        short = re.sub(r'\s*\(.*', '', what).replace('#', 'N')[:70]
        title = f'I-{next_no:03d} COMMON: {short} in {os.path.basename(path)}'
        body = '\n'.join([
            f'Type: {typ}', f'Priority: {prio}', '',
            f'**Area:** `{path}`', '',
            '**Found:** by the COMMON pipeline ' + (f'on PR #{os.environ["PR"]}, ' if os.environ.get('PR') else '')
            + f'[run]({os.environ.get("RUN_URL", "")}) - existing code, a file that PR did not change; '
            'to be fixed in a future release.', '',
            '**Findings:**', *[f'- `{x}`' for x in lines], '',
            f'**Finding key:** `{key}`', f'<!-- pipeline-finding: {mark} -->', '',
            '**Source:** COMMON pipeline (job 9, checks/issues.py)'])
        issue = gh('POST', f'/repos/{repo}/issues', {'title': title, 'body': body, 'labels': ['COMMON']})
        created.append(f'- #{issue["number"]} {title}')
        print(f'created #{issue["number"]}: {title}')
        next_no += 1
    with open(report, 'a') as fh:
        fh.write(f'\n**Issues logged for a future release ({len(created)})**\n'
                 + ('\n'.join(created) if created else '_none new - every existing finding already has an issue_') + '\n')


if __name__ == '__main__':
    try:
        main()
    except Exception as e:   # never fails the pipeline: the findings stay in the report
        print(f'::notice::issues for the existing findings were not logged: {e}')
