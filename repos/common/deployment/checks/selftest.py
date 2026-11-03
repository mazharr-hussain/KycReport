#!/usr/bin/env python3
"""Self-test of the pipeline's decision logic (step 1.1, also pipeline-check.yml): checks/affected.py chooses the DB
tests and pages a pull request affects. A throwaway git repository holds a small COMMON layout; each case commits a
change and compares the choice. Exit 1 on the first wrong choice."""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def git(*a, cwd):
    subprocess.run(['git', *a], cwd=cwd, check=True, capture_output=True)


def write(root, path, text='x\n'):
    p = os.path.join(root, path); os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w').write(text)


def case(root, name, files, want_tests, want_pages):
    base = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=root, capture_output=True, text=True).stdout.strip()
    for f, t in files.items():
        write(root, f, t)
    git('add', '-A', cwd=root); git('commit', '-qm', name, cwd=root)
    out = subprocess.run([sys.executable, os.path.join(HERE, 'affected.py'), base], cwd=root, capture_output=True,
                         text=True, check=True).stdout
    got = dict(l.split('=', 1) for l in out.split('\n') if '=' in l)
    ok = got.get('db_tests') == want_tests and got.get('pages') == want_pages
    print(('PASS ' if ok else 'FAIL ') + f'{name}: db_tests={got.get("db_tests")} pages={got.get("pages")}')
    return ok


with tempfile.TemporaryDirectory() as root:
    git('init', '-q', cwd=root); git('config', 'user.email', 't@t', cwd=root); git('config', 'user.name', 't', cwd=root)
    write(root, 'repos/common/features/lookups/db/package_bodies/xxfnd_lookup_pkg.pkb')
    write(root, 'repos/common/features/lookups/tests/r90_lookup_test.sql')
    write(root, 'repos/common/features/lookups/pages/p00102-lookups.apx')
    write(root, 'repos/common/tests/r78_common_test.sql', 'begin xxfnd_lookup_pkg.x; end;\n')
    write(root, 'repos/common/tests/r79_other_test.sql', 'begin null; end;\n')
    git('add', '-A', cwd=root); git('commit', '-qm', 'start', cwd=root)
    results = [
        case(root, 'a page only', {'repos/common/features/lookups/pages/p00102-lookups.apx': 'y\n'},
             'repos/common/features/lookups/tests/r90_lookup_test.sql', '1 102'),
        case(root, 'a package: its feature tests and the release tests that name it',
             {'repos/common/features/lookups/db/package_bodies/xxfnd_lookup_pkg.pkb': 'y\n'},
             'repos/common/features/lookups/tests/r90_lookup_test.sql repos/common/tests/r78_common_test.sql', '1'),
        case(root, 'a test file only', {'repos/common/tests/r79_other_test.sql': 'begin null; null; end;\n'},
             'repos/common/tests/r79_other_test.sql', '1'),
        case(root, 'the framework: everything', {'repos/common/db/framework/x.sql': 'y\n'}, 'ALL', 'ALL'),
        case(root, 'a KYC-only change: nothing of COMMON', {'repos/kyc/x.sql': 'y\n'}, 'NONE', '1'),
    ]
sys.exit(0 if all(results) else 1)
