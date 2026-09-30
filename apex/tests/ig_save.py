# Editable IG save (page 102 lookup values): change the description of the first value and save.
import re, time
from playwright.sync_api import sync_playwright
ROOT='http://localhost:8080/ords'
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args=['--no-sandbox'])
    pg=b.new_page()
    pg.goto(f'{ROOT}/r/xxcus/kyc/login'); pg.fill('#P9999_USERNAME','ADMIN'); pg.fill('#P9999_PASSWORD','KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    s=re.search(r'session=(\d+)',pg.url).group(1)
    pg.goto(f'{ROOT}/f?p=101:101:{s}'); pg.wait_for_load_state('networkidle')
    pg.click('#report .a-IRR-table tr:has-text("LANGUAGE") td a'); pg.wait_for_load_state('networkidle')
    stamp='IG test '+time.strftime('%H:%M:%S')
    pg.evaluate("""s=>{const g=apex.region('values').widget().interactiveGrid('getViews','grid');
        const m=g.model; const r=m.recordAt(0); m.setValue(r,'DESCRIPTION',s);}""", stamp)
    pg.evaluate("apex.region('values').widget().interactiveGrid('getActions').invoke('save')"); pg.wait_for_timeout(3000)
    body=pg.inner_text('body')
    err=None; print(body[body.find('Error'):body.find('Error')+400] if 'Error' in body else '')
    print('stamp',stamp,'| page message:',err.group(1) if err else 'no error')
    b.close()
