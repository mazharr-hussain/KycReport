#!/usr/bin/env python3
"""Checks run on every pull request by .github/workflows/checks.yml (also runnable locally).

Errors (exit 1): a manifest script or unit that does not exist; a page not listed in SOURCE-MAP.json (the build would
leave it out); a SQL comment line ending with ';' inside a plain SQL statement (SQL Developer ends the statement there);
a change under the frozen apex/ folder (with --base).
Warnings: KYC code writing COMMON (XXFND_) tables directly; HTML built in PL/SQL; a release folder without "Fixes #n"
in the PR body (with --body).
Usage: python3 repos/tools/pr_checks.py [--base <sha>] [--body-file <file>]
"""
import argparse, glob, json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
R = os.path.join(ROOT, 'repos')
errors, warnings = [], []


def manifest():
    for app in ('common', 'kyc'):
        p = f'{R}/{app}/db/manifest.json'
        if not os.path.exists(p):
            continue
        for e in json.load(open(p)):
            for u in e.get('units', []):
                if not os.path.exists(os.path.join(R, u)):
                    errors.append(f'{app}: manifest unit missing: {u} ({e.get("file")})')


def source_map():
    for app in ('common', 'kyc'):
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
    for f in glob.glob(f'{R}/*/db/**/*.sql', recursive=True) + glob.glob(f'{R}/*/features/**/*.sql', recursive=True):
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
    for f in glob.glob(f'{R}/kyc/**/*.sql', recursive=True) + glob.glob(f'{R}/kyc/**/*.pkb', recursive=True):
        if '/deploy/' in f or '/releases/' in f or '/tests/' in f:
            continue
        for i, line in enumerate(open(f, errors='ignore'), 1):
            if re.search(r'(?i)\b(insert\s+into|update|delete\s+from|merge\s+into)\s+xxfnd_\w+', line) and not line.strip().startswith('--'):
                warnings.append(f'{os.path.relpath(f, ROOT)}:{i}: KYC writes a COMMON table directly (call the COMMON routine)')
    for f in glob.glob(f'{R}/*/**/*.pkb', recursive=True):
        if '/deploy/' in f or '/releases/' in f:
            continue
        for i, line in enumerate(open(f, errors='ignore'), 1):
            if re.search(r"(?i)(htp\.p|htp\.prn)\s*\(|'<(div|span|table|a |ul|li|p>|br)", line) and not line.strip().startswith('--'):
                warnings.append(f'{os.path.relpath(f, ROOT)}:{i}: HTML in PL/SQL (use an APEX component, or comment why)')


def changes(base, body):
    names = subprocess.run(['git', 'diff', '--name-only', base, 'HEAD'], cwd=ROOT, capture_output=True, text=True).stdout.split()
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
    manifest(); source_map(); sql_comments(); golden_rules()
    if a.base:
        changes(a.base, open(a.body_file).read() if a.body_file else None)
    gh = os.environ.get('GITHUB_ACTIONS')
    for w in warnings:
        print(f'::warning::{w}' if gh else f'WARNING {w}')
    for e in errors:
        print(f'::error::{e}' if gh else f'ERROR {e}')
    print(f'{len(errors)} error(s), {len(warnings)} warning(s)')
    sys.exit(1 if errors else 0)
