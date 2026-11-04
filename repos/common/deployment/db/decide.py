#!/usr/bin/env python3
"""Step 3.2b: the deploy decision - what this version needs, from what the validation database holds.

decide.py <record> <code-manifest> <out dir>
  <record>         the output of deployed.sql mode=get: "DEPLOYED <fp> <db> <struct> <app> <verified> <tested head>",
                   "CODE <key> <hash>" (the code objects the database holds), "PASSED ...", "FAILED ..."
  <code-manifest>  this version's code-manifest.txt (checks/fingerprint.py)
Env: FINGERPRINT, DB_FINGERPRINT, STRUCT_FINGERPRINT, APP_FINGERPRINT, INSTALL_FINGERPRINT, START_FROM (4, 5, 6 or empty - see below).
Writes <out dir>/deploy (reuse | app | patch | upgrade | data | retest | full), <out dir>/patch-files (install/<file> per line, install order)
<out dir>/changed-objects (object names, one per line) and <out dir>/app-changed (true: the application without its
supporting objects differs from the one deployed - the quick check imports it); prints the reason.

  reuse  the database holds this version, fully verified (fresh install + upgrade test)        jobs 4-5 skipped
  app    the database holds these database scripts, fully verified                              job 4 imports the app only
  patch  same structure as the database, only code objects (packages, views, triggers) changed  job 4 quick check
         first (the changed code alone, then its tests: a few minutes), then the full deploy - a quick check never merges
  upgrade  job 4 (fresh install) passed for exactly this version on an earlier run and the run did not finish (e.g.
         job 5 failed, then a pipeline-only fix): job 4 skipped, job 5 (upgrade test) runs again    job 4 skipped
  retest the database holds a fully verified version and only the test data (and the pipeline's own files) changed
         since that commit (DATA_ONLY=1, from git in run.sh): job 6 loads the data, runs the failed test files only
  data   step 4.2 (deploy) passed for exactly this application and these database scripts and the test data never
         loaded since (4.2b failed): only the test data changed - job 4 loads the data (4.2b) and goes on, no redeploy
  full   anything else: no record, a deploy that did not finish (DIRTY), a structure change, a code object removed
         or renamed (it would stay in the database and hide a broken caller)

START_FROM - where to start (a PR label start-from-N from "/pipeline start-from N", a "Pipeline-Start-From: N" line in
the pushed commit's message, or the full run's "Start from" input; empty = as late as is safe, the rules above):
  4  run job 4 again: full (fresh install and upgrade test), whatever the record says
  5  skip job 4 when it passed for this version (upgrade), else the rules above (job 4 runs)
  6  skip jobs 4-5 when the database holds this version fully verified (reuse), else the rules above
A start is never later than the records allow: the reason is printed and written to <out dir>/start-note.
"""
import os, re, sys

record_file, manifest_file, out = sys.argv[1:4]
fp, db, struct = os.environ.get('FINGERPRINT', ''), os.environ.get('DB_FINGERPRINT', ''), os.environ.get('STRUCT_FINGERPRINT', '')
rec, held, passed = {}, {}, {}
for line in open(record_file, errors='ignore'):
    p = line.split()
    if p[:1] == ['DEPLOYED'] and len(p) >= 7:
        rec = dict(zip(('fp', 'db', 'struct', 'app', 'verified', 'head'), p[1:7]))
    elif p[:1] == ['CODE'] and len(p) == 3:
        held[p[1]] = p[2]
    elif p[:1] == ['PASSED'] and len(p) == 3:
        passed[p[1]] = p[2]
now = {}
for line in open(manifest_file):
    p = line.split()
    if len(p) == 3:
        now[p[0]] = (p[1], p[2])


start = os.environ.get('START_FROM', '').strip()
fresh_ok = bool(fp) and passed.get('fresh') == fp
inst = os.environ.get('INSTALL_FINGERPRINT', '')
install_ok = bool(inst) and passed.get('install') == inst   # 4.2 passed, 4.2b never loaded since
note = []


