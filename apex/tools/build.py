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
  python3 apex/tools/build.py --release 12    # ... and write, per application, the APEXlang zip, the
                                              #     one package to import (apex/KYC-Compliance-Platform-APEXlang_12.zip,
                                              #     COMMON-...). It holds APEXlang files only:
                                              #     App Builder's import wizard shows a blank page on any other file.
"""
import argparse, json, os, re, shutil, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'db')
APPS = {
    'KYC':    (os.path.join(ROOT, 'src', 'database', 'xxcus', 'apex_apps', 'f134'), 'KYC-Compliance-Platform-APEXlang'),
    'COMMON': (os.path.join(ROOT, 'src', 'database', 'xxfusion', 'apex_apps', 'f135'), 'COMMON-Application-APEXlang'),
}
# Parsing schema an application must be installed in: its scripts (except the checks, file names 00a/00b) run only
# there, so an import with the wrong parsing schema installs nothing and 00b says how to fix it.
REQUIRED_SCHEMA = {'COMMON': 'XXFUSION'}
# Object an application's scripts need before they run (release 54: KYC reaches the shared objects in XXFUSION; 03
# says what to do when the COMMON application is not installed yet), and 03 must have moved the schema's own copy of
# the shared tables; otherwise the scripts are skipped. Checks and 03 run regardless.
REQUIRED_OBJECT = {'KYC': ('XXFUSION', 'XXFND_SHARE_PKG')}
CHECKS = ('00a-', '00b-', '03-use-shared-schema')
# release 56: one package per application - the APEXlang zip (App Builder imports only APEXlang files). INSTALL.md
# and the ADMIN script stay in the repository: apex/install/<APP>/INSTALL.md, apex/db/admin/.


def ident(name):
    return re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')


def component(kind, name, seq, content_file, schema=None, needs=None):
    cond = ''
    if schema and not content_file.startswith(CHECKS):
        cond = ("    serverSideCondition {\n        type: expression\n        language: sql\n"
                "        sqlExpression:\n            ```sql\n"
                f"            sys_context('userenv', 'current_schema') = '{schema}'\n            ```\n    }}\n")
    elif needs and not content_file.startswith(CHECKS):
        # and the one-time move (ADMIN script move-kyc-shared-data-to-xxfusion.sql) is finished
        cond = ("    serverSideCondition {\n        type: rowsReturned\n"
                "        sqlQuery:\n            ```sql\n"
                f"            select 1 from all_objects where owner = '{needs[0]}' and object_name = '{needs[1]}'\n"
                "               and not exists (select 1 from user_tables\n"
                "                                where table_name in ('XXFND_LOOKUP_TYPES', 'XXCMP_SHARED_FKS'))\n"
                "            ```\n    }\n")
    return (f"{kind} {ident(name)} (\n"
            f"    execution {{\n        sequence: {seq}\n    }}\n"
            f"    script {{\n        contentFile: {content_file}\n    }}\n{cond})\n")


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
            inst.append((e['install_sequence'], component('installScript', e['name'], e['install_sequence'], e['file'], REQUIRED_SCHEMA.get(app), REQUIRED_OBJECT.get(app))))
        if e.get('upgrade_sequence') is not None:
            f = e.get('upgrade_file') or e['file']
            shutil.copy(os.path.join(DB, f), os.path.join(SO, 'upgrade-scripts', f))
            upg.append((e['upgrade_sequence'], component('upgradeScript', e['name'], e['upgrade_sequence'], f, REQUIRED_SCHEMA.get(app), REQUIRED_OBJECT.get(app))))
    for fname, items in (('install-scripts.apx', inst), ('upgrade-scripts.apx', upg)):
        seqs = [s for s, _ in items]
        if len(seqs) != len(set(seqs)):
            raise SystemExit(f'duplicate sequence in {fname}: {sorted(seqs)}')
        with open(os.path.join(SO, fname), 'w') as out:
            out.write('\n'.join(c for _, c in sorted(items)))
    print(f'{app}: {len(inst)} install scripts, {len(upg)} upgrade scripts')


def set_version(app, n):
    # release 74: the application version (footer, #APP_VERSION#) is the release number
    p = os.path.join(APPS[app][0], 'application.apx')
    s = open(p).read()
    s2 = re.sub(r'(?m)^(    version: ).*$', rf'\g<1>Release {n}', s, count=1)
    if s2 != s:
        open(p, 'w').write(s2)


def release(app, n):
    src = APPS[app][0]
    set_version(app, n)
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
    ap.add_argument('--app', choices=sorted(APPS), help='build only this application (default: all)')
    a = ap.parse_args()
    for app in ([a.app] if a.app else APPS):
        build(app)
        if a.release:
            release(app, a.release)
