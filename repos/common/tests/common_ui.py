# COMMON application skeleton (release 49): the Common Administrator opens Home; a user with only KYC access is refused.
import re, sys
from playwright.sync_api import sync_playwright
ROOT='http://localhost:8080/ords'
OTHER=sys.argv[1] if len(sys.argv)>1 else 'REQ2'
def login(pg,u):
    pg.goto(f'{ROOT}/r/xxcus/common/login'); pg.fill('#P9999_USERNAME',u); pg.fill('#P9999_PASSWORD','KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args=['--no-sandbox'])
    pg=b.new_page(); login(pg,'ADMIN')
    rows=[r.inner_text().replace('\t',' ') for r in pg.query_selector_all('#report_applications tbody tr, .t-Report-report tbody tr')]
    print('ADMIN home:', pg.title(), '| applications:', rows)
    pg=b.new_page(); login(pg,OTHER)
    body=pg.inner_text('body')
    print(f'{OTHER}:', 'refused' if 'do not have access' in body else 'NOT refused: '+pg.url)
    b.close()