def full_rec_ok(r):
    return bool(r) and r.get('verified') == 'FULL'


def done(deploy, reason, files=()):
    if start == '5' and deploy != 'upgrade' and deploy != 'reuse':
        if fresh_ok:
            deploy, reason, files = 'upgrade', f'start from job 5 as asked: job 4 passed for this version ({fp}) on an earlier run', ()
        else:
            note.append(f'start from job 5 not possible: job 4 has not passed for this version ({fp}) - it runs')
    if start == '6' and deploy != 'reuse':
        note.append('start from job 6 not possible: the database does not hold this version fully verified - '
                    + ('job 5 runs' if deploy == 'upgrade' else 'jobs 4-5 run'))
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, 'start-note'), 'w').write(''.join(f'{n}\n' for n in note))
    for n in note:
        print(f'info: {n}')
    open(os.path.join(out, 'deploy'), 'w').write(deploy + '\n')
    open(os.path.join(out, 'patch-files'), 'w').write(''.join(f + '\n' for f in files))
    names = sorted({re.sub(r'^(package-spec|package-body|view|trigger)-|\.[a-z]+$', '', os.path.basename(k)).upper()
                    for k in (re.sub(r'^install/\d+-', '', f) for f in files)})
    open(os.path.join(out, 'changed-objects'), 'w').write(''.join(n + '\n' for n in names))
    app_changed = rec.get('app') != os.environ.get('APP_FINGERPRINT', '')
    open(os.path.join(out, 'app-changed'), 'w').write(('true' if app_changed else 'false') + '\n')
    print(f'deploy: {deploy} - {reason}')
    sys.exit(0)


if not (fp and db and struct):
    done('full', 'no fingerprint')
if full_rec_ok(rec) and rec['fp'] != fp and os.environ.get('DATA_ONLY') == '1' and start in ('', '6'):
    done('retest', 'info: only the test data changed since the version the database passed with - job 6 loads it and '
                   'runs the test files that failed last time (jobs 4-5 skipped)')
if install_ok and not fresh_ok and start in ('', '4'):
    done('data', f'info: this version is installed ({inst}, step 4.2 passed) and its test data never loaded - '
                 'job 4 loads the test data only (4.2b), no redeploy')
if start == '4':
    done('full', 'start from job 4 as asked: fresh install and upgrade test')
if start not in ('', '4', '5', '6'):
    note.append(f'start from "{start}" is not a restart point (4, 5 or 6) - ignored')
if not rec or rec.get('verified') in (None, 'DIRTY', '-'):
    if fresh_ok:
        done('upgrade', f'info: job 4 (fresh install) passed for this version ({fp}) on an earlier run that did not '
                        'finish - job 4 skipped, the upgrade test (job 5) runs again')
    done('full', 'the database holds no complete deploy (nothing recorded, or the last deploy did not finish)')
full = rec['verified'] == 'FULL'
if full and rec['fp'] == fp:
    done('reuse', f'info: the validation database already holds this version ({fp}), fully verified - jobs 4-5 skipped')
if full and rec['db'] == db:
    done('app', f'info: the database scripts are those deployed ({db}) - only the APEX application is replaced (schema and data kept)')
if rec['struct'] in ('-', '') or rec['struct'] != struct:
    done('full', f'the database structure ({struct}) differs from the deployed one ({rec["struct"]}) - full fresh install and upgrade test')
gone = sorted(k for k in held if k not in now)
if gone:
    done('full', 'code object(s) removed or renamed (' + ', '.join(gone[:5]) + ') - full fresh install and upgrade test')
files = sorted((f for k, (h, f) in now.items() if held.get(k) != h), key=lambda f: os.path.basename(f))
done('patch', f'info: same database structure, {len(files)} changed code object file(s) - quick check first '
              f'(job 4), then the full deploy', files)
