#!/usr/bin/env python3
"""Step 1.6b: every test data row (repos/common/db/admin/test-data.json) loads into this version's tables - checked
offline, before any database job, against the install's own definitions.

test_data.py <repo root>   (after the build: reads repos/common/db/deploy/install in install order)
The tables as the install leaves them: CREATE TABLE (XXFND_DDL_PKG.CREATE_TABLE / ensure_table files), then every
later ADD_COLUMN, DROP_COLUMN, ADD_CONSTRAINT, DROP_CONSTRAINT, SET_NULLABLE, DROP_OBJECT ... 'TABLE' and every
"alter table ... add constraint / modify" the scripts run. Each row is checked as steps 4.2b / 5.7 insert it
(db/load-data.sql: MERGE on the primary key, WHO columns filled, a column the row does not give takes its default):
  FAIL  the file is not valid JSON, or a row is not an object of column -> string / number
  FAIL  a table the install creates has no rows and no reason in "no_data"; a table or column the install does not
        have (or drops); a column twice in a row
  FAIL  NOT NULL: a NOT NULL column (no default, not an identity, not a WHO column) the row does not give
  FAIL  CHECK: a check constraint the row breaks (in, =, <>, <, >, is [not] null, like, between, and / or / not,
        upper / lower / nvl / length / trim; a check with anything else is not evaluated - INFO line)
  FAIL  PRIMARY KEY / UNIQUE: two rows with the same key
  FAIL  FOREIGN KEY: the parent row is neither earlier in the file nor the install's own seed (the parent key value
        appears as a literal in a script that names the parent table)
Prints PASS / FAIL (and INFO) lines; exit 1 on a FAIL.
"""
import json, os, re, sys

root = sys.argv[1] if len(sys.argv) > 1 else '.'
common = os.path.join(root, 'repos', 'common')
install = os.path.join(common, 'db', 'deploy', 'install')
path = os.path.join(common, 'db', 'admin', 'test-data.json')
WHO = {'CREATED_BY', 'CREATION_DATE', 'LAST_UPDATED_BY', 'LAST_UPDATE_DATE'}
TYPES = (r'(varchar2|nvarchar2|char|number|integer|float|date|timestamp|clob|nclob|blob|raw|binary_double|json|'
         r'xmltype|boolean)')
fails, infos = [], []


# ---- the install scripts: string literals masked, so calls and DDL can be found -------------------------------------
def literals(text):
    """text with every string literal replaced by \x00<n>\x00, and the literals (decoded)"""
    out, lits, i, n = [], [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '-' and text.startswith('--', i):
            j = text.find('\n', i); j = n if j < 0 else j
            out.append(text[i:j]); i = j; continue
        if c in 'qQ' and i + 2 < n and text[i + 1] == "'" and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] == '_')):
            o = text[i + 2]; close = {'[': ']', '(': ')', '{': '}', '<': '>'}.get(o, o)
            j = text.find(close + "'", i + 3)
            if j < 0:
                break
            lits.append(text[i + 3:j]); out.append(f'\x00{len(lits) - 1}\x00'); i = j + 2; continue
        if c == "'":
            j, buf = i + 1, []
            while j < n:
                if text[j] == "'":
                    if j + 1 < n and text[j + 1] == "'":
                        buf.append("'"); j += 2; continue
                    break
                buf.append(text[j]); j += 1
            lits.append(''.join(buf)); out.append(f'\x00{len(lits) - 1}\x00'); i = j + 1; continue
        out.append(c); i += 1
    return ''.join(out), lits


def split_top(s):
    """split at commas outside parentheses"""
    parts, depth, cur = [], 0, []
    for ch in s:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ',' and depth == 0:
            parts.append(''.join(cur)); cur = []
        else:
            cur.append(ch)
    parts.append(''.join(cur))
    return [p.strip() for p in parts if p.strip()]


def paren(s, start):
    """the text inside the parenthesis that opens at s[start]"""
    depth = 0
    for j in range(start, len(s)):
        depth += s[j] == '('
        depth -= s[j] == ')'
        if depth == 0:
            return s[start + 1:j]
    return s[start + 1:]


def cols_of(s):
    return [c.strip().strip('"').upper() for c in s.split(',')]


