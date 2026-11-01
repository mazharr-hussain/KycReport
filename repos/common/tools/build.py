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
    # the database scripts: each is its whole files (one object or one change step per file) in manifest order
    for repo in ('kyc', 'common'):
        for e in json.load(open(os.path.join(REPOS, repo, 'db', 'manifest.json'))):
            for key, units in (('file', e['units']), ('upgrade_file', e.get('upgrade_units'))):
                if units and e.get(key):
                    out[f"apex/db/{e[key]}"] = b''.join(open(os.path.join(REPOS, u), 'rb').read() for u in units)
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
    return [{k: v for k, v in e.items() if k not in ('source_index', 'units', 'upgrade_units')}
            for e in sorted(entries, key=lambda e: e['source_index'])]


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
    deploy(repo, app)
    import feature_docs                     # every feature's docs/components/<feature>/technical.md
    feature_docs.run((repo,))


KIND = {'tables': 'table', 'views': 'view', 'types': 'type', 'type_bodies': 'type body', 'package_specs': 'package spec',
        'package_bodies': 'package body', 'triggers': 'trigger', 'sequences': 'sequence', 'functions': 'function',
        'procedures': 'procedure', 'synonyms': 'synonym'}


def unit_info(u):
    """(kind, object name, feature) of a unit file; changes are ('change', step, script)"""
    parts = u.split('/')
    if parts[-2] in KIND:
        feat = parts[parts.index('features') + 1] if 'features' in parts else 'framework'
        return KIND[parts[-2]], parts[-1].rsplit('.', 1)[0], feat
    return 'change', parts[-1][:-4], parts[-2]


