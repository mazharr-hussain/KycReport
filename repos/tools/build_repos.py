"""Segregates the current KYC and COMMON applications into two repository folders, one folder per feature.
Copies only: every source file (or statement / block of it) lands in exactly one place, unchanged; a source map
records where, and check() rebuilds every source from the pieces and compares byte for byte."""
import json, os, re, shutil, sys, glob, collections
sys.path.insert(0, os.path.dirname(__file__))
from sqlsplit import split
from classify import classify

ROOT = '/home/user/KycReport'
OUT = f'{ROOT}/repos'
APPS = {'kyc': f'{ROOT}/apex/src/database/xxcus/apex_apps/f134', 'common': f'{ROOT}/apex/src/database/xxfusion/apex_apps/f135'}
FP = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'feature-pages.txt')

# ---------------------------------------------------------------- feature of a database object (by name)
RULES = [
 # KYC
 ('kyc', 'kyc-requests', r'^XXCMP_(REQUEST|APPROVAL_P|HISTORY_)'),
 ('kyc', 'parties', r'^XXCMP_PART'),
 ('kyc', 'monitoring', r'^XXCMP_(ALERTS|MONITOR|WATCHLIST)'),
 ('kyc', 'alert-rules', r'^XXCMP_ALERT_RULES'),
 ('kyc', 'kyc-rules', r'^XXCMP_(QUESTION|ANSWER|CONCLUSION|APPROVAL_MATRIX|ATTACHMENT_RULES|RISK|DOC_RULE|KYC_PKG|CONFIG_CHANGES)'),
 ('kyc', 'cases', r'^XXCMP_(CASE|SCREENING|DOC_VERIF|UBO|RFI|FIU)'),
 # COMMON
 ('common', 'framework', r'^XXFND_(DDL_PKG|SCHEMA_PKG|SCHEMA_RELEASES|DROPPED_OBJECTS|UTIL_PKG|ERROR_PKG|MESSAGES|UI_PKG|SHARE_PKG)'),
 ('common', 'applications', r'^XXFND_(APPLICATION|ADMIN_|MODULES_V|SETUP_)'),
 ('common', 'app-settings', r'^XXFND_APP_SETTING'),
 ('common', 'users-access', r'^XXFND_(USER|EMPLOYEES|AUTH_PKG)'),
 ('common', 'roles-privileges', r'^XXFND_(ROLE|PRIVILEGE|FEATURE|SOD_|EFFECTIVE_ACCESS)'),
 ('common', 'data-model', r'^XXFND_(DM_|DATA_MODEL)'),          # release 89 (before data-security: XXFND_DATA_MODEL_PKG)
 ('common', 'data-security', r'^XXFND_(DATA_|VPD)'),
 ('common', 'audit-log', r'^XXFND_AUDIT'),
 ('common', 'lookups', r'^XXFND_LOOKUP'),
 ('common', 'flexfields', r'^XXFND_(DF_|DFF|VALUE_SETS)'),
 ('common', 'retention', r'^XXFND_RETENTION'),
 ('common', 'attachments', r'^XXFND_(ATTACH|DOCUMENT|DOC_|STORAGE|APP_STORAGE|ENTITY_CONTAINERS)'),
 ('common', 'information-requests', r'^XXFND_(RFI|QA_)'),
 ('common', 'change-approvals', r'^XXFND_(CONFIG_|APPROVAL_PKG$)'),
 ('common', 'approval-setup', r'^XXFND_APPROVAL_'),
 ('common', 'my-tasks', r'^XXFND_PENDING_APPROVALS'),
 ('common', 'workflow-setup', r'^XXFND_(TASK_|WORKFLOW|WF_)'),
 ('common', 'notifications', r'^XXFND_(NOTIF|NOTIFY)'),
 ('common', 'communications', r'^XXFND_COMMUNICATIONS'),
 ('common', 'integrations', r'^XXFND_(INTEGRATION|INT_|TRANSMISSIONS|SERVERS)'),
]
def feature_of(name):
    for repo, feat, p in RULES:
        if re.search(p, name):
            return repo, feat
    return None, None

