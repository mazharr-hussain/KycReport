#!/usr/bin/env python3
"""COMMON stage 1 checks, run by repos/common/deployment/checks/run.sh (also runnable locally).

Errors (exit 1): a manifest script or unit that does not exist; a page not listed in SOURCE-MAP.json (the build would
leave it out); a SQL comment line ending with ';' inside a plain SQL statement (SQL Developer ends the statement there);
a change under the frozen apex/ folder (with --base).
Warnings: KYC code writing COMMON (XXFND_) tables directly; HTML built in PL/SQL; a release folder without "Fixes #n"
in the PR body (with --body);
APEX page security (no authorization scheme, unrestricted access, inline CSS/JS); PL/SQL risks (WHEN OTHERS THEN NULL,
EXECUTE IMMEDIATE with ||, hard-coded schema, SELECT *, DBMS_OUTPUT, TO_DATE without format, COMMIT without autonomous
transaction); COMMON referring to XXCMP_; install safety (step script not in the manifest, bare CREATE/ALTER TABLE or
DROP in a step script, base table script edited); release folder incomplete (README, run-release.sql, its files).
Usage: python3 repos/common/deployment/checks/pr_checks.py [--base <sha>] [--body-file <file>]
"""
import argparse, glob, json, os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))  # repository root
R = os.path.join(ROOT, 'repos')
errors, warnings = [], []


def manifest():
    for app in ('common',):
        p = f'{R}/{app}/db/manifest.json'
        if not os.path.exists(p):
            continue
        for e in json.load(open(p)):
            for u in e.get('units', []):
                if not os.path.exists(os.path.join(R, u)):
                    errors.append(f'{app}: manifest unit missing: {u} ({e.get("file")})')


def source_map():
    for app in ('common',):
        p = f'{R}/{app}/SOURCE-MAP.json'
        if not os.path.exists(p):
            continue
        targets = {t['target'] for v in json.load(open(p)).values() for t in v}
        for page in glob.glob(f'{R}/{app}/features/*/pages/*.apx') + glob.glob(f'{R}/{app}/app/pages/*.apx'):
            rel = os.path.relpath(page, R)
            if rel not in targets:
                errors.append(f'{app}: page not in SOURCE-MAP.json (the build leaves it out): {rel}')


def sql_comments():
    plsql = re.compile(r'(declare|begin|create( or replace)?( editionable)? (package|procedure|function|trigger|type))', re.I)
    for f in glob.glob(f'{R}/common/db/**/*.sql', recursive=True) + glob.glob(f'{R}/common/features/**/*.sql', recursive=True):
        if '/deploy/' in f or '/tests/' in f:
            continue
        inst = is_plsql = False
        for i, line in enumerate(open(f, errors='ignore'), 1):
            s = line.strip()
            if not inst and s and not s.startswith('--'):
                inst, is_plsql = True, bool(plsql.match(s))
            if inst and not is_plsql and s.startswith('--') and s.endswith(';'):
                errors.append(f'{os.path.relpath(f, ROOT)}:{i}: comment line ends with ";" inside a SQL statement')
            if inst and ((not is_plsql and s.endswith(';') and '--' not in s) or (is_plsql and s == '/')):
                inst = False


def golden_rules():
    for f in glob.glob(f'{R}/common/**/*.pkb', recursive=True):
        if '/deploy/' in f or '/releases/' in f:
            continue
        lines = open(f, errors='ignore').read().splitlines()
        reason = -10**6   # line of the last documented exception (CLAUDE.md: HTML only with a comment saying why)
        for i, line in enumerate(lines, 1):
            if re.search(r'(?i)--.*(html in pl/sql on purpose|golden rule exception|no apex component)', line):
                reason = i
            if line.strip().startswith('--') or re.search(r'(?i)regexp_replace', line):
                continue   # comments, and code that removes tags (it builds no HTML)
            if re.search(r"(?i)(htp\.p|htp\.prn)\s*\(|'<(div|span|table|a |ul|li|p>|br)", line) and i - reason > 150:
                warnings.append(f'{os.path.relpath(f, ROOT)}:{i}: HTML in PL/SQL (use an APEX component, or comment why)')