tables = {}   # name -> {'cols': {col: {'notnull', 'default', 'identity'}}, 'cons': {name: (kind, data)}}
seed_text = {}   # table -> the text of the scripts that name it (for "is the parent key seeded")
anon = [0]


def constraint(t, name, body):
    """a table constraint: (kind, data) under its name"""
    b = body.strip()
    b = re.sub(r'\s+(enable|disable|novalidate|validate|deferrable|initially\s+\w+|using\s+index.*)\s*$', '', b, flags=re.I | re.S)
    b = re.sub(r'\s+(enable|disable|novalidate|validate)(\s+(enable|disable|novalidate|validate))*\s*$', '', b, flags=re.I)
    if not name:
        anon[0] += 1; name = f'#{anon[0]}'
    m = re.match(r'(primary\s+key|unique)\s*\(', b, re.I)
    if m:
        tables[t]['cons'][name.upper()] = ('U', cols_of(paren(b, m.end() - 1))); return
    m = re.match(r'foreign\s+key\s*\(', b, re.I)
    if m:
        own = cols_of(paren(b, m.end() - 1))
        r = re.search(r'references\s+"?([a-z0-9_$#]+)"?\s*\(([^)]*)\)', b, re.I)
        if r:
            tables[t]['cons'][name.upper()] = ('F', (own, r.group(1).upper(), cols_of(r.group(2))))
        return
    m = re.match(r'check\s*\(', b, re.I)
    if m:
        tables[t]['cons'][name.upper()] = ('C', paren(b, m.end() - 1))


def column(t, c, spec):
    s = spec.strip()
    d = re.search(r"\bdefault\s+(on\s+null\s+)?('(?:[^']|'')*'|-?\d+(?:\.\d+)?|[a-z_][\w$#.]*(\([^)]*\))?)", s, re.I)
    default = None
    if d:
        v = d.group(2)
        default = v[1:-1].replace("''", "'") if v.startswith("'") else (v if re.fullmatch(r'-?\d+(\.\d+)?', v) else '?')
    tables[t]['cols'][c] = {'notnull': bool(re.search(r'\bnot\s+null\b', s, re.I)) or bool(re.search(r'\bprimary\s+key\b', s, re.I)),
                            'default': default, 'identity': bool(re.search(r'\bgenerated\b', s, re.I))}
    for m in re.finditer(r'\b(?:constraint\s+"?([a-z0-9_$#]+)"?\s+)?(check|references|primary\s+key|unique)\b', s, re.I):
        kind = m.group(2).lower()
        if kind == 'check':
            k = s.find('(', m.end())
            if k >= 0:
                constraint(t, m.group(1), 'check (' + paren(s, k) + ')')
        elif kind == 'references':
            r = re.match(r'\s*"?([a-z0-9_$#]+)"?\s*\(([^)]*)\)', s[m.end():], re.I)
            if r:
                constraint(t, m.group(1), f'foreign key ({c}) references {r.group(1)} ({r.group(2)})')
        else:
            constraint(t, m.group(1), f'{m.group(2)} ({c})')


def create(t, ddl):
    ddl = re.sub(r'--[^\n]*', '', ddl)
    m = re.search(r'create\s+table(?:\s+if\s+not\s+exists)?\s+"?[a-z0-9_$#]+"?\s*\(', ddl, re.I)
    if not m:
        return
    tables[t] = {'cols': {}, 'cons': {}}
    for part in split_top(paren(ddl, m.end() - 1)):
        mc = re.match(r'constraint\s+"?([a-z0-9_$#]+)"?\s+(.*)$', part, re.I | re.S)
        if mc:
            constraint(t, mc.group(1), mc.group(2)); continue
        if re.match(r'(primary\s+key|unique|foreign\s+key|check)\b', part, re.I):
            constraint(t, None, part); continue
        mc = re.match(r'"?([a-z][a-z0-9_$#]*)"?\s+' + TYPES + r'\b(.*)$', part, re.I | re.S)
        if mc:
            column(t, mc.group(1).upper(), mc.group(3))