# feature of an APEX page: from the registered feature pages (XXFND_FEATURE_PAGES)
PAGEFEAT = {'kyc': {}, 'common': {}}
for line in open(FP):
    app, page, feat, grp = line.strip().split('|')
    if app != 'KYC':                 # COMMON's pages from its registered mapping
        PAGEFEAT['common'][int(page)] = feat.lower().replace('_', '-')
# KYC's pages from KYC's own registration (18h feature(...) calls), not from a database that may hold stale rows (C8)
for call in re.findall(r"\bfeature\('(\w+)'(.*?)\);", open(f'{ROOT}/apex/db/18h-register-with-common.sql').read(), re.S):
    for lit in re.findall(r"'([^']*)'", call[1]):
        if re.fullmatch(r"\d+(=[^|]*)?(\|\d+(=[^|]*)?)*", lit):
            for item in lit.split('|'):
                PAGEFEAT['kyc'][int(item.split('=')[0])] = call[0].lower().replace('_', '-')
FEATURE_RENAME = {'common-home': 'home'}
# COMMON pages registered under no feature, placed by what they do (99 / 100, the admin shell, stay in app/)
PAGEFEAT['common'].setdefault(50, 'information-requests')   # public answer page of an information request
PAGEFEAT['common'].setdefault(183, 'users-access')          # assign roles and data rules to users

def rd(path):
    return open(path, 'rb').read().decode('latin-1')

placed = {}          # source path -> list of (target, start_line, end_line) or 'whole:<target>'
targets = collections.defaultdict(list)   # target file -> list of text pieces

def put(target, text, source, whole=False):
    start = sum(len(t) for t in targets[target])
    targets[target].append(text)
    end = start + len(text)
    placed.setdefault(source, []).append({'target': os.path.relpath(target, OUT), 'from': start, 'to': end, 'whole': whole})

# ---------------------------------------------------------------- database scripts (per object)
manifest = json.load(open(f'{ROOT}/apex/db/manifest.json'))
order = {e['file']: e for e in manifest}
def script_repo(e):
    apps = e.get('apps', ['KYC'])
    # release 87: a generic script no application runs yet (00c-onboard-with-common.sql) is COMMON's framework too
    if set(apps) == {'COMMON', 'KYC'} or apps == []:
        return 'common', True      # the install framework every application runs: kept once, in COMMON
    return ('common' if apps == ['COMMON'] else 'kyc'), False

seen = set()
for e in sorted(manifest, key=lambda x: x.get('install_sequence', 9999)):
    f = e['file']; src = f'{ROOT}/apex/db/{f}'
    if f in seen:
        continue                    # listed twice in the manifest (install and upgrade order): one copy
    seen.add(f)
    repo, framework = script_repo(e)
    stem = f[:-4]
    last = None
    for kind, text in split(rd(src)):
        typ, name = classify(kind, text)
        if framework:
            tgt = f'{OUT}/common/db/framework/{f}'
        elif name in ('(prev)',) and last:
            tgt = last
        elif name.startswith('('):
            tgt = f'{OUT}/{repo}/db/scripts/{f}'
        else:
            r2, feat = feature_of(name)
            if feat is None or r2 != repo:
                tgt = f'{OUT}/{repo}/db/scripts/{f}'          # an object of the other repository or unmapped: stays whole
            elif feat == 'framework':
                tgt = f'{OUT}/common/db/framework/objects/{name.lower()}.sql'
            else:
                folder = {'package': 'packages', 'type': 'types', 'trigger': 'triggers', 'view': 'views',
                          'sequence': 'sequences', 'data': 'seed', 'block': 'objects', 'table': 'tables'}.get(typ, 'objects')
                if typ in ('block', 'table'):
                    folder = ('packages' if name.endswith('_PKG') else 'views' if re.search(r'_(V|VL)$', name)
                              else 'sequences' if name.endswith('_S') else 'types' if re.search(r'_(ROW|TAB)$', name)
                              else 'tables')
                    # an index or constraint goes with its table
                    base_t = re.sub(r'_(N\d+|U\d+|PK|UK\d*|FK\d*|CK\d*|MC|VER|NUM|ID|BI|LOCK|DD|CHK|LVL|SRC|INS|RO|ORDER|USER|RENAME|PROTECT|CYCLE|EVERY_ROLE|ASSIGN)$', '', name)
                    if folder == 'tables' and base_t != name:
                        name = base_t
                tgt = f'{OUT}/{repo}/features/{feat}/db/{folder}/{name.lower()}.sql'
        put(tgt, text, os.path.relpath(src, ROOT))
        last = tgt