def src(patterns, skip=('/deploy/', '/releases/', '/dist/', '/tests/')):
    for pat in patterns:
        for f in glob.glob(f'{R}/{pat}', recursive=True):
            if not any(x in f for x in skip):
                yield f, os.path.relpath(f, ROOT)


def apex_security():
    for f, rel in src(['common/features/*/pages/*.apx', 'common/app/pages/*.apx']):
        txt = open(f, errors='ignore').read()
        sec = re.search(r'\n    security \{(.*?)\n    \}', txt, re.S)
        sec = sec.group(1) if sec else ''
        public = re.search(r'authentication:\s*public', sec) or re.match(r'page 0+ ', txt) or 'login' in rel
        if not public and 'authorizationScheme' not in sec:
            warnings.append(f'{rel}: page has no authorization scheme (View / Create / Manage privilege)')
        # a public page (login) is opened without arguments from outside: unrestricted access is intended there
        if not public and re.search(r'pageAccessProtection:\s*unrestricted', sec) \
                and not re.search(r'(?i)unrestricted on purpose', txt):   # a documented reason is accepted
            warnings.append(f'{rel}: page access protection is unrestricted (use argumentsMustHaveChecksum unless intended)')
        if re.search(r'\n\s+inline:', txt):
            warnings.append(f'{rel}: inline CSS / JavaScript on the page (use the theme / a static file)')


def plsql_rules():
    rules = [
        (r'(?i)\bwhen\s+others\s+then\s+null\b', 'WHEN OTHERS THEN NULL hides errors'),
        (r'(?i)\b(xxfusion|xxcus)\.\w', 'hard-coded schema name (use synonyms / the parsing schema)'),
        (r'(?i)\bselect\s+\*\s+(?!into\b)', 'SELECT * (list the columns)'),
        (r'(?i)\bdbms_output\.', 'DBMS_OUTPUT in a package (use the log routine)'),
        (r"(?i)\bto_date\s*\([^,()]*\)", 'TO_DATE without a format mask'),
    ]
    for f, rel in src(['common/**/*.pkb']):
        if '/db/framework/' in rel:  # deployment framework: dynamic DDL by design
            continue
        txt = open(f, errors='ignore').read()
        auto = re.search(r'(?i)pragma\s+autonomous_transaction', txt)
        lines = txt.splitlines()
        for i, line in enumerate(lines, 1):
            code = line.split('--')[0]
            if re.search(r'(?i)\bexecute\s+immediate\b', code):
                # the statement up to its ';': a parameter (p_...) joined into the SQL text without DBMS_ASSERT /
                # xxfnd_util_pkg.qualified can carry SQL from the caller (injection); names from the registry or the
                # dictionary, numbers and bind variables are not flagged
                stmt = ' '.join(l.split('--')[0] for l in lines[i - 1:i + 8]).split(';')[0]
                stmt = re.sub(r"'(?:[^']|'')*'", "''", stmt)
                stmt = re.sub(r'(?i)(dbms_assert\.\w+|xxfnd_util_pkg\.qualified)\s*\((?:[^()]|\([^()]*\))*\)', 'x', stmt)
                if re.search(r'(?i)\|\|\s*p_\w+|\bp_\w+\s*\|\|', stmt):
                    warnings.append(f'{rel}:{i}: EXECUTE IMMEDIATE joins a parameter into the SQL without DBMS_ASSERT '
                                    '(SQL injection - use binds / dbms_assert)')
            for rx, msg in rules:
                if re.search(rx, code):
                    warnings.append(f'{rel}:{i}: {msg}')
            if not auto and re.search(r'(?i)^\s*(commit|rollback)\s*;', code):
                warnings.append(f'{rel}:{i}: COMMIT / ROLLBACK in a package without an autonomous transaction (the caller commits)')
    for f, rel in src(['common/**/*.sql', 'common/**/*.pk?']):
        for i, line in enumerate(open(f, errors='ignore'), 1):
            if re.search(r'(?i)\bxxcmp_\w+', line.split('--')[0]):
                warnings.append(f'{rel}:{i}: COMMON code refers to a KYC object (XXCMP_) - COMMON has no KYC dependency')


