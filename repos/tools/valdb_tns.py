#!/usr/bin/env python3
"""Validation database (#195): adds the alias "valtoken" to the wallet's tnsnames.ora - the service's descriptor with
IDCS database-token login (TOKEN_AUTH=OCI_TOKEN) and the wallet folder for mTLS.
Usage: valdb_tns.py <wallet-folder> <service alias, e.g. mydb_low>"""
import os, re, sys

folder, service = sys.argv[1], sys.argv[2].lower()
path = os.path.join(folder, 'tnsnames.ora')
text = open(path).read()
m = re.search(r'(?im)^\s*' + re.escape(service) + r'\s*=\s*(\(.*)$', text)
if not m:
    sys.exit(f'service {service} not in tnsnames.ora')
desc = m.group(1).strip()
extra = f'(TOKEN_AUTH=OCI_TOKEN)(MY_WALLET_DIRECTORY={folder})'
desc, n = re.subn(r'(?i)\(security\s*=', '(security=' + extra, desc, count=1)
if not n:
    desc = desc[:-1] + f'(security={extra}))'
with open(path, 'a') as f:
    f.write('\nvaltoken = ' + desc + '\n')
print('alias valtoken added')
