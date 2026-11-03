#!/usr/bin/env python3
"""Keeps repos/common/SOURCE-MAP.json in step with the files (pipeline step 1.1b and the regeneration after a merge).

source_map.py [--check]
The build (tools/build.py) takes an application file only when SOURCE-MAP.json lists it. This script registers every
COMMON file the map does not list yet and drops the entries of files that no longer exist, so nobody edits the map
by hand:
  common/app/shared-components/<kind>/<x>.apx  -> a piece of f135/shared-components/<kind>.apx when that file is built
                                                  from pieces (authorizations, lists, ...), else f135/<same path>
  common/app/<path>                            -> apex/src/database/xxfusion/apex_apps/f135/<path>
  common/features/<feature>/<path>             -> apex/src/database/xxfusion/apex_apps/f135/<path>  (pages, shared
                                                  components of a feature; not its db/, tests/ or docs)
  common/tests/<path> (*.sql)                  -> apex/tests/<path>
Database scripts are not here: their order is in db/manifest.json (a choice, made with the change).
--check: change nothing, exit 1 when the map is not in step (prints what is missing or gone).
"""
import json, os, sys

REPOS = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
MAP = os.path.join(REPOS, 'common', 'SOURCE-MAP.json')
F135 = 'apex/src/database/xxfusion/apex_apps/f135'


def candidates():
    """Every COMMON file the build may need: target -> source key."""
    out = {}
    for base, prefix in (('common/app', F135), ('common/tests', 'apex/tests')):
        for d, _, files in os.walk(os.path.join(REPOS, base)):
            for f in files:
                rel = os.path.relpath(os.path.join(d, f), REPOS)
                if base == 'common/tests' and not f.endswith('.sql'):
                    continue
                out[rel] = prefix + rel[len(base):]
    feats = os.path.join(REPOS, 'common', 'features')
    for feat in sorted(os.listdir(feats)):
        for d, dirs, files in os.walk(os.path.join(feats, feat)):
            rel_d = os.path.relpath(d, os.path.join(feats, feat))
            if rel_d.split(os.sep)[0] in ('db', 'tests', 'docs'):
                continue
            for f in files:
                if rel_d == '.':
                    continue            # files at the feature root (README, ...) are not application files
                rel = os.path.relpath(os.path.join(d, f), REPOS)
                out[rel] = F135 + '/' + os.path.relpath(os.path.join(d, f), os.path.join(feats, feat))
    return out


def main():
    check = '--check' in sys.argv
    raw = open(MAP).read()
    m = json.loads(raw)
    listed = {p['target'] for v in m.values() for p in v}
    pieced = {k for k, v in m.items() if len(v) > 1 or (v and v[0]['target'].rsplit('/', 2)[-2] + '.apx' == k.rsplit('/', 1)[-1])}
    changes = []
    for target, key in sorted(candidates().items()):
        if target in listed:
            continue
        parent = key.rsplit('/', 1)[0] + '.apx'      # .../shared-components/lists/x.apx -> .../shared-components/lists.apx
        size = os.path.getsize(os.path.join(REPOS, target))
        piece = {'from': 0, 'target': target, 'to': size, 'whole': True}
        if parent in pieced:
            m[parent].append(piece)
            changes.append(f'added {target} (a piece of {parent})')
        else:
            m[key] = [piece]
            changes.append(f'added {target}')
    for key in list(m):
        keep = [p for p in m[key] if not p['whole'] or os.path.exists(os.path.join(REPOS, p['target']))]
        for p in m[key]:
            if p not in keep:
                changes.append(f"dropped {p['target']} (file gone)")
        if keep:
            m[key] = keep
        else:
            del m[key]
    for c in changes:
        print(c)
    if not changes:
        print('SOURCE-MAP.json is in step with the files')
        return 0
    if check:
        print(f'SOURCE-MAP.json is not in step ({len(changes)} change(s)) - the pipeline registers them after the merge')
        return 1
    open(MAP, 'w').write(json.dumps(m, indent=1) + raw[len(raw.rstrip()):])
    return 0


if __name__ == '__main__':
    sys.exit(main())
