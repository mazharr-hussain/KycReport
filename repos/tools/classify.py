import re
def strip_comments(t):
    t=re.sub(r'--[^\n]*','',t); return re.sub(r'/\*.*?\*/','',t,flags=re.S)
PAT=[(r'^\s*create\s+(?:or\s+replace\s+)?(?:editionable\s+)?package\s+body\s+(?:\w+\.)?"?(\w+)','package'),
     (r'^\s*create\s+(?:or\s+replace\s+)?(?:editionable\s+)?package\s+(?:\w+\.)?"?(\w+)','package'),
     (r'^\s*create\s+(?:or\s+replace\s+)?(?:force\s+)?(?:editionable\s+)?type\s+body\s+(\w+)','type'),
     (r'^\s*create\s+(?:or\s+replace\s+)?(?:force\s+)?(?:editionable\s+)?type\s+(\w+)','type'),
     (r'^\s*create\s+(?:or\s+replace\s+)?(?:editionable\s+)?trigger\s+(\w+)','trigger'),
     (r'^\s*create\s+(?:or\s+replace\s+)?(?:force\s+)?(?:editionable\s+)?view\s+(\w+)','view'),
     (r'^\s*create\s+(?:or\s+replace\s+)?(?:function|procedure)\s+(\w+)','routine'),
     (r'^\s*create\s+(?:global\s+temporary\s+)?table\s+(?:if\s+not\s+exists\s+)?(\w+)','table'),
     (r'^\s*create\s+(?:unique\s+)?index\s+(?:if\s+not\s+exists\s+)?\w+\s+on\s+(\w+)','table'),
     (r'^\s*create\s+(?:or\s+replace\s+)?(?:public\s+)?synonym\s+(\w+)','synonym'),
     (r'^\s*create\s+sequence\s+(?:if\s+not\s+exists\s+)?(\w+)','sequence'),
     (r'^\s*comment\s+on\s+(?:table|column|materialized\s+view)\s+(\w+)','table'),
     (r'^\s*alter\s+(?:table|trigger|view|package)\s+(\w+)','table'),
     (r'^\s*(?:merge\s+into|insert\s+into|delete\s+from|update)\s+(\w+)','data'),
     (r'^\s*grant\s+.*?\son\s+(\w+)','grant'),
     (r'^\s*drop\s+\w+\s+(\w+)','drop')]
def classify(kind,text):
    body=strip_comments(text).strip()
    for p,typ in PAT:
        m=re.search(p,body,re.I|re.S)
        if m and body.lower().startswith(m.group(0).strip().lower()[:6]): return typ,m.group(1).upper()
    if re.match(r'^(begin|declare)\b',body,re.I):
        # first XX* identifier in a DDL helper call or DML, else any XX* name
        m=re.search(r"(?:create_table|add_column|drop_column|add_constraint|drop_constraint|ensure_index|drop_index|ensure_sequence|drop_object|set_nullable|create_who_trigger|run)\s*\(\s*'(\w+)'",body,re.I) \
          or re.search(r"(?:merge\s+into|insert\s+into|delete\s+from|update)\s+(xx\w+)",body,re.I) \
          or re.search(r"\b(xx(?:cmp|fnd)_\w+)",body,re.I)
        if m: return 'block',m.group(1).upper()
        return 'block','(script)'
    if body.lower().startswith('commit'): return 'commit','(prev)'
    if not body: return 'blank','(prev)'
    return 'other','(script)'
