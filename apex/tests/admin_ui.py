# Chunk 3 browser test: admin console, feature tabs, Data Security, role privileges, application settings.
import re, sys
from playwright.sync_api import sync_playwright
ROOT='http://localhost:8080/ords'
USER=sys.argv[1] if len(sys.argv)>1 else 'ADMIN'
out=[]
def login(pg,u):
    pg.goto(f'{ROOT}/r/xxcus/kyc/login'); pg.fill('#P9999_USERNAME',u); pg.fill('#P9999_PASSWORD','KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    return re.search(r'session=(\d+)',pg.url).group(1)
# release 68: the shared setup screens are in COMMON (app 135), opened for KYC (page 99 sets the scope once)
COMMON_PAGES=set(range(101,116))|set(range(120,126))|set(range(130,138))|set(range(145,148))|set(range(150,154))|{180,181,182}
scoped=set()
def go(pg,s,page):
    if page in COMMON_PAGES:
        if s not in scoped:
            pg.goto(f'{ROOT}/f?p=135:99:{s}::NO::G_ADMIN_APP,G_ADMIN_LOCK,P99_PAGE:KYC,Y,{page}'); pg.wait_for_load_state('networkidle')
            scoped.add(s)
        pg.goto(f'{ROOT}/f?p=135:{page}:{s}')
    else:
        pg.goto(f'{ROOT}/f?p=134:{page}:{s}')
    pg.wait_for_load_state('networkidle')
def dialog(pg):
    pg.wait_for_selector('iframe[title]')
    for _ in range(40):
        fr=[f for f in pg.frames if f!=pg.main_frame and '/r/xxcus/' in f.url]
        if fr and fr[-1].query_selector('.t-Dialog-body, .t-Drawer-body, form'):
            fr[-1].wait_for_load_state('networkidle'); return fr[-1]
        pg.wait_for_timeout(250)
    raise RuntimeError('dialog did not load')
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args=['--no-sandbox'])
    pg=b.new_page(); s=login(pg,USER)
    go(pg,s,100)
    for g in ('basic-setup','workflow-integration','security','application'):
        el=pg.query_selector(f'#admin-{g}')
        out.append(f"console {g}: " + (' | '.join(x.inner_text().strip() for x in el.query_selector_all('.t-MediaList-title')) if el else '(hidden)'))
    go(pg,s,132)
    out.append('tabs on 132: '+' | '.join(x.inner_text().strip() for x in pg.query_selector_all('#feature-tabs .t-Tabs-label'))+
               ' ; current='+(pg.inner_text('#feature-tabs .is-active') if pg.query_selector('#feature-tabs .is-active') else '?'))
    go(pg,s,101); out.append('tabs on 101 (single-page feature): '+str(pg.query_selector('#feature-tabs') is not None))
    # Data Security: create an OWN_RECORDS rule for PARTY_VIEWER on XXCMP_RFIS with a wrong combination first
    go(pg,s,180); pg.click('button:has-text("Create Rule")'); f=dialog(pg)
    f.select_option('#P181_ROLE_CODE','PARTY_VIEWER'); f.select_option('#P181_TABLE_NAME','XXCMP_RFIS')
    f.select_option('#P181_RULE_TYPE','OWN_RECORDS'); f.click('button:has-text("Create")'); pg.wait_for_timeout(1500)
    f=[x for x in pg.frames if x!=pg.main_frame][-1]
    err=f.query_selector('.t-Alert-content, .a-Notification-item, .t-Form-error')
    out.append('rule without column -> '+(' / '.join(e.inner_text().strip()[:60] for e in f.query_selector_all('.t-Form-error, .a-Notification-item')) or 'no error'))
    f.wait_for_function("document.querySelectorAll('#P181_COLUMN_NAME option').length>1")
    f.select_option('#P181_COLUMN_NAME','RECIPIENT_USER_NAME'); f.click('button:has-text("Create")'); pg.wait_for_timeout(2500)
    fr=[x for x in pg.frames if x!=pg.main_frame and '/r/xxcus/' in x.url]
    if fr:
        err=fr[-1].query_selector('.t-Alert-content, .a-Notification-item, .t-Form-error')
        out.append('second create -> '+(err.inner_text().strip()[:80] if err else 'dialog still open'))
    else: out.append('second create -> saved, dialog closed')
    out.append('data security rows: '+str(len(pg.query_selector_all('#report .a-IRR-table tr'))-1))
    # Role privileges shuttle: give PARTY_VIEWER also PARTIES.CREATE
    go(pg,s,105); pg.click('#report .a-IRR-table tr:has-text("Party Viewer") a'); f=dialog(pg)
    before=f.eval_on_selector('#P106_PRIVILEGES_RIGHT','e=>[...e.options].map(o=>o.value)')
    if 'PARTIES.CREATE' in before:   # toggle, so the test can be repeated
        f.select_option('#P106_PRIVILEGES_RIGHT','PARTIES.CREATE'); f.click('#P106_PRIVILEGES_REMOVE')
    else:
        f.select_option('#P106_PRIVILEGES_LEFT','PARTIES.CREATE'); f.click('#P106_PRIVILEGES_MOVE')
    f.click('button:has-text("Apply Changes")'); pg.wait_for_timeout(2500)
    go(pg,s,182)
    row=[r.inner_text().replace('\t',' ') for r in pg.query_selector_all('#report .a-IRR-table tr') if 'PARTIES.CREATE' in r.inner_text()]
    out.append(f'role privileges before={before}; privileges tab PARTIES.CREATE row: {row[:1]}')
    # Application setting
    go(pg,s,10022); pg.click('#report .a-IRR-table tr:has-text("MAIL_FROM") a'); f=dialog(pg)
    f.fill('#P10023_VALUE','kyc@example.com'); f.click('button:has-text("Apply")'); pg.wait_for_timeout(2500)
    go(pg,s,10022)
    out.append('settings: '+' | '.join(r.inner_text().replace('\t',' ')[:60] for r in pg.query_selector_all('#report .a-IRR-table tr')[1:]))
    b.close()
print('\n'.join(out))
