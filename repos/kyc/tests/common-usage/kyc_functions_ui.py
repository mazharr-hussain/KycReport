# Release 72: KYC's Administration lists only KYC's own setup screens (the shared setup is IT's, in COMMON);
# KYC Rules stays. Usage: python3 kyc_functions_ui.py
import re
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
    body=pg.inner_text('body')
    links={a.inner_text().strip().split('\n')[0]: a.get_attribute('href') for a in pg.query_selector_all('.t-MediaList-item a')}
    print('  KYC admin menu:', sorted(links))
    check('ORA-' not in body, 'KYC Administration opens without error')
    check(not any('/common/' in (h or '') for h in links.values()), 'no entry opens COMMON')
    check(any(t.startswith('KYC Rules') for t in links), 'KYC Rules stays in KYC')
    check(not any(t.startswith('Lookups') for t in links), 'Lookups (shared setup) is not in the KYC menu')
    b.close()
print('FAILED' if fails else 'ALL PASSED')
