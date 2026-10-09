# COMMON applications (release 73): no application filter; Applications lists the business applications (COMMON is the
# instance); an application's page shows "Managed in the Application", its setup overview (setup types with Add) and its
# setup rows (Edit); setup types decide which applications a form offers; Setup Types pages open; a function managed in
# KYC appears in KYC's Administration and opens the COMMON screen in KYC's Setup dialog for KYC only.
# Cleans up its test data. Usage: python3 common_apps_ui.py
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
def login(pg,app,u):
    pg.goto(f'{ROOT}/r/xxcus/{app}/login'); pg.fill('#P9999_USERNAME',u); pg.fill('#P9999_PASSWORD','KycTest#2026')
    pg.click('#LOGIN, button:has-text("Sign In")'); pg.wait_for_load_state('networkidle')
def open_page(pg, n, app='common'):
    sess=re.search(r'session=(\d+)', pg.url).group(1)
    pg.goto(f'{ROOT}/r/xxcus/{app}/{n}?session={sess}'); pg.wait_for_load_state('networkidle')
    return pg.inner_text('body')
def options(pg, item):
    return [o.get_attribute('value') for o in pg.query_selector_all(f'#{item} option')]
def reset():
    db("""delete from xxfnd_applications where application_code = 'ZTEST';
update xxfnd_setup_types set all_applications_flag = 'Y' where setup_type_code = 'LOOKUPS';
delete from xxfnd_setup_type_apps where setup_type_code = 'LOOKUPS';
update xxfnd_application_functions set managed_in_app_flag = 'N' where application_code = 'KYC';
commit;""")
reset()
row=db("""select max(ur.user_name || ',' || p.feature_code || ',' || f.feature_name) keep (dense_rank first order by f.display_sequence)
  from xxfnd_user_roles_v ur
  join xxfnd_role_privileges rp on rp.role_code = ur.role_code join xxfnd_privileges p on p.privilege_code = rp.privilege_code
  join xxfnd_features f on f.feature_code = p.feature_code
 where ur.application_code = 'KYC' and ur.active_flag = 'Y'
   and p.feature_code in (select feature_code from xxfnd_application_functions where application_code = 'KYC')
   and ur.user_name not in (select user_name from xxfnd_user_roles_v where role_code = 'COMMON_ADMIN' and active_flag = 'Y');""")
