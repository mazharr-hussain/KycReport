import sys, json, re
from playwright.sync_api import sync_playwright
BASE='http://localhost:8080/ords/r/xxcus/kyc'
APP=sys.argv[1] if len(sys.argv)>1 else '101'
USER=sys.argv[3] if len(sys.argv)>3 else 'ADMIN'
direct=[1,20,30,40,41,44,200,201,210,220,221,225,230,100,101,103,105,107,109,111,112,114,120,122,124,130,132,134,136,138,145,147,150,152,160,163,165,10010,10020,10030,10031,10032,10033,10051,180,182,10022]
res=[]
DENY=re.compile(r'You do not have access to|You are not allowed to|Access denied by|Insufficient privileges',re.I)
ERR=re.compile(r'Contact your application administrator|For an Editable|APEXDEV\.[A-Z_.]+|ORA-\d{5}|Session state protection violation|An unexpected (internal )?error|Technical Info|Error processing|not found|checksum',re.I)
def check(page,label):
    txt=page.inner_text('body') if page.query_selector('body') else ''
    d=DENY.search(txt)
    m=None if d else ERR.search(txt)
    title=page.title()
    return {'where':label,'url':page.url.split('/ords/')[-1][:90],'title':title,'denied':bool(d),'error':(txt[max(0,m.start()-80):m.end()+160].replace('\n',' ') if m else None)}
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args=['--no-sandbox'])
    pg=b.new_page(); jserr=[]
    pg.on('pageerror',lambda e: jserr.append(str(e)[:200]))
    pg.goto(f'{BASE}/login'); pg.fill('#P9999_USERNAME',USER); pg.fill('#P9999_PASSWORD','KycTest#2026'); pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    res.append(check(pg,'after login'))
    sess=re.search(r'session=(\d+)',pg.url)
    for pid in direct:
        pg.goto(f'http://localhost:8080/ords/f?p={APP}:{pid}:{sess.group(1) if sess else ""}'); pg.wait_for_load_state('networkidle')
        r=check(pg,f'page {pid}'); r['js']=jserr[:]; jserr.clear(); res.append(r)
        # follow first report link to detail page (list -> form/IG)
        link=None
        for a in pg.query_selector_all('.a-IRR-table a[href], .t-Report-report a[href], .a-GV a[href]'):
            h=a.get_attribute('href') or ''
            if (h.startswith('f?p=') or '/r/xxcus/' in h or 'session=' in h) and 'javascript' not in h:
                link=a; break
        if link and not r['denied'] and pid not in (1,40,10030):
            href=link.get_attribute('href')
            if href and 'javascript' not in href:
                if href.startswith('/'): href='http://localhost:8080'+href
                elif not href.startswith('http'): href='http://localhost:8080/ords/'+href
                try:
                    pg.goto(href); pg.wait_for_load_state('networkidle')
                    r=check(pg,f'page {pid} -> first row'); r['js']=jserr[:]; jserr.clear(); res.append(r)
                except Exception as e: res.append({'where':f'page {pid} -> first row','error':str(e)[:200]})
    b.close()
json.dump(res,open(sys.argv[2] if len(sys.argv)>2 else 'smoke.json','w'),indent=1)
bad=[r for r in res if r.get('error') or r.get('js')]
print(f"{USER}: checked {len(res)} views, problems {len(bad)}, denied pages {sorted(int(r['where'].split()[1]) for r in res if r.get('denied') and '->' not in r['where'] and r['where']!='after login')}")
for r in bad: print(json.dumps(r)[:400])
