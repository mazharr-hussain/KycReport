import sys,re,time
from playwright.sync_api import sync_playwright
alias,app,name=sys.argv[1],sys.argv[2],sys.argv[3]
user=sys.argv[4] if len(sys.argv)>4 else 'ADMIN'
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args=['--no-sandbox'])
    pg=b.new_page()
    pg.goto(f'http://localhost:8080/ords/r/xxcus/{alias}/login'); pg.fill('#P9999_USERNAME',user); pg.fill('#P9999_PASSWORD','KycTest#2026'); pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    s=re.search(r'session=(\d+)',pg.url).group(1)
    pg.goto(f'http://localhost:8080/ords/f?p={app}:21:{s}'); pg.wait_for_load_state('networkidle')
    pg.select_option('#P21_PARTY_TYPE','ORGANIZATION'); pg.wait_for_load_state('networkidle'); time.sleep(1)
    pg.fill('#P21_PARTY_NAME',name)
    for it in ('#P21_JURISDICTION','#P21_ENTITY_TYPE','#P21_DATA_PROVENANCE'):
        el=pg.query_selector(it)
        if el and el.is_visible():
            opts=[o.get_attribute('value') for o in el.query_selector_all('option') if o.get_attribute('value')]
            if opts: pg.select_option(it,opts[0])
    btn=pg.query_selector('button#CREATE, button:has-text("Create")')
    btn.click(); pg.wait_for_load_state('networkidle'); time.sleep(1)
    body=pg.inner_text('body')
    m=re.search(r'(Session state protection violation[^\n]*|ORA-\d{5}[^\n]*|Changes saved[^\n]*|Action Processed[^\n]*|error[^\n]{0,160})',body,re.I)
    print(alias,'->',m.group(1)[:220] if m else body[:300].replace('\n',' '))
    print('url',pg.url.split('/ords/')[-1][:100])
    b.close()