def install_safety(names):
    listed = set()
    for app in ('common',):
        p = f'{R}/{app}/db/manifest.json'
        if os.path.exists(p):
            for e in json.load(open(p)):
                for v in e.values():
                    if isinstance(v, list):
                        listed.update(x for x in v if isinstance(x, str))
    for f, rel in src(['common/db/scripts/**/*.sql', 'common/features/*/db/scripts/**/*.sql'], ('/admin/', '/tests/')):
        unit = os.path.relpath(f, R)
        if unit not in listed:
            warnings.append(f'{rel}: step script not listed in db/manifest.json (never installed)')
        for i, line in enumerate(open(f, errors='ignore'), 1):
            code = line.split('--')[0]
            if re.search(r'(?i)^\s*(create|alter)\s+table\b', code):
                warnings.append(f'{rel}:{i}: bare CREATE / ALTER TABLE in a step script (use XXFND_DDL_PKG - ORA-00955 on re-run)')
            if re.search(r'(?i)^\s*drop\s+(table|index|sequence|view|package)\b', code):
                warnings.append(f'{rel}:{i}: unguarded DROP (use XXFND_DDL_PKG.DROP_* or check it exists)')
    for n, st in names:
        if st == 'M' and re.match(r'repos/[^/]+/features/[^/]+/db/tables/[^/]+\.sql$', n):
            warnings.append(f'{n}: base table script edited - add a checked step script instead (golden rule)')


def releases(names):
    dirs = {m.group(0) for n, _ in names if (m := re.match(r'repos/[^/]+/releases/[^/]+', n)) and os.path.isdir(os.path.join(ROOT, m.group(0)))}
    for d in sorted(dirs):
        full = os.path.join(ROOT, d)
        for need in ('README.md', 'run-release.sql'):
            if not os.path.exists(os.path.join(full, need)):
                warnings.append(f'{d}: release folder has no {need}')
        rr = os.path.join(full, 'run-release.sql')
        if os.path.exists(rr):
            for i, line in enumerate(open(rr, errors='ignore'), 1):
                m = re.match(r'\s*@@?(\S+)', line)
                if m and not os.path.exists(os.path.join(full, m.group(1))):
                    warnings.append(f'{d}/run-release.sql:{i}: file not in the release folder: {m.group(1)}')


def changes(base, body):
    out = subprocess.run(['git', 'diff', '--name-status', base, 'HEAD'], cwd=ROOT, capture_output=True, text=True).stdout
    pairs = [(l.split('\t')[-1], l[0]) for l in out.splitlines() if l]
    names = [n for n, _ in pairs]
    install_safety(pairs); releases(pairs)
    frozen = [n for n in names if n.startswith('apex/')]
    if frozen:
        errors.append(f'changes under the frozen apex/ folder: {", ".join(frozen[:5])}{" ..." if len(frozen) > 5 else ""}')
    if body is not None and any(re.match(r'repos/[^/]+/releases/', n) for n in names) and not re.search(r'(?i)\b(fixes|closes|resolves) #\d+', body):
        warnings.append('a release folder changed but the PR body has no "Fixes #n"')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--base')
    ap.add_argument('--body-file')
    a = ap.parse_args()
    manifest(); source_map(); sql_comments(); golden_rules(); apex_security(); plsql_rules()
    if not a.base:
        install_safety([])
    if a.base:
        changes(a.base, open(a.body_file).read() if a.body_file else None)
    gh = os.environ.get('GITHUB_ACTIONS')
    # only findings in files this PR changes become GitHub annotations; findings in files it does not touch are
    # existing code (fixed in their own release) and are listed in the step log only
    changed = set()
    if a.base:
        changed = set(subprocess.run(['git', 'diff', '--name-only', a.base, 'HEAD'], cwd=ROOT, capture_output=True,
                                     text=True).stdout.split())
    new = [w for w in warnings if not a.base or w.split(':')[0] in changed or not w.startswith('repos/')]
    old = [w for w in warnings if w not in new]
    for w in old:
        print(f'existing: {w}')
    for w in new:
        print(f'::warning::{w}' if gh else f'WARNING {w}')
    for e in errors:
        print(f'::error::{e}' if gh else f'ERROR {e}')
    print(f'{len(errors)} error(s), {len(new)} warning(s) in this change, {len(old)} existing finding(s) in unchanged '
          'files (listed above, not annotated)')
    sys.exit(1 if errors else 0)
