#!/usr/bin/env python3
"""The application's own database objects (I-077): what its install and upgrade scripts create.

app_objects.py <deploy dir>   (repos/common/db/deploy, built by build.sh)
Prints one "<TYPE> <NAME>" line per object, sorted: TABLE, VIEW, MATERIALIZED_VIEW, SEQUENCE, PACKAGE, TYPE,
TRIGGER, FUNCTION, PROCEDURE, SYNONYM, JOB. Read from every CREATE statement (direct or inside a DDL string handed
to XXFND_DDL_PKG), from XXFND_DDL_PKG.RENAME_TABLE (the new name) and from DBMS_SCHEDULER.CREATE_JOB. Indexes,
constraints and VPD policies belong to their table and are removed with it (policies first, by db/run.sh).

Steps 5.1 / 6.1 remove only these objects (plus the ones recorded for an earlier deploy): a schema can hold the
objects of more than one application, so it is never emptied, dropped or created.
"""
import os, re, sys

NAME = r'"?(?:[A-Za-z0-9_$#]+"?\."?)?([A-Za-z][A-Za-z0-9_$#]*)"?'
CREATE = re.compile(
    r'\bcreate\s+(?:or\s+replace\s+)?(?:(?:no)?force\s+)?(?:(?:non)?editionable\s+)?'
    r'(table|view|materialized\s+view|sequence|package(?:\s+body)?|type(?:\s+body)?|trigger|function|procedure|synonym)'
    r'\s+(?:if\s+not\s+exists\s+)?' + NAME, re.I)
RENAME = re.compile(r"\brename_table\s*\(\s*'[^']+'\s*,\s*'([A-Za-z][A-Za-z0-9_$#]*)'", re.I)
JOB = re.compile(r"\bcreate_job\s*\(\s*(?:job_name\s*=>\s*)?'([A-Za-z][A-Za-z0-9_$#]*)'", re.I)
KEYWORDS = {'IF', 'OR', 'AS', 'IS', 'BODY'}


def objects(deploy_dir):
    found = set()
    for sub in ('install', 'upgrade'):
        d = os.path.join(deploy_dir, sub)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            text = open(os.path.join(d, f), errors='ignore').read()
            text = re.sub(r'--[^\n]*', '', text)                        # line comments
            text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)           # block comments
            for kind, name in CREATE.findall(text):
                kind = re.sub(r'\s+', '_', kind.upper()).replace('_BODY', '')
                if name.upper() not in KEYWORDS:
                    found.add((kind, name.upper()))
            for name in RENAME.findall(text):
                found.add(('TABLE', name.upper()))
            for name in JOB.findall(text):
                found.add(('JOB', name.upper()))
    return sorted(found)


if __name__ == '__main__':
    for kind, name in objects(sys.argv[1]):
        print(kind, name)
