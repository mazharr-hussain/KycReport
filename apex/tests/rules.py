import sys,re,json,os
sys.path.insert(0,os.path.dirname(__file__)); import apxparse as A
ROOT=sys.argv[1]; SCHEMA=json.load(open(sys.argv[2]))
cols={k:set(v) for k,v in SCHEMA.items()}
R=A.load(ROOT)
_ddl=open(os.path.join(ROOT,'supporting-objects/supporting-objects.apx')).read()
IDENT={}
for m in re.finditer(r'create table (\w+) \((.*?)\n\s*\)\s*;',_ddl,re.S|re.I):
    for mm in re.finditer(r'^\s*(\w+)\s+number\s+generated[^,\n]*identity',m.group(2),re.M|re.I):
        IDENT.setdefault(m.group(1).lower(),set()).add(mm.group(1).lower())
def walk(c):
    yield c
    for k in c.children: yield from walk(k)
pages={int(c.name):c for c in R if c.kind=='page'}
shared={}
for c in R:
    if c.kind!='page': shared.setdefault(c.kind,{})[c.name]=c
app=shared['app']['KYC']
app_items=set(shared.get('appItem',{}))
rows=[]   # (rule, page, component, file:line, evidence, result)
def add(rule,page,comp,loc,ev,res): rows.append((rule,page,comp,loc,ev,res))
def loc(c,key=None): return f"{c.file}:{c.lines.get(key,c.line) if key else c.line}"
def L(v):
    if v is None: return []
    if isinstance(v,str): v=[v]
    out=[]
    for x in v: out+=[y.strip() for y in x.split(',') if y.strip()]
    return out
def ref(v): return v[1:] if isinstance(v,str) and v.startswith('@') and not v.startswith('@/') else None
def rtype(r): return r.get('type')
def is_editable(r): return rtype(r)=='interactiveGrid' and r.get('edit.enabled')=='true'
# ---------- SQL helpers ----------
def strip_sql(s): s=re.sub(r'--[^\n]*','',s); return re.sub(r"'(?:[^']|'')*'","''",s)
def top_select_list(sql):
    s=strip_sql(sql); low=s.lower()
    i=low.find('select'); 
    if i<0: return None,None
    j=i+6; d=0; out=''
    while j<len(s):
        c=s[j]
        if c=='(':d+=1
        elif c==')':d-=1
        if d==0 and re.match(r'\sfrom\s',low[j:j+6]): break
        out+=c; j+=1
    parts=[];d=0;cur=''
    for c in out:
        if c=='(':d+=1
        if c==')':d-=1
        if c==',' and d==0: parts.append(cur);cur=''
        else: cur+=c
    parts.append(cur)
    names=[];stars=[]
    for p in parts:
        p=p.strip()
        if re.search(r'(^|\.)\*$',p): stars.append(p.split('.')[0] if '.' in p else '*'); continue
        m=re.search(r'(\w+)\s*$',p)
        if m: names.append(m.group(1).upper())
    return names,(stars,s[j:])
def from_tables(rest):
    return re.findall(r'\b(?:from|join)\s+([a-z_][\w$]*)\s*([a-z_]\w*)?',rest.lower())
def select_cols(sql):
    names,info=top_select_list(sql)
    if names is None: return None
    stars,rest=info
    for st in stars:
        # inline view "( select ... ) q"
        m=re.search(r'from\s*\(\s*(select.*)\)\s*'+(re.escape(st) if st!='*' else r'\w*'),rest,re.S|re.I)
        if m:
            inner=select_cols(m.group(1))
            if inner is None: return None
            names+=inner; continue
        tb=None
        for t,al in from_tables(rest):
            if al==st.lower() or t==st.lower() or st=='*': tb=t
        if tb and tb in cols: names+=[c.upper() for c in cols[tb]]
        else: return None
    return names