def alter(ddl):
    m = re.match(r'\s*alter\s+table\s+"?([a-z0-9_$#]+)"?\s+(.*)$', ddl, re.I | re.S)
    if not m or m.group(1).upper() not in tables:
        return
    t, rest = m.group(1).upper(), m.group(2)
    a = re.match(r'add\s+constraint\s+"?([a-z0-9_$#]+)"?\s+(.*)$', rest, re.I | re.S)
    if a:
        constraint(t, a.group(1), a.group(2)); return
    a = re.match(r'drop\s+constraint\s+"?([a-z0-9_$#]+)"?', rest, re.I)
    if a:
        tables[t]['cons'].pop(a.group(1).upper(), None); return
    a = re.match(r'modify\s*\(?\s*"?([a-z0-9_$#]+)"?\s+(.*?)\)?\s*$', rest, re.I | re.S)
    if a and a.group(1).upper() in tables[t]['cols']:
        col, spec = tables[t]['cols'][a.group(1).upper()], a.group(2)
        if re.search(r'\bnot\s+null\b', spec, re.I):
            col['notnull'] = True
        elif re.search(r'\bnull\b', spec, re.I):
            col['notnull'] = False
        d = re.search(r"\bdefault\s+(on\s+null\s+)?('(?:[^']|'')*'|-?\d+(?:\.\d+)?|\S+)", spec, re.I)
        if d:
            v = d.group(2); col['default'] = v[1:-1] if v.startswith("'") else (v if re.fullmatch(r'-?\d+(\.\d+)?', v) else '?')


L = r"\x00(\d+)\x00"
for f in sorted(os.listdir(install)):
    if not f.endswith('.sql') or f == 'run-all.sql':
        continue
    text = open(os.path.join(install, f), errors='ignore').read()
    masked, lits = literals(text)
    lit = lambda m, g: lits[int(m.group(g))]
    for name in set(re.findall(r'\bxx[a-z]{2,4}_[a-z0-9_$#]+', text, re.I)):
        seed_text.setdefault(name.upper(), []).append(text)
    events = []   # (position, kind, match) in script order
    for m in re.finditer(r'(?:create|ensure)_table\(\s*' + L + r'\s*,\s*' + L, masked, re.I):
        events.append((m.start(), 'create', lit(m, 1).upper(), lit(m, 2)))
    for m in re.finditer(r'create\s+table(?:\s+if\s+not\s+exists)?\s+"?([a-z0-9_$#]+)"?\s*\(', masked, re.I):
        # a plain CREATE TABLE statement (the base table files)
        body = re.sub(L, lambda x: "'" + lits[int(x.group(1))].replace("'", "''") + "'", paren(masked, m.end() - 1))
        events.append((m.start(), 'create', m.group(1).upper(), 'create table x (' + body + ')'))
    for m in re.finditer(r'add_column\(\s*' + L + r'\s*,\s*' + L + r'\s*,\s*' + L, masked, re.I):
        events.append((m.start(), 'add_column', lit(m, 1).upper(), (lit(m, 2).upper(), lit(m, 3))))
    for m in re.finditer(r'drop_column\(\s*' + L + r'\s*,\s*' + L, masked, re.I):
        events.append((m.start(), 'drop_column', lit(m, 1).upper(), lit(m, 2).upper()))
    for m in re.finditer(r'add_constraint\(\s*' + L + r'\s*,\s*' + L + r'\s*,\s*' + L, masked, re.I):
        events.append((m.start(), 'add_constraint', lit(m, 1).upper(), (lit(m, 2), lit(m, 3))))
    for m in re.finditer(r'drop_constraint\(\s*' + L + r'\s*,\s*' + L, masked, re.I):
        events.append((m.start(), 'drop_constraint', lit(m, 1).upper(), lit(m, 2).upper()))
    for m in re.finditer(r'set_nullable\(\s*' + L + r'\s*,\s*' + L, masked, re.I):
        events.append((m.start(), 'set_nullable', lit(m, 1).upper(), lit(m, 2).upper()))
    for m in re.finditer(r'drop_object\(\s*' + L + r'\s*,\s*' + L, masked, re.I):
        if lit(m, 2).upper() == 'TABLE':
            events.append((m.start(), 'drop_table', lit(m, 1).upper(), None))
    for m in re.finditer(L, masked):
        s = lits[int(m.group(1))]
        if re.match(r'\s*alter\s+table\b', s, re.I):
            events.append((m.start(), 'alter', None, s))
    for _, kind, t, data in sorted(events, key=lambda e: e[0]):
        if kind == 'create':
            if t not in tables:
                create(t, data)
        elif kind == 'alter':
            alter(data)
        elif t not in tables:
            continue
        elif kind == 'add_column':
            if data[0] not in tables[t]['cols']:
                column(t, data[0], data[1])
        elif kind == 'drop_column':
            tables[t]['cols'].pop(data, None)
        elif kind == 'add_constraint':
            if data[0].upper() not in tables[t]['cons']:
                constraint(t, data[0], data[1])
        elif kind == 'drop_constraint':
            tables[t]['cons'].pop(data, None)
        elif kind == 'set_nullable':
            if data in tables[t]['cols']:
                tables[t]['cols'][data]['notnull'] = False
        elif kind == 'drop_table':
            tables.pop(t, None)