# 18h (registration with COMMON) and 03 (use the shared schema) are KYC's whole-application scripts: per object would
# scatter one registration across features; they stay whole in kyc/db/scripts (handled above: their blocks are '(script)'
# or name COMMON objects).

# ---------------------------------------------------------------- APEX applications
BLOCK = re.compile(r'^(\w+) (\S+) \($')
def apx_blocks(text):
    """Top-level blocks of an .apx file: [(kind, name, text)]; text between blocks goes with the next block."""
    lines = text.splitlines(keepends=True); out = []; buf = []; cur = None
    for l in lines:
        buf.append(l)
        m = BLOCK.match(l.rstrip('\n'))
        if m and cur is None:
            cur = (m.group(1), m.group(2))
        elif cur and l.rstrip('\n') == ')':
            out.append((cur[0], cur[1], ''.join(buf))); buf = []; cur = None
    if buf:
        out.append(('tail', None, ''.join(buf)))
    return out

def page_id(fname):
    m = re.match(r'p(\d{5})-', fname)
    return int(m.group(1)) if m else None

for repo, app in APPS.items():
    base = f'{OUT}/{repo}'
    # pages
    pagefeat = {}
    for p in sorted(glob.glob(f'{app}/pages/*.apx')):
        pid = page_id(os.path.basename(p)); feat = PAGEFEAT[repo].get(pid)
        feat = FEATURE_RENAME.get(feat, feat)
        tgt = f'{base}/features/{feat}/pages/{os.path.basename(p)}' if feat else f'{base}/app/pages/{os.path.basename(p)}'
        pagefeat[os.path.basename(p)] = feat
        put(tgt, rd(p), os.path.relpath(p, ROOT), whole=True)
    pagetext = {n: rd(f'{app}/pages/{n}') for n in pagefeat}
    # components used by pages of one feature only go with that feature
    def owner(ref):
        feats = {pagefeat[n] for n, t in pagetext.items() if re.search(r'@' + re.escape(ref) + r'\b', t)}
        return feats.pop() if len(feats) == 1 and None not in feats else None
    sc = f'{app}/shared-components'
    for fpath in sorted(glob.glob(f'{sc}/**/*', recursive=True)):
        if os.path.isdir(fpath):
            continue
        rel = os.path.relpath(fpath, sc)
        if rel in ('lovs.apx', 'authorizations.apx', 'lists.apx'):
            for kind, name, text in apx_blocks(rd(fpath)):
                feat = owner(name) if name else None
                tgt = (f'{base}/features/{feat}/shared-components/{rel}' if feat else f'{base}/app/shared-components/{rel}')
                put(tgt, text, os.path.relpath(fpath, ROOT))
            continue
        # task definitions, workflows, automations: by the feature whose pages / objects name them
        feat = None
        top = rel.split('/')[0]
        if top in ('task-definitions', 'workflows', 'automations'):
            key = os.path.basename(rel).split('.')[0].upper().replace('-', '_')
            guess = {'DOC_CHECKLIST_REVIEW': 'kyc-requests', 'KYC_REQUEST': 'kyc-requests', 'CASE_INVESTIGATION': 'cases',
                     'CASE_APPROVAL': 'cases', 'KYC_CASE': 'cases', 'COUNTERPARTY_MATCH': 'kyc-requests',
                     'KYC_MONITORING': 'monitoring', 'RFI': 'information-requests', 'RFI_RESPONSE': 'information-requests',
                     'RFI_REVIEW': 'information-requests', 'CONFIG_CHANGE': 'change-approvals',
                     'TASK_DEADLINES': 'workflow-setup', 'FUSION_HCM_SYNC': 'users-access'}
            for k, v in guess.items():
                if key.startswith(k):
                    feat = v; break
        tgt = f'{base}/features/{feat}/shared-components/{rel}' if feat else f'{base}/app/shared-components/{rel}'
        put(tgt, rd(fpath), os.path.relpath(fpath, ROOT), whole=True)
    # the rest of the application (application.apx, page groups, deployments, workspace components); supporting
    # objects are generated from apex/db by build.py and are not copied (they would be a second copy of the scripts)
    for fpath in sorted(glob.glob(f'{app}/**/*', recursive=True)):
        if os.path.isdir(fpath):
            continue
        rel = os.path.relpath(fpath, app)
        if rel.startswith(('pages/', 'shared-components/')) or (rel.startswith('supporting-objects/')
                                                                and rel != 'supporting-objects/supporting-objects.apx'):
            continue
        put(f'{base}/app/{rel}', rd(fpath), os.path.relpath(fpath, ROOT), whole=True)