BIND=re.compile(r'[:&](P\d+_[A-Z0-9_$]+)\b')
BIND2=re.compile(r'\b(P\d+_[A-Z0-9_$]+)\b')
# ---------- per page ----------
for pid,p in sorted(pages.items()):
    items={c.name:c for c in p.kids('pageItem')}
    g0={c.name for c in pages[0].kids('pageItem')} if 0 in pages else set()
    known_items=set(items)|g0|app_items
    regions={c.name:c for c in p.kids('region')}
    buttons={c.name:c for c in p.kids('button')}
    bnames={(c.get('buttonName') or '').upper() for c in p.kids('button')}
    procs=p.kids('process'); vals=p.kids('validation'); das=p.kids('dynamicAction')
    ros=p.get('advanced.reloadOnSubmit') or 'onlyForSuccess(default)'
    def chk_items(where,c,key,names,rule='d'):
        for n in sorted(set(names)):
            if n.startswith('P') and re.match(r'P\d+_',n):
                pg=int(n[1:].split('_')[0])
                ok = n in known_items if pg in (pid,0) else (pg in pages and n in {x.name for x in pages[pg].kids('pageItem')})
                add(rule,pid,f"{where}",loc(c,key),f"refs {n}",'PASS' if ok else 'FAIL')
    # rule a/b per IG
    for rn,r in regions.items():
        if rtype(r)=='interactiveGrid':
            ed=is_editable(r)
            add('a',pid,f"region {rn} (IG, editable={ed})",loc(r),f"page reloadOnSubmit={ros}",
                'N/A' if not ed else ('PASS' if ros.startswith('onlyForSuccess') else 'FAIL'))
            if ed:
                pk=[c.name for c in r.kids('column') if c.get('source.primaryKey')=='true']
                rowid=r.get('source.includeRowidColumn')=='true'
                add('b',pid,f"region {rn} PK column",loc(r),f"primaryKey={pk or '-'} rowid={rowid}",'PASS' if pk or rowid else 'FAIL')
                dml=[x for x in procs if x.get('type')=='interactiveGridAutoRowProcessing' and ref(x.get('editableRegion'))==rn]
                add('b',pid,f"region {rn} IG DML process",loc(r),f"processes={[x.name for x in dml] or '-'}",'PASS' if dml else 'FAIL')
                rest=top_select_list(r.get('source.sqlQuery',''))[1][1]
                d0=0; top=''
                for ch in rest:
                    if ch=='(': d0+=1
                    elif ch==')': d0-=1
                    elif d0==0: top+=ch
                real=[t for t,_ in from_tables(re.split(r'\bwhere\b',top,1,flags=re.I)[0]) if t.startswith('xx')]
                add('b',pid,f"region {rn} DML target (single table source)",loc(r,'source.sqlQuery'),f"from={real}",'PASS' if len(set(real))==1 else 'FAIL')
                # PK populated on insert (identity / default) if add allowed
                ops=r.get('edit.allowedOperations') or []
                if 'add' in ops and pk and len(set(real))==1:
                    t=real[0]
                    for k in pk:
                        col=[c for c in r.kids('column') if c.name==k][0]
                        dflt=col.get('default.type')
                        how=('identity' if k.lower() in IDENT.get(t,set()) else f"default {dflt}" if dflt else
                             f"master column {col.get('masterDetail.masterColumn')}" if col.get('masterDetail.masterColumn') else
                             f"user entry ({col.get('type')})" if col.get('type') not in ('hidden','displayOnly') else None)
                        add('g10',pid,f"region {rn} PK {k} populated on insert",loc(col),f"table={t}: {how or 'nothing populates it'}",'PASS' if how else 'FAIL')
    # rule c forms
    for rn,r in regions.items():
        if rtype(r)=='form':
            tb=(r.get('source.tableName') or '').lower()
            fitems=[i for i in items.values() if ref(i.get('source.formRegion'))==rn]
            bad=[(i.name,i.get('source.column')) for i in fitems if (i.get('source.column') or '').lower() not in cols.get(tb,set())|{'rowid'}]
            add('c',pid,f"form {rn} items→columns of {tb.upper()}",loc(r),f"{len(fitems)} items; unmapped={bad or '-'}",'PASS' if tb in cols and not bad else 'FAIL')
            pk=[i.name for i in fitems if i.get('source.primaryKey')=='true']
            add('c',pid,f"form {rn} primary key item",loc(r),f"pk={pk or '-'}",'PASS' if pk else 'FAIL')
            arp=[x.name for x in procs if x.get('type')=='formAutoRowProcessing' and ref(x.get('formRegion'))==rn]
            ini=[x.name for x in procs if x.get('type')=='formInitialization' and ref(x.get('formRegion'))==rn]
            custom=[x.name for x in procs if x.get('type')=='executeCode' and x.get('execution.point') in ('afterSubmit','processing')]
            add('c',pid,f"form {rn} Automatic Row Processing",loc(r),f"arp={arp or '-'}"+('' if arp else f"; saved by custom processes {custom}"),'PASS' if arp else ('INFO' if custom else 'FAIL'))
            add('c',pid,f"form {rn} Form Initialization",loc(r),f"init={ini or '-'}",'PASS' if ini else 'FAIL')
    # rule d references
    for x in procs:
        for k in ('formRegion','editableRegion'):
            if x.get(k): add('d',pid,f"process {x.name}.{k}",loc(x,k),x.get(k),'PASS' if ref(x.get(k)) in regions else 'FAIL')
        wb=ref(x.get('serverSideCondition.whenButtonPressed'))
        if wb: add('d',pid,f"process {x.name} whenButtonPressed",loc(x,'serverSideCondition.whenButtonPressed'),wb,'PASS' if wb in buttons else 'FAIL')
        if x.get('serverSideCondition.type')=='requestIsContainedInValue':
            vs=[v.strip() for v in x.get('serverSideCondition.value').split(',')]
            miss=[v for v in vs if v.upper() not in bnames]
            add('g6',pid,f"process {x.name} request values match buttons",loc(x,'serverSideCondition.value'),f"values={vs} buttons={sorted(bnames)}",'PASS' if not miss else f"FAIL ({','.join(miss)})")
        code=x.get('source.plsqlCode') or ''
        chk_items(f"process {x.name} code",x,'source.plsqlCode',BIND.findall(code))
    for v in vals:
        wb=ref(v.get('serverSideCondition.whenButtonPressed'))
        if wb: add('d',pid,f"validation {v.name} whenButtonPressed",loc(v),wb,'PASS' if wb in buttons else 'FAIL')
        ai=v.get('error.associatedItem')
        if ai: add('d',pid,f"validation {v.name} associatedItem",loc(v,'error.associatedItem'),ai,'PASS' if ai.lstrip('@') in items else 'FAIL')
        chk_items(f"validation {v.name} code",v,'validation.plsqlFunctionBody',BIND.findall(v.get('validation.plsqlFunctionBody') or ''))
    for d in das:
        for n in L(d.get('when.items')): add('d',pid,f"DA {d.name} when.items",loc(d),n,'PASS' if n in known_items else 'FAIL')
        for k in ('when.button','when.region'):
            if d.get(k): add('d',pid,f"DA {d.name} {k}",loc(d,k),d.get(k),'PASS' if ref(d.get(k)) in (buttons if 'button' in k else regions) else 'FAIL')
        for ac in d.kids('action'):
            its=L(ac.get('affectedElements.items'))
            for n in its: add('d',pid,f"DA {d.name}/{ac.name} affected item",loc(ac),n,'PASS' if n in known_items else 'FAIL')
            if ac.get('affectedElements.region'): add('d',pid,f"DA {d.name}/{ac.name} affected region",loc(ac),ac.get('affectedElements.region'),'PASS' if ref(ac.get('affectedElements.region')) in regions else 'FAIL')
            its=L(ac.get('settings.itemsToSubmit'))
            for n in its: add('d',pid,f"DA {d.name}/{ac.name} itemsToSubmit",loc(ac),n,'PASS' if n in known_items else 'FAIL')
            chk_items(f"DA {d.name}/{ac.name} code",ac,'settings.jsCode',BIND2.findall((ac.get('settings.jsCode') or '')+(ac.get('settings.sqlQuery') or '')))
            # g1: client-side change of value-protected hidden items
            if ac.get('action') in ('setValue','nativeSetValue') or 'setValue' in (ac.get('settings.jsCode') or '') or 'xxfndDff.bind' in (ac.get('settings.jsCode') or ''):
                pass
    for rn,r in regions.items():
        its=L(r.get('source.pageItemsToSubmit'))
        for n in its: add('d',pid,f"region {rn} pageItemsToSubmit",loc(r,'source.pageItemsToSubmit'),n,'PASS' if n in known_items else 'FAIL')
        if r.get('serverSideCondition.item'): 
            n=r.get('serverSideCondition.item'); add('d',pid,f"region {rn} condition item",loc(r),n,'PASS' if n in known_items else 'FAIL')
        mr=ref(r.get('masterDetail.masterRegion'))
        if mr: add('d',pid,f"region {rn} masterRegion",loc(r),mr,'PASS' if mr in regions else 'FAIL')
        sql=(r.get('source.sqlQuery') or '')+(r.get('source.plsqlFunctionBody') or '')
        chk_items(f"region {rn} source",r,'source.sqlQuery',BIND.findall(sql))
        # g4 declared columns vs query
        if r.get('source.sqlQuery') and rtype(r) in ('interactiveGrid','interactiveReport','classicReport'):
            sc=select_cols(r.get('source.sqlQuery'))
            decl=[c.name for c in r.kids('column') if not c.name.startswith('APEX$')]
            if sc is None: add('g4',pid,f"region {rn} columns vs query",loc(r),'select list not resolvable statically','UNVERIFIED')
            else:
                miss=[c for c in decl if c not in sc and not (r.kids('column') and [k for k in r.kids('column') if k.name==c][0].get('source.type') not in (None,'databaseColumn'))]
                extra=[c for c in sc if c not in decl]
                add('g4',pid,f"region {rn} ({rtype(r)}) columns vs query",loc(r,'source.sqlQuery'),f"declared-not-in-query={miss or '-'}; query-not-declared={extra or '-'}",'PASS' if not miss and not extra else 'FAIL')
            # HTML expressions / link substitutions reference existing columns
            for c in r.kids('column'):
                for k in ('columnFormatting.htmlExpression','link.linkText'):
                    subs=re.findall(r'#([A-Z0-9_$]+)#',c.get(k) or '')
                    subs=[s for s in subs if not s.startswith('APEX$')]
                    if subs and sc is not None:
                        bad=[s for s in subs if s not in sc]
                        add('d',pid,f"region {rn} column {c.name} {k.split('.')[-1]} #COL#",loc(c,k),f"{subs}",'PASS' if not bad else f"FAIL {bad}")
                # IG default item
                if c.get('default.item'): 
                    n=c.get('default.item'); add('d',pid,f"region {rn} column {c.name} default item",loc(c),n,'PASS' if n in known_items else 'FAIL')
                mc=c.get('masterDetail.masterColumn')
                if mc: add('d',pid,f"region {rn} column {c.name} masterColumn",loc(c),mc,'PASS' if True else 'FAIL')
                # e: databaseColumn source outside IG
                if c.get('source.type')=='databaseColumn' and rtype(r)!='interactiveGrid':
                    add('e',pid,f"region {rn} column {c.name}",loc(c),f"databaseColumn in {rtype(r)}",'FAIL')
                if rtype(r)=='interactiveGrid' and c.get('source.type')=='databaseColumn' and sc is not None:
                    dc=(c.get('source.databaseColumn') or '').upper()
                    add('e',pid,f"region {rn} column {c.name} databaseColumn",loc(c),dc,'PASS' if dc in sc else 'FAIL')
    # items
    for n,i in items.items():
        for k in ('serverSideCondition.plsqlExpression','readOnly.plsqlExpression','lov.sqlQuery','source.sqlQuery'):
            chk_items(f"item {n} {k}",i,k,BIND.findall(i.get(k) or ''))
        if i.get('serverSideCondition.item'):
            m=i.get('serverSideCondition.item'); add('d',pid,f"item {n} condition item",loc(i),m,'PASS' if m in known_items else 'FAIL')
        fr=ref(i.get('source.formRegion'))
        st=i.get('source.type')
        if fr: add('e',pid,f"item {n} formRegion",loc(i,'source.formRegion'),f"@{fr} type={rtype(regions.get(fr)) if fr in regions else 'MISSING'}",'PASS' if fr in regions and rtype(regions[fr])=='form' else 'FAIL')
        if i.get('source.column') and not fr: add('e',pid,f"item {n} column source without form",loc(i),i.get('source.column'),'FAIL')
        if st=='databaseColumn' and not fr: add('e',pid,f"item {n}",loc(i),'databaseColumn source without form region','FAIL')
        rg=ref(i.get('layout.region'))
        if rg: add('d',pid,f"item {n} layout.region",loc(i,'layout.region'),rg,'PASS' if rg in regions else 'FAIL')
        # g1 hidden value protected + modified in browser
        if i.get('type')=='hidden':
            vp=i.get('settings.valueProtected','true(default)')
            js_set=any(('xxfndDff.bind' in (ac.get('settings.jsCode') or '') and n in (ac.get('settings.jsCode') or '')) or
                       (n in L(ac.get('affectedElements.items')) and ac.get('action') in ('setValue','clear'))
                       for d in das for ac in d.kids('action'))
            if js_set:
                add('g1',pid,f"item {n} (hidden) changed in browser",loc(i),f"valueProtected={vp}",'PASS' if vp=='false' else 'FAIL')
    # buttons / links targets
    def chk_target(c,prefix):
        tp=c.get(prefix+'target.page')
        if tp is None: return
        try: tpn=int(tp)
        except: tpn={pg.get('alias'):k for k,pg in pages.items()}.get(tp,None)
        add('d',pid,f"{c.kind} {c.name} target page",loc(c,prefix+'target.page'),tp,'PASS' if tpn in pages else 'FAIL')
        if tpn in pages:
            tit={x.name for x in pages[tpn].kids('pageItem')}
            for k in c.props:
                if k.startswith(prefix+'target.items.'):
                    n=k.split('.')[-1]; add('d',pid,f"{c.kind} {c.name} target item",loc(c,k),f"{n} on page {tpn}",'PASS' if n in tit else 'FAIL')
                    chk_items(f"{c.kind} {c.name} target value",c,k,BIND2.findall(c.props[k]))
    for b in buttons.values():
        chk_target(b,'behavior.')
        if b.get('serverSideCondition.plsqlExpression'): chk_items(f"button {b.name} condition",b,'serverSideCondition.plsqlExpression',BIND.findall(b.get('serverSideCondition.plsqlExpression')))
        rg=ref(b.get('layout.region'))
        if rg: add('d',pid,f"button {b.name} layout.region",loc(b),rg,'PASS' if rg in regions else 'FAIL')
    for r in regions.values():
        for c in r.kids('column'): chk_target(c,'link.')
    # apex_page.get_url in SQL
    for r in regions.values():
        for m in re.finditer(r"apex_page\.get_url\(p_page\s*=>\s*(\d+)\s*,\s*p_items\s*=>\s*'([^']+)'",r.get('source.sqlQuery') or '',re.I):
            tpn=int(m.group(1))
            for n in m.group(2).split(','):
                ok = tpn in pages and n in {x.name for x in pages[tpn].kids('pageItem')}
                add('d',pid,f"region {r.name} get_url item",loc(r,'source.sqlQuery'),f"{n} on page {tpn}",'PASS' if ok else 'FAIL')
    # g3 modal dialog submit → close dialog
    if p.get('appearance.pageMode')=='modalDialog' or 'modalDialog' in json.dumps(p.props):
        sub=[x for x in procs if x.get('execution.point')=='afterSubmit' and x.get('type')!='closeDialog']
        cd=[x for x in procs if x.get('type')=='closeDialog']
        if sub: add('g3',pid,'modal dialog: submit closes dialog',loc(p),f"afterSubmit={len(sub)} closeDialog={[x.name for x in cd] or '-'}",'PASS' if cd else 'FAIL')
    # g2 f?p links with args to checksum-protected pages
    for r in regions.values():
        for c in r.kids('column'):
            h=c.get('columnFormatting.htmlExpression') or ''
            for m in re.finditer(r'f\?p=&APP_ID\.:(\d+):&SESSION\.:([^:"]*):[^:"]*:[^:"]*:([^:"]*):',h):
                tp=int(m.group(1)); prot=pages[tp].get('security.pageAccessProtection')
                add('g2',pid,f"region {r.name} column {c.name} f?p link",loc(c,'columnFormatting.htmlExpression'),f"page {tp} protection={prot}, request={m.group(2)}, items={m.group(3)}, no checksum",
                    'FAIL' if prot=='argumentsMustHaveChecksum' else 'PASS')
