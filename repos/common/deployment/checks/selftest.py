#!/usr/bin/env python3
"""Self-test of the pipeline's decision logic (step 1.1, also pipeline-check.yml):
  - checks/affected.py chooses the DB tests and pages a pull request affects (and the tests of given objects)
  - checks/fingerprint.py: renumbering keeps the structure; a code change changes only the code manifest
  - db/decide.py: reuse / app / patch / full from what the database holds
A throwaway git repository holds a small COMMON layout; each case compares the choice. Exit 1 when any is wrong."""
import os, shutil, subprocess, sys, tempfile

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
        case(root, 'a page under app/pages: that page (Q5)', {'repos/common/app/pages/p00100-administration.apx': 'y\n'},
             'NONE', '1 100'),
        case(root, 'an application shared component: everything', {'repos/common/app/shared-components/lov.apx': 'y\n'},
             'ALL', 'ALL'),
    ]
    out = subprocess.run([sys.executable, os.path.join(HERE, 'affected.py'), '--objects', 'XXFND_LOOKUP_PKG'], cwd=root,
                         capture_output=True, text=True, check=True).stdout.strip()
    want = 'db_tests=repos/common/features/lookups/tests/r90_lookup_test.sql repos/common/tests/r78_common_test.sql'
    print(('PASS ' if out == want else 'FAIL ') + f'objects mode: {out}')
    results.append(out == want)

# ---- fingerprint.py and decide.py ----------------------------------------------------------------------------------
DECIDE = os.path.join(HERE, '..', 'db', 'decide.py')


def build(root, install, upgrade=None):
    """a built version: db/deploy/install + upgrade (upgrade = install unless given) and dist/app"""
    d = os.path.join(root, 'repos/common/db/deploy')
    shutil.rmtree(d, ignore_errors=True)
    for sub, files in (('install', install), ('upgrade', upgrade or install)):
        for f, t in files.items():
            write(root, f'repos/common/db/deploy/{sub}/{f}', t)
        write(root, f'repos/common/db/deploy/{sub}/run-all.sql', ''.join(f'@@{f}\n' for f in sorted(files)))
    write(root, 'repos/common/dist/app/application.apx', 'app\n')
    write(root, 'repos/common/dist/app/supporting-objects/install.sql', ''.join(sorted(install.values())))
    out = subprocess.run([sys.executable, os.path.join(HERE, 'fingerprint.py'), root], capture_output=True, text=True,
                         check=True).stdout
    fp = dict(l.split('=', 1) for l in out.split('\n') if '=' in l)
    fp['manifest'] = open(os.path.join(d, 'code-manifest.txt')).read()
    return fp


def record(fp, verified='FULL'):
    lines = [f'DEPLOYED {fp["fingerprint"]} {fp["db_fingerprint"]} {fp["struct_fingerprint"]} {fp["app_fingerprint"]} {verified} abc']
    lines += [f'CODE {l.split()[0]} {l.split()[1]}' for l in fp['manifest'].split('\n') if l.strip()]
    return '\n'.join(lines) + '\n'


def decide(root, rec, fp, start=''):
    open(os.path.join(root, 'rec.txt'), 'w').write(rec)
    open(os.path.join(root, 'repos/common/db/deploy/code-manifest.txt'), 'w').write(fp['manifest'])   # this version's
    env = dict(os.environ, FINGERPRINT=fp['fingerprint'], DB_FINGERPRINT=fp['db_fingerprint'],
               STRUCT_FINGERPRINT=fp['struct_fingerprint'], APP_FINGERPRINT=fp['app_fingerprint'],
               INSTALL_FINGERPRINT=fp['install_fingerprint'], START_FROM=start)
    subprocess.run([sys.executable, DECIDE, os.path.join(root, 'rec.txt'),
                    os.path.join(root, 'repos/common/db/deploy/code-manifest.txt'), os.path.join(root, 'out')],
                   env=env, check=True, capture_output=True)
    r = lambda f: open(os.path.join(root, 'out', f)).read().split()
    return r('deploy')[0], r('patch-files'), r('changed-objects')


def check(name, got, want):
    ok = got == want
    print(('PASS ' if ok else 'FAIL ') + f'{name}: {got}' + ('' if ok else f' (expected {want})'))
    results.append(ok)