# ---- CHECK constraints: a small evaluator with SQL's three-valued logic (None = unknown) -----------------------------
class Unsupported(Exception):
    pass


TOK = re.compile(r"\s*(?:(\d+(?:\.\d+)?)|('(?:[^']|'')*')|(<>|!=|>=|<=|\|\||[=<>(),+-])|([a-z_][a-z0-9_$#]*))", re.I)


def tokens(s):
    out, i = [], 0
    s = s.strip()
    while i < len(s):
        m = TOK.match(s, i)
        if not m or m.end() == i:
            raise Unsupported(s[i:i + 20])
        num, st, op, word = m.groups()
        out.append(('n', float(num)) if num else ('s', st[1:-1].replace("''", "'")) if st else ('o', op) if op
                   else ('w', word.lower()))
        i = m.end()
        while i < len(s) and s[i].isspace():
            i += 1
    return out


class Check:
    def __init__(self, text, row):
        self.t, self.i, self.row = tokens(text), 0, row

    def peek(self, k=0):
        return self.t[self.i + k] if self.i + k < len(self.t) else (None, None)

    def take(self, kind=None, val=None):
        tk = self.peek()
        if (kind and tk[0] != kind) or (val is not None and tk[1] != val):
            raise Unsupported(f'expected {val or kind}, got {tk[1]}')
        self.i += 1
        return tk

    def run(self):
        v = self.expr()
        if self.i != len(self.t):
            raise Unsupported('trailing text')
        return v

    def expr(self):
        v = self.conj()
        while self.peek() == ('w', 'or'):
            self.take(); w = self.conj()
            v = True if (v is True or w is True) else (None if (v is None or w is None) else False)
        return v

    def conj(self):
        v = self.neg()
        while self.peek() == ('w', 'and'):
            self.take(); w = self.neg()
            v = False if (v is False or w is False) else (None if (v is None or w is None) else True)
        return v

    def neg(self):
        if self.peek() == ('w', 'not'):
            self.take(); v = self.neg()
            return None if v is None else not v
        return self.pred()

    def pred(self):
        if self.peek() == ('o', '('):   # a condition in parentheses, or a value in parentheses
            save = self.i
            try:
                self.take(); v = self.expr(); self.take('o', ')')
                op = self.peek()
                if op[0] == 'o' and op[1] in ('=', '<>', '!='):   # (condition) = (condition): 23ai booleans
                    self.take(); w = self.pred()
                    return None if v is None or w is None else ((v == w) if op[1] == '=' else (v != w))
                if op[0] != 'o' or op[1] in (')', ','):
                    return v
            except Unsupported:
                pass
            self.i = save
        if self.peek() == ('w', 'regexp_like') and self.peek(1) == ('o', '('):
            self.take(); self.take()
            args = [self.value()]
            while self.peek() == ('o', ','):
                self.take(); args.append(self.value())
            self.take('o', ')')
            if args[0] is None or args[1] is None:
                return None
            flags = re.I if len(args) > 2 and 'i' in str(args[2]) else 0
            return re.search(str(args[1]), str(args[0]), flags) is not None
        a = self.value()
        tk = self.peek()
        neg = False
        if tk == ('w', 'not'):
            self.take(); neg = True; tk = self.peek()
        if tk == ('w', 'is'):
            self.take()
            isnot = self.peek() == ('w', 'not')
            if isnot:
                self.take()
            self.take('w', 'null')
            return (a is not None) if isnot else (a is None)
        if tk == ('w', 'in'):
            self.take(); self.take('o', '(')
            vals = [self.value()]
            while self.peek() == ('o', ','):
                self.take(); vals.append(self.value())
            self.take('o', ')')
            if a is None:
                return None
            r = any(cmp(a, v) == 0 for v in vals if v is not None)
            r = True if r else (None if any(v is None for v in vals) else False)
            return None if r is None else (not r if neg else r)
        if tk == ('w', 'between'):
            self.take(); lo = self.value(); self.take('w', 'and'); hi = self.value()
            if None in (a, lo, hi):
                return None
            r = cmp(a, lo) >= 0 and cmp(a, hi) <= 0
            return not r if neg else r
        if tk == ('w', 'like'):
            self.take(); p = self.value()
            if a is None or p is None:
                return None
            r = re.fullmatch(re.escape(str(p)).replace('%', '.*').replace('_', '.'), str(a), re.S) is not None
            return not r if neg else r
        if tk[0] == 'o' and tk[1] in ('=', '<>', '!=', '<', '>', '<=', '>='):
            self.take(); b = self.value()
            if a is None or b is None:
                return None
            c = cmp(a, b)
            return {'=': c == 0, '<>': c != 0, '!=': c != 0, '<': c < 0, '>': c > 0, '<=': c <= 0, '>=': c >= 0}[tk[1]]
        raise Unsupported(f'condition at {tk[1]}')

    def value(self):
        v = self.primary()
        while self.peek() == ('o', '||'):
            self.take(); w = self.primary()
            v = (v or '') + (w or '') if (v is not None or w is not None) else None
        return v

    def primary(self):
        kind, val = self.take()
        if kind in ('n', 's'):
            return val
        if kind == 'o' and val == '(':
            v = self.value(); self.take('o', ')'); return v
        if kind == 'o' and val == '-':
            v = self.primary(); return None if v is None else -num(v)
        if kind == 'w':
            if val == 'null':
                return None
            if self.peek() == ('o', '('):
                self.take(); args = [self.value()]
                while self.peek() == ('o', ','):
                    self.take(); args.append(self.value())
                self.take('o', ')')
                f = {'upper': lambda x: None if x is None else str(x).upper(),
                     'lower': lambda x: None if x is None else str(x).lower(),
                     'trim': lambda x: None if x is None else (str(x).strip() or None),
                     'length': lambda x: None if x in (None, '') else float(len(str(x))),
                     'nvl': lambda x, y: y if x is None else x}.get(val)
                if not f:
                    raise Unsupported(f'function {val}')
                return f(*args)
            col = val.upper()
            if col not in self.row:
                raise Unsupported(f'name {val}')
            return self.row[col]
        raise Unsupported(f'token {val}')


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def cmp(a, b):
    x, y = num(a), num(b)
    if x is not None and y is not None and (isinstance(a, float) or isinstance(b, float)):
        return (x > y) - (x < y)
    a, b = str(a), str(b)
    return (a > b) - (a < b)


