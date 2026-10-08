# COMMON for IT (release 71): the Common Administrator (ADMIN) sees every application on the setup screens (selector
# All by default, Application column), can narrow to one application, opens components from the Administration
# tree; a KYC administrator who is not IT (MGR1) is refused. Usage: python3 common_it_ui.py
import re
from playwright.sync_api import sync_playwright
ROOT='http://localhost:8080/ords'
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
def apps_in_report(pg):
    # the values of the report's Application column (cells carry the heading's id)
    hid=next((th.get_attribute('id') for th in pg.query_selector_all('#report th') if th.inner_text().strip()=='Application'), None)
    return sorted(set(td.inner_text().strip() for td in pg.query_selector_all(f'#report td[headers="{hid}"]'))) if hid else []
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args=['--no-sandbox'])
    pg=b.new_page(); login(pg,'ADMIN')
    body=open_page(pg, 101)
    check('ORA-' not in body, 'Lookups opens without error')
    check(pg.input_value('#P0_ADMIN_APP')=='ALL', 'the selector opens on All applications')
    allapps=apps_in_report(pg); print('  applications listed:', allapps)
    check(len(allapps)>=2, 'All: rows of several applications are listed')
    pg.select_option('#P0_ADMIN_APP','KYC'); pg.wait_for_timeout(1500)
    body=open_page(pg, 101); kyc=apps_in_report(pg); print('  with KYC:', kyc)
    check(set(kyc) <= {'KYC','Shared'} and 'KYC' in kyc, 'KYC chosen: only KYC and shared rows')
    body=open_page(pg, 10020)
    check('Choose it in the Application selector' not in body, 'Feature Configuration works for the chosen application')
    pg.select_option('#P0_ADMIN_APP','ALL'); pg.wait_for_timeout(1500)
    body=open_page(pg, 10020)
    check('Choose it in the Application selector' in body, 'Feature Configuration asks for an application on All')
    nav=pg.text_content('#t_TreeNav') if pg.query_selector('#t_TreeNav') else ''
    check('Administration' in nav and 'Basic Setup' in nav, 'navigation tree has Administration and its groups')
    lk=pg.query_selector('#t_TreeNav a:has-text("Lookups")')
    check(lk is not None, 'Lookups opens from the tree')
    body=open_page(pg, 102)
    check(pg.query_selector('#P102_APPLICATION_CODE') is not None and 'ORA-' not in body, 'the lookup form has an Application field')
    for n in (105,107,112,120,130,132,134,136,150,152,180):
        body=open_page(pg, n)
        check('ORA-' not in body and 'error' not in body.lower()[:3000], f'page {n} on All: {pg.title()}')
    pg2=b.new_page(); login(pg2,'MGR1'); body=pg2.inner_text('body')
    check('do not have access' in body or 'You do not' in body or 'login' in pg2.url, 'MGR1 (not IT) is refused in COMMON')
    b.close()
print('FAILED' if fails else 'ALL PASSED')
