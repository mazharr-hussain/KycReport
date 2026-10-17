import re
PLSQL_START=re.compile(r'^\s*(create\s+(or\s+replace\s+)?(editionable\s+|noneditionable\s+)?(package|type|trigger|function|procedure)\b|begin\b|declare\b)',re.I)
def split(text):
    """Split a SQL*Plus script into statements; each = (kind, text). Leading comment/blank lines join the next statement.
    The concatenation of all statement texts equals the input exactly."""
    lines=text.splitlines(keepends=True); out=[]; buf=[]; i=0; n=len(lines)
    def flush(kind):
        nonlocal buf
        if buf: out.append([kind,''.join(buf)]); buf=[]
    while i<n:
        l=lines[i]; s=l.strip()
        if not s or s.startswith('--') or s.startswith('rem ') or s.lower().startswith(('prompt','set ','whenever','spool','@')) and not buf_has_stmt(buf):
            buf.append(l); i+=1
            if s.lower().startswith(('prompt','set ','whenever','spool','@')): flush('cmd')
            continue
        if PLSQL_START.match(l):
            while i<n:
                buf.append(lines[i]); i+=1
                if lines[i-1].strip()=='/': break
            flush('plsql'); continue
        # plain SQL until a line ending with ';' (outside quotes, approx.)
        while i<n:
            buf.append(lines[i]); i+=1
            if lines[i-1].rstrip().endswith(';') or lines[i-1].strip()=='/': break
        flush('sql')
    flush('trailer')
    return out
def buf_has_stmt(buf): return False
