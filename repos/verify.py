"""Rebuilds every source file of apex/ from the pieces recorded in kyc/ and common/ SOURCE-MAP.json and compares it byte
for byte. Run from the repository root: python3 repos/verify.py"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
bad = 0; n = 0
for repo in ('kyc', 'common'):
    for src, pieces in json.load(open(os.path.join(HERE, repo, 'SOURCE-MAP.json'))).items():
        rebuilt = b''
        for p in pieces:
            data = open(os.path.join(HERE, p['target']), 'rb').read()
            rebuilt += data if p['whole'] else data.decode('latin-1')[p['from']:p['to']].encode('latin-1')
        n += 1
        if rebuilt != open(os.path.join(ROOT, src), 'rb').read():
            bad += 1; print('DIFFERENT', src)
print(f'{n} sources checked, {bad} different')
sys.exit(1 if bad else 0)