# ---------------------------------------------------------------- tests and documents
TESTS = [(r'^(kyc87|kyc88|kyc89|kyc90|kyc91|kyc92|r73_kyc|r75|r76_kyc|kyc_flow|kyc_ui|workflow_test|token_test)', 'kyc', None),
         (r'^(party|r74_party)', 'kyc', 'parties'), (r'^(request_party|r74_kyc)', 'kyc', 'kyc-requests'),
         (r'^r74_case', 'kyc', 'cases'), (r'^(monitoring)', 'kyc', 'monitoring'), (r'^r74_risk', 'kyc', 'kyc-rules'),
         (r'^r74_(email|perf)', 'kyc', None), (r'^security_test', 'kyc', None)]
for fpath in sorted(glob.glob(f'{ROOT}/apex/tests/*')):
    if os.path.isdir(fpath):
        continue
    n = os.path.basename(fpath); repo, feat = 'common', None
    for p, r, f in TESTS:
        if re.match(p, n):
            repo, feat = r, f; break
    else:
        if n in ('run_all.sh',) or n.startswith('setup_'):
            repo = 'kyc'
    tgt = f'{OUT}/{repo}/features/{feat}/tests/{n}' if feat else f'{OUT}/{repo}/tests/{n}'
    put(tgt, rd(fpath), os.path.relpath(fpath, ROOT), whole=True)
for repo, d in (('kyc', 'install/KYC'), ('common', 'install/COMMON')):
    for fpath in sorted(glob.glob(f'{ROOT}/apex/{d}/**/*', recursive=True)):
        if not os.path.isdir(fpath):
            put(f'{OUT}/{repo}/docs/install/{os.path.relpath(fpath, f"{ROOT}/apex/{d}")}',
                rd(fpath), os.path.relpath(fpath, ROOT), whole=True)
for n, repo in (('clean-common.sql', 'common'), ('create-xxfusion-schema.sql', 'common'), ('onboard-application.sql', 'common'),
                ('move-kyc-shared-data-to-xxfusion.sql', 'kyc'), ('qd-users-and-roles.sql', 'kyc')):
    put(f'{OUT}/{repo}/db/admin/{n}', rd(f'{ROOT}/apex/db/admin/{n}'), f'apex/db/admin/{n}', whole=True)
put(f'{OUT}/common/db/scripts/05-core-packages-part-1-of-2-upgrade.sql', rd(f'{ROOT}/apex/db/05-core-packages-part-1-of-2-upgrade.sql'),
    'apex/db/05-core-packages-part-1-of-2-upgrade.sql', whole=True)
for fpath in sorted(glob.glob(f'{ROOT}/apex/src/database/sys/**/*.sql', recursive=True)):
    put(f'{OUT}/kyc/db/grants/{os.path.basename(fpath)}', rd(fpath), os.path.relpath(fpath, ROOT), whole=True)
put(f'{OUT}/common/docs/COMMON-ISSUES.md', rd(f'{ROOT}/apex/COMMON-ISSUES.md'), 'apex/COMMON-ISSUES.md', whole=True)
# the developer tools: the build and checks once, in COMMON (every application builds with them); each application's
# own user-guide recorder with it (copied unchanged; build.py in common/tools is the repository build, kept as it is)
for n, repo in (('sql_install.py', 'common'), ('check_session_state.py', 'common'), ('record_user_guide.py', 'common'),
                ('record_kyc_user_guide.py', 'kyc')):
    put(f'{OUT}/{repo}/tools/{n}', rd(f'{ROOT}/apex/tools/{n}'), f'apex/tools/{n}', whole=True)

# ---------------------------------------------------------------- write, then check
# rewrite what the split makes; the build (common/tools, the build.sh wrappers) and dist/ stay
for repo in APPS:
    for part in ('app', 'db', 'docs', 'features', 'tests'):
        shutil.rmtree(f'{OUT}/{repo}/{part}', ignore_errors=True)
