import re
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args=['--no-sandbox'])
    for u in ('REQ2','OFFICER1'):
        pg=b.new_page()
        pg.goto('http://localhost:8080/ords/r/xxcus/kyc/login'); pg.fill('#P9999_USERNAME',u); pg.fill('#P9999_PASSWORD','KycTest#2026'); pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
        s=re.search(r'session=(\d+)',pg.url).group(1)
        pg.goto(f'http://localhost:8080/ords/f?p=134:20:{s}'); pg.wait_for_load_state('networkidle')
        pg.click('.a-IRR-table td a'); pg.wait_for_load_state('networkidle')
        pg.fill('#P21_PARTY_NAME', 'Renamed by '+u)
        pg.evaluate("apex.page.submit({request:'SAVE', validate:false})"); pg.wait_for_load_state('networkidle')
        txt=pg.inner_text('body')
        m=re.search(r'(You are not allowed[^\n]*|Changes saved[^\n]*|Action Processed[^\n]*|Error[^\n]*)',txt)
        print(u,'->',m.group(1) if m else txt[:300].replace('\n',' '))
        pg.close()
    b.close()