# ---- the rows ---------------------------------------------------------------------------------------------------------
try:
    data = json.load(open(path, encoding='utf-8'))
except (OSError, ValueError) as e:
    print(f'FAIL test data: {path} - {e}')
    sys.exit(1)

covered, keys, rowcount = set(), {}, 0   # keys: (table, unique columns) -> the key values seen
loaded = {}   # table -> the rows of the file so far, as inserted (a later row's foreign keys look here)


def key_of(row, cols):
    v = tuple(row.get(c) for c in cols)
    return None if any(x is None for x in v) else tuple(str(int(x)) if isinstance(x, float) and x.is_integer() else str(x) for x in v)


def seeded(parent, values):
    texts = seed_text.get(parent, [])
    return all(any((f"'{v}'" in t or re.search(rf'\b{re.escape(str(v))}\b', t)) for t in texts) for v in values) and bool(texts)


for i, block in enumerate(data.get('tables', [])):
    t = str(block.get('table', '')).upper()
    if t not in tables:
        fails.append(f'{t or "(no name)"}: not a table of the install (missing, or dropped by it) (entry {i + 1})')
        continue
    if not block.get('rows'):
        fails.append(f'{t}: no rows (give rows, or move it to "no_data" with the reason)')
    covered.add(t)
    tdef = tables[t]
    for n, row in enumerate(block.get('rows', []), 1):
        rowcount += 1
        where = f'{t} row {n}'
        if not isinstance(row, dict):
            fails.append(f'{where}: not an object'); continue
        given, seen = {}, set()
        for c, v in row.items():
            cu = c.upper()
            if cu in seen:
                fails.append(f'{where}: column {cu} given twice')
            seen.add(cu)
            if cu not in tdef['cols']:
                fails.append(f'{where}: column {cu} is not in the table (after the install\'s column changes)')
            if v is not None and not isinstance(v, (str, int, float)):
                fails.append(f'{where}: {cu} is not a string or a number')
            if v is not None:
                given[cu] = float(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else v
        # the row as the insert writes it: given values, else the column default (unknown default: not judged)
        full, unknown = {}, set()
        for c, d in tdef['cols'].items():
            if c in given:
                full[c] = given[c]
            elif c in WHO:
                full[c] = 'TEST_DATA'
            elif d['default'] == '?' or d['identity']:
                full[c] = 'x'; unknown.add(c)
            elif d['default'] is not None:
                full[c] = num(d['default']) if re.fullmatch(r'-?\d+(\.\d+)?', d['default']) else d['default']
            else:
                full[c] = None
            if d['notnull'] and full[c] is None:
                fails.append(f'{where}: {c} is NOT NULL - give it a value')
        for name, (kind, cd) in tdef['cons'].items():
            if kind == 'C':
                if any(re.search(rf'\b{re.escape(c)}\b', cd, re.I) for c in unknown):
                    continue
                try:
                    ok = Check(cd, full).run()
                except Unsupported as e:
                    infos.append(f'{t}: check {name} not evaluated offline ({e})'); continue
                if ok is False:
                    fails.append(f'{where}: breaks check {name} ({" ".join(cd.split())})')
            elif kind == 'U':
                k = key_of(full, cd)
                if k is not None:
                    bucket = keys.setdefault((t, tuple(cd)), set())
                    if k in bucket:
                        fails.append(f'{where}: duplicate key {name} ({", ".join(cd)} = {", ".join(k)})')
                    bucket.add(k)
            elif kind == 'F':
                own, parent, pcols = cd
                k = key_of(full, own)
                if k is None or any(c in unknown for c in own):
                    continue
                prows = loaded.get(parent, []) + ([full] if parent == t else [])
                if any(key_of(r, pcols) == k for r in prows):
                    continue
                if not seeded(parent, k):
                    fails.append(f'{where}: {name} - no {parent} row with {", ".join(pcols)} = {", ".join(k)} '
                                 f'earlier in the file (or in the install\'s seed)')
        if any(x.startswith(where + ':') for x in fails):
            continue   # a row that does not load is no parent for the rows after it (as in the database)
        loaded.setdefault(t, []).append({c: v for c, v in full.items() if c not in unknown})
for t, why in data.get('no_data', {}).items():
    if t.upper() not in tables:
        fails.append(f'{t}: listed in "no_data" but not a table of the install')
    elif not str(why).strip():
        fails.append(f'{t}: "no_data" needs the reason')
    covered.add(t.upper())
for t in sorted(set(tables) - covered):
    fails.append(f'{t}: a table of the install without test rows - add its rows to {os.path.relpath(path, root)} '
                 '(or list it in "no_data" with the reason)')
for f in sorted(set(infos)):
    print(f'INFO test data: {f}')
for f in fails:
    print(f'FAIL test data: {f}')
if not fails:
    print(f'PASS test data: {len(covered)} table(s) of the install covered, {rowcount} row(s): columns, NOT NULL, '
          'checks, keys and foreign keys')
sys.exit(1 if fails else 0)
