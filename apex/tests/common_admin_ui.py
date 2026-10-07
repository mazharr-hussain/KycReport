# COMMON administration (release 61+): the Common Administrator opens Administration with the application selector;
# a user without an admin role is refused. Usage: python3 common_admin_ui.py [OTHER_USER] [page,page,...]
import re, sys
from playwright.sync_api import sync_playwright
ROOT='http://localhost:8080/ords'
OTHER=sys.argv[1] if len(sys.argv)>1 else 'REQ2'
PAGES=[int(x) for x in (sys.argv[2] if len(sys.argv)>2 else '100').split(',')]
fails=0
def check(ok, msg):
    global fails
    print(('PASS ' if ok else 'FAIL ')+msg); fails+= 0 if ok else 1
def login(pg,u):
    pg.goto(f'{ROOT}/r/xxcus/common/login'); pg.fill('#P9999_USERNAME',u); pg.fill('#P9999_PASSWORD','KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
def open_page(pg, n):
    pg.goto(re.sub(r'/r/xxcus/common/[^?]*', f'/r/xxcus/common/{n}', pg.url)); pg.wait_for_load_state('networkidle')
    return pg.inner_text('body')
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args=['--no-sandbox'])
    pg=b.new_page(); login(pg,'ADMIN')
    for n in PAGES:
        body=open_page(pg, n)
        bad=[w for w in ('ORA-','error occurred','do not have access','not found','Page not available') if w in body]
        check(not bad, f'ADMIN page {n}: {pg.title()} {bad or ""}')
        if n==100:
            check(pg.query_selector('#P0_ADMIN_APP') is not None, 'page 100 shows the application selector')
            links=[a.inner_text().split('\n')[0] for a in pg.query_selector_all('.t-MediaList-item a, .t-MediaList-title')]
            print('  menu:', links)
    pg2=b.new_page(); login(pg2,OTHER); body=open_page(pg2, 100)
    check('do not have access' in body or 'You do not' in body, f'{OTHER} is refused on Administration')
    b.close()
print('FAILED' if fails else 'ALL PASSED')
