#!/usr/bin/env python3
"""Job 3, step 3.0a - the pull request's title and linked issues (issue #218).

  Title:  <APP> Release <Number>: <short summary>   APP = COMMON | KYC, summary at most 60 characters
  Body:   one "Fixes #n" line (or Closes / Resolves) per issue of the release - GitHub links them to the PR
          (Development) and closes them when it merges
Each linked issue must exist, be an issue (not a PR) and carry the label of the title's application.

Usage: pr_meta.py   Env: PR_TITLE, PR_BODY, GITHUB_TOKEN, GITHUB_REPOSITORY (owner/repo), GITHUB_API_URL (optional).
Prints the release as "release=<N>" and "app=<APP>"; exit 1 with the reasons when something is wrong.
"""
import json, os, re, sys, urllib.request

TITLE = re.compile(r'^(COMMON|KYC) Release ([0-9]+): (.+)$')
FIXES = re.compile(r'\b(?:fixes|closes|resolves)\s+#([0-9]+)\b', re.I)
MAX_SUMMARY = 60


def issue(number):
    api = os.environ.get('GITHUB_API_URL', 'https://api.github.com')
    req = urllib.request.Request(f"{api}/repos/{os.environ['GITHUB_REPOSITORY']}/issues/{number}",
                                 headers={'Authorization': f"Bearer {os.environ['GITHUB_TOKEN']}",
                                          'Accept': 'application/vnd.github+json'})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        return None if e.code == 404 else sys.exit(f'GitHub API error {e.code} for issue #{number}')


def main():
    title, body = os.environ.get('PR_TITLE', '').strip(), os.environ.get('PR_BODY', '')
    problems = []
    m = TITLE.match(title)
    if not m:
        problems.append(f'PR title "{title}" must be "<COMMON|KYC> Release <Number>: <short summary>"')
    elif len(m.group(3)) > MAX_SUMMARY:
        problems.append(f'PR title summary has {len(m.group(3))} characters - at most {MAX_SUMMARY} '
                        '(list the issues in the body with "Fixes #n", not in the title)')
    numbers = sorted({int(n) for n in FIXES.findall(body)})
    if not numbers:
        problems.append('PR body has no "Fixes #n" line - link every issue of the release')
    for n in numbers:
        data = issue(n)
        if data is None:
            problems.append(f'#{n} does not exist')
        elif 'pull_request' in data:
            problems.append(f'#{n} is a pull request, not an issue')
        elif m and m.group(1) not in [label['name'] for label in data.get('labels', [])]:
            problems.append(f'#{n} ("{data["title"][:60]}") does not carry the label {m.group(1)}')
    for p in problems:
        print(f'::error title=PR title / linked issues::{p}')
    if problems:
        sys.exit(1)
    print(f'app={m.group(1)}')
    print(f'release={m.group(2)}')
    print(f"linked issues: {', '.join(f'#{n}' for n in numbers)}")


if __name__ == '__main__':
    main()