# ---------- rule f: shared component references ----------
defs={'lov':set(shared.get('lov',{})),'authorizationScheme':set(shared.get('authorization',{})),'list':set(shared.get('list',{})),
      'breadcrumb':set(shared.get('breadcrumb',{})),'pageGroup':set(shared.get('pageGroup',{})),'scheme':set(shared.get('authentication',{}))|set(shared.get('authorization',{}))}
for r in R:
    for c in walk(r):
        for k,v in c.props.items():
            last=k.split('.')[-1]
            if last in ('lov','authorizationScheme','list','breadcrumb','pageGroup') and ref(v):
                pg=c
                while pg.parent: pg=pg.parent
                add('f',pg.name if pg.kind=='page' else '-',f"{c.kind} {c.name}.{k}",loc(c,k),v,'PASS' if ref(v) in defs[last] else 'FAIL')
branches=[c for r in R for c in walk(r) if c.kind=='branch']
add('f','-','branches','-',f"{len(branches)} branches in export",'N/A' if not branches else 'CHECK')
# nav/breadcrumb targets
for kind in ('list','breadcrumb'):
    for l in shared.get(kind,{}).values():
        for e in walk(l):
            tp=e.get('target.page') or e.get('link.target.page') or e.get('targetPage')
            for k,v in e.props.items():
                if k.endswith('target.page') or k=='page':
                    try: ok=int(v) in pages
                    except: ok=v in {pg.get('alias') for pg in pages.values()} or v.startswith('&')
                    add('f','-',f"{kind} {l.name}/{e.name} target",loc(e,k),v,'PASS' if ok else 'FAIL')
