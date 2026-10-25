#!/usr/bin/env python3
"""Technical document of every feature: <repo>/features/<feature>/docs/TECHNICAL.md (both repositories).

Answers how the feature is built (pages, the standard APEX features and shared components it uses, the custom
database objects), how it is configured (its setup pages, seed / configuration scripts, settings), what it depends on
and what depends on it, and which test scripts cover it. Generated from the source by build.py on every build - never
edited by hand: purpose and business notes live in the feature's README.md and in docs/NOTES.md.
The functional reference of all features is the COMMON requirements summary (see the repository README).
Usage: python3 repos/common/tools/feature_docs.py [--repo kyc|common]
"""
import argparse, glob, json, os, re

REPOS = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TYPES = (('tables', 'Tables'), ('views', 'Views'), ('types', 'Types'), ('sequences', 'Sequences'),
         ('triggers', 'Triggers'), ('package_specs', 'Package specs'), ('package_bodies', 'Package bodies'))
REGION = re.compile(r'(?m)^        type: (interactiveReport|classicReport|interactiveGrid|form|cards|chart|map|tree|calendar|'
                    r'dynamicContent|plsqlDynamicContent|list|breadcrumb|appTemplateComponent/[\w-]+|facetedSearch|'
                    r'smartFilters|searchConfiguration|templateComponent)\b')
APIS = re.compile(r'(?i)\b(apex_human_task|apex_workflow|apex_approval|apex_mail|apex_pwa|apex_web_service|apex_exec|'
                  r'apex_data_parser|apex_data_export|apex_zip|apex_app_setting|apex_authorization|apex_automation|'
                  r'apex_util\.set_build_option_status|apex_workspace_activity_log|apex_application_pages|'
                  r'apex_collection|apex_session|apex_jwt|apex_credential|dbms_rls|dbms_cloud|dbms_scheduler|'
                  r'dbms_crypto|utl_match|utl_compress)\b')
LABEL = {'lov': 'LOVs', 'authorization': 'Authorizations', 'list': 'Lists', 'appItem': 'App items',
         'appProcess': 'App processes', 'breadcrumb': 'Breadcrumbs', 'emailTemplate': 'Email templates',
         'workflow': 'Workflows', 'taskDefinition': 'Task definitions', 'automation': 'Automations',
         'restDataSource': 'REST data sources'}


def read(p):
    return open(p, errors='ignore').read()


def shared_defs(app_dir):
    defs = {}
    for f in glob.glob(f'{app_dir}/shared-components/*.apx'):
        for m in re.finditer(r'(?m)^(\w+) ([\w-]+) \(', read(f)):
            defs.setdefault(m.group(2), m.group(1))
    for d in ('workflows', 'task-definitions', 'automations', 'rest-data-sources'):
        for f in glob.glob(f'{app_dir}/shared-components/{d}/*.apx'):
            m = re.search(r'(?m)^(\w+) (\S+) \(', read(f))
            defs[m.group(2)] = m.group(1)
    return defs


def section_readme(text, head):
    m = re.search(rf'(?ms)^## {head}\n(.*?)(?=^## |\Z)', text)
    return m.group(1).strip() if m else ''