for t, pieces in targets.items():
    os.makedirs(os.path.dirname(t), exist_ok=True)
    with open(t, 'wb') as fh:
        fh.write(''.join(pieces).encode('latin-1'))
for repo in APPS:
    json.dump({s: v for s, v in placed.items() if all(x['target'].startswith(repo + '/') for x in v)},
              open(f'{OUT}/{repo}/SOURCE-MAP.json', 'w'), indent=1, sort_keys=True)

# the install order: each manifest entry goes to the repository that owns its script (the framework scripts every
# application runs are COMMON's); the two manifests together hold every entry once
MAN = {'kyc': [], 'common': []}
for i, e in enumerate(manifest):
    repo, _ = script_repo(e)
    MAN[repo].append(dict(e, source_index=i))
for repo, entries in MAN.items():
    json.dump(entries, open(f'{OUT}/{repo}/db/manifest.json', 'w'), indent=1)

# ---------------------------------------------------------------- READMEs (what each feature has, uses and is used by)

from common_components import C as COMPONENTS, COMMON_REQ, OTHER_APP

def component_readme(repo, f, d, files, uses_f, used_by):
    """README of a COMMON component: the curated answers (common_components.py) and the lists read from its files."""
    c = COMPONENTS.get(f, {})
    texts = {x: ''.join(targets[f'{d}/{x}']) for x in files}
    pages = []
    for x in files:
        if x.startswith('pages/'):
            m = re.search(r'^\s+name:\s*(.+)$', texts[x], re.M)
            pages.append(f'- {int(os.path.basename(x)[1:6])} {m.group(1).strip() if m else ""} (`{x}`)')
    shared = [f'- `{x}`' for x in files if x.startswith('shared-components/')]
    dbo = collections.defaultdict(list)
    for x in files:
        if x.startswith('db/'):
            dbo[x.split('/')[1]].append(os.path.basename(x)[:-4].upper())
    api = []
    for x in files:
        if x.startswith('db/packages/'):
            m = re.search(r'create\s+or\s+replace\s+package\s+(?!body)(\w+).*?\n(.*?)\nend\s+\1\s*;', texts[x], re.I | re.S)
            if m:
                names = sorted(set(n.upper() for n in re.findall(r'^\s+(?:procedure|function)\s+(\w+)', m.group(2), re.M | re.I)))
                reg = [n for n in names if n.startswith('REGISTER_')]
                api.append(f'- `{m.group(1).upper()}`: ' + ', '.join(names) + (f' (registration: {", ".join(reg)})' if reg else ''))
    tests = [f'- `{x}`' for x in files if x.startswith('tests/')]
    title = c.get('name', f)
    L = [f'# {title}', '', f'COMMON component, module {c.get("module", "-")}'
         + (f' (feature `{c["feature"]}`).' if c.get('feature') else '.'), '',
         '## Purpose', c.get('purpose', '-'), '', '## Usage', c.get('usage', '-'), '', '## Benefit', c.get('benefit', '-'), '',
         '## Depends on (objects of these components are named in its files)', ', '.join(uses_f) or '-', '',
         '## Used by (COMMON components)', ', '.join(used_by) or '-', '',
         '## Installation requirements', COMMON_REQ + (' ' + c['req'] if c.get('req') else ''), '',
         '## Application objects', '### Pages'] + (pages or ['-']) + ['', '### Shared components'] + (shared or ['-']) + [
         '', '## Database objects (schema XXFUSION)']
    for kind in ('tables', 'views', 'packages', 'types', 'sequences', 'triggers', 'seed', 'objects'):
        if dbo.get(kind):
            L.append(f'- {kind}: ' + ', '.join(f'`{n}`' for n in sorted(dbo[kind])))
    if not dbo:
        L.append('- none of its own (it uses the objects of the components above)')
    L += ['', '## Roles and privileges',
          (f'Privileges `{c["feature"]}.<action>` for {c.get("actions")} (VIEW opens its pages, CREATE adds, MANAGE changes and '
           'deletes); a page opens with the privilege on the feature it is mapped to.' if c.get('feature') else 'No feature of its own.'),
          f'Roles at install: {c.get("roles", "-")}', '',
          '## How another application uses it', OTHER_APP, '', c.get('other', '-'), '', '### Public routines'] + (api or ['-'])
    L += ['', '## Tests'] + (tests or ['- in `../../tests/` (whole application)']) + ['', '## Files'] + [f'- `{x}`' for x in files] + ['']
    return L