def deploy(repo, app):
    """<repo>/db/deploy: the install and upgrade steps as numbered whole files with run-all.sql, INDEX.md and the
    dependency tree (DEPENDENCIES.md, dependencies.json) - written on every build, never edited by hand."""
    root = os.path.join(REPOS, repo, 'db', 'deploy')
    shutil.rmtree(root, ignore_errors=True)
    entries = []
    for r in ('kyc', 'common'):
        entries += json.load(open(os.path.join(REPOS, r, 'db', 'manifest.json')))
    entries = [e for e in entries if app in e.get('apps', ['KYC'])]
    index = []
    for mode, seq, units in (('install', 'install_sequence', 'units'), ('upgrade', 'upgrade_sequence', 'upgrade_units')):
        d = os.path.join(root, mode)
        os.makedirs(d)
        run, n = ['-- Runs every ' + mode + ' step in order (SQLcl / SQL Developer: @run-all.sql). Generated by build.py.',
                  'set define off'], 0
        for e in sorted((e for e in entries if e.get(seq) is not None), key=lambda e: e[seq]):
            for u in e.get(units) or e['units']:
                n += 10
                kind, name, where = unit_info(u)
                f = f"{n:04d}-{kind.replace(' ', '-')}-{name}{os.path.splitext(u)[1]}" if kind != 'change' else \
                    f"{n:04d}-{e['file'][:-4]}-{name}.sql"
                shutil.copyfile(os.path.join(REPOS, u), os.path.join(d, f))
                run.append(f'@@{f}')
                if mode == 'install':
                    index.append((f[:4], kind, name, where, e['file'][:-4], u))
        open(os.path.join(d, 'run-all.sql'), 'w').write('\n'.join(run) + '\n')
    # the dependency tree (both applications, so KYC's use of COMMON shows): the objects, APEX files and other
    # objects that name each object
    objs, texts = {}, {}
    for r in ('kyc', 'common'):
        for e in json.load(open(os.path.join(REPOS, r, 'db', 'manifest.json'))):
            owner = 'COMMON' if 'COMMON' in e.get('apps', ['KYC']) and r == 'common' else 'KYC'
            for u in e['units'] + (e.get('upgrade_units') or []):
                kind, name, where = unit_info(u)
                if kind != 'change':
                    label = name + (' (body)' if kind in ('package body', 'type body') else '')
                    objs.setdefault(name, (kind.replace(' body', ' spec') if kind == 'package body' else kind, where, u, owner))
                    texts[label] = (owner, re.sub(r'(?m)--.*$', '', open(os.path.join(REPOS, u), errors='ignore').read()))
        app_dir = os.path.join(REPOS, r, 'dist', 'app')
        for d, _, fs in os.walk(app_dir):
            for f in fs:
                if f.endswith('.apx') and 'supporting-objects' not in d:
                    texts[f'apex:{APP[r][0]}:' + os.path.relpath(os.path.join(d, f), app_dir)] = \
                        (APP[r][0], open(os.path.join(d, f), errors='ignore').read())
    pat = re.compile(r'(?i)\b(' + '|'.join(map(re.escape, sorted(objs, key=len, reverse=True))) + r')\b')
    uses = {k: sorted({m.lower() for m in pat.findall(t)} - {k.replace(' (body)', '')}) for k, (_, t) in texts.items()}
    used_by = {}
    for k, v in uses.items():
        for o in v:
            used_by.setdefault(o, set()).add(k.replace(' (body)', ''))
    mine = {n: o for n, o in objs.items() if o[3] == app or (app == 'KYC' and o[2] == 'framework')}
    json.dump({'objects': {n: {'type': o[0], 'feature': o[1], 'file': o[2], 'application': o[3]} for n, o in mine.items()},
               'uses': {k: v for k, v in uses.items() if k.replace(' (body)', '') in mine or k.startswith(f'apex:{app}:')},
               'used_by': {k: sorted(v) for k, v in used_by.items() if k in mine}},
              open(os.path.join(root, 'dependencies.json'), 'w'), indent=1)
    def tag(x):
        return x if x.startswith('apex:') or objs.get(x, (0, 0, 0, app))[3] == app else f'{x} [{objs[x][3]}]'
    md = [f'# {app} - dependency tree', '', 'Generated by build.py from the source files. **Uses**: what the object '
          'names; **Used by**: objects and APEX files (`apex:`) naming it; [APP] marks the other application.', '']
    for name in sorted(mine):
        kind, where, u, _ = mine[name]
        md += [f'## {name}', f'{kind} - feature `{where}` - `{u}`', '']
        for label in (name, name + ' (body)'):
            if uses.get(label):
                md.append(f"- **Uses{' (body)' if label != name else ''}**: " + ', '.join(tag(x) for x in uses[label]))
        if used_by.get(name):
            md.append('- **Used by**: ' + ', '.join(tag(x) for x in sorted(used_by[name])))
        md.append('')
    md += ['## APEX files', '']
    md += [f'- `{k}`: ' + ', '.join(tag(x) for x in v) for k, v in sorted(uses.items()) if k.startswith(f'apex:{app}:') and v]
    open(os.path.join(root, 'DEPENDENCIES.md'), 'w').write('\n'.join(md) + '\n')
    # one diagram per feature: its objects and what they use
    os.makedirs(os.path.join(root, 'diagrams'))
    for feat in sorted({o[1] for o in mine.values()}):
        edges = sorted({(n, x) for n, o in mine.items() if o[1] == feat for lab in (n, n + ' (body)')
                        for x in uses.get(lab, [])})
        lines = [f'# {feat}', '', '```mermaid', 'graph LR'] + [f'    {a} --> {b}' for a, b in edges] + ['```', '']
        open(os.path.join(root, 'diagrams', feat + '.md'), 'w').write('\n'.join(lines))
    rows = ['# ' + app + ' - install steps', '', 'Generated by build.py. Run `install/run-all.sql` (new database) or '
            '`upgrade/run-all.sql` (existing database); the APEX import runs the same steps. Edit the **source** file, never '
            'this folder.', '', '| # | Type | Object / step | Feature / script | Source file |', '|---|---|---|---|---|']
    rows += [f'| {n} | {k} | {nm} | {w} | `{u}` |' for n, k, nm, w, _, u in index]
    open(os.path.join(root, 'INDEX.md'), 'w').write('\n'.join(rows) + '\n')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', required=True, choices=sorted(APP))
    ap.add_argument('--release', type=int)
    ap.add_argument('--out', help='output folder (default: <repo>/dist)')
    a = ap.parse_args()
    build(a.repo, a.release, a.out or os.path.join(REPOS, a.repo, 'dist'))