def feature_doc(repo, feat, app_dir, defs, dep, tests):
    d = os.path.join(REPOS, repo, 'features', feat)
    readme = read(f'{d}/README.md') if os.path.exists(f'{d}/README.md') else ''
    m = re.search(r'(?m)^# (.+)', readme)
    title = m.group(1) if m else feat.replace('-', ' ').title()
    pages = sorted(glob.glob(f'{d}/pages/*.apx'))
    ptext = ''.join(read(p) for p in pages)
    code = ''.join(read(p) for p in glob.glob(f'{d}/db/**/*.*', recursive=True))
    own = {}
    for folder, lab in TYPES:
        names = sorted(os.path.splitext(f)[0].upper() for f in os.listdir(f'{d}/db/{folder}')) \
            if os.path.isdir(f'{d}/db/{folder}') else []
        if names:
            own[lab] = names
    own_names = {n.lower() for v in own.values() for n in v}
    # standard APEX features: region types, shared components, APIs
    regions = sorted({r.replace('appTemplateComponent/', 'template component ') for r in REGION.findall(ptext)})
    used = {}
    for ref in set(re.findall(r'@([\w-]+)\b', ptext)):
        if ref in defs:
            used.setdefault(LABEL.get(defs[ref], defs[ref]), set()).add(ref)
    for k, v in defs.items():
        if v == 'appItem' and re.search(r'[:&]' + re.escape(k) + r'\b', ptext):
            used.setdefault('App items', set()).add(k)
        if v in ('workflow', 'taskDefinition', 'restDataSource', 'emailTemplate', 'automation') and \
                re.search(r"['\"/ ]" + re.escape(k) + r"['\"\b]", ptext + code):
            used.setdefault(LABEL[v], set()).add(k)
    for sub in ('workflows', 'task-definitions', 'automations', 'rest-data-sources'):
        for p in glob.glob(f'{d}/shared-components/{sub}/*.apx'):
            m = re.search(r'(?m)^(\w+) (\S+) \(', read(p))
            used.setdefault(LABEL[m.group(1)], set()).add(m.group(2))
    apis = sorted({a.upper() for a in APIS.findall(ptext + code)})
    # dependencies from the generated tree
    uses, used_by = set(), set()
    for n in own_names:
        for lab in (n, n + ' (body)'):
            uses |= set(dep['uses'].get(lab, []))
        used_by |= set(dep['used_by'].get(n, []))
    for p in pages:
        uses |= set(dep['uses'].get('apex:' + ('COMMON' if repo == 'common' else 'KYC') + ':pages/' + os.path.basename(p), []))
    uses = sorted(u.upper() for u in uses - own_names)
    used_by = sorted(x for x in used_by if x.replace(' (body)', '') not in own_names)
    # configuration: change / seed scripts touching the feature's objects, settings it reads
    cfg = sorted({os.path.relpath(p, os.path.join(REPOS, repo)) for p in glob.glob(f'{REPOS}/{repo}/db/scripts/**/*.sql', recursive=True)
                  if own_names & {w.lower() for w in re.findall(r'\b(?:XX|xx)\w+', read(p))}})
    settings = sorted(set(re.findall(r"apex_app_setting\.get_value\s*\(\s*(?:p_name\s*=>\s*)?'(\w+)'", code + ptext, re.I)))
    # tests: feature tests folder + repository tests naming its objects or pages
    pnums = {re.search(r'p(\d+)-', os.path.basename(p)).group(1).lstrip('0') for p in pages}
    tlist = sorted({os.path.relpath(p, os.path.join(REPOS, repo)) for p in glob.glob(f'{d}/tests/*')} |
                   {t for t, txt in tests.items()
                    if own_names & {w.lower() for w in re.findall(r'\b(?:XX|xx)\w+', txt)}
                    or any(re.search(rf'(?i)(page[_ ]?(id)?\s*[=:(,]?\s*|p){n}\b', txt) for n in pnums if n)})
    L = [f'# {title} - technical document', '',
         f'Generated by `tools/feature_docs.py` from the source on every build; do not edit. Purpose and business notes: '
         f'`README.md` and `docs/NOTES.md`. Functional reference: the requirements summary named in the repository README.', '']
    for head in ('Purpose', 'Usage', 'Benefit'):
        s = section_readme(readme, head)
        if s:
            L += [f'## {head}', '', s, '']
    L += ['## How it is built', '', '### Pages', '']
    for p in pages:
        t = read(p)
        num = re.search(r'(?m)^page (\d+)', t).group(1)
        name = (re.search(r'(?m)^    name: (.+)', t) or re.search('()', '')).group(1)
        L.append(f'- {num} {name} (`pages/{os.path.basename(p)}`)')
    if not pages:
        L.append('- none')
    L += ['', '### Standard APEX features used', '']
    L += [f'- Regions: {", ".join(regions)}'] if regions else []
    L += [f'- {k}: {", ".join(sorted(v))}' for k, v in sorted(used.items())]
    L += [f'- APIs: {", ".join(apis)}'] if apis else []
    L += ['', '### Custom database objects', '']
    L += [f'- {k}: {", ".join(v)}' for k, v in own.items()] or ['- none (uses other features\' objects)']
    L += ['', '## Configuration', '']
    L += ['- Configured on its pages above (setup pages need the feature\'s privileges: View / Create / Manage).']
    L += [f'- Application settings read: {", ".join(settings)}'] if settings else []
    L += ['- Seed and change scripts:'] + [f'    - `{c}`' for c in cfg] if cfg else ['- Seed and change scripts: none']
    by_obj = sorted({x.replace(' (body)', '').upper() for x in used_by if not x.startswith('apex:')})
    by_app = {}
    for x in used_by:
        if x.startswith('apex:'):
            _, app, path = x.split(':', 2)
            m = re.search(r'p0*(\d+)-', path)
            by_app.setdefault(app, set()).add(m.group(1) if m else os.path.basename(path)[:-4])
    L += ['', '## Dependencies', '', f'- Uses: {", ".join(uses) or "none"}',
          f'- Used by objects: {", ".join(by_obj) or "none"}']
    L += [f'- Used by {app} pages / components: ' + ', '.join(sorted(v, key=lambda z: (not z.isdigit(), z.zfill(6))))
          for app, v in sorted(by_app.items())]
    L += ['', '## Test scripts', '']
    L += [f'- `{t}`' for t in tlist] or ['- none yet']
    os.makedirs(f'{d}/docs', exist_ok=True)
    open(f'{d}/docs/TECHNICAL.md', 'w').write('\n'.join(L) + '\n')


def run(repos=('common', 'kyc')):
    for repo in repos:
        app_dir = os.path.join(REPOS, repo, 'dist', 'app')
        dep_p = os.path.join(REPOS, repo, 'db', 'deploy', 'dependencies.json')
        if not os.path.isdir(app_dir) or not os.path.exists(dep_p):
            continue
        defs, dep = shared_defs(app_dir), json.load(open(dep_p))
        tests = {os.path.relpath(p, os.path.join(REPOS, repo)): read(p)
                 for p in glob.glob(f'{REPOS}/{repo}/tests/*') + glob.glob(f'{REPOS}/{repo}/features/*/tests/*')
                 if os.path.isfile(p)}
        for d in sorted(glob.glob(f'{REPOS}/{repo}/features/*/')):
            feature_doc(repo, os.path.basename(d.rstrip('/')), app_dir, defs, dep, tests)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', choices=('kyc', 'common'))
    a = ap.parse_args()
    run((a.repo,) if a.repo else ('common', 'kyc'))