TITLE = {'kyc': 'KYC Compliance Platform (application 134, schema XXCUS)',
         'common': 'COMMON (application 135, schema XXFUSION): shared security, setup, documents, workflow, integrations'}
def objects_of(feat_dir):
    return sorted({os.path.basename(f)[:-4].upper() for f in glob.glob(f'{feat_dir}/db/**/*.sql', recursive=True)})
for repo in APPS:
    feats = sorted(os.listdir(f'{OUT}/{repo}/features'))
    objs = {f: objects_of(f'{OUT}/{repo}/features/{f}') for f in feats}
    if repo == 'kyc':
        objs.update({f'common:{f}': objects_of(f'{OUT}/common/features/{f}') for f in os.listdir(f'{OUT}/common/features')})
    texts = {f: ''.join(''.join(targets[t]) for t in targets if t.startswith(f'{OUT}/{repo}/features/{f}/')).upper() for f in feats}
    uses = {f: sorted({g for g, names in objs.items() if g != f and any(re.search(r'\b' + n + r'\b', texts[f]) for n in names)})
            for f in feats}
    for f in feats:
        d = f'{OUT}/{repo}/features/{f}'
        files = sorted(os.path.relpath(t, d) for t in targets if t.startswith(d + '/'))
        used_by = sorted(g for g in feats if f in uses[g])
        lines = [f'# {f}', '', f'Feature of {TITLE[repo].split(" (")[0]}. Copied as it is from the current application (no change).', '']
        lines += ['## Uses (objects of these features are named in its files)', ', '.join(uses[f]) or '-', '', '## Used by', ', '.join(used_by) or '-', '', '## Files']
        lines += [f'- `{x}`' for x in files] + ['']
        targets[f'{d}/README.md'] = ['\n'.join(component_readme(repo, f, d, files, uses[f], used_by) if repo == 'common' else lines)]
    if repo == 'kyc':
        os.makedirs(f'{OUT}/kyc/features/case-assignment', exist_ok=True)
        targets[f'{OUT}/kyc/features/case-assignment/README.md'] = ['\n'.join([
            '# case-assignment', '', 'Feature of KYC Compliance Platform. It has no page or object of its own: it is the',
            'privilege CASE_ASSIGNMENT.MANAGE (registered in `db/scripts/18h-register-with-common.sql`), checked by',
            'XXCMP_CASE_PKG.CAN_ASSIGN in `features/cases`.', ''])]
    targets[f'{OUT}/{repo}/README.md'] = ['\n'.join([
        f'# {TITLE[repo]}', '',
        'Segregated from the current application under `apex/` (one folder per feature). Nothing was changed or fixed: every',
        'file, statement or component is copied as it is, and `SOURCE-MAP.json` records where each source went',
        '(`python3 ../verify.py` rebuilds every source from its pieces and compares it byte for byte).', '',
        '## Layout',
        '- `features/<feature>/` - its pages, its shared components (LOVs, authorizations, lists, task definitions, workflows,',
        '  automations used only by it), its database objects (`db/tables`, `db/packages`, `db/views`, `db/sequences`,',
        '  `db/types`, `db/triggers`, `db/seed`) and its tests; its README lists what it uses and what uses it.',
        '- `app/` - the application parts every feature uses: application.apx, Global Page 0, login, page groups,',
        '  authentications, navigation lists, themes, static files, plugins, deployments.',
        '- `db/manifest.json` - the install / upgrade order (the original entries); `db/scripts/` - the statements that belong to',
        '  a whole script, not one object (release markers, registration, checks); `db/admin/` - administrator scripts.',
        ('- `db/framework/` - the install framework every application runs in its own schema (deployment framework,' if repo == 'common'
         else '- the install framework (deployment framework, prerequisites, triggers, recompile) is COMMON\'s, in'),
        ('  prerequisites, who / audit triggers, recompile): kept once, here.' if repo == 'common'
         else '  `common/db/framework/`: KYC runs it from there (no copy).'),
        '- `docs/` - install notes' + (' and the COMMON issue list' if repo == 'common' else '') + '; `tests/` - tests of the whole application.', '',
        '## Build', f'`./build.sh [--release N]` - the one build, `common/tools/build.py` (no build logic in this repository' + ('' if repo == 'common' else ' - it is COMMON\'s') + '); output in `dist/` (not kept in git).', '',
        '## Not copied', '- the generated install / upgrade scripts of `supporting-objects/` (the build makes them from the database scripts).',
        '- History stays in `apex/`: release zips, patches, ARCHITECTURE.md, CHANGELOG.md, PROJECT.md, and the one-off page '
        'generators of the early releases. The build and checks are in `common/tools/` (one copy for every application); '
        '`tools/` of each repository holds its own user-guide recorder.', ''])]
