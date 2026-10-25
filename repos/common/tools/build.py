#!/usr/bin/env python3
"""The one build for every application (COMMON owns it; each repository has a thin wrapper, build.sh).

Rebuilds, from the feature folders, the application tree and the database scripts exactly as they were before the
split (every piece is listed in <repo>/SOURCE-MAP.json; KYC takes the install framework from common/db/framework),
then does what apex/tools/build.py did: the supporting objects (install / upgrade scripts in manifest order) and, with
--release, the APEXlang zip to import (APEXlang files only).

Usage (from a wrapper):  repos/kyc/build.sh --release 92      repos/common/build.sh --release 86
  python3 repos/common/tools/build.py --repo kyc|common [--release N] [--out DIR]
Output: <repo>/dist/ (the rebuilt application in dist/app, and the zip). Nothing in the feature folders changes.
"""
import argparse, json, os, re, shutil, zipfile

REPOS = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))   # .../repos
APP = {'kyc': ('KYC', 'apex/src/database/xxcus/apex_apps/f134', 'KYC-Compliance-Platform-APEXlang'),
       'common': ('COMMON', 'apex/src/database/xxfusion/apex_apps/f135', 'COMMON-Application-APEXlang')}
# Parsing schema an application must be installed in, the object its scripts need first, and the checks that run
# regardless (unchanged from apex/tools/build.py)
REQUIRED_SCHEMA = {'COMMON': 'XXFUSION'}
REQUIRED_OBJECT = {'KYC': ('XXFUSION', 'XXFND_SHARE_PKG')}
CHECKS = ('00a-', '00b-', '03-use-shared-schema')


def sources():
    """Every source file, rebuilt from its pieces in both repositories: {original path: bytes}."""
    out = {}
    for repo in ('kyc', 'common'):
        for src, pieces in json.load(open(os.path.join(REPOS, repo, 'SOURCE-MAP.json'))).items():
            data = b''
            for p in pieces:
                raw = open(os.path.join(REPOS, p['target']), 'rb').read()
                data += raw if p['whole'] else raw.decode('latin-1')[p['from']:p['to']].encode('latin-1')
            out[src] = data
    check_splits()
    return out


def check_splits():
    """A file split into several scripts (e.g. package spec / body) must still be covered exactly by its pieces: an
    edit that changes its length moves the cuts and truncates the scripts (KYC 100)."""
    split = {}
    for repo in ('kyc', 'common'):
        for pieces in json.load(open(os.path.join(REPOS, repo, 'SOURCE-MAP.json'))).values():
            for p in pieces:
                if not p['whole']:
                    split.setdefault(p['target'], []).append((p['from'], p['to']))
    for target, ranges in split.items():
        text = open(os.path.join(REPOS, target), 'rb').read().decode('latin-1')
        ranges.sort()
        if (ranges[0][0] != 0 or ranges[-1][1] != len(text)
                or any(a[1] != b[0] for a, b in zip(ranges, ranges[1:]))):
            raise SystemExit(f'SOURCE-MAP.json: the pieces of {target} no longer cover the file (length {len(text)}, '
                             f'pieces {ranges}): move the cuts to where each part now ends')


def manifest():
    """The install / upgrade order: both repositories' entries, in their original order."""
    entries = []
    for repo in ('kyc', 'common'):
        entries += json.load(open(os.path.join(REPOS, repo, 'db', 'manifest.json')))
    return [{k: v for k, v in e.items() if k != 'source_index'} for e in sorted(entries, key=lambda e: e['source_index'])]


def ident(name):
    return re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')


