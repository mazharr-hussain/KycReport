"""Release 89 browser check (COMMON): the Data Model as IT (ADMIN) - listed under Platform, the object catalogue
(page 175), an object (176) and the diagram of a group (177). Usage: HOST=http://localhost:8080 python3 r89_data_model_ui.py"""
from playwright.sync_api import sync_playwright
import os
S=os.environ.get('SHOTS', '/tmp')
R=os.environ.get('HOST', 'http://localhost:8080') + '/ords/r/xxcus/common'
def chk(ok,t): print(('PASS ' if ok else 'FAIL ')+t)
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
    pg=b.new_page(viewport={'width':1400,'height':1000}); errs=[]
    pg.on('pageerror',lambda e: errs.append(str(e)[:200]))
    pg.goto(f'{R}/login',timeout=120000)
    pg.fill('#P9999_USERNAME','ADMIN'); pg.fill('#P9999_PASSWORD','KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
    sess=pg.url.split('session=')[1].split('&')[0]
    pg.goto(f'{R}/data-model?session={sess}',timeout=120000); pg.wait_for_load_state('networkidle')
    pg.locator('.t-Breadcrumb a', has_text='Platform').first.click(); pg.wait_for_load_state('networkidle')
    chk('Data Model' in pg.inner_text('body'),'Data Model is listed under Platform')
    pg.goto(f'{R}/data-model?session={sess}',timeout=120000); pg.wait_for_load_state('networkidle')
    pg.fill('#objects_search_field','XXFND_ROLES'); pg.keyboard.press('Enter'); pg.wait_for_timeout(2500)
    body=pg.inner_text('#objects')
    chk('XXFND_ROLES' in body,'the catalogue lists COMMON objects (search XXFND_ROLES)')
    chk(pg.locator('#P175_APPLICATION').input_value()=='COMMON','COMMON is chosen first')
    pg.screenshot(path=f'{S}/r89_p175.png')
    pg.locator('#objects td a[href*="database-object"]', has_text='XXFND_ROLES').first.click(); pg.wait_for_load_state('networkidle')
    body=pg.inner_text('body')
    chk('ROLE_CODE' in body and 'Primary key' in body,'the object page shows columns and constraints')
    chk('XXFND_PRIVILEGE_PKG' in body or 'Used By' in body,'and its dependencies')
    pg.screenshot(path=f'{S}/r89_p176.png', full_page=True)
    pg.goto(f'{R}/data-model?session={sess}'); pg.wait_for_load_state('networkidle')
    pg.click('button:has-text("Diagram")'); pg.wait_for_load_state('networkidle')
    pg.select_option('#P177_GROUP','Security'); pg.wait_for_load_state('networkidle')
    try:
        pg.wait_for_selector('#dm-erd svg', timeout=90000); ok=True
    except Exception: ok=False
    chk(ok,'the Security diagram is drawn ('+pg.inner_text('#dm-erd')[:80].replace('\n',' ')+')')
    pg.screenshot(path=f'{S}/r89_p177.png')
    chk(not errs,'no JavaScript error '+str(errs[:2]))
    b.close()