with tempfile.TemporaryDirectory() as root:
    v1 = {'0010-table-xxfnd_a.sql': 'create table a\n', '0020-package-spec-xxfnd_a_pkg.pks': 'spec 1\n',
          '0030-package-body-xxfnd_a_pkg.pkb': 'body 1\n', '0040-view-xxfnd_a_v.sql': 'view 1\n'}
    a = build(root, v1)
    renum = {'0010-table-xxfnd_a.sql': 'create table a\n', '0015-package-spec-xxfnd_b_pkg.pks': 'spec b\n',
             '0025-package-spec-xxfnd_a_pkg.pks': 'spec 1\n', '0035-package-body-xxfnd_a_pkg.pkb': 'body 1\n',
             '0045-view-xxfnd_a_v.sql': 'view 1\n'}
    b = build(root, renum)
    check('fingerprint: a new package renumbers the later files - same structure', b['struct_fingerprint'], a['struct_fingerprint'])
    check('decide: same version, fully verified -> reuse', decide(root, record(b), b)[0], 'reuse')
    check('decide: same version, quick check only -> patch (never reuse)', decide(root, record(b, 'PATCH'), b)[0], 'patch')
    check('decide: start from job 4 -> full', decide(root, record(b), b, '4')[0], 'full')
    fresh = record(b, 'DIRTY') + f'PASSED fresh {b["fingerprint"]}\n'
    check('decide: job 4 passed for this version, run did not finish -> upgrade', decide(root, fresh, b)[0], 'upgrade')
    check('decide: start from job 5, job 4 passed -> upgrade', decide(root, record(a) + f'PASSED fresh {b["fingerprint"]}\n', b, '5')[0], 'upgrade')
    check('decide: start from job 5, job 4 not passed -> rules (full)', decide(root, record(b, 'DIRTY'), b, '5')[0], 'full')
    check('decide: start from job 6 but not verified -> rules (full)', decide(root, record(b, 'DIRTY'), b, '6')[0], 'full')
    check('decide: job 4 passed for another version -> full', decide(root, record(b, 'DIRTY') + 'PASSED fresh other\n', b)[0], 'full')
    check('decide: last deploy did not finish -> full', decide(root, record(b, 'DIRTY'), b)[0], 'full')
    check('decide: nothing recorded -> full', decide(root, '', b)[0], 'full')
    c = build(root, dict(v1, **{'0030-package-body-xxfnd_a_pkg.pkb': 'body 2\n'}))
    check('fingerprint: a package body change keeps the structure', c['struct_fingerprint'], a['struct_fingerprint'])
    check('decide: a package body changed -> patch with that file and object',
          decide(root, record(a), c), ('patch', ['install/0030-package-body-xxfnd_a_pkg.pkb'], ['XXFND_A_PKG']))
    check('decide: a new package -> patch with its files', decide(root, record(a), b),
          ('patch', ['install/0015-package-spec-xxfnd_b_pkg.pks'], ['XXFND_B_PKG']))
    check('decide: a package removed -> full', decide(root, record(b), a)[0], 'full')
    d = build(root, dict(v1, **{'0010-table-xxfnd_a.sql': 'create table a (x number)\n'}))
    check('fingerprint: a table change changes the structure', d['struct_fingerprint'] != a['struct_fingerprint'], True)
    check('decide: a table changed -> full', decide(root, record(a), d)[0], 'full')
    e = build(root, v1, dict(v1, **{'0030-package-body-xxfnd_a_pkg.pkb': 'body other\n'}))
    check('fingerprint: install and upgrade copies differ - structure', e['struct_fingerprint'] != a['struct_fingerprint'], True)
    f = build(root, dict(v1, **{'0050-01-step-xxfnd_a-add-column.sql': 'exec add_column\n'}))
    data = os.path.join(root, 'repos/common/db/admin/test-data.json')
    write(root, 'repos/common/db/admin/test-data.json', '{"tables": []}\n'); g1 = build(root, v1)
    write(root, 'repos/common/db/admin/test-data.json', '{"tables": [], "no_data": {}}\n'); g2 = build(root, v1)
    os.remove(data)
    check('fingerprint: a test data change keeps the install fingerprint', g2['install_fingerprint'], g1['install_fingerprint'])
    check('fingerprint: a test data change changes the version fingerprint', g2['fingerprint'] != g1['fingerprint'], True)
    inst = record(g1, 'DIRTY') + f'PASSED install {g1["install_fingerprint"]}\n'
    check('decide: installed, data load failed, only the data changed -> data', decide(root, inst, g2)[0], 'data')
    check('decide: same, start from job 4 -> data (no redeploy)', decide(root, inst, g2, '4')[0], 'data')
    check('decide: installed, then the scripts changed -> full', decide(root, inst, f)[0], 'full')
    check('decide: a numbered step added -> full', decide(root, record(a), f)[0], 'full')
sys.exit(0 if all(results) else 1)