targets[f'{OUT}/common/db/framework/README.md'] = ['\n'.join([
    '# Framework (COMMON)', '',
    'The base every COMMON component and every application runs on. No feature, no page: database only.', '',
    '## Purpose',
    'Install and upgrade safety (checked DDL steps, release tracking), the who / audit columns, errors and messages, shared',
    'utilities, the sharing of COMMON objects with the application schemas, and the final recompile.', '',
    '## Usage',
    '- `00a-prerequisites-check.sql` - first script of every install and upgrade of every application: checks the privileges.',
    '- `00-deployment-framework.sql` - `XXFND_DDL_PKG` (CREATE_TABLE, ADD_COLUMN, ADD_CONSTRAINT, ENSURE_INDEX, ... , RELEASE_APPLIED,',
    '  MARK_RELEASE) and `XXFND_SCHEMA_RELEASES`, `XXFND_DROPPED_OBJECTS`: runs in each schema (COMMON and every application).',
    '- `07-who-and-audit-triggers.sql`, `19-reporting-views-and-recompile.sql` - run for every application.',
    '- `objects/`: `XXFND_UTIL_PKG` (install mode, current user, language), `XXFND_ERROR_PKG` / `XXFND_MESSAGES` (messages and',
    '  error handling), `XXFND_SCHEMA_PKG` (who triggers, policies), `XXFND_UI_PKG` (status colours), `XXFND_SHARE_PKG` (grants',
    '  to the application schemas, COMMON seed).', '',
    '## Benefit', 'No install error (no ORA-00955): every database gets exactly what it is missing and a re-run does nothing.', '',
    '## Depends on', '-', '', '## Installation requirements', 'Runs first; 00a lists the grants the schema needs when one is missing.', '',
    '## Roles and privileges', 'None (database only). `XXFND_SHARE_PKG.GRANT_TO` gives application schemas SELECT and EXECUTE (and today',
    'also INSERT / UPDATE / DELETE: COMMON issue C10) on the COMMON objects.', '',
    '## How another application uses it',
    'Its install runs 00a, 00, 07 and 19 from here (no copy) and uses `XXFND_DDL_PKG` for every change to its own objects;',
    'it reaches the shared packages through grants and synonyms (KYC script 03). `XXFND_DDL_PKG` and `XXFND_SCHEMA_RELEASES` are',
    'local to each schema (never granted).', ''])]
targets[f'{OUT}/verify.py'] = [open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'verify_template.py')).read()]
for t in [t for t in targets if t.endswith(('README.md', 'verify.py')) and not any(x['target'] == os.path.relpath(t, OUT) for v in placed.values() for x in v)]:
    os.makedirs(os.path.dirname(t), exist_ok=True)
    open(t, 'wb').write(''.join(targets[t]).encode('latin-1'))

def check():
    bad = []
    for src, pieces in placed.items():
        rebuilt = ''
        for p in pieces:
            t = rd(f'{OUT}/{p["target"]}')
            rebuilt += t if p['whole'] else t[p['from']:p['to']]
        orig = rd(f'{ROOT}/{src}')
        if rebuilt != orig:
            bad.append(src)
    return bad
bad = check()
idx = sorted(e['source_index'] for r in MAN for e in MAN[r])
if idx != list(range(len(manifest))):
    bad.append('apex/db/manifest.json')
print('sources placed:', len(placed), 'target files:', len(targets), 'mismatches:', len(bad), bad[:10])
