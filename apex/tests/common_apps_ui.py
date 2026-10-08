# COMMON applications (release 71): IT lists the applications, opens one (function switches, setup overview with
# links filtered to the application), registers a new one (all functions off), and a setup form offers an application
# only when the page's function is switched on for it. Cleans up its test application. Usage: python3 common_apps_ui.py
import re, subprocess
from playwright.sync_api import sync_playwright
ROOT='http://localhost:8080/ords'
SQL='/tmp/claude-0/-home-user-KycReport/5e8c20fd-6c82-5747-8066-a7d503f76bd3/scratchpad/sqlcl/bin/sql'
CONN='xxfusion/"Xxfusion#Local1"@localhost:1521/FREEPDB1'
fails=0
def check(ok, msg):
    global fails
    print(('PASS ' if ok else 'FAIL ')+msg); fails+= 0 if ok else 1
def db(stmt):
    out=subprocess.run([SQL,'-S',CONN],input=f'set heading off feedback off\n{stmt}\nexit\n',capture_output=True,text=True).stdout
    return '\n'.join(l for l in out.splitlines() if l.strip() and 'JAVA' not in l).strip()
def login(pg,u):
    pg.goto(f'{ROOT}/r/xxcus/common/login'); pg.fill('#P9999_USERNAME',u); pg.fill('#P9999_PASSWORD','KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
def open_page(pg, n):
    pg.goto(re.sub(r'/r/xxcus/common/[^?]*', f'/r/xxcus/common/{n}', pg.url)); pg.wait_for_load_state('networkidle')
    return pg.inner_text('body')
db("delete from xxfnd_applications where application_code = 'ZTEST';\ncommit;")
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args=['--no-sandbox'])
    pg=b.new_page(); login(pg,'ADMIN')
    body=open_page(pg, 160)
    check('ORA-' not in body and 'KYC' in body and 'COMMON' in body, 'Applications lists COMMON and KYC')
    pg.click('#report a:has-text("KYC")'); pg.wait_for_load_state('networkidle'); body=pg.inner_text('body')
    check('Common Functions' in body and 'Setup Overview' in body and 'ORA-' not in body, 'the KYC application shows its functions and setup overview')
    ov=pg.inner_text('#overview') if pg.query_selector('#overview') else ''
    check('Lookups' in ov and 'On' in ov, 'overview: Lookups switched on for KYC')
    pg.click('#overview a:has-text("Lookups")'); pg.wait_for_load_state('networkidle')
    check(pg.input_value('#P0_ADMIN_APP')=='KYC' and 'Lookups' in pg.title(), 'the overview link opens Lookups filtered to KYC')
    open_page(pg, 160); pg.click('button:has-text("Register Application")'); pg.wait_for_load_state('networkidle')
    pg.fill('#P161_APPLICATION_CODE','ztest'); pg.fill('#P161_APPLICATION_NAME','Test Application')
    pg.select_option('#P161_SCHEMA_NAME','XXCUS'); pg.click('button:has-text("Register")'); pg.wait_for_load_state('networkidle')
    body=pg.inner_text('body')
    check('ORA-' not in body, 'registering a new application saves without error')
    n=db("select count(*) || '/' || sum(case when enabled_flag = 'Y' then 1 else 0 end) from xxfnd_application_functions where application_code = 'ZTEST';")
    check(n=='12/0', f'the new application has 12 function switches, all off ({n})')
    open_page(pg, 101); pg.select_option('#P0_ADMIN_APP','ALL'); pg.wait_for_timeout(1500)
    open_page(pg, 102); opts=[o.get_attribute('value') for o in pg.query_selector_all('#P102_APPLICATION_CODE option')]
    check('KYC' in opts and 'ZTEST' not in opts, 'Lookup form: ZTEST not offered while Lookups is off')
    db("update xxfnd_application_functions set enabled_flag = 'Y' where application_code = 'ZTEST' and feature_code = 'LOOKUPS';\ncommit;")
    open_page(pg, 102); opts=[o.get_attribute('value') for o in pg.query_selector_all('#P102_APPLICATION_CODE option')]
    check('ZTEST' in opts, 'Lookup form: ZTEST offered once Lookups is switched on')
    b.close()
db("delete from xxfnd_applications where application_code = 'ZTEST';\ncommit;")
print('FAILED' if fails else 'ALL PASSED')
