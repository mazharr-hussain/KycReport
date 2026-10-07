#!/usr/bin/env python3
"""Build the APEXlang supporting objects from apex/db and, optionally, the release zip.

apex/db/*.sql is the single source of every database script; apex/db/manifest.json says
which scripts run on install and/or upgrade and in which order:

  {"name": "18c Admin console", "file": "18c-admin-console.sql",
   "install_sequence": 187, "upgrade_sequence": 147}

"upgrade_file" (optional) gives an upgrade-only variant; a script without "file" is upgrade-only.
"apps" (optional, default ["KYC"]) lists the applications whose supporting objects run the script:
KYC (app 134, schema XXCUS) and COMMON (schema XXFUSION, the shared security / setup / workflow application).
APEXlang reads install scripts from supporting-objects/install-scripts/ and upgrade scripts from
supporting-objects/upgrade-scripts/, so this tool writes a copy into each folder it is used in.

Usage:
  python3 apex/tools/build.py                 # regenerate apex/src/database/xxcus/apex_apps/f134/supporting-objects
  python3 apex/tools/build.py --release 12    # ... and write apex/KYC-Compliance-Platform-APEXlang_12.zip
                                              #     and apex/COMMON-Application-APEXlang_12.zip
"""
import argparse, json, os, re, shutil, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'db')
APPS = {
    'KYC':    (os.path.join(ROOT, 'src', 'database', 'xxcus', 'apex_apps', 'f134'), 'KYC-Compliance-Platform-APEXlang'),
    'COMMON': (os.path.join(ROOT, 'src', 'database', 'xxfusion', 'apex_apps', 'f135'), 'COMMON-Application-APEXlang'),
}


def ident(name):
    return re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')


def component(kind, name, seq, content_file):
    return (f"{kind} {ident(name)} (\n"
            f"    execution {{\n        sequence: {seq}\n    }}\n"
            f"    script {{\n        contentFile: {content_file}\n    }}\n)\n")


def build(app):
    SO = os.path.join(APPS[app][0], 'supporting-objects')
    manifest = json.load(open(os.path.join(DB, 'manifest.json')))
    names = [e['name'] for e in manifest]
    if len(names) != len(set(names)):
        raise SystemExit('duplicate script names in manifest.json')
    for sub in ('install-scripts', 'upgrade-scripts'):
        shutil.rmtree(os.path.join(SO, sub), ignore_errors=True)
        os.makedirs(os.path.join(SO, sub))
    inst, upg = [], []
    for e in manifest:
        if app not in e.get('apps', ['KYC']):
            continue
        if e.get('install_sequence') is not None:
            shutil.copy(os.path.join(DB, e['file']), os.path.join(SO, 'install-scripts', e['file']))
            inst.append((e['install_sequence'], component('installScript', e['name'], e['install_sequence'], e['file'])))
        if e.get('upgrade_sequence') is not None:
            f = e.get('upgrade_file') or e['file']
            shutil.copy(os.path.join(DB, f), os.path.join(SO, 'upgrade-scripts', f))
            upg.append((e['upgrade_sequence'], component('upgradeScript', e['name'], e['upgrade_sequence'], f)))
    for fname, items in (('install-scripts.apx', inst), ('upgrade-scripts.apx', upg)):
        seqs = [s for s, _ in items]
        if len(seqs) != len(set(seqs)):
            raise SystemExit(f'duplicate sequence in {fname}: {sorted(seqs)}')
        with open(os.path.join(SO, fname), 'w') as out:
            out.write('\n'.join(c for _, c in sorted(items)))
    print(f'{app}: {len(inst)} install scripts, {len(upg)} upgrade scripts')


def release(app, n):
    src = APPS[app][0]
    target = os.path.join(ROOT, f'{APPS[app][1]}_{n}.zip')
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as z:
        for d, dirs, files in os.walk(src):
            dirs[:] = sorted(x for x in dirs if not x.startswith('.'))
            for f in sorted(files):
                if f.startswith('.'):
                    continue
                p = os.path.join(d, f)
                z.write(p, os.path.relpath(p, src))
    print('wrote', target)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--release', type=int)
    a = ap.parse_args()
    for app in APPS:
        build(app)
        if a.release:
            release(app, a.release)
