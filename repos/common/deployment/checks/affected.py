#!/usr/bin/env python3
"""What a pull request affects - the pipeline tests only that on a PR (K, L; CLAUDE.md "test only what the feature
touches"); the full run (on demand) tests everything.

affected.py <base sha>   (run from the repository root, after the build) - prints two lines for $GITHUB_OUTPUT:
  db_tests=<ALL | repo paths of the DB test files to run, space separated>
  pages=<ALL | APEX page numbers the browser test opens, space separated>
ALL when the PR changes what every feature stands on: the COMMON framework and database scripts (repos/common/db),
the build tools, the application's shared components or definition (anything under app/ except its pages), the test
fixtures (tests/setup) or the pipeline. A page under app/pages is one page like a feature's page (Q5).
Otherwise:
  DB tests  - the tests of every changed feature (features/<f>/tests), every changed test file, and every release test
              (tests/*.sql) that names an object the PR changes (a package, table, view ... file under features/*/db)
  pages     - every changed page, plus the home page (1)
The fixtures (tests/setup) always run first - db/run.sh adds them.

affected.py --objects "<NAME> ..."   (job 4 quick check) - prints db_tests=<the tests of these database objects>: the
tests of every feature that holds one of them (features/<f>/db/.../<name>.*) and every test file that names one.
"""
import os, re, subprocess, sys

def tests_naming(objects):
    found = set()
    feats = os.listdir('repos/common/features') if os.path.isdir('repos/common/features') else []
    for d in ['repos/common/tests'] + sorted(f'repos/common/features/{f}/tests' for f in feats
                                              if os.path.isdir(f'repos/common/features/{f}/tests')):
        if not os.path.isdir(d):
            continue
        for t in sorted(os.listdir(d)):
            p = f'{d}/{t}'
            if t.endswith('.sql') and objects and re.search(r'\b(' + '|'.join(map(re.escape, objects)) + r')\b',
                                                             open(p, errors='ignore').read().lower()):
                found.add(p)
    return found


def feature_tests(features):
    found = set()
    for f in sorted(features):
        d = f'repos/common/features/{f}/tests'
        if os.path.isdir(d):
            found.update(f'{d}/{x}' for x in os.listdir(d) if x.endswith('.sql'))
    return found


if len(sys.argv) > 2 and sys.argv[1] == '--objects':
    objects = {o.lower() for o in sys.argv[2].split()}
    owners = {m.group(1) for d, _, fs in os.walk('repos/common/features') for x in fs
              if os.path.splitext(x)[0].lower() in objects and (m := re.match(r'repos/common/features/([^/]+)/db(/|$)', d))}
    print('db_tests=' + (' '.join(sorted(tests_naming(objects) | feature_tests(owners))) or 'NONE'))
    sys.exit(0)
base = sys.argv[1] if len(sys.argv) > 1 else ''
if not base:
    print('db_tests=ALL'); print('pages=ALL'); sys.exit(0)
changed = subprocess.run(['git', 'diff', '--name-only', base, 'HEAD'], capture_output=True, text=True,
                         check=True).stdout.split()
common = [c for c in changed if c.startswith('repos/common/')]
everything = re.compile(r'repos/common/(db/|tools/|app/(?!pages/)|tests/setup/|deployment/|build\.sh)')
if any(everything.match(c) for c in common):
    print('db_tests=ALL'); print('pages=ALL'); sys.exit(0)

features = {m.group(1) for c in common if (m := re.match(r'repos/common/features/([^/]+)/', c))}
objects = {os.path.splitext(os.path.basename(c))[0].lower() for c in common
           if re.match(r'repos/common/features/[^/]+/db/', c)}
tests = feature_tests(features)
tests.update(c for c in common if re.match(r'repos/common/(features/[^/]+/)?tests/[^/]+\.sql$', c) and os.path.exists(c))
tests.update(t for t in tests_naming(objects) if t.startswith('repos/common/tests/'))
pages = {'1'} | {str(int(m.group(1))) for c in common if (m := re.search(r'/pages/p(\d+)-[^/]+\.apx$', c))}
print('db_tests=' + (' '.join(sorted(tests)) or 'NONE'))
print('pages=' + ' '.join(sorted(pages, key=int)))
