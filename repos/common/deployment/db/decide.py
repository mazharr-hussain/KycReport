#!/usr/bin/env python3
"""Step 3.2b: the deploy decision - what this version needs, from what the validation database holds.

decide.py <record> <code-manifest> <out dir>
  <record>         the output of deployed.sql mode=get: "DEPLOYED <fp> <db> <struct> <app> <verified> <tested head>",
                   "CODE <key> <hash>" (the code objects the database holds), "PASSED ...", "FAILED ..."
  <code-manifest>  this version's code-manifest.txt (checks/fingerprint.py)
Env: FINGERPRINT, DB_FINGERPRINT, STRUCT_FINGERPRINT, APP_FINGERPRINT, REFRESH_BASELINE (true: full).
Writes <out dir>/deploy (reuse | app | patch | full), <out dir>/patch-files (install/<file> per line, install order)
<out dir>/changed-objects (object names, one per line) and <out dir>/app-changed (true: the application without its
supporting objects differs from the one deployed - the quick check imports it); prints the reason.

  reuse  the database holds this version, fully verified (fresh install + upgrade test)        jobs 4-5 skipped
  app    the database holds these database scripts, fully verified                              job 4 imports the app only
  patch  same structure as the database, only code objects (packages, views, triggers) changed  job 4 quick check
         first (the changed code alone, then its tests: a few minutes), then the full deploy - a quick check never merges
  full   anything else: no record, a deploy that did not finish (DIRTY), a structure change, a code object removed
         or renamed (it would stay in the database and hide a broken caller), or "refresh baseline"
"""
import os, re, sys

record_file, manifest_file, out = sys.argv[1:4]
fp, db, struct = os.environ.get('FINGERPRINT', ''), os.environ.get('DB_FINGERPRINT', ''), os.environ.get('STRUCT_FINGERPRINT', '')
rec, held = {}, {}
for line in open(record_file, errors='ignore'):
    p = line.split()
    if p[:1] == ['DEPLOYED'] and len(p) >= 7:
        rec = dict(zip(('fp', 'db', 'struct', 'app', 'verified', 'head'), p[1:7]))
    elif p[:1] == ['CODE'] and len(p) == 3:
        held[p[1]] = p[2]
now = {}
for line in open(manifest_file):
    p = line.split()
    if len(p) == 3:
        now[p[0]] = (p[1], p[2])


def done(deploy, reason, files=()):
    os.makedirs(out, exist_ok=True)
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
if os.environ.get('REFRESH_BASELINE') == 'true':
    done('full', 'refresh baseline asked for')
if not rec or rec.get('verified') in (None, 'DIRTY', '-'):
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