# LOV column mapping
for l in shared.get('lov',{}).values():
    sc=select_cols(l.get('source.sqlQuery') or '') if l.get('source.sqlQuery') else None
    for k in ('columnMapping.return','columnMapping.display'):
        v=l.get(k)
        if v and sc is not None: add('g5',"-",f"lov {l.name} {k}",loc(l,k),f"{v} in {sc}",'PASS' if v.upper() in sc else 'FAIL')
# inline LOVs must return 2 columns
for r in R:
    for c in walk(r):
        q=c.get('lov.sqlQuery')
        if q:
            sc=select_cols(q); pg=c
            while pg.parent: pg=pg.parent
            add('g5',pg.name,f"{c.kind} {c.name} inline LOV columns",loc(c,'lov.sqlQuery'),f"{sc}",'PASS' if sc and len(sc)==2 else ('UNVERIFIED' if sc is None else 'FAIL'))
# g11: page processes run at Processing (after validations); APEXlang 'afterSubmit' = before computations and validations
for pid,p in sorted(pages.items()):
    for c in p.kids('process'):
        pt=c.get('execution.point')
        if pt in ('afterSubmit','processing'):
            ok = pt=='processing' or c.get('type') in ('clearSessionState',)
            add('g11',pid,f"process {c.name} execution point",loc(c,'execution.point'),pt,'PASS' if ok else 'FAIL')
json.dump(rows,open(sys.argv[3],'w'))
from collections import Counter
print(Counter((r[0],r[5].split()[0]) for r in rows))
