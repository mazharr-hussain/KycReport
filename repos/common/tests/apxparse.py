"""Minimal APEXlang parser: components `kind name (`...`)`, groups `key {`...`}`,
arrays `key: [`...`]`, inline maps `key: {`, code fences, scalars. Keeps line numbers."""
import re
class Comp:
    def __init__(s,kind,name,line,file):
        s.kind,s.name,s.line,s.file=kind,name,line,file; s.props={}; s.lines={}; s.children=[]; s.parent=None
    def get(s,path,default=None): return s.props.get(path,default)
    def kids(s,kind): return [c for c in s.children if c.kind==kind]
    def __repr__(s): return f"{s.kind} {s.name}@{s.file}:{s.line}"
COMP=re.compile(r'^\s*([A-Za-z][\w]*)\s+("[^"]*"|[^\s(]+)?\s*\($')
COMP0=re.compile(r'^\s*([A-Za-z][\w]*)\s*\($')
GROUP=re.compile(r'^\s*([A-Za-z][\w$]*)\s*\{$')
KV=re.compile(r'^\s*([A-Za-z_$][\w$]*)\s*:\s*(.*)$')
def parse(path,rel):
    L=open(path,encoding='utf-8').read().split('\n')
    roots=[]; stack=[]; gpath=[]  # gpath: list of (type,name) where type in 'g','m'
    i=0
    def cur(): return stack[-1] if stack else None
    def key(k): return '.'.join([g for g in gpath]+[k])
    while i<len(L):
        raw=L[i]; s=raw.strip(); ln=i+1
        if not s: i+=1; continue
        m=COMP.match(raw) or COMP0.match(raw)
        if m and not KV.match(raw):
            c=Comp(m.group(1), (m.group(2) or '').strip('"') if m.lastindex and m.lastindex>=2 else '', ln, rel)
            if stack: c.parent=stack[-1]; stack[-1].children.append(c)
            else: roots.append(c)
            stack.append(c); c._g=gpath; gpath=[]; i+=1; continue
        if s==')':
            c=stack.pop(); gpath=c._g; i+=1; continue
        m=GROUP.match(raw)
        if m: gpath=gpath+[m.group(1)]; i+=1; continue
        if s=='}': gpath=gpath[:-1]; i+=1; continue
        m=KV.match(raw)
        if m and cur() is not None:
            k,v=m.group(1),m.group(2).strip()
            if v=='' and i+1<len(L) and L[i+1].strip().startswith('```'):
                j=i+2; body=[]
                while not L[j].strip().startswith('```'): body.append(L[j]); j+=1
                cur().props[key(k)]='\n'.join(body); cur().lines[key(k)]=ln; i=j+1; continue
            if v=='[':
                j=i+1; vals=[]
                while L[j].strip()!=']': vals.append(L[j].strip()); j+=1
                cur().props[key(k)]=vals; cur().lines[key(k)]=ln; i=j+1; continue
            if v=='{':
                gpath=gpath+[k]; i+=1; continue
            if v.startswith('```') and v.endswith('```') and len(v)>6: v=v[3:-3]
            cur().props[key(k)]=v; cur().lines[key(k)]=ln; i+=1; continue
        # bare list items / unknown -> record
        if cur() is not None: cur().props.setdefault('_bare',[]).append((ln,s))
        i+=1
    assert not stack, (rel,stack)
    return roots
def load(root):
    import os
    out=[]
    for dp,_,fs in os.walk(root):
        for f in sorted(fs):
            if f.endswith('.apx'):
                p=os.path.join(dp,f); out+=parse(p,os.path.relpath(p,root))
    return out
