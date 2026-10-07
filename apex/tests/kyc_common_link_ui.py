# Release 68: KYC's Administration opens the shared setup screens in COMMON, for KYC (no second sign-in, no
# application selector, KYC's rows), and KYC's own setup screens (KYC rules, approval matrix) stay in KYC.
import re, sys
from playwright.sync_api import sync_playwright
ROOT='http://localhost:8080/ords'
fails=0
def check(ok, msg):
    global fails
    print(('PASS ' if ok else 'FAIL ')+msg); fails+= 0 if ok else 1
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args=['--no-sandbox'])
    pg=b.new_page()
    pg.goto(f'{ROOT}/r/xxcus/kyc/login'); pg.fill('#P9999_USERNAME','ADMIN'); pg.fill('#P9999_PASSWORD','KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    pg.goto(re.sub(r'/r/xxcus/kyc/[^?]*', '/r/xxcus/kyc/administration', pg.url)); pg.wait_for_load_state('networkidle')
    links={a.inner_text().strip().split('\n')[0]: a.get_attribute('href') for a in pg.query_selector_all('.t-MediaList-item a')}
    print('  KYC admin menu:', sorted(links))
    check(any('/common/' in (h or '') for h in links.values()), 'shared setup entries point to COMMON')
    check(any('/kyc/' in (h or '') or (h or '').startswith('f?p') for t,h in links.items() if 'KYC Rules' in t) or 'KYC Rules' not in links,
          'KYC Rules stays in KYC')
    lk=[t for t in links if t.startswith('Lookups')]
    check(bool(lk), 'Lookups is in the KYC admin menu')
    if lk:
        pg.goto(links[lk[0]] if links[lk[0]].startswith('http') else ROOT+'/'+links[lk[0]].lstrip('/').replace('ords/','',1))
        pg.wait_for_load_state('networkidle'); body=pg.inner_text('body')
        check('/common/' in pg.url and 'Lookups' in pg.title(), f'Lookups opens in COMMON ({pg.title()})')
        check('Sign In' not in body and 'P9999_USERNAME' not in pg.content(), 'no second sign-in')
        check(pg.query_selector('#P0_ADMIN_APP') is None, 'no application selector (locked to KYC)')
        check('ORA-' not in body, 'no error')
    b.close()
print('FAILED' if fails else 'ALL PASSED')