def component(kind, name, seq, content_file, schema=None, needs=None):
    cond = ''
    if schema and not content_file.startswith(CHECKS):
        cond = ("    serverSideCondition {\n        type: expression\n        language: sql\n"
                "        sqlExpression:\n            ```sql\n"
                f"            sys_context('userenv', 'current_schema') = '{schema}'\n            ```\n    }}\n")
    elif needs and not content_file.startswith(CHECKS):
        cond = ("    serverSideCondition {\n        type: rowsReturned\n"
                "        sqlQuery:\n            ```sql\n"
                f"            select 1 from all_objects where owner = '{needs[0]}' and object_name = '{needs[1]}'\n"
                "               and not exists (select 1 from user_tables\n"
                "                                where table_name in ('XXFND_LOOKUP_TYPES', 'XXCMP_SHARED_FKS'))\n"
                "            ```\n    }\n")
    return (f"{kind} {ident(name)} (\n"
            f"    execution {{\n        sequence: {seq}\n    }}\n"
            f"    script {{\n        contentFile: {content_file}\n    }}\n{cond})\n")


def build(repo, release, out):
    app, app_path, zip_name = APP[repo]
    src = sources()
    dist_app = os.path.join(out, 'app')
    shutil.rmtree(dist_app, ignore_errors=True)
    # the application tree (supporting objects are generated below)
    for path, data in src.items():
        if path.startswith(app_path + '/'):
            target = os.path.join(dist_app, os.path.relpath(path, app_path))
            os.makedirs(os.path.dirname(target), exist_ok=True)
            open(target, 'wb').write(data)
    if release:
        p = os.path.join(dist_app, 'application.apx')
        s = open(p, 'rb').read().decode('latin-1')
        open(p, 'wb').write(re.sub(r'(?m)^(    version: ).*$', rf'\g<1>Release {release}', s, count=1).encode('latin-1'))
    # the supporting objects, in manifest order
    so = os.path.join(dist_app, 'supporting-objects')
    entries = manifest()
    if len({e['name'] for e in entries}) != len(entries):
        raise SystemExit('duplicate script names in the manifests')
    for sub in ('install-scripts', 'upgrade-scripts'):
        os.makedirs(os.path.join(so, sub), exist_ok=True)
    inst, upg = [], []
    for e in entries:
        if app not in e.get('apps', ['KYC']):
            continue
        if e.get('install_sequence') is not None:
            open(os.path.join(so, 'install-scripts', e['file']), 'wb').write(src[f"apex/db/{e['file']}"])
            inst.append((e['install_sequence'], component('installScript', e['name'], e['install_sequence'], e['file'],
                                                          REQUIRED_SCHEMA.get(app), REQUIRED_OBJECT.get(app))))
        if e.get('upgrade_sequence') is not None:
            f = e.get('upgrade_file') or e['file']
            open(os.path.join(so, 'upgrade-scripts', f), 'wb').write(src[f'apex/db/{f}'])
            upg.append((e['upgrade_sequence'], component('upgradeScript', e['name'], e['upgrade_sequence'], f,
                                                         REQUIRED_SCHEMA.get(app), REQUIRED_OBJECT.get(app))))
    for fname, items in (('install-scripts.apx', inst), ('upgrade-scripts.apx', upg)):
        seqs = [s for s, _ in items]
        if len(seqs) != len(set(seqs)):
            raise SystemExit(f'duplicate sequence in {fname}: {sorted(seqs)}')
        with open(os.path.join(so, fname), 'w') as fh:
            fh.write('\n'.join(c for _, c in sorted(items)))
    print(f'{app}: {len(inst)} install scripts, {len(upg)} upgrade scripts -> {dist_app}')
    if release:
        target = os.path.join(out, f'{zip_name}_{release}.zip')
        with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as z:
            for d, dirs, files in os.walk(dist_app):
                dirs[:] = sorted(x for x in dirs if not x.startswith('.'))
                for f in sorted(files):
                    if not f.startswith('.'):
                        z.write(os.path.join(d, f), os.path.relpath(os.path.join(d, f), dist_app))
        print('wrote', target)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', required=True, choices=sorted(APP))
    ap.add_argument('--release', type=int)
    ap.add_argument('--out', help='output folder (default: <repo>/dist)')
    a = ap.parse_args()
    build(a.repo, a.release, a.out or os.path.join(REPOS, a.repo, 'dist'))
