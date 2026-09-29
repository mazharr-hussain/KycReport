import re
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args=['--no-sandbox'])
    for u in ('REQ2','OFFICER1','REQ1'):
        pg=b.new_page()
        pg.goto('http://localhost:8080/ords/r/xxcus/kyc/login'); pg.fill('#P9999_USERNAME',u); pg.fill('#P9999_PASSWORD','KycTest#2026'); pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
        s=re.search(r'session=(\d+)',pg.url).group(1)
        menu=[t.strip() for t in pg.inner_text('#t_TreeNav').split('\n') if t.strip()]
        pg.goto(f'http://localhost:8080/ords/f?p=101:20:{s}'); pg.wait_for_load_state('networkidle')
        if 'do not have access' in pg.inner_text('body'): print(u,'menu=',menu,'| page 20 denied'); pg.close(); continue
        create20=pg.query_selector('button:has-text("Create")') is not None
        rows=len(pg.query_selector_all('.a-IRR-table tr'))-1
        pg.click('.a-IRR-table td a'); pg.wait_for_load_state('networkidle')
        btns=[x.inner_text().strip() for x in pg.query_selector_all('button') if x.is_visible() and x.inner_text().strip()]
        print(u,'menu=',menu,'| p20 create:',create20,'rows:',rows,'| party page buttons:',btns)
        pg.close()
    b.close()