deleg, feat, fname = (row.split(',', 2) + ['', '', ''])[:3] if row else ('', '', '')
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args=['--no-sandbox'])
    pg=b.new_page(); login(pg,'common','ADMIN')
    body=open_page(pg, 1)
    check(pg.query_selector('#P0_ADMIN_APP') is None, 'no application filter')
    check(pg.query_selector('a:has-text("KYC")') is not None, 'Home: the application code is a link')
    body=open_page(pg, 160)
    rep=pg.inner_text('#report')
    check('ORA-' not in body and 'KYC' in rep and 'COMMON' not in rep, 'Applications lists KYC, not COMMON (the instance)')
    pg.click('#report a:has-text("KYC")'); pg.wait_for_load_state('networkidle'); body=pg.inner_text('body')
    check('Managed in the Application' in body and 'Setup Overview' in body and 'ORA-' not in body, 'KYC: managed switches and setup overview')
    ov=pg.inner_text('#overview') if pg.query_selector('#overview') else ''
    check('Lookups' in ov and 'Add' in ov and 'Value Sets' not in ov, 'overview: Lookups with Add; Value Sets (instance only) not listed')
    rows=pg.inner_text('#setup-rows') if pg.query_selector('#setup-rows') else ''
    check("Data Security Rules" in rows and "Attachment Pages" in rows, "setup rows of KYC listed with their setup type")
    pg.click('#overview a:has-text("Lookups")'); pg.wait_for_load_state('networkidle'); body=pg.inner_text('body')
    check('Lookups' in pg.title() and "Application = 'KYC'" in body and 'ORA-' not in body, 'the overview link opens Lookups filtered to KYC')
    open_page(pg, 160); pg.wait_for_timeout(1000); pg.click('button:has-text("Register Application")'); pg.wait_for_load_state('networkidle')
    pg.fill('#P161_APPLICATION_CODE','ztest'); pg.fill('#P161_APPLICATION_NAME','Test Application')
    pg.select_option('#P161_SCHEMA_NAME','XXCUS'); pg.click('button:has-text("Register")'); pg.wait_for_load_state('networkidle')
    check('ORA-' not in pg.inner_text('body'), 'registering a new application saves without error')
    n=db("select count(*) || '/' || sum(case when managed_in_app_flag = 'Y' then 1 else 0 end) from xxfnd_application_functions where application_code = 'ZTEST';")
    check(n.endswith('/0') and not n.startswith('0'), f'the new application has its functions, none managed in it ({n})')
    open_page(pg, 102); o=options(pg,'P102_APPLICATION_CODE')
    check('KYC' in o and 'ZTEST' in o and 'COMMON' not in o and '' in o, f'Lookup form: instance, KYC and ZTEST offered, not COMMON ({o})')
    db("""update xxfnd_setup_types set all_applications_flag = 'N' where setup_type_code = 'LOOKUPS';
insert into xxfnd_setup_type_apps (setup_type_code, application_code) values ('LOOKUPS', 'KYC');
commit;""")
    open_page(pg, 102); o=options(pg,'P102_APPLICATION_CODE')
    check('KYC' in o and 'ZTEST' not in o, f'Lookups limited to KYC: ZTEST no longer offered ({o})')
    open_page(pg, 151); o=[x for x in options(pg,'P151_APPLICATION_CODE') if x]
    check(o==[], f'Value Set form (instance only): no application offered ({o})')
    body=open_page(pg, 162)
    check('Setup Types' in pg.title() and 'Lookups' in body and 'ORA-' not in body, 'Setup Types list opens')
    open_page(pg, 130); pg.click('button:has-text("Register Entity")'); pg.wait_for_timeout(4000)
    dlg=[f for f in pg.frames[1:] if f.query_selector('#P131_TABLE_NAME')]
    t=[o.get_attribute('value') for o in dlg[0].query_selector_all('#P131_TABLE_NAME option') if o.get_attribute('value')] if dlg else []
    check(len(t) > 5 and 'XXCMP_PARTIES' in t, f'Document Entity: Table is a list ({len(t)} tables)')
    body=open_page(pg, 147)
    check('Workflow Processes' in body and 'KYC_CASE' in body.upper().replace(' ','_') or 'KYC Case' in body, 'Workflow Processes listed with their switches')
    # delegated administration
    if not deleg:
        print('SKIP no KYC user with a common function privilege (delegation)')
    else:
        db(f"update xxfnd_application_functions set managed_in_app_flag = 'Y' where application_code = 'KYC' and feature_code = '{feat}';\ncommit;")
        k=b.new_page(); login(k,'kyc',deleg)
        body=open_page(k, 'administration', 'kyc')
        check(f'{fname} (shared setup)' in body, f'{deleg}: {fname} (shared setup) is in KYC Administration')
        k.click(f'a:has-text("{fname} (shared setup)")'); k.wait_for_timeout(6000)
        fr=None
        for f in k.frames:
            if '/common/' in f.url and 'r/xxcus' in f.url: fr=f
        ftxt=fr.inner_text('body') if fr else ''
        check(fr is not None and 'ORA-' not in ftxt and 'not allowed' not in ftxt.lower() and 'do not have access' not in ftxt.lower(),
              f'the Setup dialog shows the COMMON {fname} screen inside KYC ({ftxt[:80]!r})')
        if fr:
            check(fr.query_selector('.t-Header') is None or not fr.is_visible('.t-Header'), 'no COMMON header in the dialog')
        c=b.new_page(); login(c,'common',deleg)
        check('Home' not in c.title() or 'not' in c.inner_text('body').lower(), f'{deleg} cannot use COMMON directly')
    b.close()
reset()
print('FAILED' if fails else 'ALL PASSED')
