#!/usr/bin/env python3
"""Fingerprints of this version (job 1) - what job 3 compares with what the validation database holds.

fingerprint.py <repo root>   (after the build) - prints lines for $GITHUB_OUTPUT and writes the code manifest
  fingerprint=<the whole version: application + database scripts>
  db_fingerprint=<the database scripts (db/deploy install + upgrade) and the test data (db/admin/test-data.json)>
  struct_fingerprint=<the database structure: every install / upgrade step that is not a code object, and the test data>
  app_fingerprint=<the application without its supporting objects (pages, shared components ...)>
  install_fingerprint=<the application + database scripts without the test data: what step 4.2 deploys - a change of
                      the test data alone keeps it, so a run whose data load failed reloads the data only (deploy=data)>
and repos/common/db/deploy/code-manifest.txt: one line per code object - "<key> <hash> install/<file>".

Code objects are the files the build names package-spec-*, package-body-*, view-* and trigger-*: each holds one
CREATE OR REPLACE statement, the same in install and upgrade, so a changed one can be run again on its own (quick
check, job 4). Everything else - tables, types, sequences, numbered steps (columns, constraints, indexes, seed data) -
is structure. A key is the file name without its number, so inserting a file (which renumbers the later ones) changes
neither the manifest keys nor the structure fingerprint. A code key whose install and upgrade copies differ counts as
structure (it cannot be patched on its own). run-all.sql is left out: it only lists the files in order.
"""
import hashlib, os, re, sys

CODE = re.compile(r'^(package-spec|package-body|view|trigger)-')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def tree(path, skip=()):
    """sha of every file under path (relative names, sorted)"""
    h = hashlib.sha256()
    for d, dirs, files in os.walk(path):
        dirs[:] = sorted(x for x in dirs if os.path.join(d, x) not in skip)
        for f in sorted(files):
            p = os.path.join(d, f)
            h.update(os.path.relpath(p, path).encode() + b'\0' + open(p, 'rb').read() + b'\0')
    return h.hexdigest()


def key(name):
    return re.sub(r'^\d+-', '', name)


def main(root):
    common = os.path.join(root, 'repos', 'common')
    deploy = os.path.join(common, 'db', 'deploy')
    app = os.path.join(common, 'dist', 'app')
    if not os.path.isfile(os.path.join(app, 'application.apx')):
        sys.exit(f'fingerprint.py: no built application in {app} - run the build first')
    data_file = os.path.join(common, 'db', 'admin', 'test-data.json')   # jobs 4-5 load it: a change redeploys
    data = sha(open(data_file, 'rb').read()) if os.path.isfile(data_file) else '-'
    scripts = b''.join(tree(os.path.join(deploy, d)).encode() for d in ('install', 'upgrade'))
    db = sha(scripts + data.encode())[:16]
    files = {}
    for d in ('install', 'upgrade'):
        for f in sorted(os.listdir(os.path.join(deploy, d))):
            if f != 'run-all.sql':
                files.setdefault(d, []).append((key(f), f, sha(open(os.path.join(deploy, d, f), 'rb').read())))
    up = {k: h for k, _, h in files['upgrade']}
    struct = hashlib.sha256(f'test-data {data}\n'.encode())
    manifest = []
    for d in ('install', 'upgrade'):
        for k, f, h in files[d]:
            if CODE.match(k) and (d == 'upgrade' or up.get(k) == h):
                if d == 'install':
                    manifest.append(f'{k} {h[:16]} install/{f}')
                continue
            struct.update(f'{d}/{k} {h}\n'.encode())
    with open(os.path.join(deploy, 'code-manifest.txt'), 'w') as fh:
        fh.write('\n'.join(manifest) + '\n')
    appfp = tree(app, skip=(os.path.join(app, 'supporting-objects'),))[:16]
    print(f'fingerprint={sha((tree(app)[:16] + db).encode())[:16]}')
    print(f'db_fingerprint={db}')
    print(f'struct_fingerprint={struct.hexdigest()[:16]}')
    print(f'app_fingerprint={appfp}')
    print(f'install_fingerprint={sha(tree(app)[:16].encode() + scripts)[:16]}')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '.')
